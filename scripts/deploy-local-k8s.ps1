Param(
  [string]$Registry = "localhost:6000",
  [string]$KubeContext = "docker-desktop",
  [switch]$SkipBuild
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$kustomizePath = Join-Path $repoRoot "deploy/k8s/local"

$services = @(
  @{ project = "src/Catalog.API/Catalog.API.csproj"; image = "catalog-api" },
  @{ project = "src/Basket.API/Basket.API.csproj"; image = "basket-api" },
  @{ project = "src/Ordering.API/Ordering.API.csproj"; image = "ordering-api" },
  @{ project = "src/OrderProcessor/OrderProcessor.csproj"; image = "order-processor" },
  @{ project = "src/PaymentProcessor/PaymentProcessor.csproj"; image = "payment-processor" },
  @{ project = "src/Webhooks.API/Webhooks.API.csproj"; image = "webhooks-api" },
  @{ project = "src/WebhookClient/WebhookClient.csproj"; image = "webhooksclient" },
  @{ project = "src/WebApp/WebApp.csproj"; image = "webapp" }
)

function Ensure-Registry {
  param([string]$RegistryHost)
  $parts = $RegistryHost.Split(":")
  $port = if ($parts.Length -gt 1) { $parts[-1] } else { "5000" }
  $name = "eshop-registry"

  $existing = docker ps -a --filter "name=$name" --format "{{.ID}}"
  if (-not $existing) {
    Write-Host "Starting local registry $RegistryHost (container name $name)..."
    docker run -d -p "${port}:5000" --restart=always --name $name registry:2 | Out-Null
  } elseif ((docker inspect -f '{{.State.Running}}' $name) -ne "true") {
    Write-Host "Starting stopped registry container $name..."
    docker start $name | Out-Null
  }
}

function Publish-Service {
  param(
    [string]$ProjectPath,
    [string]$ImageName
  )

  Write-Host "Publishing container for $ImageName from $ProjectPath..."
  dotnet publish $ProjectPath -c Release -r linux-x64 `
    /t:PublishContainer `
    -p:ContainerRegistry=$Registry `
    -p:ContainerImageName=$ImageName `
    -p:ContainerImageTags=latest

  docker push "$Registry/$ImageName:latest"
}

if (-not $SkipBuild) {
  Ensure-Registry -RegistryHost $Registry
  foreach ($svc in $services) {
    Publish-Service -ProjectPath (Join-Path $repoRoot $svc.project) -ImageName $svc.image
  }
} else {
  Write-Host "Skipping image build/push (using existing tags in local registry)..."
}

kubectl --context $KubeContext apply -k $kustomizePath

$deployments = @("catalog-api", "basket-api", "webapp")
foreach ($dep in $deployments) {
  kubectl --context $KubeContext rollout status deployment/$dep --timeout=300s
}

kubectl --context $KubeContext get pods

Write-Host "Local Kubernetes deployment complete."
