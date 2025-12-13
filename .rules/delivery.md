Delivery rules (from agents.md)
1) Use the GitHub Actions perf workflow as the primary path (`.github/workflows/ci-perf.yml`); treat Aspir8 as legacy/reference only.
2) CI trigger: any push. Steps: build/test web solution filter (Basket + Ordering), publish `catalog-api:ci` and `basket-api:ci`, bring up `.github/compose/ci.yml`, wait for Postgres/RabbitMQ healthy, run migrations and reseed identity sequences, execute k6 write then read tests from `resources/k6/scripts`, then tear down.
3) Local mirror of CI: publish the two APIs as containers, `docker compose -p eshopci -f .github/compose/ci.yml up -d`, run k6 scripts against `http://catalog-api:8080`, then `docker compose ... down -v`. DB access for tools: `localhost:55432` / user+pwd `postgres`.
4) Perf telemetry in CI: OTEL trace sampling enabled at 5% via `OTEL_TRACE_SAMPLE_RATIO` on APIs; no extra asserts or exports beyond built-in k6 thresholds.
5) Repo locations: k6 scripts in `resources/k6/scripts`; compose in `.github/compose/ci.yml`; workflow in `.github/workflows/ci-perf.yml`; aspirate manifests live in `src/eShop.AppHost/aspirate-output` but are not the delivery path.
6) Avoid editing Aspir8-generated output unless explicitly required; prefer pipeline/compose changes in the CI stack instead.
