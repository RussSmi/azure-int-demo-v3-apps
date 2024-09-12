targetScope = 'resourceGroup'
param env string = 'dev'
param serviceId string = 'aisv31'
param logicAppName string = 'la-${serviceId}-${env}'
param workflowName string = 'publisher'

resource siteLogicApp 'Microsoft.Web/sites@2023-12-01' existing = {
  name: logicAppName
  scope: resourceGroup('rg-app-${serviceId}-${env}')
}

// get the logic app callback url
var workflowUrl = listCallbackUrl('${siteLogicApp.id}/hostruntime/runtime/webhooks/workflow/api/management/workflows/${workflowName}/triggers/When_a_HTTP_request_is_received', '2023-12-01').value

output workflowUrl string = workflowUrl
