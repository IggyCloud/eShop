import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate } from 'k6/metrics';

const errorRate = new Rate('errors');
const BASE_URL = __ENV.BASE_URL || 'http://catalog-api.default.svc.cluster.local:8080';

export let options = {
  stages: [
    { duration: '30s', target: 100 },
  ],
  thresholds: {
    http_req_duration: ['p(95)<500'], 
    http_req_failed: ['rate<0.01'], 
    errors: ['rate<0.01'], 
  },
};

export default function () {
  let catalogResponse = http.get(`${BASE_URL}/api/catalog/items?api-version=1.0`, {
    headers: {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    },
  });

  check(catalogResponse, {
    'catalog API status is 200': (r) => r.status === 200,
    'catalog API response time < 500ms': (r) => r.timings.duration < 500,
    'catalog API returns JSON data': (r) => {
      try {
        const data = JSON.parse(r.body);
        return data && data.data && Array.isArray(data.data);
      } catch (e) {
        return false;
      }
    },
  }) || errorRate.add(1);
}
