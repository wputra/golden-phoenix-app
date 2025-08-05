###
### Stage 1: Build stage
###
FROM golang:1.24-alpine AS builder
WORKDIR /app

# Copy go.mod and go.sum first to leverage Docker's layer caching
COPY go.mod go.sum ./
RUN go mod download

# Copy the rest of the application source code
COPY *.go ./

# Build the Go application, disabling CGO and targeting Linux
# -ldflags="-w -s" reduces binary size by omitting debug info and symbol table
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-w -s" -o myapp .

###
### Stage 2: Final image stage
###
FROM alpine:latest

WORKDIR /app
ENV GOPORT=80

# Copy the compiled binary from the build stage
COPY --from=builder /app/myapp .

# Install necessary runtime dependencies (e.g., CA certificates for HTTPS)
RUN apk add --no-cache ca-certificates tzdata

# Set the entrypoint for the application
ENTRYPOINT ["./myapp"]
