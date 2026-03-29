# syntax=docker/dockerfile:1

FROM golang:1.23-alpine AS build
WORKDIR /src
RUN apk add --no-cache ca-certificates
COPY go.mod go.sum ./
RUN go mod download
COPY cmd ./cmd
COPY internal ./internal
RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /demo-api ./cmd/demo-api

FROM alpine:3.21
RUN apk add --no-cache ca-certificates
COPY --from=build /demo-api /demo-api
USER 65532:65532
EXPOSE 8080
ENTRYPOINT ["/demo-api"]
