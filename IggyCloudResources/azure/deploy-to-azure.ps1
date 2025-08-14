# eShop Azure Container Apps Deployment Script
# This script deploys the eShop application to Azure Container Apps using Key Vault for secrets

param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory=$true)]
    [string]$ContainerAppsEnvironmentName,
    
    [Parameter(Mandatory=$true)]
    [string]$KeyVaultName,
    
    [Parameter(Mandatory=$false)]
    [string]$Location = "East US",
    
    [Parameter(Mandatory=$false)]
    [string]$RegistryName = "eshopregistry"
)

Write-Host "🚀 Starting eShop deployment to Azure Container Apps..." -ForegroundColor Green

# Check if user is logged into Azure
Write-Host "Checking Azure login status..." -ForegroundColor Yellow
$account = az account show --query "name" -o tsv 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "Please login to Azure first: az login" -ForegroundColor Red
    exit 1
}
Write-Host "✅ Logged in as: $account" -ForegroundColor Green

# Create resource group if it doesn't exist
Write-Host "Creating resource group: $ResourceGroupName" -ForegroundColor Yellow
az group create --name $ResourceGroupName --location $Location

# Create Azure Container Registry
Write-Host "Creating Azure Container Registry: $RegistryName" -ForegroundColor Yellow
az acr create --resource-group $ResourceGroupName --name $RegistryName --sku Basic --admin-enabled true

# Get ACR credentials
$acrLoginServer = az acr show --name $RegistryName --query loginServer --output tsv
$acrUsername = az acr credential show --name $RegistryName --query username --output tsv
$acrPassword = az acr credential show --name $RegistryName --query passwords[0].value --output tsv

Write-Host "✅ ACR Login Server: $acrLoginServer" -ForegroundColor Green

# Create Container Apps Environment with Key Vault integration
Write-Host "Creating Container Apps Environment: $ContainerAppsEnvironmentName" -ForegroundColor Yellow
az containerapp env create `
    --name $ContainerAppsEnvironmentName `
    --resource-group $ResourceGroupName `
    --location $Location

# Get Key Vault ID for managed identity access
$keyVaultId = az keyvault show --name $KeyVaultName --resource-group $ResourceGroupName --query id --output tsv

# Build and push container images
Write-Host "Building and pushing container images..." -ForegroundColor Yellow

# Login to ACR
az acr login --name $RegistryName

# Build images for each service
$services = @(
    @{name="identity-api"; path="src/Identity.API"},
    @{name="catalog-api"; path="src/Catalog.API"},
    @{name="basket-api"; path="src/Basket.API"},
    @{name="ordering-api"; path="src/Ordering.API"},
    @{name="webhooks-api"; path="src/Webhooks.API"},
    @{name="payment-processor"; path="src/PaymentProcessor"},
    @{name="order-processor"; path="src/OrderProcessor"},
    @{name="mobile-bff"; path="src/Mobile.Bff.Shopping"},
    @{name="webapp"; path="src/WebApp"},
    @{name="webhooksclient"; path="src/WebhookClient"}
)

foreach ($service in $services) {
    Write-Host "Building $($service.name)..." -ForegroundColor Cyan
    docker build -f "$($service.path)/Dockerfile" -t "$acrLoginServer/eshop/$($service.name):latest" .
    docker push "$acrLoginServer/eshop/$($service.name):latest"
}

# Get PostgreSQL password from Key Vault
Write-Host "Retrieving PostgreSQL password from Key Vault..." -ForegroundColor Yellow
$PostgresPassword = az keyvault secret show --vault-name $KeyVaultName --name "postgres-admin-password" --query value --output tsv

# Create PostgreSQL flexible server
Write-Host "Creating PostgreSQL server..." -ForegroundColor Yellow
$postgresServerName = "$ResourceGroupName-postgres"
az postgres flexible-server create `
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
    az postgres flexible-server db create `
        --resource-group $ResourceGroupName `
        --server-name $postgresServerName `
        --database-name $db
}

# Create Redis cache
Write-Host "Creating Redis cache..." -ForegroundColor Yellow
$redisName = "$ResourceGroupName-redis"
az redis create `
    --resource-group $ResourceGroupName `
    --name $redisName `
    --location $Location `
    --sku Basic `
    --vm-size C0

