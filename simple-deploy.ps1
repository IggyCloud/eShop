# Simple eShop Deployment to Azure Container Apps
# This script deploys directly without Key Vault to get you started quickly

param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory=$true)]
    [string]$ContainerAppsEnvironmentName,
    
    [Parameter(Mandatory=$false)]
    [string]$Location = "East US",
    
    [Parameter(Mandatory=$false)]
    [string]$RegistryName = "eshopregistry$((Get-Random))",
    
    [Parameter(Mandatory=$false)]
    [string]$PostgresPassword = "eShopP@ssw0rd123!"
)

Write-Host "🚀 Starting simple eShop deployment to Azure Container Apps..." -ForegroundColor Green

# Set Azure CLI path
$env:PATH += ";C:\Program Files\Microsoft SDKs\Azure\CLI2\wbin"

# Check if user is logged into Azure
Write-Host "Checking Azure login status..." -ForegroundColor Yellow
$account = & az account show --query "name" -o tsv 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "Please login to Azure first: az login" -ForegroundColor Red
    exit 1
}
Write-Host "✅ Logged in as: $account" -ForegroundColor Green

# Create resource group if it doesn't exist
Write-Host "Creating resource group: $ResourceGroupName" -ForegroundColor Yellow
& az group create --name $ResourceGroupName --location $Location

# Create Azure Container Registry
Write-Host "Creating Azure Container Registry: $RegistryName" -ForegroundColor Yellow
& az acr create --resource-group $ResourceGroupName --name $RegistryName --sku Basic --admin-enabled true

# Get ACR credentials
$acrLoginServer = & az acr show --name $RegistryName --query loginServer --output tsv
$acrUsername = & az acr credential show --name $RegistryName --query username --output tsv
$acrPassword = & az acr credential show --name $RegistryName --query passwords[0].value --output tsv

Write-Host "✅ ACR Login Server: $acrLoginServer" -ForegroundColor Green

# Create Container Apps Environment
Write-Host "Creating Container Apps Environment: $ContainerAppsEnvironmentName" -ForegroundColor Yellow
& az containerapp env create --name $ContainerAppsEnvironmentName --resource-group $ResourceGroupName --location $Location

# Create PostgreSQL flexible server
Write-Host "Creating PostgreSQL server..." -ForegroundColor Yellow
$postgresServerName = "$ResourceGroupName-postgres"
& az postgres flexible-server create `
    --resource-group $ResourceGroupName `
    --name $postgresServerName `
    --location $Location `
    --admin-user postgres `
    --admin-password $PostgresPassword `
    --sku-name Standard_B1ms `
    --tier Burstable `
    --public-access 0.0.0.0 `
    --storage-size 32 `
    --version 14

# Create databases
$databases = @("catalogdb", "identitydb", "orderingdb", "webhooksdb")
foreach ($db in $databases) {
    Write-Host "Creating database: $db" -ForegroundColor Cyan
    & az postgres flexible-server db create --resource-group $ResourceGroupName --server-name $postgresServerName --database-name $db
}

# Create Redis cache
Write-Host "Creating Redis cache..." -ForegroundColor Yellow
$redisName = "$ResourceGroupName-redis"
& az redis create --resource-group $ResourceGroupName --name $redisName --location $Location --sku Basic --vm-size C0

# Get connection strings
$postgresHost = & az postgres flexible-server show --resource-group $ResourceGroupName --name $postgresServerName --query fullyQualifiedDomainName --output tsv
$redisHost = & az redis show --resource-group $ResourceGroupName --name $redisName --query hostName --output tsv
$redisKey = & az redis list-keys --resource-group $ResourceGroupName --name $redisName --query primaryKey --output tsv

$postgresConnectionString = "Host=$postgresHost;Database=catalogdb;Username=postgres;Password=$PostgresPassword;Include Error Detail=true;Trust Server Certificate=true"
$redisConnectionString = "$redisHost:6380,password=$redisKey,ssl=True,abortConnect=False"

