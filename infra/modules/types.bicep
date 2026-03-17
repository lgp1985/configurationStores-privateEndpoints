@export()
@minLength(1)
@maxLength(90)
type rgName = string

// Define the resource parameters for the network module
@export()
type networkParams = {
  resourceGroupName: rgName
  routeTablesName: string
  virtualNetworkName: string
  networkSecurityGroupName: string
  subnetName: string
  // applicationSecurityGroup: applicationSecurityGroupParam
  networkSecurityGroup: networkSecurityGroupParam
}

type networkSecurityGroupParam = {
  name: string
}

// type securityRulesParam = {
//   name: string
//   destinationPortRanges: string[]
//   sourceAddressPrefixes: string[]
//   priority: int
// }

// type applicationSecurityGroupParam = {
//   name: string
//   securityRules: securityRulesParam
// }

// Define the resource parameters for the workload module
@export()
type workloadParams = {
  resourceGroupName: rgName
  appServicePlanName: string
  webAppName: string
  logAnalyticsWorkspaceName: string
  applicationInsightsName: string
  userAssignedIdentityName: string
  keyVaultName: string

  secretName: string
  KnwonValue: string
  configurationStore: configurationStoreParam
}

type privateEndpointParam = {
  name: string
  customNetworkInterfaceName: string
  subnetName: string
  addressPrefixes: string[]
  applicationSecurityGroupName: string
}

@export()
type configurationStoreParam = {
  name: string
  privateEndpoint: privateEndpointParam
}