# Get connection strings and store in Key Vault
$postgresHost = az postgres flexible-server show --resource-group $ResourceGroupName --name $postgresServerName --query fullyQualifiedDomainName --output tsv
$redisHost = az redis show --resource-group $ResourceGroupName --name $redisName --query hostName --output tsv
$redisKey = az redis list-keys --resource-group $ResourceGroupName --name $redisName --query primaryKey --output tsv

# Store Redis password in Key Vault
az keyvault secret set --vault-name $KeyVaultName --name "redis-password" --value $redisKey

# Create connection string templates that reference Key Vault
$postgresConnectionString = "Host=$postgresHost;Database=catalogdb;Username=postgres;Password=@Microsoft.KeyVault(VaultName=$KeyVaultName;SecretName=postgres-admin-password);Include Error Detail=true;Trust Server Certificate=true"
$identityConnectionString = "Host=$postgresHost;Database=identitydb;Username=postgres;Password=@Microsoft.KeyVault(VaultName=$KeyVaultName;SecretName=postgres-admin-password);Include Error Detail=true;Trust Server Certificate=true"
$orderingConnectionString = "Host=$postgresHost;Database=orderingdb;Username=postgres;Password=@Microsoft.KeyVault(VaultName=$KeyVaultName;SecretName=postgres-admin-password);Include Error Detail=true;Trust Server Certificate=true"
$webhooksConnectionString = "Host=$postgresHost;Database=webhooksdb;Username=postgres;Password=@Microsoft.KeyVault(VaultName=$KeyVaultName;SecretName=postgres-admin-password);Include Error Detail=true;Trust Server Certificate=true"
$redisConnectionString = "$redisHost:6380,password=@Microsoft.KeyVault(VaultName=$KeyVaultName;SecretName=redis-password),ssl=True,abortConnect=False"

# Store connection strings in Key Vault
az keyvault secret set --vault-name $KeyVaultName --name "postgres-catalog-connection" --value $postgresConnectionString
az keyvault secret set --vault-name $KeyVaultName --name "postgres-identity-connection" --value $identityConnectionString  
az keyvault secret set --vault-name $KeyVaultName --name "postgres-ordering-connection" --value $orderingConnectionString
az keyvault secret set --vault-name $KeyVaultName --name "postgres-webhooks-connection" --value $webhooksConnectionString
az keyvault secret set --vault-name $KeyVaultName --name "redis-connection" --value $redisConnectionString

# Deploy container apps with managed identity and Key Vault integration
Write-Host "Deploying container apps with Key Vault integration..." -ForegroundColor Yellow

# Create a managed identity for Key Vault access
Write-Host "Creating user-assigned managed identity..." -ForegroundColor Yellow
$identityName = "eshop-identity"
az identity create --resource-group $ResourceGroupName --name $identityName --location $Location
$identityId = az identity show --resource-group $ResourceGroupName --name $identityName --query id --output tsv
$identityClientId = az identity show --resource-group $ResourceGroupName --name $identityName --query clientId --output tsv
$identityPrincipalId = az identity show --resource-group $ResourceGroupName --name $identityName --query principalId --output tsv

# Grant Key Vault access to the managed identity
Write-Host "Granting Key Vault access to managed identity..." -ForegroundColor Yellow
az keyvault set-policy `
    --name $KeyVaultName `
    --object-id $identityPrincipalId `
    --secret-permissions get list

# Identity API
Write-Host "Deploying Identity API..." -ForegroundColor Cyan
az containerapp create `
    --name identity-api `
    --resource-group $ResourceGroupName `
    --environment $ContainerAppsEnvironmentName `
    --image "$acrLoginServer/eshop/identity-api:latest" `
    --registry-server $acrLoginServer `
    --registry-username $acrUsername `
    --registry-password $acrPassword `
    --user-assigned $identityId `
    --target-port 8080 `
    --ingress external `
    --secrets "identity-connection=@Microsoft.KeyVault(VaultName=$KeyVaultName;SecretName=postgres-identity-connection)" `
    --secrets "jwt-secret=@Microsoft.KeyVault(VaultName=$KeyVaultName;SecretName=jwt-secret)" `
    --env-vars "ConnectionStrings__DefaultConnection=secretref:identity-connection" "JwtSettings__Secret=secretref:jwt-secret"

