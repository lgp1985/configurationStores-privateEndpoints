using './main.bicep'

param network = {
  resourceGroupName: 'rg-lg-vnet-temp1'
  routeTablesName: 'rt-temp1'
  virtualNetworkName: 'vnet-temp1'
  networkSecurityGroupName: 'nsg-temp1'
  subnetName: 'snet-kv-web-temp1'
  // applicationSecurityGroup: {
  //   name: 'asg-kv-web-temp1'
  //   securityRules: {
  //     name: 'allow-inbound-Inbound-temp1'
  //     priority: 100
  //     sourceAddressPrefixes: [
  //       '10.241.144.0/20'
  //       '10.241.192.0/18'
  //       '10.243.192.0/19'
  //       '10.238.24.0/21'
  //       '10.238.17.0/24'
  //     ]
  //     destinationPortRanges: [
  //       '443'
  //     ]
  //   }
  // }
  networkSecurityGroup: {
    name: 'nsg-temp1'
  }
}

param workload = {
  resourceGroupName: 'rg-lgp-workload-temp1'
  logAnalyticsWorkspaceName: 'law-temp1'
  applicationInsightsName: 'appi-temp1'
  keyVaultName: 'kv-lgp-temp1'
  appServicePlanName: 'asp-temp1'
  webAppName: 'webapp-lgp-temp1'
  userAssignedIdentityName: 'uai-temp1'
  configurationStore: {
    name: 'appcs-lgp-temp1'
    privateEndpoint: {
      name: 'pe-appcs-temp1'
      customNetworkInterfaceName: 'nic-pe-appcs-temp1'
    }
  }
  secretName: 'secret-temp1'
  KnwonValue: 'This is a known value for testing'
}
