# eShop Azure Deployment Guide with Key Vault Security

## Prerequisites

1. **Install Azure CLI**
   - Download from: https://aka.ms/installazurecliwindows
   - Or use winget: `winget install -e --id Microsoft.AzureCLI`
   - Or use chocolatey: `choco install azure-cli`

2. **Login to Azure**
   ```bash
   az login
   ```

3. **Install Docker Desktop** (if not already installed)
   - Download from: https://www.docker.com/products/docker-desktop

## 🔐 Secure Deployment with Azure Key Vault

This deployment uses Azure Key Vault to store all secrets securely, making it safe for public repositories.

### Step 1: Set Up Key Vault

First, create and configure the Key Vault with all necessary secrets:

```powershell
.\setup-keyvault.ps1 -ResourceGroupName "eshop-rg" -KeyVaultName "eshop-kv-unique123"
```

This script will:
- Create Azure Key Vault
- Generate secure passwords for PostgreSQL, JWT tokens, etc.
- Store all secrets securely in Key Vault
- Configure access policies

### Step 2: Deploy Application

Run the deployment script with Key Vault integration:

```powershell
.\deploy-to-azure.ps1 -ResourceGroupName "eshop-rg" -ContainerAppsEnvironmentName "eshop-env" -KeyVaultName "eshop-kv-unique123"
```

This script will:
- Create Azure Container Registry
- Create PostgreSQL database (using Key Vault password)
- Create Redis cache (storing connection in Key Vault)
- Build and push Docker images
- Deploy all services with managed identity and Key Vault references
- Configure secure secret injection into containers

### Option 2: Manual Deployment

If you prefer to deploy manually or customize the deployment:

#### 1. Create Resources

```bash
# Set variables
RESOURCE_GROUP="eshop-rg"
LOCATION="eastus"
ACR_NAME="eshopregistry$RANDOM"
ACA_ENV="eshop-env"

# Create resource group
az group create --name $RESOURCE_GROUP --location $LOCATION

# Create Azure Container Registry
az acr create --resource-group $RESOURCE_GROUP --name $ACR_NAME --sku Basic --admin-enabled true

# Create Container Apps Environment
az containerapp env create --name $ACA_ENV --resource-group $RESOURCE_GROUP --location $LOCATION
```

#### 2. Build and Push Images

```bash
# Login to ACR
az acr login --name $ACR_NAME

# Build images (run from repository root)
docker build -f src/Identity.API/Dockerfile -t $ACR_NAME.azurecr.io/eshop/identity-api:latest .
docker build -f src/Catalog.API/Dockerfile -t $ACR_NAME.azurecr.io/eshop/catalog-api:latest .
docker build -f src/Basket.API/Dockerfile -t $ACR_NAME.azurecr.io/eshop/basket-api:latest .
docker build -f src/Ordering.API/Dockerfile -t $ACR_NAME.azurecr.io/eshop/ordering-api:latest .
docker build -f src/WebApp/Dockerfile -t $ACR_NAME.azurecr.io/eshop/webapp:latest .

# Push images
docker push $ACR_NAME.azurecr.io/eshop/identity-api:latest
docker push $ACR_NAME.azurecr.io/eshop/catalog-api:latest
docker push $ACR_NAME.azurecr.io/eshop/basket-api:latest
docker push $ACR_NAME.azurecr.io/eshop/ordering-api:latest
docker push $ACR_NAME.azurecr.io/eshop/webapp:latest
```

#### 3. Create Supporting Services

```bash
# PostgreSQL
az postgres flexible-server create \
    --resource-group $RESOURCE_GROUP \
    --name eshop-postgres \
    --location $LOCATION \
    --admin-user postgres \
    --admin-password P@ssw0rd123! \
    --sku-name Standard_B1ms \
    --tier Burstable \
    --public-access 0.0.0.0 \
    --storage-size 32 \
    --version 14

# Create databases
az postgres flexible-server db create --resource-group $RESOURCE_GROUP --server-name eshop-postgres --database-name catalogdb
az postgres flexible-server db create --resource-group $RESOURCE_GROUP --server-name eshop-postgres --database-name identitydb
az postgres flexible-server db create --resource-group $RESOURCE_GROUP --server-name eshop-postgres --database-name orderingdb
az postgres flexible-server db create --resource-group $RESOURCE_GROUP --server-name eshop-postgres --database-name webhooksdb

# Redis Cache
az redis create \
    --resource-group $RESOURCE_GROUP \
    --name eshop-redis \
    --location $LOCATION \
    --sku Basic \
    --vm-size C0
```

#### 4. Deploy Container Apps

Get ACR credentials:
```bash
ACR_USERNAME=$(az acr credential show --name $ACR_NAME --query username --output tsv)
ACR_PASSWORD=$(az acr credential show --name $ACR_NAME --query passwords[0].value --output tsv)
```

Deploy each service:
```bash
# Identity API
az containerapp create \
    --name identity-api \
    --resource-group $RESOURCE_GROUP \
    --environment $ACA_ENV \
    --image $ACR_NAME.azurecr.io/eshop/identity-api:latest \
    --registry-server $ACR_NAME.azurecr.io \
    --registry-username $ACR_USERNAME \
    --registry-password $ACR_PASSWORD \
    --target-port 8080 \
    --ingress external

# Repeat for other services...
```

## Post-Deployment

1. **Get Application URL:**
   ```bash
   az containerapp show --name webapp --resource-group $RESOURCE_GROUP --query properties.configuration.ingress.fqdn --output tsv
   ```

2. **Monitor Logs:**
   ```bash
   az containerapp logs show --name webapp --resource-group $RESOURCE_GROUP --follow
   ```

## Cleanup

To remove all resources:
```bash
az group delete --name $RESOURCE_GROUP --yes --no-wait
```

## Cost Optimization

- Use Basic SKUs for development/testing
- Consider scaling to zero for non-production environments
- Use Azure Dev/Test pricing for development subscriptions

## Security Considerations

- Enable managed identity for service-to-service communication
- Use Azure Key Vault for secrets management
- Configure network restrictions as needed
- Enable diagnostic logging

For production deployments, consider:
- Using Azure Front Door for global load balancing
- Implementing Azure Application Gateway for advanced routing
- Setting up Azure Monitor and Application Insights for observability
- Configuring backup strategies for databases