Write-Host "Building and pushing container images..." -ForegroundColor Yellow

# Login to ACR
& az acr login --name $RegistryName

# Build and push key images (focusing on main services first)
Write-Host "Building Identity API..." -ForegroundColor Cyan
& docker build -f src/Identity.API/Dockerfile -t "$acrLoginServer/eshop/identity-api:latest" .
& docker push "$acrLoginServer/eshop/identity-api:latest"

Write-Host "Building Catalog API..." -ForegroundColor Cyan
& docker build -f src/Catalog.API/Dockerfile -t "$acrLoginServer/eshop/catalog-api:latest" .
& docker push "$acrLoginServer/eshop/catalog-api:latest"

Write-Host "Building Web App..." -ForegroundColor Cyan
& docker build -f src/WebApp/Dockerfile -t "$acrLoginServer/eshop/webapp:latest" .
& docker push "$acrLoginServer/eshop/webapp:latest"

# Deploy container apps
Write-Host "Deploying container apps..." -ForegroundColor Yellow

# Identity API
Write-Host "Deploying Identity API..." -ForegroundColor Cyan
& az containerapp create `
    --name identity-api `
    --resource-group $ResourceGroupName `
    --environment $ContainerAppsEnvironmentName `
    --image "$acrLoginServer/eshop/identity-api:latest" `
    --registry-server $acrLoginServer `
    --registry-username $acrUsername `
    --registry-password $acrPassword `
    --target-port 8080 `
    --ingress external `
    --env-vars "ConnectionStrings__DefaultConnection=$postgresConnectionString"

# Catalog API
Write-Host "Deploying Catalog API..." -ForegroundColor Cyan
& az containerapp create `
    --name catalog-api `
    --resource-group $ResourceGroupName `
    --environment $ContainerAppsEnvironmentName `
    --image "$acrLoginServer/eshop/catalog-api:latest" `
    --registry-server $acrLoginServer `
    --registry-username $acrUsername `
    --registry-password $acrPassword `
    --target-port 8080 `
    --ingress external `
    --env-vars "ConnectionStrings__CatalogDatabase=$postgresConnectionString"

# Web App
Write-Host "Deploying Web App..." -ForegroundColor Cyan
& az containerapp create `
    --name webapp `
    --resource-group $ResourceGroupName `
    --environment $ContainerAppsEnvironmentName `
    --image "$acrLoginServer/eshop/webapp:latest" `
    --registry-server $acrLoginServer `
    --registry-username $acrUsername `
    --registry-password $acrPassword `
    --target-port 8080 `
    --ingress external

Write-Host "🎉 Basic deployment completed!" -ForegroundColor Green
Write-Host "Your eShop application is now running on Azure Container Apps." -ForegroundColor Green

# Get app URLs
$webappUrl = & az containerapp show --name webapp --resource-group $ResourceGroupName --query properties.configuration.ingress.fqdn --output tsv
$catalogUrl = & az containerapp show --name catalog-api --resource-group $ResourceGroupName --query properties.configuration.ingress.fqdn --output tsv
$identityUrl = & az containerapp show --name identity-api --resource-group $ResourceGroupName --query properties.configuration.ingress.fqdn --output tsv

Write-Host "🌐 Application URLs:" -ForegroundColor Green
Write-Host "Web App: https://$webappUrl" -ForegroundColor Cyan
Write-Host "Catalog API: https://$catalogUrl" -ForegroundColor Cyan  
Write-Host "Identity API: https://$identityUrl" -ForegroundColor Cyan

Write-Host "Connection Details:" -ForegroundColor Yellow
Write-Host "PostgreSQL Server: $postgresHost" -ForegroundColor White
Write-Host "Redis Server: $redisHost" -ForegroundColor White
Write-Host "Container Registry: $acrLoginServer" -ForegroundColor White