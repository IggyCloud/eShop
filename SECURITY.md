# Security Implementation Guide

## Overview

This eShop deployment implements enterprise-grade security practices suitable for production environments and public repositories.

## 🔐 Key Security Features

### 1. Azure Key Vault Integration
- **No secrets in code**: All passwords, connection strings, and API keys stored in Azure Key Vault
- **Managed Identity**: Container Apps use managed identity to access Key Vault (no passwords or keys)
- **Least Privilege**: Each service only accesses the secrets it needs
- **Audit Trail**: All secret access is logged and auditable

### 2. Secret Management
- **Auto-generated passwords**: Strong passwords generated automatically
- **Connection string templates**: Database passwords referenced via Key Vault
- **Runtime secret injection**: Secrets injected at runtime, never stored in images
- **Secret rotation**: Easy secret rotation without redeploying applications

### 3. Network Security
- **Container Apps Environment**: Isolated network environment
- **Internal communication**: Services communicate via internal endpoints
- **PostgreSQL**: Configured with SSL and restricted access
- **Redis**: Password-protected with SSL encryption

## 🔍 Security Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Container     │    │   Managed        │    │   Azure Key     │
│   Apps          │────│   Identity       │────│   Vault         │
│                 │    │                  │    │                 │
│ • Web App       │    │ • No passwords   │    │ • Secrets       │
│ • APIs          │    │ • Azure AD auth  │    │ • Connections   │
│ • Services      │    │ • Scoped access  │    │ • Certificates  │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

## 📋 Security Checklist

### Before Deployment
- [ ] Azure CLI installed and logged in
- [ ] Appropriate Azure permissions (Contributor + Key Vault Administrator)
- [ ] Unique Key Vault name chosen (globally unique)
- [ ] Resource group planned and created

### During Deployment
- [ ] Key Vault created with proper access policies
- [ ] Strong passwords generated and stored
- [ ] Managed identity created and configured
- [ ] Container Apps deployed with Key Vault references
- [ ] Database connections secured with SSL

### After Deployment
- [ ] Verify all services can access their secrets
- [ ] Test application functionality
- [ ] Review Key Vault access logs
- [ ] Document Key Vault name and resource group

## 🛡️ Security Best Practices Implemented

### 1. Infrastructure Security
```powershell
# Managed Identity for Key Vault access (no passwords)
$identityId = az identity create --resource-group $ResourceGroupName --name $identityName

# Key Vault with proper access policies
az keyvault set-policy --name $KeyVaultName --object-id $identityPrincipalId --secret-permissions get list
```

### 2. Secret References in Container Apps
```yaml
secrets:
  - name: "db-connection"
    keyVaultUrl: "@Microsoft.KeyVault(VaultName=your-kv;SecretName=postgres-connection)"
env:
  - name: "ConnectionStrings__Database"
    secretRef: "db-connection"
```

### 3. Connection String Security
```csharp
// Before: Insecure (password in connection string)
"Host=server;Database=db;Username=user;Password=plaintext123"

// After: Secure (Key Vault reference)
"Host=server;Database=db;Username=user;Password=@Microsoft.KeyVault(VaultName=kv;SecretName=password)"
```

## 🔄 Secret Rotation

### Automatic Rotation (Recommended)
1. Enable Key Vault secret rotation policies
2. Set up Azure Functions for automated rotation
3. Configure applications to refresh secrets periodically

### Manual Rotation
```powershell
# Update password in Key Vault
az keyvault secret set --vault-name $KeyVaultName --name "postgres-admin-password" --value $newPassword

# Restart Container Apps to pick up new secret
az containerapp revision restart --name identity-api --resource-group $ResourceGroupName
```

## 📊 Security Monitoring

### Key Vault Monitoring
- Enable diagnostic logging for all Key Vault operations
- Monitor secret access patterns
- Set up alerts for unusual access patterns
- Regular access reviews

### Container Apps Monitoring
```powershell
# View application logs
az containerapp logs show --name webapp --resource-group $ResourceGroupName --follow

# Monitor Key Vault access
az monitor activity-log list --resource-group $ResourceGroupName
```

## 🚨 Security Incidents

### If Secrets Are Compromised
1. **Immediate Actions**:
   - Rotate all affected secrets in Key Vault
   - Review access logs to understand scope
   - Restart affected Container Apps

2. **Investigation**:
   - Check Key Vault access logs
   - Review Container Apps logs
   - Verify network security groups

3. **Recovery**:
   - Generate new secrets
   - Update Key Vault
   - Validate all services are working

## 📚 Additional Security Resources

- [Azure Key Vault Security Guide](https://docs.microsoft.com/azure/key-vault/general/security-features)
- [Container Apps Security Best Practices](https://docs.microsoft.com/azure/container-apps/security)
- [Managed Identity Documentation](https://docs.microsoft.com/azure/active-directory/managed-identities-azure-resources/)
- [Azure Security Baseline](https://docs.microsoft.com/security/benchmark/azure/)

## 🔧 Troubleshooting Security Issues

### Key Vault Access Denied
```powershell
# Check managed identity permissions
az keyvault show-deleted-vault --name $KeyVaultName
az role assignment list --assignee $identityPrincipalId
```

### Container App Can't Access Secrets
```powershell
# Verify Key Vault reference format
az containerapp show --name webapp --resource-group $ResourceGroupName --query properties.template.containers[0].env

# Check managed identity assignment
az containerapp identity show --name webapp --resource-group $ResourceGroupName
```

### Connection Failures
```powershell
# Test Key Vault connectivity
az keyvault secret show --vault-name $KeyVaultName --name "postgres-connection" --query value

# Verify PostgreSQL configuration  
az postgres flexible-server show --resource-group $ResourceGroupName --name $postgresServerName
```

## 📞 Security Support

For security-related issues:
1. Check Azure Security Center recommendations
2. Review diagnostic logs and metrics
3. Consult Azure documentation
4. Contact Azure Support for critical security incidents

Remember: **Never commit secrets to your repository, even in private repos!**