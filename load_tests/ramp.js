// Ramp test: teste principal da apresentação.
//
// Aumenta gradualmente o número de usuários virtuais (VUs) para descobrir
// até qual nível de concorrência a aplicação atende ao requisito:
//   p95 < 500ms e error rate < 1%
//
// O endpoint testado é escolhido por variável de ambiente, permitindo
// comparar /slow e /fast sob exatamente a mesma carga.
//
// Uso:
//   ENDPOINT=/api/v1/users/slow k6 run load_tests/ramp.js
//   ENDPOINT=/api/v1/users/fast k6 run load_tests/ramp.js
//   BASE_URL=http://localhost:3000 ENDPOINT=/health k6 run load_tests/ramp.js

import http from "k6/http";
import { check } from "k6";

const BASE_URL = __ENV.BASE_URL || "http://localhost:3000";
const ENDPOINT = __ENV.ENDPOINT || "/health";

export const options = {
  stages: [
    { duration: "15s", target: 10 },
    { duration: "15s", target: 25 },
    { duration: "15s", target: 50 },
    { duration: "15s", target: 100 },
    { duration: "15s", target: 200 },
    { duration: "15s", target: 300 },
    { duration: "10s", target: 0 },
  ],
  thresholds: {
    http_req_failed: [ "rate<0.01" ],
    http_req_duration: [ "p(95)<500" ],
  },
};

export default function () {
  const res = http.get(`${BASE_URL}${ENDPOINT}`);

  check(res, {
    "status is 200": (r) => r.status === 200,
  });
}
