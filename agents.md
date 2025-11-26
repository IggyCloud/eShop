# Delivery Playbook

This repo now uses the GitHub Actions perf pipeline as the primary delivery path. The former Aspir8-based flow is considered legacy/deprecated.

## Current CI/CD path (preferred)
- Trigger: any push (`.github/workflows/ci-perf.yml`).
- Steps:
  1) Restore/build/test web solution filter (Basket + Ordering unit tests).
  2) Publish `catalog-api` and `basket-api` container images locally (`catalog-api:ci`, `basket-api:ci`).
  3) Bring up the perf compose stack (`.github/compose/ci.yml`) with pgvector Postgres, Redis, RabbitMQ (with health checks).
  4) Wait for Postgres and RabbitMQ to be healthy, then start APIs.
  5) Run k6 perf tests (read/write) against `catalog-api` with thresholds enforced by `.github/scripts/assert-k6.js`.
  6) Teardown the stack.
- Scripts: k6 lives in `resources/k6/scripts`; compose config in `.github/compose/ci.yml`; workflow in `.github/workflows/ci-perf.yml`.
- To run locally (mirror CI):
  ```
  dotnet publish src/Catalog.API/Catalog.API.csproj -c Release -r linux-x64 /t:PublishContainer -p:ContainerRepository=catalog-api -p:ContainerImageTags=ci
  dotnet publish src/Basket.API/Basket.API.csproj -c Release -r linux-x64 /t:PublishContainer -p:ContainerRepository=basket-api -p:ContainerImageTags=ci
  docker compose -p eshopci -f .github/compose/ci.yml up -d
  docker run --rm --network eshopci_default -v "$PWD":/work -w /work -e BASE_URL=http://catalog-api:8080 grafana/k6:0.54.0 run resources/k6/scripts/catalog-api-closed-model-read-test-quick.js
  docker run --rm --network eshopci_default -v "$PWD":/work -w /work -e BASE_URL=http://catalog-api:8080 grafana/k6:0.54.0 run resources/k6/scripts/catalog-api-closed-model-write-test-quick.js
  docker compose -p eshopci -f .github/compose/ci.yml down -v
  ```

## Legacy (deprecated) Aspir8 path
- Docs: `README-ASPIRATE.md`.
- Notes: kept for reference only; prefer the CI/CD pipeline above for builds/tests and perf gating.
- Resources: k6 scripts live under `resources/k6/scripts`; aspirate manifests live under `src/eShop.AppHost/aspirate-output` but are not the recommended path.
