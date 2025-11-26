#!/usr/bin/env node
/* eslint-disable no-console */
const fs = require('fs');
const path = require('path');

function loadSummary(filePath) {
  const full = path.resolve(process.cwd(), filePath);
  if (!fs.existsSync(full)) {
    throw new Error(`Summary file not found: ${filePath}`);
  }
  return JSON.parse(fs.readFileSync(full, 'utf8'));
}

function getMetric(summary, name, field) {
  const metric = summary.metrics?.[name];
  if (!metric) return undefined;
  return metric[field];
}

function assertSpec(summary, spec) {
  const failures = [];

  const p95 = getMetric(summary, 'http_req_duration', 'p(95)');
  if (p95 === undefined || p95 > spec.p95Ms) {
    failures.push(`p95 ${p95 ?? 'n/a'}ms > ${spec.p95Ms}ms`);
  }

  const failRate = getMetric(summary, 'http_req_failed', 'rate');
  if (failRate === undefined || failRate > spec.failRate) {
    failures.push(`fail rate ${failRate ?? 'n/a'} > ${spec.failRate}`);
  }

  return failures;
}

function main() {
  const files = process.argv.slice(2);
  if (files.length === 0) {
    console.error('Usage: assert-k6.js <summary1.json> [summary2.json ...]');
    process.exit(2);
  }

  const specs = [
    { file: files[0], name: 'read', p95Ms: 300, failRate: 0.01 },
    { file: files[1], name: 'write', p95Ms: 800, failRate: 0.05 },
  ].filter((s) => s.file);

  const allFailures = [];
  specs.forEach((spec) => {
    const summary = loadSummary(spec.file);
    const failures = assertSpec(summary, spec);
    if (failures.length) {
      allFailures.push({ name: spec.name, failures });
    }
  });

  if (allFailures.length) {
    console.error('k6 performance gate failed:');
    allFailures.forEach((f) => {
      console.error(`  ${f.name}: ${f.failures.join('; ')}`);
    });
    process.exit(1);
  }

  console.log('k6 performance gate passed.');
}

main();
