# AuthService Performance Testing Suite

This directory contains comprehensive performance and load testing for the AuthService authentication system.

## 🎯 **Test Objectives**

- **Primary Goal**: Validate 3 million login requests in 3 minutes (16,667 RPS)
- **Secondary Goals**: Stress testing, memory profiling, and system limits validation

## 📋 **Test Suite Overview**

### 1. **Unit & Integration Tests**
- `authentication_test.exs` - Core authentication logic tests
- `auth_controller_test.exs` - HTTP API endpoint tests

### 2. **Performance Benchmarks**
- `login_benchmark_test.exs` - **3M requests in 3 minutes benchmark**
- `stress_test.exs` - Concurrent load and memory pressure tests
- `http_load_test.exs` - HTTP-based realistic load testing

### 3. **External Load Testing**
- `external_load_test.sh` - Script using wrk, curl, and Apache Bench
- `run_benchmarks.exs` - Automated benchmark runner

## 🚀 **Quick Start**

### Prerequisites
```bash
# Ensure PostgreSQL is running
# Update .env with correct database credentials
# Start the application
mix run --no-halt
```

### Run the Main Benchmark (3M requests)
```bash
# Set performance test environment
export PERFORMANCE_TESTS=true

# Run the 3M login benchmark
mix test test/performance/login_benchmark_test.exs --only performance
```

### Run All Performance Tests
```bash
# Automated runner for all benchmarks
mix run test/performance/run_benchmarks.exs all
```

### Run External Load Tests
```bash
# Using external tools (wrk, curl, ab)
./scripts/external_load_test.sh
```

## 📊 **Detailed Test Descriptions**

### 1. **3M Login Benchmark** (`login_benchmark_test.exs`)

**Objective**: Process 3 million login requests in exactly 3 minutes

**Configuration**:
- Target: 3,000,000 requests in 180 seconds
- Expected RPS: 16,667
- Concurrent workers: 1,000
- Requests per worker: 3,000
- Test users: 100 (distributed load)

**Metrics Collected**:
- Total requests completed
- Success/failure rates
- Response time percentiles (P50, P95, P99)
- Memory usage
- Process count
- Error distribution

**Success Criteria**:
- ≥95% of target requests completed
- ≥80% of target RPS achieved
- ≥95% success rate
- Average response time ≤100ms

**Example Output**:
```
🏆 LOGIN PERFORMANCE BENCHMARK REPORT
========================================
Target Requests:     3,000,000
Actual Requests:     2,987,543
Target RPS:          16,667
Actual RPS:          16,597
Success Rate:        98.7%
Average Response:    45.2ms
P95 Response:        89.1ms
P99 Response:        156.3ms
```

### 2. **Stress Tests** (`stress_test.exs`)

**Concurrent Login Stress**:
- 500 concurrent users
- 20 requests per user batch
- Validates system behavior under extreme load

**Memory Pressure Test**:
- Creates 10,000 concurrent sessions
- Monitors memory usage per session
- Tests session cleanup and garbage collection

**Token Cluster Stress**:
- Generates 1,000 JWT tokens
- Validates tokens concurrently
- Tests token blacklisting at scale

### 3. **HTTP Load Test** (`http_load_test.exs`)

**Realistic HTTP Testing**:
- Real HTTP requests to running server
- 100 concurrent users
- 1,000 requests per user
- Full HTTP stack validation

**Metrics**:
- HTTP status code distribution
- Network latency impact
- Connection pooling efficiency
- Real-world performance characteristics

### 4. **External Load Testing** (`external_load_test.sh`)

**Tools Supported**:
- **wrk**: High-performance HTTP benchmarking
- **curl**: Parallel request testing
- **Apache Bench**: Traditional load testing

**Usage**:
```bash
# Interactive mode
./scripts/external_load_test.sh

# Specific tool
./scripts/external_load_test.sh 1  # wrk
./scripts/external_load_test.sh 2  # curl
./scripts/external_load_test.sh 3  # ab
./scripts/external_load_test.sh 4  # all tools
```

## ⚙️ **Configuration**

### Test Environment Variables
```bash
# Enable performance testing
export PERFORMANCE_TESTS=true

# Database configuration
export DB_USERNAME=postgres
export DB_PASSWORD=postgres
export DB_NAME=auth_service_test

# Performance tuning
export PERFORMANCE_MODE=true
```

