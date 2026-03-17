using Azure.Core;
using Azure.Identity;
using Azure.Security.KeyVault.Secrets;

var builder = WebApplication.CreateBuilder(args);

var credential = CreateCredential(builder.Environment, builder.Configuration);
var appConfigurationEndpoint = builder.Configuration["Endpoints:AppConfiguration"];

if (!string.IsNullOrWhiteSpace(appConfigurationEndpoint))
{
	builder.Configuration.AddAzureAppConfiguration(options =>
	{
		options.Connect(new Uri(appConfigurationEndpoint), credential);
		options.ConfigureKeyVault(keyVaultOptions =>
		{
			keyVaultOptions.SetCredential(credential);
		});
	});
}

builder.Services.AddSingleton<TokenCredential>(credential);
builder.Services.AddSingleton<KeyVaultSecretReader>();

var app = builder.Build();

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
