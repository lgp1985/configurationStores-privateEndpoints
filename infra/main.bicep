@description('The GitHub Actions run ID for this deployment')
param githubRun_id string = last(split(deployment().name, '-'))

targetScope = 'subscription'

@description('The GitHub Actions run ID for this deployment, same as input')
output githubRunId string = githubRun_id
