// Baseline: mede o desempenho do Rails/Puma fazendo praticamente nenhum trabalho.
// Serve de referência para comparar com /slow e /fast.
//
// Uso:
//   k6 run load_tests/health.js
//   BASE_URL=http://localhost:3000 k6 run load_tests/health.js

import http from "k6/http";
import { check } from "k6";

const BASE_URL = __ENV.BASE_URL || "http://localhost:3000";

export const options = {
  vus: 50,
  duration: "30s",
  thresholds: {
    http_req_failed: [ "rate<0.01" ],
    http_req_duration: [ "p(95)<500" ],
  },
};

export default function () {
  const res = http.get(`${BASE_URL}/health`);

  check(res, {
    "status is 200": (r) => r.status === 200,
  });
}
