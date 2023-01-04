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
"  Subscription = " + $SubscriptionName 
"  Region = " + $Region
"  RG = " + $RG
"  AKSCluster = " + $AKSCluster
"  ACR_NAME = " + $ACR_NAME


#
# 0.2 Login
#
az login


#
# 0.3 Set defaults
#

# Set subscription
$AzAccount = (az account list --query "[?name == '$SubscriptionName'].{id:id,tenantId:tenantId}[0]" | ConvertFrom-yaml)
#$TenantId = $AzAccount.tenantId
$Sub = $AzAccount.id
az account set -s $Sub

# Set resource group
az configure --defaults group=$RG


#
# 0.4 Start AKS cluster
#
az aks start --name $AKSCluster --resource-group $RG



#
# 1. Create ACR
#

# NOTE: az acr create is idempotent
az acr create --name $ACR_NAME --resource-group $RG --sku Basic

az acr list --query "[].{loginServer:loginServer,name:name,location:location,resourceGroup:resourceGroup,sku:sku,tags:tags}"



#
# 2. Add repository to the registry
#

# 2.0 Before importing the repository
az acr repository list -n $ACR_NAME


#
# 2.1 Import a repository
#

# NOTE az acr import is not idempotent
#
#   It creates a cached version of the image hello-world:latest in
#   the repos hello-world-backup, and tag the image with version 1.0.0
#   A subsequent import must specify a new tag to succeed, i.e.,
#   a new name or a new version.
#

#$DockerRepos = "nginx"
#$ImageName = "nginx"
#$ImageVersion = "v1"             

$DockerRepos = "hello-world"
$ImageName = "hello-world-backup"
$ImageVersion = "1.0.0"

az acr import -n $ACR_NAME `
              --source "docker.io/library/${DockerRepos}:latest" `
              -t "${ImageName}:${ImageVersion}"



#
# 3.2 After importing the repository
#

# 3.2.1 List repositories
$ImageNames = (az acr repository list -n $ACR_NAME | Out-String | ConvertFrom-Json -AsHashtable)

$found = $false
foreach ($image in $ImageNames) {
    if ($image -eq $ImageName) {
        $found = $true
    }
}
if ( -not $found) {
    throw "Did not find repository $ImageName in the registry" 
    #Write-Error -Message "Did not find repository $ImageName in the registry" -ErrorAction Stop
}



# 3.2.2 List images in repos hello-world-backup and their tags

# 3.2.2.1 imageName must match $ImageName
$ActualImageName = (az acr repository show -n $ACR_NAME `
                 --repository $ImageName --query "imageName" | Out-String | ConvertFrom-Json -AsHashtable)

if ( $ActualImageName -ne $ImageName) {
    throw "Did not find image $ImageName in the repository" 
    #Write-Error -Message "Did not find image $ImageName in the repository" -ErrorAction Stop
}

# 3.2.2.2 tags must include $ImageVersion
$ActualImageTags = (az acr repository show-tags -n $ACR_NAME --repository $ImageName `
                   | Out-String | ConvertFrom-Json -AsHashtable)

if ( $ActualImageTags -ne $ImageVersion) {
    throw "Did not find tag for image $ImageVersion in the repository" 
}



#
# 3.3 Delete repos
#
#az acr repository delete --yes -n $ACR_NAME --repository "${ImageName}"




#
#  4. Build and push to repos a sample image
#     The project is a hello world Node.js webserver
#     With a Dockerfile to build an image
#

#$GitHubProject = "https://github.com/Azure/acr-builder.git"
$GitHubProject = "https://github.com/Azure-Samples/acr-build-helloworld-node"

$ImageName = "helloacrtasks"
$ImageVersion = "v1"


#
#  4.1 Method 1: Create local contecxt by cloning, then build
#

# 4.1.1 Clone a sample project from GitHub
#git clone $GitHubProject
#code ./acr-build-helloworld-node/server.js


#
# 4.1.2 Build Docker image for the hello world app
#
# Tell az acr build the name of the dir containing Dockerfile, i.e., acr-build-helloworld-node
#az acr build --registry $ACR_NAME --image "${ImageName}:${ImageVersion}" acr-build-helloworld-node


#
# 4.1.3 Clean up the clone
#
#Remove-Item acr-build-helloworld-node -Recurse -Force



#
# 4.2 Method 2: Use remote GitHub context and build
#
az acr build --registry $ACR_NAME $GitHubProject --image "${ImageName}:${ImageVersion}"


#
# 4.3 Check repository appears in the registry
#
az acr repository show -n $ACR_NAME --repository ${ImageName} --query "imageName" | Out-String | ConvertFrom-Json -AsHashtable
az acr repository show-tags -n $ACR_NAME --repository ${ImageName} | Out-String | ConvertFrom-Json -AsHashtable



#
# 5. Deploy image as a Kubernetes app
#

#
# 5.1 Create namespace "acr" and make it the current namespace
#

#  5.1.1 Create namespace "acr" 
#        This is not idempotent
kubectl create namespace acr

# 5.1.2 Make namespace "acr" the default namespace
#kubectl config current-context
kubectl config get-contexts
kubectl config set-context  --current --namespace acr
kubectl config get-contexts

#
# 5.2 Attach the ACR to the AKS cluster, so that
#     the cluster can access repositories in the ACR
#
az aks update -n $AKSCluster -g $RG --attach-acr $ACR_NAME


#
# 5.3 Get ACR endpoint
#
$loginServer = (az acr show -n $ACR_NAME --query "loginServer" | ConvertFrom-json -AsHashtable)


#
# 5.4 Create deployment
#
kubectl create deployment helloworld --image=${loginServer}/${ImageName}:${ImageVersion}


#
# 5.5 Check deployment
#

#kubectl get deployment -o=yaml
kubectl get deployment
kubectl get pods
kubectl describe pod (kubectl get pods -o=jsonpath='{.items[0].metadata.name}' ) | grep Image:
#  Image:          acrgabi.azurecr.io/helloacrtasks:v1

#
# 5.6 Scale deployment to 0
#
kubectl scale deployment/helloworld --replicas=0
kubectl get deployment
