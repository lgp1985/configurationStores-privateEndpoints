@export()
@minLength(1)
@maxLength(90)
type rgName = string

@export()
type networkParams = {
  resourceGroupName: rgName
  routeTablesName: string
  virtualNetworkName: string
  networkSecurityGroupName: string
  subnetName: string
}
