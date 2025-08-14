# eShop Local Kubernetes Deployment

This setup provides a simplified local Kubernetes deployment of eShop without authentication complexity, focused on development and monitoring with Grafana.

## Prerequisites

- Local Kubernetes cluster (Docker Desktop, minikube, or kind)
- kubectl configured to access your cluster
- PowerShell (for deployment scripts)

## Quick Start

1. **Deploy to Kubernetes:**
   ```powershell
   .\deploy-local.ps1
   ```

2. **Access the application:**
   - **WebApp**: http://localhost:30080
   - **RabbitMQ Management**: http://localhost:30672 (guest/guest)
   - **Prometheus**: http://localhost:30900
   - **Grafana**: http://localhost:30300 (admin/admin)

3. **Clean up:**
   ```powershell
   .\undeploy-local.ps1
   ```

## Architecture

### Services Deployed

- **PostgreSQL**: Database for catalog and ordering data
- **Redis**: Caching and basket storage
- **RabbitMQ**: Message broker for event bus
- **Catalog API**: Product catalog service
- **Basket API**: Shopping basket service
- **Ordering API**: Order management service
- **WebApp**: Blazor web frontend (with authentication disabled)

### Monitoring Stack

- **Prometheus**: Metrics collection
- **Grafana**: Monitoring dashboards

## Key Changes for Local Development

### Authentication Disabled

The local deployment disables IdentityServer and uses a mock authentication provider:

- `DISABLE_AUTH=true` environment variable enables no-auth mode
- All services accessible without authentication
- Mock user "test-user" is automatically logged in

### Service Configuration

All services are configured to work with local Kubernetes networking:

- Internal service communication via Kubernetes service names
- External access via NodePort services
- Simplified connection strings and configuration

## Manual Deployment

If you prefer manual deployment:

```bash
# Apply all manifests
kubectl apply -k k8s/

# Check status
kubectl get pods -n eshop-local

# View service endpoints
kubectl get svc -n eshop-local
```

## Development Workflow

1. **Build and push custom images** (if needed):
   ```bash
   docker build -t your-registry/eshop-webapp ./src/WebApp
   docker push your-registry/eshop-webapp
   ```

2. **Update image references** in YAML files

3. **Apply changes**:
   ```bash
   kubectl apply -k k8s/
   ```

4. **View logs**:
   ```bash
   kubectl logs -f deployment/webapp -n eshop-local
   ```

## Monitoring

### Grafana Dashboards

Access Grafana at http://localhost:30300:
- Username: `admin`
- Password: `admin`

The deployment includes:
- Pre-configured Prometheus datasource
- eShop application monitoring dashboard
- Request rate and response time metrics

### Prometheus

Access Prometheus at http://localhost:30900 to:
- Query metrics directly
- Check service discovery
- Debug metric collection issues

## File Organization

```
├── k8s/
│   ├── local-deployment/     # Local K8s manifests
│   ├── monitoring/          # Grafana & Prometheus
│   ├── legacy/             # Legacy YAML files
│   └── deploy-local.yaml   # Kustomization file
├── deployment-azure/        # Azure-specific files
│   ├── aspirate.json
│   ├── deploy-to-azure.ps1
│   └── resources/
└── src/WebApp/Extensions/
    └── Extensions.NoAuth.cs # No-auth extensions
```

## Troubleshooting

### Services not starting

```bash
# Check pod status
kubectl describe pod <pod-name> -n eshop-local

# View logs
kubectl logs <pod-name> -n eshop-local
```

### Connectivity issues

```bash
# Test service connectivity
kubectl exec -it <pod-name> -n eshop-local -- curl http://catalog-api/health
```

### Database issues

```bash
# Connect to PostgreSQL
kubectl exec -it deployment/postgres -n eshop-local -- psql -U postgres -d eshop
```

## Production Considerations

This local setup is optimized for development and includes:

- **Simplified authentication**: No IdentityServer complexity
- **In-memory storage**: Data doesn't persist between restarts
- **Development certificates**: Not suitable for production
- **NodePort services**: Use LoadBalancer or Ingress for production

For production deployment, use the Azure-specific files in `deployment-azure/`.