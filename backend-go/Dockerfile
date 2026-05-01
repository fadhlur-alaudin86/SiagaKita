# ==========================================
# STAGE 1: Builder
# ==========================================
FROM golang:1.26.2-alpine AS builder

RUN apk update && apk add --no-cache git

WORKDIR /app

COPY go.mod go.sum ./
RUN go mod download

COPY . .

RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-w -s" -o siagakita-api ./cmd/api/main.go

# ==========================================
# STAGE 2: Runner (Production Image)
# ==========================================
FROM alpine:latest

# curl diperlukan untuk Docker healthcheck, tzdata untuk timezone Asia/Jakarta
RUN apk --no-cache add tzdata curl
ENV TZ=Asia/Jakarta

WORKDIR /app

COPY --from=builder /app/siagakita-api .

EXPOSE 8080
EXPOSE 8081

CMD ["./siagakita-api"]