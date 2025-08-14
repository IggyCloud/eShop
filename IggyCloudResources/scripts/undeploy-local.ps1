#!/usr/bin/env pwsh

Write-Host "Removing eShop from local Kubernetes cluster..." -ForegroundColor Yellow

# Delete the local deployment
kubectl delete -k ../k8s-local/ --ignore-not-found=true

Write-Host "eShop removed successfully!" -ForegroundColor Green