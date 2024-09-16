targetScope= 'resourceGroup'

param env string = 'dev'  /// Use prod for production
param location string = resourceGroup().location
param storageAccountSku string = 'Standard_LRS'

@description('Service ID used in resource naming to group all related resources')
param serviceId string

param clientStorageConnectionString string
param clientStorageAccountName string

var key = uniqueString(resourceGroup().id)
var logicAppName = 'la-${serviceId}-${env}'
var minimumElasticSize = 1
var maximumElasticSize = 3

@description('Name of the logic app storage account')
var tempName = 'stla${env}${key}'
var logicAppStorageName = length(tempName) > 24 ? substring('stla${env}${key}',0,24) : tempName

///Get reference to existing service bus namespace
resource serviceBusNamespace 'Microsoft.ServiceBus/namespaces@2022-10-01-preview' existing = {
  name: 'sbus-${serviceId}-${env}'
  scope: resourceGroup('rg-sbus-${serviceId}-${env}') 
}

var endpoint = '${serviceBusNamespace.id}/AuthorizationRules/RootManageSharedAccessKey'
var serviceBusConnectionString = listKeys(endpoint, serviceBusNamespace.apiVersion).primaryConnectionString

/// Storage account for the logic app ///
resource logicAppStorage 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: logicAppStorageName
  location: location
  kind: 'StorageV2'
  sku: {
    name: storageAccountSku
  }
  properties: {
    allowBlobPublicAccess: false
    accessTier: 'Hot'
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
  }
}

 /// Dedicated app plan for the service ///
 resource servicePlanLogicApp 'Microsoft.Web/serverfarms@2023-01-01' = {
  name: 'plan-${logicAppName}'
  location: location
  sku: {
    tier: 'WorkflowStandard'
    name: 'WS1'
  }
  properties: {
    targetWorkerCount: minimumElasticSize
    maximumElasticWorkerCount: maximumElasticSize
    elasticScaleEnabled: true
    isSpot: false
    zoneRedundant: ((env == 'prod') ? true : false)
  }
}

 // Create log analytics workspace
 resource logAnalyticsWorkspacelogicApp 'Microsoft.OperationalInsights/workspaces@2021-06-01' = {
  name: 'law-${key}-${env}'
  location: location
  properties: {
    sku: {
      name: 'PerGB2018' // Standard
    }
  }
}

 /// Log analytics workspace insights ///
 resource applicationInsightsLogicApp 'Microsoft.Insights/components@2020-02-02' = {
  name: 'appinss-${key}-${env}'
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    Flow_Type: 'Bluefield'
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
    Request_Source: 'rest'
    RetentionInDays: 30
    WorkspaceResourceId: logAnalyticsWorkspacelogicApp.id
  }
}

// App service containing the workflow runtime ///
resource siteLogicApp 'Microsoft.Web/sites@2023-01-01' = {
  name: logicAppName
  location: location
  kind: 'functionapp,workflowapp'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    httpsOnly: true
    siteConfig: {
      appSettings: [
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'node'
        }
        {
          name: 'WEBSITE_NODE_DEFAULT_VERSION'
          value: '~14'
        }
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${logicAppStorage.name};AccountKey=${listKeys(logicAppStorage.id, '2019-06-01').keys[0].value};EndpointSuffix=core.windows.net'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${logicAppStorage.name};AccountKey=${listKeys(logicAppStorage.id, '2019-06-01').keys[0].value};EndpointSuffix=core.windows.net'
        }
        {
          name: 'WEBSITE_CONTENTSHARE'
          value: '${logicAppName}-fileshare-content'
        }
        {
          name: 'AzureFunctionsJobHost__extensionBundle__id'
          value: 'Microsoft.Azure.Functions.ExtensionBundle.Workflows'
        }
        {
          name: 'AzureFunctionsJobHost__extensionBundle__version'
          value: '[1.*, 2.0.0)'
        }
        {
          name: 'APP_KIND'
          value: 'workflowApp'
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: applicationInsightsLogicApp.properties.InstrumentationKey
        }
        {
          name: 'ApplicationInsightsAgent_EXTENSION_VERSION'
          value: '~2'
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: applicationInsightsLogicApp.properties.ConnectionString
        }        
        {
          name: 'WORKFLOWS_SUBSCRIPTION_ID'
          value: subscription().subscriptionId
        }
        {
          name: 'WORKFLOWS_RESOURCE_GROUP_NAME'
          value: resourceGroup().name
        }
        {
          name: 'serviceBus_connectionString'
          value: serviceBusConnectionString
        }
        {
          name: 'sbtopic'
          value: 'sbtopicpub${serviceId}'
        }
        {
          name: 'sbsubscription'
          value: 'sbsubSub${serviceId}'
        }
        {
          name: 'AzureBlob_blobStorageEndpoint'
          value: clientStorageConnectionString
        }
      ]
      use32BitWorkerProcess: true
    }
    serverFarmId: servicePlanLogicApp.id
    clientAffinityEnabled: false
  }
}

resource storage 'Microsoft.Storage/storageAccounts@2023-01-01' existing = {
  name: clientStorageAccountName
  scope: resourceGroup()
}

// Storage Blob Data Contributor role id from docs
var dataContributorRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe')
var resourceGroupReaderRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'acdd72a7-3385-48ef-bd42-f606fba81ae7')

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: storage
  name: guid(resourceGroup().id, storage.id)
  properties: {
    roleDefinitionId: dataContributorRoleId
    principalId: siteLogicApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource roleAssignment2 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: resourceGroup()
  name: guid(resourceGroup().id, resourceGroupReaderRoleId)
  properties: {
    roleDefinitionId: resourceGroupReaderRoleId
    principalId: siteLogicApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}
output LogicAppName string = logicAppName




