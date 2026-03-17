import * as types from './modules/types.bicep'
param network types.networkParams
param workload types.workloadParams

@description('The GitHub Actions run ID for this deployment')
var githubRun_id string = last(split(deployment().name, '-'))

targetScope = 'subscription'

resource networkResourceGroup 'Microsoft.Resources/resourceGroups@2025-04-01' = {
  name: network.resourceGroupName
  location: deployment().location
  tags: {}
}

@description('Deploys the network resources including virtual network, subnet, NSG, ASG')
module networkDeployment './modules/network/main.bicep' = {
  name: 'deployNetwork-${githubRun_id}'
  scope: networkResourceGroup
  params: {
    network: network
  }
}

resource workloadResourceGroup 'Microsoft.Resources/resourceGroups@2025-04-01' = {
  name: workload.resourceGroupName
  location: deployment().location
  tags: {}
}

@description('Deploys the workload resources including App Service, Log Analytics, Application Insights, and Key Vault')
module workloadDeployment './modules/workload/main.bicep' = {
  name: 'deployWorkload-${githubRun_id}'
  scope: workloadResourceGroup
  params: {
    workload: workload
    network: network
  }
  dependsOn: [
    networkDeployment
  ]
}
@description('The GitHub Actions run ID for this deployment, same as input deployment name split by "-" and taking the last part')
output githubRunId string = githubRun_id
output webAppName string = workloadDeployment.outputs.webAppName
output workloadResourceGroupName string = workloadDeployment.outputs.workloadResourceGroupName
