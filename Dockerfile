# Multi-stage build for GoKeyCheck
FROM golang:1.21-alpine AS builder

# Install git for version information
RUN apk add --no-cache git

# Set working directory
WORKDIR /app

# Copy go mod and sum files
COPY go.mod go.sum ./

# Download dependencies
RUN go mod download

# Copy source code
COPY . .

# Build the application
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o gokeycheck ./cmd/gokeycheck

# Final stage
FROM alpine:latest

# Install ca-certificates for HTTPS requests
RUN apk --no-cache add ca-certificates

# Create non-root user
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

# Set working directory
WORKDIR /app

# Copy binary from builder stage
COPY --from=builder /app/gokeycheck .

# Change ownership to appuser
RUN chown appuser:appgroup gokeycheck

# Switch to non-root user
USER appuser

# Expose working directory as volume
VOLUME ["/workspace"]

# Set default working directory for scans
WORKDIR /workspace

# Default command
ENTRYPOINT ["/app/gokeycheck"]
CMD ["--help"]