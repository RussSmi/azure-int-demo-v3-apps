targetScope = 'resourceGroup'
param env string = 'dev'
param serviceId string = 'aisv31'
param workflowName string = 'publisher'
param apimName string = 'apim-${serviceId}-${env}'

resource apiManagementService 'Microsoft.ApiManagement/service@2023-03-01-preview' existing = {
  name: apimName
  scope: resourceGroup()
}

module logicappUrl 'modules/logicappurl.bicep' = {
  name: 'logicappUrl'
  params: {
    env: env
    serviceId: serviceId
    logicAppName: 'la-${serviceId}-${env}'
    workflowName: workflowName
  }
}

// Create API to access the logic app
resource api 'Microsoft.ApiManagement/service/apis@2023-03-01-preview' = {
  parent: apiManagementService
  name: workflowName
  properties: {
    displayName: workflowName
    serviceUrl: logicappUrl.outputs.workflowUrl
    subscriptionRequired: false
    path: workflowName
    protocols: [
      'https'
    ]
  }
}

// Create operation to access the logic app
resource operation 'Microsoft.ApiManagement/service/apis/operations@2023-09-01-preview' = {
  parent: api
  name: 'post'
  properties: {
    displayName: 'Trigger'
    method: 'POST'
    urlTemplate: '/'
    request: {
      queryParameters: []
      headers: []
    }
    responses: []
  }
}


