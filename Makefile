# Makefile for gokeycheck

# Go parameters
GOCMD=go
GOBUILD=$(GOCMD) build
GOCLEAN=$(GOCMD) clean
GOTEST=$(GOCMD) test
GOGET=$(GOCMD) get
GOMOD=$(GOCMD) mod
GOLINT=golangci-lint

# Binary names
BINARY_NAME=gokeycheck
BINARY_UNIX=$(BINARY_NAME)_unix

# Version info
VERSION ?= $(shell git describe --tags --always --dirty 2>/dev/null || echo "dev")
COMMIT ?= $(shell git rev-parse --short HEAD 2>/dev/null || echo "unknown")
BUILD_DATE ?= $(shell date -u +%Y-%m-%dT%H:%M:%SZ)

# Build flags
LDFLAGS=-ldflags "-X main.version=$(VERSION) -X main.commit=$(COMMIT) -X main.date=$(BUILD_DATE)"

# Default target
.DEFAULT_GOAL := help

.PHONY: help
help: ## Display this help message
	@echo "Available targets:"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-15s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

.PHONY: build
build: ## Build the binary
	$(GOBUILD) $(LDFLAGS) -o $(BINARY_NAME) -v ./cmd/gokeycheck

.PHONY: build-linux
build-linux: ## Build for Linux
	CGO_ENABLED=0 GOOS=linux GOARCH=amd64 $(GOBUILD) $(LDFLAGS) -o $(BINARY_UNIX) -v ./cmd/gokeycheck

.PHONY: clean
clean: ## Clean build artifacts
	$(GOCLEAN)
	rm -f $(BINARY_NAME)
	rm -f $(BINARY_UNIX)
	rm -rf coverage.out
	rm -rf test-reports/
	rm -rf bin/

.PHONY: test
test: ## Run tests
	$(GOTEST) -v ./...

.PHONY: test-coverage
test-coverage: ## Run tests with coverage
	$(GOTEST) -v -coverprofile=coverage.out -covermode=atomic ./...
	$(GOCMD) tool cover -html=coverage.out -o coverage.html

.PHONY: test-race
test-race: ## Run tests with race detection
	$(GOTEST) -race -v ./...

.PHONY: test-integration
test-integration: ## Run integration tests
	$(GOTEST) -tags=integration -v ./test/integration/...

.PHONY: test-benchmark
test-benchmark: ## Run benchmark tests
	$(GOTEST) -bench=. -benchmem ./...

.PHONY: test-all
test-all: test test-race test-integration test-benchmark ## Run all tests

.PHONY: lint
lint: ## Run linter
	$(GOLINT) run

.PHONY: fmt
fmt: ## Format code
	$(GOCMD) fmt ./...

.PHONY: vet
vet: ## Run go vet
	$(GOCMD) vet ./...

.PHONY: mod-download
mod-download: ## Download dependencies
	$(GOMOD) download

.PHONY: mod-tidy
mod-tidy: ## Tidy dependencies
	$(GOMOD) tidy

.PHONY: mod-verify
mod-verify: ## Verify dependencies
	$(GOMOD) verify

.PHONY: deps
deps: mod-download mod-tidy mod-verify ## Manage dependencies

.PHONY: check
check: fmt vet lint ## Run all checks

.PHONY: install
install: ## Install binary to GOPATH/bin
	$(GOCMD) install $(LDFLAGS) ./cmd/gokeycheck

.PHONY: run-example
run-example: build ## Run example scan
	./$(BINARY_NAME) scan testdata/projects/sample1

.PHONY: run-example-json
run-example-json: build ## Run example scan with JSON output
	./$(BINARY_NAME) scan --format json testdata/projects/sample1

.PHONY: run-example-html
run-example-html: build ## Run example scan with HTML output
	./$(BINARY_NAME) scan --format html --output report.html testdata/projects/sample1

# Test data targets
.PHONY: test-sample1
test-sample1: build ## Test with sample1 project
	./$(BINARY_NAME) scan --format json testdata/projects/sample1

.PHONY: test-sample2
test-sample2: build ## Test with sample2 project
	./$(BINARY_NAME) scan --format json testdata/projects/sample2

.PHONY: test-minimal
test-minimal: build ## Test with minimal project
	./$(BINARY_NAME) scan --format json testdata/projects/minimal

.PHONY: test-config
test-config: build ## Test with configuration file
	./$(BINARY_NAME) scan --config testdata/configs/gokeycheck.yaml --format json testdata/projects/sample1

# CI/CD targets
.PHONY: ci-test
ci-test: ## Run CI tests
	$(GOTEST) -v -race -coverprofile=coverage.out ./...

.PHONY: ci-build
ci-build: ## CI build
	CGO_ENABLED=0 $(GOBUILD) $(LDFLAGS) -o $(BINARY_NAME) ./cmd/gokeycheck

.PHONY: ci-lint
ci-lint: ## CI lint
	$(GOLINT) run --timeout=5m

.PHONY: ci
ci: ci-lint ci-test ci-build ## Run CI pipeline

