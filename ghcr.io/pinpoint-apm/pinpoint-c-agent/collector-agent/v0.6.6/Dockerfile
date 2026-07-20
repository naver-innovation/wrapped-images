FROM golang:1.26.4-alpine3.24 AS builder
WORKDIR /src
USER root

RUN apk add --no-cache make protobuf-dev git
RUN go install google.golang.org/protobuf/cmd/protoc-gen-go@v1.33.0 \
    && go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@v1.3.0

RUN git clone --depth 1 --recurse-submodules \
    --branch v0.6.6 \
    https://github.com/pinpoint-apm/pinpoint-c-agent.git \
    /src/pinpoint-c-agent

WORKDIR /src/pinpoint-c-agent/collector-agent
RUN go get google.golang.org/grpc@v1.79.3 && go mod tidy
RUN make TAG=v0.6.6

FROM me-riyadh-1.ocir.io/axlo4g31gl45/baseimage/alpine:3.23
USER root
WORKDIR /
COPY --from=builder \
    /src/pinpoint-c-agent/collector-agent/collector-agent \
    /usr/local/bin/CollectorAgent

LABEL org.opencontainers.image.source="https://github.com/pinpoint-apm/pinpoint-c-agent.git"
LABEL org.opencontainers.image.description="collector agent for pinpoint-collector"
LABEL org.opencontainers.image.licenses="Apache-2.0"

ENTRYPOINT ["CollectorAgent"]
