@description('The GitHub Actions run ID for this deployment')
param githubRun_id string = '0'

targetScope = 'subscription'

@description('The name for this deployment')
output deploymentName string = deployment().name
@description('The GitHub Actions run ID for this deployment, same as input')
output githubRunId string = githubRun_id
