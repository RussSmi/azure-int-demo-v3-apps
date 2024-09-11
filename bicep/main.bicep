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
    env: env
    location: location
    serviceId: serviceId
  }
}

module storage 'modules/storage.bicep' = {
  name: 'storage-mod-${env}'
  params: {
    location: location
    env: env
  }
}

output LogicAppName string = la.outputs.LogicAppName
