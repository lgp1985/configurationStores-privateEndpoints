# AppConfigKeyVaultSample

This sample ASP.NET Core application is intentionally separated from the Bicep under `infra/`.

It demonstrates:

- reading regular settings from Azure App Configuration with `DefaultAzureCredential` during local development
- switching to an explicit `ManagedIdentityCredential` in Azure-hosted environments
- bootstrapping required App Configuration keys at startup in Azure-hosted environments
- resolving App Configuration Key Vault references with the same credential
- reading a secret directly from Azure Key Vault with `SecretClient`
- comparing the direct Key Vault read with the `secret__temp1` App Service Key Vault reference so users can verify both values match

## Configuration

The application reads these settings from configuration or environment variables:

- `Endpoints:AppConfiguration`
- `KeyVault:VaultUri`
- `KeyVault:SecretName`
- `Azure:ManagedIdentityClientId`

When the app runs in `Development`, it uses `DefaultAzureCredential` so local developer credentials work.

When the app runs outside `Development`, it uses `ManagedIdentityCredential` explicitly and requires `Azure:ManagedIdentityClientId` for the user-assigned managed identity.

## Local Run

1. Sign in locally with Azure credentials that can read the target App Configuration store and Key Vault.
2. Set the required configuration values in `appsettings.json`, user secrets, or environment variables.
3. Run the app:

```bash
dotnet run --project src/AppConfigKeyVaultSample/AppConfigKeyVaultSample.csproj
```

Browse to `/` to see the values loaded from App Configuration and Key Vault.

The response also includes a `comparison` section that shows:

- the value read directly from Key Vault using `KeyVault:SecretName`
- the value resolved by App Service from the `secret__temp1` Key Vault reference
- a `valuesMatch` flag so users can confirm both retrieval paths return the same secret

## Expected App Configuration Keys

- `SampleApp:Settings:Message`
- `SampleApp:Settings:KeyVaultMessage`

When the app runs outside `Development`, it bootstraps these keys on startup if they don't exist yet:

- `SampleApp:Settings:Message` gets a plain text value
- `SampleApp:Settings:KeyVaultMessage` gets an App Configuration Key Vault reference to `KeyVault:SecretName`

The managed identity used by the app must have `App Configuration Data Owner` on the store for bootstrap writes.
