using Azure.Core;
using Azure.Data.AppConfiguration;
using Azure.Identity;
using Azure.Monitor.OpenTelemetry.AspNetCore;
using Azure.Security.KeyVault.Secrets;
using OpenTelemetry.Resources;
using System.Text.Json;

var builder = WebApplication.CreateBuilder(args);

//https://learn.microsoft.com/en-us/azure/azure-monitor/app/opentelemetry-enable?tabs=aspnetcore
builder.Services.AddOpenTelemetry()
.UseAzureMonitor()
.ConfigureResource(rb => rb.AddAttributes(new Dictionary<string, object> {
            { "service.name", Environment.GetEnvironmentVariable("SERVICE_NAME")! },
        { "service.namespace", Environment.GetEnvironmentVariable("SERVICE_NAMESPACE")! },
        { "service.instance.id", Environment.GetEnvironmentVariable("SERVICE_INSTANCE_ID")!}}.Where(d => d.Value is not null).ToDictionary()));

var credential = CreateCredential(builder.Environment, builder.Configuration);
builder.Services.AddSingleton<TokenCredential>(credential);
builder.Services.AddSingleton<KeyVaultSecretReader>();

var app = builder.Build();

var appConfigurationEndpoint = app.Configuration["Endpoints:AppConfiguration"];

if (!string.IsNullOrWhiteSpace(appConfigurationEndpoint))
{
    app.Logger.LogInformation("Azure App Configuration endpoint detected. Starting bootstrap for {AppConfigurationEndpoint}.", appConfigurationEndpoint);

    await AppConfigurationBootstrapper.EnsureSettingsExistAsync(
        app.Configuration,
        new Uri(appConfigurationEndpoint),
        credential,
        app.Environment,
        app.Logger,
        CancellationToken.None
    );

    builder.Configuration.AddAzureAppConfiguration(options =>
    {
        options.Connect(new Uri(appConfigurationEndpoint), credential);
        options.ConfigureKeyVault(keyVaultOptions =>
        {
            keyVaultOptions.SetCredential(credential);
        });
    });

    app.Logger.LogInformation("Azure App Configuration provider added for {AppConfigurationEndpoint}.", appConfigurationEndpoint);
}
else
{
    app.Logger.LogInformation("No Azure App Configuration endpoint configured. Skipping bootstrap.");
}

app.MapGet("/", async (IConfiguration configuration, IHostEnvironment environment, KeyVaultSecretReader secretReader, CancellationToken cancellationToken) =>
{
    var messageKey = configuration["AppConfiguration:Keys:Message"] ?? "SampleApp:Settings:Message";
    var keyVaultReferenceKey = configuration["AppConfiguration:Keys:KeyVaultReference"] ?? "SampleApp:Settings:KeyVaultMessage";
    var appServiceKeyVaultReferenceValue = configuration["secret:temp1"];
    var keyVaultSecret = await secretReader.ReadAsync(cancellationToken);
    var valuesMatch = !string.IsNullOrWhiteSpace(appServiceKeyVaultReferenceValue)
        && !string.IsNullOrWhiteSpace(keyVaultSecret.Value)
        && string.Equals(appServiceKeyVaultReferenceValue, keyVaultSecret.Value, StringComparison.Ordinal);

    return Results.Ok(new
    {
        application = "AppConfigKeyVaultSample",
        environment = environment.EnvironmentName,
        endpoints = new
        {
            appConfiguration = configuration["Endpoints:AppConfiguration"],
            keyVault = configuration["KeyVault:VaultUri"]
        },
        appConfiguration = new
        {
            messageKey,
            message = configuration[messageKey] ?? "No App Configuration value was found for the configured message key.",
            keyVaultReferenceKey,
            keyVaultReferenceValue = configuration[keyVaultReferenceKey] ?? "No App Configuration Key Vault reference was found for the configured key."
        },
        keyVault = new
        {
            keyVaultSecret.SecretName,
            keyVaultSecret.Value,
            keyVaultSecret.Error
        },
        comparison = new
        {
            directSecretName = configuration["KeyVault:SecretName"],
            directSecretValue = keyVaultSecret.Value,
            appServiceKeyVaultReferenceKey = "secret:temp1",
            appServiceKeyVaultReferenceValue,
            valuesMatch
        }
    });
});

app.MapGet("/healthz", () => Results.Ok(new { status = "ok" }));

app.Run();

static TokenCredential CreateCredential(IHostEnvironment environment, IConfiguration configuration)
{
    if (environment.IsDevelopment())
    {
        return new DefaultAzureCredential();
    }

    var managedIdentityClientId = configuration["Azure:ManagedIdentityClientId"];

    if (string.IsNullOrWhiteSpace(managedIdentityClientId))
    {
        throw new InvalidOperationException(
            "Azure:ManagedIdentityClientId must be configured when running outside Development so the app can use the user-assigned managed identity explicitly."
        );
    }

    return new ManagedIdentityCredential(ManagedIdentityId.FromUserAssignedClientId(managedIdentityClientId));
}

