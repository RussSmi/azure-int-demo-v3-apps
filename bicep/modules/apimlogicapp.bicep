targetScope = 'resourceGroup'
param env string = 'dev'
param serviceId string = 'aisv31'
param logicAppName string = 'la-${serviceId}-${env}'
param workflowName string = 'publisher'
param apimName string = 'apim-${serviceId}-${env}'


resource apiManagementService 'Microsoft.ApiManagement/service@2023-03-01-preview' existing = {
  name: apimName
  scope: resourceGroup()
}
  
resource siteLogicApp 'Microsoft.Web/sites@2023-12-01' existing = {
  name: logicAppName
  scope: resourceGroup('rg-app-${serviceId}-${env}')
}

// get the logic app callback url
var workflowUrl = listCallbackUrl('${siteLogicApp.id}/hostruntime/runtime/webhooks/workflow/api/management/workflows/${workflowName}/triggers/When_a_HTTP_request_is_received', '2023-12-01').value

// Create API to access the logic app
resource api 'Microsoft.ApiManagement/service/apis@2023-03-01-preview' = {
  parent: apiManagementService
  name: workflowName
  properties: {
    displayName: workflowName
    serviceUrl: workflowUrl
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

output workflowUrl string = workflowUrl
