import http from "k6/http";
import { check, sleep } from "k6";
import { Counter, Rate } from "k6/metrics";

const targetURL = __ENV.TARGET_URL;

const readRate = 0.9; // 읽기 작업 비율
const writeRate = 0.1; // 쓰기 작업 비율

export let options = {
  scenarios: {
    normal_traffic: {
      executor: "constant-arrival-rate",
      duration: "10m",
      rate: 420,
      timeUnit: "1s",
      preAllocatedVUs: 50,
      maxVUs: 500,
    },
    peak_time_traffic: {
      executor: "constant-arrival-rate",
      duration: "10m",
      rate: 1670,
      timeUnit: "1s",
      startTime: "10m",
      preAllocatedVUs: 100,
      maxVUs: 500,
    },
  },
  thresholds: {
    http_req_duration: ["p(95)<100"], //
    checks: ["rate>0.999999"],
  },
};

function getRandomInt(min, max) {
  return Math.floor(Math.random() * (max - min)) + min;
}

export default function () {
  let res;
  if (Math.random() < readRate) {
    var randomId = getRandomInt(1, 5000);
    res = http.get(`${targetURL}/home?id=${randomId}`);
  } else {
    res = http.post(
      `${targetURL}/article`,
      JSON.stringify({ employee_id: randomId, content: "good" }),
      {
        headers: { "Content-Type": "application/json" },
      }
    );
  }

  check(res, {
    "status is 200 or 201": (r) => r.status === 200 || r.status === 201,
  });
}
