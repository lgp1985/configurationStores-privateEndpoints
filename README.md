# Azure App Configuration with Private Endpoint and Key Vault Access from App Service

This repository shows one way to model an Azure environment where:

- Azure App Configuration is deployed as a `Microsoft.AppConfiguration/configurationStores` resource.
- The App Configuration store is reachable through an associated Private Endpoint.
- A private DNS zone is linked so name resolution for the private endpoint works inside the virtual network.
- An Azure Key Vault stores a secret that is exposed to an Azure Web App through an app setting backed by a Key Vault reference.
- The Web App uses a user-assigned managed identity to resolve the Key Vault reference.

The repository is focused on infrastructure. It demonstrates how to wire the Azure resources together in Bicep rather than how to implement application code that consumes App Configuration.

## What This Deploys

At a high level, the Bicep in this repo deploys:

- A network resource group and a workload resource group.
- A virtual network with:
  - one subnet delegated to `Microsoft.Web/serverFarms` for App Service VNet integration and Key Vault access through service endpoints
  - one subnet dedicated to the App Configuration Private Endpoint
- A route table and NSG used by the subnets.
- A Key Vault using Azure RBAC authorization.
- A user-assigned managed identity.
- An App Service plan and Linux Web App.
- A Log Analytics workspace and Application Insights instance.
- An Azure App Configuration store with:
  - `Standard` SKU
  - local authentication disabled
  - public network access disabled
  - a user-assigned managed identity attached
- A Private Endpoint for the App Configuration store.
- A `privatelink.azconfig.io` private DNS zone and VNet link.

## Repository Layout

- `infra/main.bicep`: subscription-scope entry point that creates the resource groups and invokes the modules.
- `infra/main.bicepparam`: example parameter file with sample names.
- `infra/modules/network/main.bicep`: virtual network, subnets, route table, and NSG.
- `infra/modules/workload/main.bicep`: Key Vault, identity, App Service, monitoring, and App Configuration.
- `infra/modules/workload/private-endpoint.bicep`: App Configuration Private Endpoint, dedicated subnet, ASG, private DNS zone, and VNet link.
- `infra/modules/types.bicep`: shared parameter types.
- `src/AppConfigKeyVaultSample`: sample ASP.NET Core application that reads Azure App Configuration and Azure Key Vault with `DefaultAzureCredential`.

## Architecture Summary

```text
Subscription scope
|- Network resource group
|  |- Virtual network
|  |- Web integration subnet
|  |- App Configuration private endpoint subnet
|  |- NSG
|  |- Route table
|  |- Private endpoint for App Configuration
|  |- Private DNS zone: privatelink.azconfig.io
|
|- Workload resource group
  |- User-assigned managed identity
  |- Key Vault
  |- Secret in Key Vault
  |- App Service plan
  |- Linux Web App
  |- Log Analytics workspace
  |- Application Insights
  |- App Configuration store
```

## Design Choices Reflected in the Bicep

### 1. App Configuration is private only

The App Configuration store is configured with:

- `publicNetworkAccess: 'Disabled'`
- `disableLocalAuth: true`

That is the right direction for a locked-down deployment because:

- traffic stays on the virtual network through Private Link
- shared access keys are not the default access path
- managed identity and Microsoft Entra ID become the intended authentication model

### 2. The private endpoint is deployed in its own subnet

The private endpoint is not placed on the App Service integration subnet. Instead, the repo creates a dedicated subnet for the App Configuration private endpoint and links the `privatelink.azconfig.io` zone to the virtual network.

That separation is usually the cleaner design because it avoids mixing outbound App Service integration concerns with Private Link resources.

### 3. Key Vault access is handled through a user-assigned managed identity

The Web App:

- is assigned a user-assigned managed identity
- sets `keyVaultReferenceIdentity` to that identity
- receives an app setting whose value is a Key Vault reference

The identity is granted the `Key Vault Secrets User` role on the vault. This lets the platform resolve the secret reference without storing credentials in app settings or source code.

### 4. Key Vault is network-restricted through the App Service integration subnet

The Key Vault is configured with:

- Azure RBAC authorization enabled
- `defaultAction: 'Deny'`
- an allowed virtual network rule for the App Service subnet

The App Service subnet is configured with a `Microsoft.KeyVault` service endpoint. In this sample, Key Vault is restricted to traffic coming from the VNet-integrated app subnet rather than being exposed broadly.

## How the Key Vault Flow Works

This repo uses the App Service Key Vault reference pattern, not an application SDK call.

The sequence is:

1. A secret is created in Key Vault.
2. The Web App gets a user-assigned managed identity.
3. That identity is assigned the `Key Vault Secrets User` role on the vault.
4. The Web App app settings include a value like `@Microsoft.KeyVault(SecretUri=...)`.
5. App Service resolves the secret using the configured user-assigned identity.

This is a good fit when the application expects configuration through environment variables and you want Azure to resolve the secret for you.

## How the App Configuration Private Endpoint Works

The private endpoint module does the following:

