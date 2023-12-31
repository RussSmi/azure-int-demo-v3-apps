targetScope= 'resourceGroup'

param env string = 'dev'  /// Use prod for production
param location string = resourceGroup().location
param storageAccountSku string = 'Standard_LRS'
@description('Service ID used in resource naming to group all related resources')

var name = 'messaging'
var logicAppName = 'logicapp-${name}-${env}'
var minimumElasticSize = 1
var maximumElasticSize = 3

@description('Name of the logic app storage account')
var tempName = 'stla${env}${uniqueString(resourceGroup().id)}'
var logicAppStorageName = length(tempName) > 24 ? substring('stla${env}${uniqueString(resourceGroup().id)}',0,24) : tempName

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
  name: 'plan-${name}-logic-app-${env}'
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
  name: '${name}-logicapp-loganalytics-workspace-${env}'
  location: location
  properties: {
    sku: {
      name: 'PerGB2018' // Standard
    }
  }
}

 /// Log analytics workspace insights ///
 resource applicationInsightsLogicApp 'Microsoft.Insights/components@2020-02-02' = {
  name: 'application-insights-${name}-logic-${env}'
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
      ]
      use32BitWorkerProcess: true
    }
    serverFarmId: servicePlanLogicApp.id
    clientAffinityEnabled: false
  }
}

output LogicAppName string = logicAppName




