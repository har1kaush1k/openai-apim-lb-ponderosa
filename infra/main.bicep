targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the the environment which is used to generate a short unique hash used in all resources.')
param environmentName string

@minLength(1)
@description('Primary location for all resources (filtered on available regions for Azure Open AI Service).')
@allowed([ 'westeurope', 'southcentralus', 'australiaeast', 'canadaeast', 'eastus', 'eastus2', 'francecentral', 'japaneast', 'northcentralus', 'swedencentral', 'switzerlandnorth', 'uksouth' ])
param location string

//Leave blank to use default naming conventions

@description('Name of the resource group. Leave blank to use default naming conventions.')
param resourceGroupName string = ''

@description('Name of the identity. Leave blank to use default naming conventions.')
param identityName string = ''

@description('Name of the API Management service. Leave blank to use default naming conventions.')
param apimServiceName string = ''

@description('Name of the Log Analytics workspace. Leave blank to use default naming conventions.')
param logAnalyticsName string = ''

@description('Name of the Application Insights dashboard. Leave blank to use default naming conventions.')
param applicationInsightsDashboardName string = ''

@description('Name of the Application Insights resource. Leave blank to use default naming conventions.')
param applicationInsightsName string = ''

// You can add more OpenAI instances by adding more objects to the openAiInstances object
// Then update the apim policy xml to include the new instances
@description('Object containing OpenAI instances. You can add more instances by adding more objects to this parameter.')
param openAiInstances object = {
  openAi1: {
    name: 'openai1'
    location: 'westus'
    existingEndpoint: 'https://azure-openai-ponderosa.openai.azure.com/openai/deployments/gpt-4o-data-zone-standard/chat/completions?api-version=2024-08-01-preview'
  }, openAi2: {
    name: 'openai2'
    location: 'eastus'
    existingEndpoint: 'https://azure-openai-east.openai.azure.com/openai/deployments/gpt-4o-east-global/chat/completions?api-version=2024-08-01-preview'
  }, openAi3: {
    name: 'openai3'
    location: 'westus'
    existingEndpoint: 'https://azure-openai-ponderosa.openai.azure.com/openai/deployments/gpt-4o-2/chat/completions?api-version=2024-08-01-preview'
  }, openAi4: {
    name: 'openai4'
    location: 'eastus'
    existingEndpoint: 'https://azure-openai-east.openai.azure.com/openai/deployments/gpt-4o/chat/completions?api-version=2024-08-01-preview'
  }, openAi5: {
    name: 'openai5'
    location: 'northcentralus'
    existingEndpoint: 'https://ponderosa-openai-northcentral.openai.azure.com/openai/deployments/gpt-4o-northcentral-dz/chat/completions?api-version=2024-08-01-preview'
  }
}

@description('SKU name for OpenAI.')
param openAiSkuName string = 'S0'

@description('Version of the Chat GPT model.')
param chatGptModelVersion string = '0613'

@description('Name of the Chat GPT deployment.')
param chatGptDeploymentName string = 'chat'

@description('Name of the Chat GPT model.')
param embeddingGptModelName string = 'text-embedding-ada-002'

@description('Version of the Chat GPT model.')
param embeddingGptModelVersion string = '2'

@description('Name of the Chat GPT deployment.')
param embeddingGptDeploymentName string = 'embedding'

@description('Name of the Chat GPT model.')
param chatGptModelName string = 'gpt-35-turbo'

@description('The OpenAI endpoints capacity (in thousands of tokens per minute)')
param deploymentCapacity int = 30

@description('Tags to be applied to resources.')
param tags object = { 'azd-env-name': environmentName }

@description('Should Entra ID validation be enabled')
param entraAuth bool = false
param entraTenantId string = ''
param entraClientId string = ''
param entraAudience string = ''

param openAiKeys object

// Load abbreviations from JSON file
var abbrs = loadJsonContent('./abbreviations.json')
// Generate a unique token for resources
var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))


// Organize resources in a resource group
resource resourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: !empty(resourceGroupName) ? resourceGroupName : '${abbrs.resourcesResourceGroups}${environmentName}'
  location: location
  tags: tags
}

module managedIdentity './modules/security/managed-identity.bicep' = {
  name: 'managed-identity'
  scope: resourceGroup
  params: {
    name: !empty(identityName) ? identityName : '${abbrs.managedIdentityUserAssignedIdentities}${resourceToken}'
    location: location
    tags: tags
  }
}

module monitoring './modules/monitor/monitoring.bicep' = {
  name: 'monitoring'
  scope: resourceGroup
  params: {
    location: location
    tags: tags
    logAnalyticsName: !empty(logAnalyticsName) ? logAnalyticsName : '${abbrs.operationalInsightsWorkspaces}${resourceToken}'
    applicationInsightsName: !empty(applicationInsightsName) ? applicationInsightsName : '${abbrs.insightsComponents}${resourceToken}'
    applicationInsightsDashboardName: !empty(applicationInsightsDashboardName) ? applicationInsightsDashboardName : '${abbrs.portalDashboards}${resourceToken}'
  }
}

module apim './modules/apim/apim.bicep' = {
  name: 'apim'
  scope: resourceGroup
  params: {
    name: !empty(apimServiceName) ? apimServiceName : '${abbrs.apiManagementService}${resourceToken}'
    location: location
    tags: tags
    applicationInsightsName: monitoring.outputs.applicationInsightsName
    managedIdentityName: managedIdentity.outputs.managedIdentityName
    entraAuth: entraAuth
    clientAppId: entraAuth ? entraClientId : null 
    tenantId: entraAuth ? entraTenantId : null
    audience: entraAuth ? entraAudience : null
    openAiKeys: openAiKeys
    // Use base URLs without query parameters
    openAiUris: ['https://azure-openai-ponderosa.openai.azure.com', 'https://azure-openai-east.openai.azure.com', 'https://azure-openai-ponderosa.openai.azure.com', 'https://azure-openai-east.openai.azure.com', 'https://ponderosa-openai-northcentral.openai.azure.com']
  }
}

output APIM_NAME string = apim.outputs.apimName
output APIM_AOI_PATH string = apim.outputs.apimOpenaiApiPath
output APIM_GATEWAY_URL string = apim.outputs.apimGatewayUrl
