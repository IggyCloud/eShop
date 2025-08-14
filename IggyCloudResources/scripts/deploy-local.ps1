#!/usr/bin/env pwsh

Write-Host "Deploying eShop to local Kubernetes cluster..." -ForegroundColor Green

# Apply the local deployment
kubectl apply -k ../k8s-local/

# Wait for deployments to be ready
Write-Host "Waiting for deployments to be ready..." -ForegroundColor Yellow

kubectl wait --for=condition=available --timeout=300s deployment/postgres -n eshop-local
kubectl wait --for=condition=available --timeout=300s deployment/redis -n eshop-local
kubectl wait --for=condition=available --timeout=300s deployment/rabbitmq -n eshop-local
kubectl wait --for=condition=available --timeout=300s deployment/catalog-api -n eshop-local
kubectl wait --for=condition=available --timeout=300s deployment/basket-api -n eshop-local
kubectl wait --for=condition=available --timeout=300s deployment/ordering-api -n eshop-local
kubectl wait --for=condition=available --timeout=300s deployment/webapp -n eshop-local
kubectl wait --for=condition=available --timeout=300s deployment/prometheus -n eshop-local
kubectl wait --for=condition=available --timeout=300s deployment/grafana -n eshop-local

Write-Host "eShop deployed successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "Access URLs:" -ForegroundColor Cyan
Write-Host "  - WebApp: http://localhost:30080" -ForegroundColor White
Write-Host "  - RabbitMQ Management: http://localhost:30672 (guest/guest)" -ForegroundColor White
Write-Host "  - Prometheus: http://localhost:30900" -ForegroundColor White
Write-Host "  - Grafana: http://localhost:30300 (admin/admin)" -ForegroundColor White
Write-Host ""
Write-Host "To check status: kubectl get pods -n eshop-local" -ForegroundColor Yellow
Write-Host "To view logs: kubectl logs -f deployment/<service-name> -n eshop-local" -ForegroundColor Yellow