sealed class KeyVaultSecretReader(IConfiguration configuration, TokenCredential credential, ILogger<KeyVaultSecretReader> logger)
{
    public async Task<KeyVaultSecretResult> ReadAsync(CancellationToken cancellationToken)
    {
        var vaultUri = configuration["KeyVault:VaultUri"];
        var secretName = configuration["KeyVault:SecretName"];

        if (string.IsNullOrWhiteSpace(vaultUri) || string.IsNullOrWhiteSpace(secretName))
        {
            return new KeyVaultSecretResult(secretName, null, "Set KeyVault:VaultUri and KeyVault:SecretName to enable direct Key Vault reads.");
        }

        try
        {
            var secretClient = new SecretClient(new Uri(vaultUri), credential);
            var secret = await secretClient.GetSecretAsync(secretName, cancellationToken: cancellationToken);

            return new KeyVaultSecretResult(secret.Value.Name, secret.Value.Value, null);
        }
        catch (Exception exception)
        {
            logger.LogError(exception, "Failed to read secret {SecretName} from Key Vault.", secretName);
            return new KeyVaultSecretResult(secretName, null, exception.Message);
        }
    }
}

sealed record KeyVaultSecretResult(string? SecretName, string? Value, string? Error);

sealed class AppConfigurationBootstrapper
{
    private const string KeyVaultReferenceContentType = "application/vnd.microsoft.appconfig.keyvaultref+json;charset=utf-8";

    public static async Task EnsureSettingsExistAsync(
        IConfiguration configuration,
        Uri appConfigurationEndpoint,
        TokenCredential credential,
        IHostEnvironment environment,
        ILogger logger,
        CancellationToken cancellationToken)
    {
        if (environment.IsDevelopment())
        {
            logger.LogInformation("Skipping Azure App Configuration bootstrap in Development environment.");
            return;
        }

        var messageKey = configuration["AppConfiguration:Keys:Message"] ?? "SampleApp:Settings:Message";
        var keyVaultReferenceKey = configuration["AppConfiguration:Keys:KeyVaultReference"] ?? "SampleApp:Settings:KeyVaultMessage";
        var messageValue = configuration["AppConfiguration:Bootstrap:MessageValue"] ?? "Hello from Azure App Configuration.";
        var keyVaultSecretUri = BuildKeyVaultSecretUri(configuration);

        if (string.IsNullOrWhiteSpace(keyVaultSecretUri))
        {
            logger.LogWarning("Skipping Azure App Configuration bootstrap because Key Vault secret URI could not be built. Configure KeyVault:VaultUri and KeyVault:SecretName.");
            return;
        }

        logger.LogInformation(
            "Ensuring Azure App Configuration bootstrap settings exist at {AppConfigurationEndpoint}. MessageKey: {MessageKey}, KeyVaultReferenceKey: {KeyVaultReferenceKey}.",
            appConfigurationEndpoint,
            messageKey,
            keyVaultReferenceKey);

        try
        {
            var client = new ConfigurationClient(appConfigurationEndpoint, credential);

            await client.SetConfigurationSettingAsync(
                new ConfigurationSetting(messageKey, messageValue),
                cancellationToken: cancellationToken
            );

            logger.LogInformation("Ensured Azure App Configuration setting {MessageKey}.", messageKey);

            await client.SetConfigurationSettingAsync(
                new ConfigurationSetting(keyVaultReferenceKey, JsonSerializer.Serialize(new { uri = keyVaultSecretUri }))
                {
                    ContentType = KeyVaultReferenceContentType
                },
                cancellationToken: cancellationToken
            );

            logger.LogInformation("Ensured Azure App Configuration Key Vault reference {KeyVaultReferenceKey}.", keyVaultReferenceKey);
        }
        catch (Exception exception)
        {
            logger.LogError(exception, "Failed to bootstrap Azure App Configuration settings at {AppConfigurationEndpoint}.", appConfigurationEndpoint);
            throw;
        }
    }

    private static string? BuildKeyVaultSecretUri(IConfiguration configuration)
    {
        var vaultUri = configuration["KeyVault:VaultUri"];
        var secretName = configuration["KeyVault:SecretName"];

        if (string.IsNullOrWhiteSpace(vaultUri) || string.IsNullOrWhiteSpace(secretName))
        {
            return null;
        }

        return $"{vaultUri.TrimEnd('/')}/secrets/{secretName}";
    }
}
