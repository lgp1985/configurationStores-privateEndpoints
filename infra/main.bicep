import * as types from './modules/types.bicep'
param network types.networkParams

@description('The GitHub Actions run ID for this deployment')
var githubRun_id string = last(split(deployment().name, '-'))

targetScope = 'subscription'

resource networkResourceGroup 'Microsoft.Resources/resourceGroups@2025-04-01' = {
  name: network.resourceGroupName
  location: deployment().location
  tags: {}
}

module networkDeployment './modules/network/main.bicep' = {
  name: 'deployNetwork-${githubRun_id}'
  scope: networkResourceGroup
  params: {
    network: network
  }
}

@description('The GitHub Actions run ID for this deployment, same as input deployment name split by "-" and taking the last part')
output githubRunId string = githubRun_id
