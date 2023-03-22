# Pin specific version for stability
# Use separate stage for building image
# Use debian for easier build utilities
FROM golang:1.19-bullseye AS build-base

# ENV GOARCH=amd64
ARG BUILD_COMMIT
ARG BUILD_TIME

WORKDIR /app 

# Copy only files required to install dependencies (better layer caching)
COPY go.mod go.sum ./

# Use cache mount to speed up install of existing dependencies
RUN --mount=type=cache,target=/go/pkg/mod \
  --mount=type=cache,target=/root/.cache/go-build \
  go mod download

COPY . .

RUN go build \
  -ldflags="-linkmode external -extldflags -static \
    -X gitlab.com/cjexpress/tildi/lineoa/api/signac.buildcommit=$BUILD_COMMIT \
    -X gitlab.com/cjexpress/tildi/lineoa/api/signac.buildtime=$BUILD_TIME" \
  -o api-golang

# Separate build from deploy stage

FROM cgr.dev/chainguard/static:latest

LABEL version="X.Y.Z"

USER nonroot:nonroot

COPY --from=krallin/ubuntu-tini:trusty /usr/bin/tini-static ./tini-static

COPY --from=build-base /app/api-golang .

# Indicate expected port
EXPOSE 8080

ENTRYPOINT [ "./tini-static", "--" ]

CMD ["/api-golang"]