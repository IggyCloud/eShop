#!/usr/bin/env pwsh

Write-Host "Testing eShop local deployment..." -ForegroundColor Green

# Check if namespace exists
$namespace = kubectl get namespace eshop-local -o name 2>$null
if (-not $namespace) {
    Write-Host "ERROR: eshop-local namespace not found. Run deploy-local.ps1 first." -ForegroundColor Red
    exit 1
}

Write-Host "✓ Namespace exists" -ForegroundColor Green

# Check pod status
Write-Host "`nChecking pod status..." -ForegroundColor Yellow
kubectl get pods -n eshop-local

# Test service endpoints
Write-Host "`nTesting service endpoints..." -ForegroundColor Yellow

$endpoints = @(
    @{Name="WebApp"; Url="http://localhost:30080"; Port=30080},
    @{Name="RabbitMQ Management"; Url="http://localhost:30672"; Port=30672},
    @{Name="Prometheus"; Url="http://localhost:30900"; Port=30900},
    @{Name="Grafana"; Url="http://localhost:30300"; Port=30300}
)

foreach ($endpoint in $endpoints) {
    try {
        $response = Invoke-WebRequest -Uri $endpoint.Url -Method Head -TimeoutSec 10 -ErrorAction Stop
        Write-Host "✓ $($endpoint.Name): $($endpoint.Url) - Status: $($response.StatusCode)" -ForegroundColor Green
    }
    catch {
        Write-Host "✗ $($endpoint.Name): $($endpoint.Url) - Error: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "`nDeployment test completed!" -ForegroundColor Cyan
Write-Host "Access your services at:" -ForegroundColor White
foreach ($endpoint in $endpoints) {
    Write-Host "  - $($endpoint.Name): $($endpoint.Url)" -ForegroundColor Cyan
}