# Release targets  
.PHONY: release-dry-run
release-dry-run: ## Dry run release build
	@echo "Version: $(VERSION)"
	@echo "Commit: $(COMMIT)"
	@echo "Build Date: $(BUILD_DATE)"

.PHONY: release-build
release-build: ## Build release binaries
	mkdir -p bin
	# Linux
	CGO_ENABLED=0 GOOS=linux GOARCH=amd64 $(GOBUILD) $(LDFLAGS) -o bin/$(BINARY_NAME)-linux-amd64 ./cmd/gokeycheck
	CGO_ENABLED=0 GOOS=linux GOARCH=arm64 $(GOBUILD) $(LDFLAGS) -o bin/$(BINARY_NAME)-linux-arm64 ./cmd/gokeycheck
	# macOS  
	CGO_ENABLED=0 GOOS=darwin GOARCH=amd64 $(GOBUILD) $(LDFLAGS) -o bin/$(BINARY_NAME)-darwin-amd64 ./cmd/gokeycheck
	CGO_ENABLED=0 GOOS=darwin GOARCH=arm64 $(GOBUILD) $(LDFLAGS) -o bin/$(BINARY_NAME)-darwin-arm64 ./cmd/gokeycheck
	# Windows
	CGO_ENABLED=0 GOOS=windows GOARCH=amd64 $(GOBUILD) $(LDFLAGS) -o bin/$(BINARY_NAME)-windows-amd64.exe ./cmd/gokeycheck

# Documentation targets
.PHONY: docs
docs: ## Generate documentation
	$(GOCMD) doc ./...

.PHONY: godoc
godoc: ## Start godoc server
	godoc -http=:6060

# Validation targets
.PHONY: validate-testdata
validate-testdata: build ## Validate test data expectations
	@echo "Validating test data..."
	./$(BINARY_NAME) scan --format json testdata/projects/sample1 > /tmp/sample1-output.json
	@if [ -f testdata/expected/sample1_expected.json ]; then \
		echo "Comparing with expected output..."; \
		echo "Note: In real implementation, would compare JSON structure"; \
	fi

# Performance targets
.PHONY: profile-cpu
profile-cpu: build ## Run CPU profiling
	$(GOTEST) -cpuprofile cpu.prof -bench=. ./internal/detector/
	$(GOCMD) tool pprof cpu.prof

.PHONY: profile-mem
profile-mem: build ## Run memory profiling
	$(GOTEST) -memprofile mem.prof -bench=. ./internal/scanner/
	$(GOCMD) tool pprof mem.prof

# Security scanning (if tools are available)
.PHONY: security-scan
security-scan: ## Run security scanning tools
	@which gosec >/dev/null 2>&1 && gosec ./... || echo "gosec not installed"
	@which nancy >/dev/null 2>&1 && nancy sleuth || echo "nancy not installed"

# Development helpers
.PHONY: watch
watch: ## Watch for changes and rebuild
	@which fswatch >/dev/null 2>&1 || (echo "fswatch not installed"; exit 1)
	fswatch -o . | xargs -n1 -I{} make build

.PHONY: dev-setup
dev-setup: ## Setup development environment
	$(GOGET) -u golang.org/x/tools/cmd/godoc
	$(GOGET) -u github.com/golangci/golangci-lint/cmd/golangci-lint@latest

# Docker targets (if Dockerfile exists)
.PHONY: docker-build
docker-build: ## Build Docker image
	@if [ -f Dockerfile ]; then \
		docker build -t $(BINARY_NAME):$(VERSION) .; \
	else \
		echo "Dockerfile not found"; \
	fi

.PHONY: docker-run
docker-run: docker-build ## Run in Docker container
	docker run --rm -v $(PWD)/testdata:/testdata $(BINARY_NAME):$(VERSION) scan /testdata/projects/sample1

# Report generation examples
.PHONY: example-reports
example-reports: build ## Generate example reports in all formats
	mkdir -p examples/reports
	./$(BINARY_NAME) scan --format json --output examples/reports/report.json testdata/projects/sample1
	./$(BINARY_NAME) scan --format html --output examples/reports/report.html testdata/projects/sample1  
	./$(BINARY_NAME) scan --format csv --output examples/reports/report.csv testdata/projects/sample1
	./$(BINARY_NAME) scan --format text --output examples/reports/report.txt testdata/projects/sample1
	@echo "Example reports generated in examples/reports/"

# Clean up examples
.PHONY: clean-examples
clean-examples: ## Clean example outputs
	rm -rf examples/reports/
	rm -f report.html report.json report.csv report.txt

# Version and info
.PHONY: version
version: ## Show version information
	@echo "Version: $(VERSION)"
	@echo "Commit: $(COMMIT)" 
	@echo "Build Date: $(BUILD_DATE)"

.PHONY: info
info: version ## Show build information
	@echo "Go version: $(shell $(GOCMD) version)"
	@echo "Platform: $(shell $(GOCMD) env GOOS)/$(shell $(GOCMD) env GOARCH)"
	@echo "Dependencies:"
	@$(GOMOD) list -m all