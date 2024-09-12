// Create a storage account and container for client messages
targetScope='resourceGroup'

@description('Location for all resources.')
param location string = resourceGroup().location

param env string = 'dev'  /// Use prod for production

resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: 'clistrg${env}${uniqueString(resourceGroup().id)}'
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' = {
  parent: storage
  name: 'default'
}

resource container 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  parent: blobService
  name: 'client'
  properties: {
    publicAccess: 'None'
  }
}

var blobStorageConnectionString  = 'DefaultEndpointsProtocol=https;AccountName=${storage.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${listKeys(storage.id, storage.apiVersion).keys[0].value}'

output storageConnectionString string = blobStorageConnectionString
output storageAccountName string = storage.name