1. Creates a subnet for the private endpoint.
2. Creates the private endpoint targeting the App Configuration store with group ID `configurationStores`.
3. Creates the `privatelink.azconfig.io` private DNS zone.
4. Links that DNS zone to the virtual network.
5. Creates a private DNS zone group on the private endpoint.

That combination is what makes App Configuration reachable privately by name from resources connected to the VNet.

## Deployment

This repository is configured to deploy through the GitHub Actions workflow in `.github/workflows/deploy.yml`.

The workflow:

- runs on `push`
- can also be triggered manually through `workflow_dispatch`
- installs the .NET SDK and builds the sample app in `src/AppConfigKeyVaultSample`
- signs in to Azure with `azure/login@v3`
- deploys the subscription-scope Bicep template with `azure/bicep-deploy@v2`
- reads the deployed `webAppName` and `workloadResourceGroupName` from template outputs
- publishes the sample app and deploys the published asset to the Azure Web App with `azure/webapps-deploy@v3`
- uses `infra/main.bicep` and `infra/main.bicepparam`
- deploys to the `Central US` location

The deployment name is generated as `main-${{ github.run_id }}`, which matches the Bicep logic that derives the run identifier from the deployment name.

The sample application that gets deployed is `src/AppConfigKeyVaultSample/AppConfigKeyVaultSample.csproj`.

Before running the workflow, update the names in `infra/main.bicepparam` so they are globally unique where required, especially:

- Key Vault name
- Web App name
- App Configuration store name

You also need the GitHub repository variables referenced by the workflow:

- `AZURE_CLIENT_ID`
- `AZURE_SUBSCRIPTION_ID`
- `AZURE_TENANT_ID`

These values are used for Azure federated authentication from GitHub Actions. The service principal or managed identity behind that login must have permission to execute subscription-scope deployments and create the resources defined by the template.

## Important Remarks About This Repository

These points come directly from the current implementation in the repo.

### This sample separates network and workload resources into different resource groups

That is useful if you want network ownership and application ownership to be split operationally.

### The web app is VNet integrated, but the sample does not include application code that reads App Configuration

The infrastructure now includes a separate sample application under `src/AppConfigKeyVaultSample`. It demonstrates:

- reading a value from Azure App Configuration with `DefaultAzureCredential`
- resolving an App Configuration Key Vault reference with `DefaultAzureCredential`
- reading a secret directly from Azure Key Vault with `SecretClient`

The deployment also sets matching App Service settings for:

- `Azure__ManagedIdentityClientId`
- `Endpoints__AppConfiguration`
- `KeyVault__VaultUri`
- `KeyVault__SecretName`

That keeps the sample application configuration aligned with the deployed infrastructure while allowing the sample code to use an explicit `ManagedIdentityCredential` in Azure.

### Key Vault is restricted by network ACLs, but it is not using a private endpoint in this sample

That is an important distinction:

- App Configuration uses Private Link.
- Key Vault in this repo uses firewall rules plus a service endpoint-enabled subnet.

That can be a valid design, but it is a different access pattern.

### The App Configuration resource uses a preview API version

The current Bicep uses `Microsoft.AppConfiguration/configurationStores@2025-06-01-preview`. If you want a more conservative production posture, consider moving to the latest stable API version that supports the same properties you need.

### The Key Vault settings should be reviewed before using this as a production baseline

The current template sets `enableSoftDelete: false`. For production use, you should review Key Vault deletion protection settings carefully and align them with current Azure guidance for soft delete and purge protection.

### Validation status

The Bicep files in `infra/` currently show no compile or lint errors in the workspace.

## Microsoft Learn References

- Azure App Configuration private endpoints:
 <https://learn.microsoft.com/azure/azure-app-configuration/concept-private-endpoint>
- Azure Private Endpoint DNS configuration:
 <https://learn.microsoft.com/azure/private-link/private-endpoint-dns>
- Managed identities for Azure App Service:
 <https://learn.microsoft.com/azure/app-service/overview-managed-identity>
- Key Vault references in App Service:
 <https://learn.microsoft.com/azure/app-service/app-service-key-vault-references>
- App Service virtual network integration:
 <https://learn.microsoft.com/azure/app-service/overview-vnet-integration>
- Azure Key Vault RBAC guide:
 <https://learn.microsoft.com/azure/key-vault/general/rbac-guide>
- Azure Key Vault virtual network service endpoints:
 <https://learn.microsoft.com/azure/key-vault/general/overview-vnet-service-endpoints>
- Azure App Configuration with managed identity:
 <https://learn.microsoft.com/azure/azure-app-configuration/howto-integrate-azure-managed-service-identity>

## When You Would Extend This Sample

Common next steps for this repository would be:

- add a private endpoint for Key Vault if you want both services to use Private Link consistently
- add deployment validation with `what-if` or CI checks
- add DNS and routing guidance for hybrid connectivity scenarios

## Summary

This repository is a useful infrastructure example for:

- defining an Azure App Configuration store correctly for private access
- associating that store with a private endpoint and private DNS
- securing a Key Vault and exposing its secret to App Service through a user-assigned managed identity

It is not yet a complete end-to-end application sample for consuming App Configuration from code, but the network and identity foundations are in place.
