#!/usr/bin/env pwsh


#
# 0. Initialize
#

#
# 0.1 Source the settings script
#
$Here = [string](Get-Location)
$SettingsScript = "00_settings.ps1"
#$SettingsScriptPath = (Join-Path -Path ([string](Get-Location)) -ChildPath $SettingsScript)
#$SettingsScriptPath = (Join-Path -Path $Here -ChildPath $SettingsScript)
$SettingsScriptPath =  $Here + [IO.Path]::DirectorySeparatorChar + $SettingsScript 
. $SettingsScriptPath

"Using the parameters"
"  SubscriptionName = " + $SubscriptionName 
"  Region = " + $Region
"  RG = " + $RG
"  AKSCluster = " + $AKSCluster
"  ACR_NAME = " + $ACR_NAME


#
# 0.2 Install powershell-yaml
#
$YamlModule = "powershell-yaml"
$ModulePresent = (Get-Module -ListAvailable -FullyQualifiedName $YamlModule).Name  
if (! $ModulePresent) {
  Write-Warning -Message "Installing module $YamlModule"
  Install-Module -Name $YamlModule -Force
}



#
# 0.3 Check kubectl is available
#
$KubectlVersion = (kubectl version --client --output=json | ConvertFrom-Json -AsHashtable)
$KubectlClientVersion = $KubectlVersion.clientVersion.major + "." + $KubectlVersion.clientVersion.minor
"kubectl client version = " + $KubectlClientVersion


#
# 0.4 Log in
#
#az login



#
# 1. Set active subscription
#

#
# 1.1 Get tenant name
#
$TenantName = (az rest `
              --method get `
              --url https://graph.microsoft.com/v1.0/domains `
              --query 'value[?isDefault].id'  | jq -Mr '.[]')
"TenantName = " + $TenantName          


#
# 1.2 Get tenant-ID and subscription-ID
#
<#
  az account list | jq -M '.[] | select(.name == "Main subscription") | .id'
  "20e8d604-6e68-4d49-9ead-9d31a58a705b"

  az account list --query "[?name == 'Main subscription'].id" -o tsv
  20e8d604-6e68-4d49-9ead-9d31a58a705b


  $SubscriptionName = "Main subscription"

  az account list --query "[?name == '$SubscriptionName'].id" -o tsv  
  20e8d604-6e68-4d49-9ead-9d31a58a705b


  PS > az account list --query "[?name == '$SubscriptionName'].{id:id, tenantId:tenantId}[0]"
  {
    "id": "20e8d604-6e68-4d49-9ead-9d31a58a705b",
    "tenantId": "e50ebc84-76f2-4636-b550-c3f7abc924af"
  }


  PS > az account list --query "[?name == '$SubscriptionName'].{id:id, tenantId:tenantId}[0]" | ConvertFrom-yaml
  Name                           Value
  ----                           -----
  id                             20e8d604-6e68-4d49-9ead-9d31a58a705b
  tenantId                       e50ebc84-76f2-4636-b550-c3f7abc924af


  PS > $AzAccount = (az account list --query "[?name == '$SubscriptionName'].{id:id,tenantId:tenantId}[0]"|ConvertFrom-yaml)
#>

$AzAccount = (az account list --query "[?name == '$SubscriptionName'].{id:id,tenantId:tenantId}[0]" | ConvertFrom-yaml)
#$TenantId = $AzAccount.tenantId
$Sub = $AzAccount.id
"subscriptionId = " + $Sub


#
# 1.3 Set subscription $Sub as active subscription
#
az account set --subscription $Sub




#
# 2. Create resource group if needed
#

#
# 2.1 Create resource group if it does not already exist
#

