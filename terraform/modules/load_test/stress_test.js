import http from "k6/http";
import { check, sleep } from "k6";
import { Counter, Rate } from "k6/metrics";

const targetURL = __ENV.TARGET_URL;

const readRate = 0.9; // 읽기 작업 비율
const writeRate = 0.1; // 쓰기 작업 비율

export let options = {
  scenarios: {
    ramping_requests: {
      executor: "ramping-arrival-rate",
      startRate: 0, // 시작 시 초당 요청 수
      timeUnit: "1s", // rate 단위
      preAllocatedVUs: 50, // 필요한 VUs 수
      maxVUs: 500, // 최대 VUs 수
      stages: [
        { target: 50, duration: "2m" },
        { target: 100, duration: "2m" },
        { target: 200, duration: "2m" },
        { target: 300, duration: "2m" },
        { target: 420, duration: "10m" },
        { target: 500, duration: "2m" },
        { target: 600, duration: "2m" },
        { target: 700, duration: "2m" },
        { target: 800, duration: "2m" },
        { target: 900, duration: "2m" },
        { target: 1000, duration: "2m" },
        { target: 1100, duration: "2m" },
        { target: 1200, duration: "2m" },
        { target: 1300, duration: "2m" },
        { target: 1400, duration: "2m" },
        { target: 1500, duration: "2m" },
        { target: 1600, duration: "2m" },
        { target: 1670, duration: "10m" },
      ],
    },
  },
  thresholds: {
    http_req_duration: ["p(95)<100"], // 95%의 요청이 500ms 이내에 완료되어야 함
  },
};

function getRandomInt(max) {
  return Math.floor(Math.random() * max);
}

export default function () {
  let res;
  if (Math.random() < readRate) {
    var randomId = getRandomInt(5000);
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
    "status is 200": (r) => r.status === 200 || r.status === 201,
  });
}
