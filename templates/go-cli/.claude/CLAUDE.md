# Go CLI/Service Project Guidelines

Project-specific rules that extend global `~/.claude/CLAUDE.md`.

## Stack

- Go 1.22+
- Cobra for CLI framework (if CLI)
- Standard library preferred over dependencies

## Architecture

### CLI Tool
```
cmd/
└── <app>/
    └── main.go       # Entry point
internal/
├── cli/              # Command definitions
├── config/           # Configuration handling
└── <domain>/         # Business logic
pkg/                  # Public packages (if any)
```

### Service
```
cmd/
└── <service>/
    └── main.go
internal/
├── api/              # HTTP handlers
├── service/          # Business logic
├── repository/       # Data access
└── model/            # Domain types
```

## Rules

### Code Style
- Follow Effective Go and Go Code Review Comments
- Use `gofmt` and `golangci-lint`
- Prefer composition over inheritance
- Keep functions <50 lines

### Error Handling
- Return errors, don't panic (except truly unrecoverable)
- Wrap errors with context: `fmt.Errorf("doing X: %w", err)`
- Use custom error types for programmatic handling
- Errors to stderr, output to stdout

### Testing
- Table-driven tests with descriptive names
- Use `testify/assert` for assertions
- Mock external dependencies with interfaces
- Run with race detector: `go test -race ./...`

### CLI Specific
- Meaningful exit codes: 0=success, 1=error, 2=usage error
- Implement `--help` with useful examples
- Support `--version` flag
- Respect `NO_COLOR` environment variable

### Dependencies
- Minimize external dependencies
- Vendor dependencies for reproducibility
- Use `go mod tidy` before commits

## Commands

```bash
go build ./...              # Build all
go test ./... -race -cover  # Test with race detection
golangci-lint run           # Lint
go mod tidy                 # Clean dependencies
```

## Release

- Use goreleaser for cross-platform builds
- Tag releases with semantic versioning
- Generate changelog from commits
