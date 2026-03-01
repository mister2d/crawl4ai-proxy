# Stage 1: Build the Go binary
FROM golang:1.24-alpine AS builder

# Set the working directory
WORKDIR /app

# Copy go.mod and go.sum (if it exists)
COPY go.mod ./
# RUN go mod download # Only if go.sum exists

# Copy the source code
COPY . .

# Build the binary
RUN CGO_ENABLED=0 GOOS=linux go build -o crawl-proxy .

# Stage 2: Create a minimal final image
FROM alpine:3.21

# Add maintainer and source labels
LABEL org.opencontainers.image.source="https://github.com/mister2d/crawl4ai-proxy"
LABEL org.opencontainers.image.description="A simple proxy that enables OpenWebUI to talk to crawl4ai"

# Install necessary packages (like curl for healthcheck)
RUN apk --no-cache add curl

# Create a non-root user
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

# Set the working directory
WORKDIR /home/appuser

# Copy the binary from the builder stage
COPY --from=builder /app/crawl-proxy /usr/local/bin/crawl-proxy

# Use the non-root user
USER appuser

# Expose the application port
EXPOSE 8000

# Set environment variables
ENV LISTEN_PORT=8000

# Healthcheck
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:${LISTEN_PORT}/health || exit 1

# Command to run the application
ENTRYPOINT ["/usr/local/bin/crawl-proxy"]