# Catalog API  
Write-Host "Deploying Catalog API..." -ForegroundColor Cyan
az containerapp create `
    --name catalog-api `
    --resource-group $ResourceGroupName `
    --environment $ContainerAppsEnvironmentName `
    --image "$acrLoginServer/eshop/catalog-api:latest" `
    --registry-server $acrLoginServer `
    --registry-username $acrUsername `
    --registry-password $acrPassword `
    --user-assigned $identityId `
    --target-port 8080 `
    --ingress external `
    --secrets "catalog-connection=@Microsoft.KeyVault(VaultName=$KeyVaultName;SecretName=postgres-catalog-connection)" `
    --env-vars "ConnectionStrings__CatalogDatabase=secretref:catalog-connection"

# Basket API
Write-Host "Deploying Basket API..." -ForegroundColor Cyan
az containerapp create `
    --name basket-api `
    --resource-group $ResourceGroupName `
    --environment $ContainerAppsEnvironmentName `
    --image "$acrLoginServer/eshop/basket-api:latest" `
    --registry-server $acrLoginServer `
    --registry-username $acrUsername `
    --registry-password $acrPassword `
    --user-assigned $identityId `
    --target-port 8080 `
    --ingress external `
    --secrets "redis-connection=@Microsoft.KeyVault(VaultName=$KeyVaultName;SecretName=redis-connection)" `
    --env-vars "ConnectionStrings__Redis=secretref:redis-connection"

# Ordering API
Write-Host "Deploying Ordering API..." -ForegroundColor Cyan
az containerapp create `
    --name ordering-api `
    --resource-group $ResourceGroupName `
    --environment $ContainerAppsEnvironmentName `
    --image "$acrLoginServer/eshop/ordering-api:latest" `
    --registry-server $acrLoginServer `
    --registry-username $acrUsername `
    --registry-password $acrPassword `
    --user-assigned $identityId `
    --target-port 8080 `
    --ingress external `
    --secrets "ordering-connection=@Microsoft.KeyVault(VaultName=$KeyVaultName;SecretName=postgres-ordering-connection)" `
    --env-vars "ConnectionStrings__OrderingDatabase=secretref:ordering-connection"

# Webhooks API
Write-Host "Deploying Webhooks API..." -ForegroundColor Cyan
az containerapp create `
    --name webhooks-api `
    --resource-group $ResourceGroupName `
    --environment $ContainerAppsEnvironmentName `
    --image "$acrLoginServer/eshop/webhooks-api:latest" `
    --registry-server $acrLoginServer `
    --registry-username $acrUsername `
    --registry-password $acrPassword `
    --user-assigned $identityId `
    --target-port 8080 `
    --ingress external `
    --secrets "webhooks-connection=@Microsoft.KeyVault(VaultName=$KeyVaultName;SecretName=postgres-webhooks-connection)" `
    --secrets "webhook-secret=@Microsoft.KeyVault(VaultName=$KeyVaultName;SecretName=webhook-secret)" `
    --env-vars "ConnectionStrings__DefaultConnection=secretref:webhooks-connection" "WebhookSettings__Secret=secretref:webhook-secret"

# Web App
Write-Host "Deploying Web App..." -ForegroundColor Cyan
az containerapp create `
    --name webapp `
    --resource-group $ResourceGroupName `
    --environment $ContainerAppsEnvironmentName `
    --image "$acrLoginServer/eshop/webapp:latest" `
    --registry-server $acrLoginServer `
    --registry-username $acrUsername `
    --registry-password $acrPassword `
    --user-assigned $identityId `
    --target-port 8080 `
    --ingress external

Write-Host "🎉 Deployment completed!" -ForegroundColor Green
Write-Host "Your eShop application is now running on Azure Container Apps." -ForegroundColor Green

# Get app URLs
$webappUrl = az containerapp show --name webapp --resource-group $ResourceGroupName --query properties.configuration.ingress.fqdn --output tsv
Write-Host "🌐 Web App URL: https://$webappUrl" -ForegroundColor Cyan