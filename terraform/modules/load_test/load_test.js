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
        { target: 100, duration: "2m" }, // 2분 동안 초당 100개 요청까지 증가
        { target: 200, duration: "2m" }, // 2분 동안 초당 200개 요청까지 증가
        { target: 300, duration: "2m" }, // 2분 동안 초당 300개 요청까지 증가
        { target: 360, duration: "2m" }, // 2분 동안 초당 420개 요청까지 증가
        { target: 420, duration: "2m" }, // 5분 동안 초당 420개 요청 유지
        { target: 0, duration: "2m" }, // 2분 동안 초당 0개 요청까지 감소
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
