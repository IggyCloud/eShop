# IggyCloudResources

Central location for all eShop cloud deployment resources, scripts, and documentation.

## 📁 Folder Structure

```
IggyCloudResources/
├── scripts/               # Deployment and management scripts
│   ├── deploy-local.ps1   # Deploy to local K8s
│   ├── undeploy-local.ps1 # Clean up local deployment
│   └── test-deployment.ps1 # Verify deployment
├── k8s-local/             # Local Kubernetes manifests
│   ├── local-deployment/  # Core service deployments
│   ├── monitoring/        # Grafana & Prometheus
│   ├── legacy/           # Legacy YAML files
│   └── deploy-local.yaml # Kustomization file
├── azure/                # Azure deployment resources
│   ├── aspirate.json     # Aspirate configuration
│   ├── deploy-to-azure.ps1
│   ├── setup-keyvault.ps1
│   └── resources/        # Additional Azure resources
└── docs/                 # Documentation
    └── README-LOCAL-K8S.md # Local K8s deployment guide
```

## 🚀 Quick Start

### Local Kubernetes Deployment

1. **Navigate to scripts folder:**
   ```powershell
   cd IggyCloudResources\scripts
   ```

2. **Deploy to local K8s:**
   ```powershell
   .\deploy-local.ps1
   ```

3. **Test deployment:**
   ```powershell
   .\test-deployment.ps1
   ```

4. **Access services:**
   - **WebApp**: http://localhost:30080
   - **Grafana**: http://localhost:30300 (admin/admin)
   - **Prometheus**: http://localhost:30900
   - **RabbitMQ**: http://localhost:30672 (guest/guest)

5. **Clean up when done:**
   ```powershell
   .\undeploy-local.ps1
   ```

### Azure Deployment

1. **Navigate to azure folder:**
   ```powershell
   cd IggyCloudResources\azure
   ```

2. **Setup Azure resources:**
   ```powershell
   .\setup-keyvault.ps1
   .\deploy-to-azure.ps1
   ```

## 📊 Monitoring & Observability

### Grafana Dashboard
- **URL**: http://localhost:30300
- **Credentials**: admin/admin
- **Features**:
  - Pre-configured Prometheus datasource
  - eShop application metrics
  - Request rate and response time monitoring

### Prometheus Metrics
- **URL**: http://localhost:30900
- **Collects metrics from**:
  - All API services (Catalog, Basket, Ordering)
  - WebApp frontend
  - Infrastructure components

## 🔧 Configuration

### Local Development Features

- **Authentication Disabled**: No IdentityServer complexity
- **Mock Authentication**: Automatic login as "test-user"
- **Simplified Services**: Direct API access without auth tokens
- **Local Storage**: In-memory databases (data doesn't persist)

### Environment Variables

Key configuration for local deployment:
- `DISABLE_AUTH=true`: Enables no-auth mode in WebApp
- `ASPNETCORE_ENVIRONMENT=Development`: Development configuration

## 📝 Documentation

- **[Local K8s Guide](docs/README-LOCAL-K8S.md)**: Comprehensive local deployment documentation
- **Architecture**: Microservices with event-driven communication
- **Monitoring**: Prometheus + Grafana stack
- **Development**: No-auth setup for simplified local development

## 🛠 Development Workflow

1. **Make changes to source code**
2. **Build custom images** (if needed):
   ```bash
   docker build -t your-registry/eshop-webapp ./src/WebApp
   ```
3. **Update image references** in `k8s-local/` manifests
4. **Redeploy**:
   ```powershell
   cd IggyCloudResources\scripts
   .\undeploy-local.ps1
   .\deploy-local.ps1
   ```

## 🔍 Troubleshooting

### Check deployment status:
```bash
kubectl get pods -n eshop-local
```

### View service logs:
```bash
kubectl logs -f deployment/webapp -n eshop-local
```

### Test connectivity:
```bash
kubectl exec -it deployment/webapp -n eshop-local -- curl http://catalog-api/health
```

## 📋 Service Endpoints

| Service | Internal URL | External URL |
|---------|-------------|-------------|
| WebApp | webapp:80 | localhost:30080 |
| Catalog API | catalog-api:80 | - |
| Basket API | basket-api:80 | - |
| Ordering API | ordering-api:80 | - |
| RabbitMQ | rabbitmq:5672 | localhost:30672 |
| Prometheus | prometheus:9090 | localhost:30900 |
| Grafana | grafana:3000 | localhost:30300 |

## ⚠️ Important Notes

- **aspirate.json**: Must remain in project root for Aspirate functionality
- **Development Focus**: Local setup optimized for development, not production
- **Data Persistence**: Local deployment uses in-memory storage
- **Authentication**: Disabled for local K8s, enabled for Azure deployment

---

*This resource folder consolidates all deployment assets for easy management and clear separation between local development and cloud deployment scenarios.*