targetScope = 'resourceGroup'

@description('Location to deploy to')
param location string = resourceGroup().location
@description('Environment to deploy to')
param env string = 'dev'
@description('Service ID used in resource naming to group all related resources')
param serviceId string


module la 'modules/logicapp.bicep' = {
  name: 'la-mod-${env}'
  params: {
    serviceId: serviceId
    env: env
    location: location
  }
}

output LogicAppName string = la.outputs.LogicAppName