#$ActualResourceGroup = (az group list --query "[?name == '$RG' ].name" | ConvertFrom-Yaml)
#$ActualResourceGroup = (az group list --query "[?name == '$RG' ].name" | ConvertFrom-Json -AsHashtable)
#$ActualResourceGroup = (az group list --query "[?location == '$Region' ].name" | ConvertFrom-Json)
$ActualResourceGroup = (az group list --query "[?location == '$Region' ].name" | ConvertFrom-Json | Where-Object {$_ -eq $RG} )
if ( ($null -eq $ActualResourceGroup) -or (! $ActualResourceGroup) ) {
  Write-Warning -Message "Creating resource group $RG"
  az group create --location $Region  --resource-group $RG
}


#
# 2.2 Configure default resource group
#
az configure --defaults group=$RG



#
# 2.2 Check the region of the resource group
#
<#
  $ az group list
  [
    {
      "id": "/subscriptions/20e8d604-6e68-4d49-9ead-9d31a58a705b/resourceGroups/AKSRG",
      "location": "eastus",
      "managedBy": null,
      "name": "AKSRG",
      "properties": {
        "provisioningState": "Succeeded"
      },
      "tags": null,
      "type": "Microsoft.Resources/resourceGroups"
    },
  ]

  $ az group list | jq -M '.[] | select (.name == "AKSRG") | .location'
  "eastus"
#>
$ActualRegion = (az group list --query "[?name == '$RG'].location" | ConvertFrom-Json)
if ( ($null -eq $ActualRegion) -or ($ActualRegion -ne $Region) ) {
  Write-Error "Incorrect region: expected $Region, actual $ActualRegion"  
}



#
# 3. Create AKS cluster if needed then start it, set context and get credentials
#

#
# 3.1 Create AKS cluster if it does not already exist
#
<#
az aks list | jq -M '.[] | {name:.name, resourceGroup:.resourceGroup, fqdn:.fqdn, dnsPrefix:.dnsPrefix}'
{
  "name": "AKS_CLUSTER_ONE",
  "resourceGroup": "AKSRG",
  "fqdn": "aksclusterone-dns-9da25c1b.hcp.eastus.azmk8s.io",
  "dnsPrefix": "AKSCLUSTERONE-dns"
}

az aks list | jq -M '.[] | select(.resourceGroup == "AKSRG") | .name'
"AKS_CLUSTER_ONE"
#>

$ActualAKSCluster = (az aks list --query "[?resourceGroup == '$RG'].name" | ConvertFrom-Json | Where-Object {$_ -eq $AKSCluster} )
if ( ($null -eq $ActualAKSCluster) -or (! $ActualAKSCluster) ) {
  Write-Warning -Message "Creating AKS Cluster $AKSCluster"
  try {
    #az aks create --resource-group $RG  --node-count $NodeCount --enable-node-public-ip --name $AKSCluster
    az aks create --resource-group $RG  --node-count 1 --name $AKSCluster
  }
  catch {
    az aks delete --yes --name $AKSCluster --resource-group $RG
    Write-Error "Cannot create cluster $AKSCluster balining out"  
  }

  az aks wait --created --interval 30 -n $AKSCluster --resource-group $RG --timeout 600
}


#
# 3.2 Start cluster
#
az aks start --name $AKSCluster --resource-group $RG


#
# 3.3 Use context $AKSCluster
#
kubectl config use-context $AKSCluster 
#$ActualAKSCluster = (kubectl config current-context)
#if ( $ActualAKSCluster  -ne $AKSCluster) {
#  Write-Error "Incorrect cluster: expected $AKSCluster, actual $ActualAKSCluster"  
#}


#
# 3.4 Check nodes
#
$ClusterNodes = (kubectl get nodes -o=json 2>/dev/null | ConvertFrom-Json -AsHashtable)
if ( ! $ClusterNodes ) {
  Write-Warning "No nodes found in cluster $AKSCluster"  
}



#
# 3.5 Update kubectl credentials
#
az aks get-credentials -g $RG -n $AKSCluster --overwrite-existing



#
# 4. Stop cluster
#
if ( $StopCluster) {
  Write-Warning "Stopping cluster $AKSCluster"
  az aks stop --name $AKSCluster --resource-group $RG
}




#
# Clear screen
#
#Clear-Host