### System Optimization
```bash
# Increase system limits (may require sudo)
ulimit -n 65536           # File descriptors
ulimit -u 32768           # Max processes

# Erlang VM optimization
export ERL_MAX_PORTS=65536
export ERL_MAX_PROCESSES=2000000
```

### Application Configuration (`config/test.exs`)
```elixir
config :auth_service,
  # High rate limits for testing
  rate_limit_max_requests: 10000,
  
  # Database pool optimization
  pool_size: 100,
  max_overflow: 200,
  
  # Disable rate limiting for benchmarks
  disable_rate_limiting: true
```

## 📈 **Performance Targets & Thresholds**

### Primary Targets
- **RPS**: 16,667 (3M requests / 180 seconds)
- **Response Time**: <100ms average, <200ms P95
- **Success Rate**: >95%
- **Memory**: <2GB total usage
- **Concurrency**: 1,000+ concurrent users

### Minimum Thresholds
- **RPS**: >10,000 (60% of target)
- **Response Time**: <500ms average
- **Success Rate**: >90%
- **Memory**: <4GB total usage

## 🔧 **Troubleshooting**

### Common Issues

**Database Connection Limits**:
```bash
# PostgreSQL max connections
# Edit postgresql.conf:
max_connections = 500
```

**File Descriptor Limits**:
```bash
# Check current limits
ulimit -n

# Increase (temporary)
ulimit -n 65536

# Permanent (add to ~/.bashrc or ~/.zshrc)
echo "ulimit -n 65536" >> ~/.bashrc
```

**Memory Issues**:
```bash
# Monitor memory usage
mix run -e "IO.inspect(:erlang.memory())"

# Force garbage collection
mix run -e ":erlang.garbage_collect()"
```

**Port Exhaustion**:
```bash
# Check available ports
netstat -an | grep TIME_WAIT | wc -l

# Reduce TIME_WAIT (Linux)
echo 1 > /proc/sys/net/ipv4/tcp_tw_reuse
```

### Performance Tuning

**Database Optimization**:
```sql
-- PostgreSQL tuning for high load
SET shared_buffers = '256MB';
SET effective_cache_size = '1GB';
SET work_mem = '4MB';
SET maintenance_work_mem = '64MB';
SET max_connections = 500;
```

**Erlang VM Tuning**:
```bash
# Start with optimized settings
elixir --erl "+K true +A 32 +P 2000000" -S mix run --no-halt
```

## 📊 **Expected Results**

### High-Performance System
- **RPS**: 15,000-20,000
- **Response Time**: 30-80ms average
- **Memory**: 1-2GB under load
- **CPU**: 70-90% utilization

### Standard System
- **RPS**: 8,000-12,000
- **Response Time**: 80-150ms average
- **Memory**: 2-3GB under load
- **CPU**: 80-95% utilization

### Resource-Limited System
- **RPS**: 3,000-6,000
- **Response Time**: 150-300ms average
- **Memory**: 3-4GB under load
- **CPU**: 95-100% utilization

## 📝 **Report Generation**

All tests generate detailed reports saved to:
- `test/performance/reports/` - JSON format reports
- Console output with formatted metrics
- External tool results in `/tmp/`

**Report Contents**:
- Test configuration and parameters
- Performance metrics and percentiles
- Error analysis and distribution
- System resource utilization
- Recommendations and observations

## 🔄 **Continuous Integration**

To integrate performance testing in CI/CD:

```yaml
# GitHub Actions example
- name: Performance Tests
  run: |
    export PERFORMANCE_TESTS=true
    mix test test/performance/login_benchmark_test.exs --only performance
  env:
    DB_USERNAME: postgres
    DB_PASSWORD: postgres
```

## 📚 **Additional Resources**

- [Elixir Performance Guide](https://hexdocs.pm/elixir/performance.html)
- [Phoenix Performance](https://hexdocs.pm/phoenix/performance.html)
- [Ecto Performance](https://hexdocs.pm/ecto/performance.html)
- [Load Testing Best Practices](https://github.com/wg/wrk)

---

**Happy Load Testing! 🚀**