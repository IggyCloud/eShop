# eShop Key Vault Setup Script
# This script creates and configures Azure Key Vault with all necessary secrets for eShop

param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory=$true)]
    [string]$KeyVaultName,
    
    [Parameter(Mandatory=$false)]
    [string]$Location = "East US",
    
    [Parameter(Mandatory=$false)]
    [string]$PostgresAdminPassword,
    
    [Parameter(Mandatory=$false)]
    [string]$IdentityServerSecret,
    
    [Parameter(Mandatory=$false)]
    [string]$JwtSecret
)

Write-Host "🔐 Setting up Azure Key Vault for eShop..." -ForegroundColor Green

# Check if user is logged into Azure
Write-Host "Checking Azure login status..." -ForegroundColor Yellow
$account = az account show --query "name" -o tsv 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "Please login to Azure first: az login" -ForegroundColor Red
    exit 1
}
Write-Host "✅ Logged in as: $account" -ForegroundColor Green

# Get current user's object ID for Key Vault access policy
$currentUserObjectId = az ad signed-in-user show --query id --output tsv
Write-Host "Current user object ID: $currentUserObjectId" -ForegroundColor Cyan

# Create resource group if it doesn't exist
Write-Host "Ensuring resource group exists: $ResourceGroupName" -ForegroundColor Yellow
az group create --name $ResourceGroupName --location $Location

# Create Key Vault
Write-Host "Creating Key Vault: $KeyVaultName" -ForegroundColor Yellow
az keyvault create `
    --name $KeyVaultName `
    --resource-group $ResourceGroupName `
    --location $Location `
    --enable-rbac-authorization false `
    --enabled-for-template-deployment true

# Set access policy for current user
Write-Host "Setting Key Vault access policy..." -ForegroundColor Yellow
az keyvault set-policy `
    --name $KeyVaultName `
    --object-id $currentUserObjectId `
    --secret-permissions get list set delete

# Generate secure passwords if not provided
if (-not $PostgresAdminPassword) {
    Write-Host "Generating secure PostgreSQL password..." -ForegroundColor Cyan
    $PostgresAdminPassword = -join ((33..126) | Get-Random -Count 20 | % {[char]$_})
}

if (-not $IdentityServerSecret) {
    Write-Host "Generating IdentityServer secret..." -ForegroundColor Cyan
    $IdentityServerSecret = [System.Web.Security.Membership]::GeneratePassword(32, 8)
}

if (-not $JwtSecret) {
    Write-Host "Generating JWT secret..." -ForegroundColor Cyan
    $JwtSecret = [System.Web.Security.Membership]::GeneratePassword(64, 16)
}

# Store secrets in Key Vault
Write-Host "Storing secrets in Key Vault..." -ForegroundColor Yellow

# Database passwords
az keyvault secret set --vault-name $KeyVaultName --name "postgres-admin-password" --value $PostgresAdminPassword
az keyvault secret set --vault-name $KeyVaultName --name "redis-password" --value "auto-generated-by-azure"

# Identity and authentication secrets
az keyvault secret set --vault-name $KeyVaultName --name "identity-server-secret" --value $IdentityServerSecret
az keyvault secret set --vault-name $KeyVaultName --name "jwt-secret" --value $JwtSecret

# Application-specific secrets
az keyvault secret set --vault-name $KeyVaultName --name "webhook-secret" --value ([System.Web.Security.Membership]::GeneratePassword(32, 8))

# Connection string templates (will be populated during deployment)
$postgresTemplate = 'Host={postgres-host};Database={database};Username=postgres;Password=@Microsoft.KeyVault(VaultName=' + $KeyVaultName + ';SecretName=postgres-admin-password);Include Error Detail=true;Trust Server Certificate=true'
az keyvault secret set --vault-name $KeyVaultName --name "postgres-connection-template" --value $postgresTemplate

Write-Host "✅ Key Vault setup completed!" -ForegroundColor Green
Write-Host "Key Vault Name: $KeyVaultName" -ForegroundColor Cyan
Write-Host "Resource Group: $ResourceGroupName" -ForegroundColor Cyan

# Display secret references for deployment
Write-Host "`n📋 Secret References for Deployment:" -ForegroundColor Green
Write-Host "PostgreSQL Password: @Microsoft.KeyVault(VaultName=$KeyVaultName;SecretName=postgres-admin-password)" -ForegroundColor Yellow
Write-Host "Identity Secret: @Microsoft.KeyVault(VaultName=$KeyVaultName;SecretName=identity-server-secret)" -ForegroundColor Yellow
Write-Host "JWT Secret: @Microsoft.KeyVault(VaultName=$KeyVaultName;SecretName=jwt-secret)" -ForegroundColor Yellow

Write-Host "`n⚠️  Important Security Notes:" -ForegroundColor Yellow
Write-Host "1. The Key Vault is now created with your user permissions" -ForegroundColor White
Write-Host "2. Container Apps will need managed identity to access secrets" -ForegroundColor White
Write-Host "3. Never commit the actual secret values to your repository" -ForegroundColor White
Write-Host "4. Use Key Vault references in your deployment scripts" -ForegroundColor White