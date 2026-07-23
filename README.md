# crawl4ai OpenWebUI proxy
This simple proxy server can be run in a docker container to let an [OpenWebUI](https://github.com/open-webui/open-webui) instance interact with a [crawl4ai](https://github.com/unclecode/crawl4ai) instance.
This makes the OpenWebUI's web search feature a lot faster and way more usable without paying for an API service. 🎉

## Features
- **Modern Docker Image**: Built with a multi-stage process for minimal size and enhanced security.
- **Non-Root Execution**: Runs as a dedicated `appuser` for improved container security.
- **Multi-Arch Support**: Pre-built images available for both `x86_64` (amd64) and `arm64` (Apple Silicon, Raspberry Pi, etc.).
- **Healthcheck Support**: Built-in `/health` endpoint and Docker healthcheck for reliable orchestration.

## Usage
Given a `compose.yml` file that looks something like this:

```yaml
services:
    crawl4ai-proxy:
        image: ghcr.io/mister2d/crawl4ai-proxy:latest
        environment:
            - LISTEN_PORT=8000
            - CRAWL4AI_ENDPOINT=http://crawl4ai:11235/crawl
            # Required if the crawl4ai backend enforces bearer auth (see below).
            # Must match the backend's CRAWL4AI_API_TOKEN value.
            - CRAWL4AI_API_TOKEN=${CRAWL4AI_API_TOKEN}
        healthcheck:
          test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
          interval: 30s
          timeout: 10s
          retries: 3
        networks:
            - openwebui

    openwebui:
        image: ghcr.io/open-webui/open-webui:ollama
        ports:
            - "8080:8080"
        deploy:
            resources:
                reservations:
                    devices:
                        - driver: nvidia
                          count: all
                          capabilities: [gpu]
        networks:
            - openwebui

    crawl4ai:
        image: unclecode/crawl4ai:0.6.0-r2
        shm_size: 1g
        environment:
            # When set, crawl4ai's startup auth guard requires this bearer token
            # on every request. Give the proxy the same value above.
            - CRAWL4AI_API_TOKEN=${CRAWL4AI_API_TOKEN}
        networks:
            - openwebui

networks:
    openwebui:
        driver: bridge
```

## Environment Variables

| Variable | Default | Description |
| --- | --- | --- |
| `LISTEN_PORT` | `8000` | Port the proxy listens on. |
| `LISTEN_IP` | `` (all interfaces) | Address the proxy binds to. |
| `CRAWL4AI_ENDPOINT` | `http://crawl4ai:11235/crawl` | URL of the backend crawl4ai `/crawl` endpoint. |
| `CRAWL4AI_API_TOKEN` | `` (unset) | Optional bearer token. When set, the proxy sends `Authorization: Bearer <token>` on every request to the backend. Required if the crawl4ai server enforces authentication (recent crawl4ai versions refuse to start on a non-loopback bind without a `CRAWL4AI_API_TOKEN`). Leave unset for un-secured backends. |

Run `docker compose up -d`, visit `localhost:8080` in a browser, navigate to `Admin Panel -> Web Search` and under the "Loader" section, set:

- **Web Loader Engine**: external
- **External Web Loader URL**: `http://crawl4ai-proxy:8000/crawl`
- **External Web Loader API Key**: `*` (doesn't matter, but is a required field)

## Local Development & Build

### Requirements
- Go 1.24+
- Docker (optional, for containerized build)

### Build the Binary
```bash
go build -o crawl-proxy .
```

### Build the Docker Image
To build the image locally:
```bash
docker build -t crawl-proxy .
```

To build for multiple architectures locally (requires Docker Buildx):
```bash
docker buildx build --platform linux/amd64,linux/arm64 -t crawl-proxy:local .
```

## CI/CD and Releases
This project uses GitHub Actions for continuous integration and delivery.
- **Tests**: Automated tests run on every push and pull request.
- **Releases**: Pushing a semantic version tag (e.g., `v1.0.0`) automatically builds and pushes a multi-arch image to GHCR with appropriate tags (`1.0.0`, `1.0`, `1`, and `latest`).
