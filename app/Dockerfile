FROM golang:1.21 as builder
# 작업 디렉토리 설정 
WORKDIR /app
# 의존성 설치
COPY go.mod go.sum ./
RUN go mod download
# 소스코드 복사 후실행파일 빌드 
COPY . .
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o app .

FROM alpine:latest
# 빌드 스테이지에서 실행파일 가져오기
COPY --from=builder /app/app /app
CMD ["/app"]


