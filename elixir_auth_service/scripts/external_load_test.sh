#!/bin/bash

# External Load Testing Script for AuthService
# This script uses external tools like wrk, curl, and ab for load testing

set -e

# Configuration
SERVER_URL="http://localhost:4000"
TEST_USER_EMAIL="loadtest@example.com"
TEST_USER_PASSWORD="loadtest123"
DURATION="3m"  # 3 minutes
CONNECTIONS=1000
THREADS=100
TARGET_RPS=16667  # Target: 3M requests in 3 minutes

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Check if server is running
check_server() {
    print_header "Checking Server Status"
    
    if curl -s "${SERVER_URL}/health" > /dev/null; then
        print_success "Server is running at ${SERVER_URL}"
    else
        print_error "Server is not responding at ${SERVER_URL}"
        echo "Please start the server with: mix run --no-halt"
        exit 1
    fi
}

# Setup test user
setup_test_user() {
    print_header "Setting Up Test User"
    
    # Create test user via API
    USER_DATA=$(cat <<EOF
{
    "email": "${TEST_USER_EMAIL}",
    "password": "${TEST_USER_PASSWORD}",
    "first_name": "Load",
    "last_name": "Test"
}
EOF
)
    
    echo "Creating test user: ${TEST_USER_EMAIL}"
    
    RESPONSE=$(curl -s -w "%{http_code}" -o /tmp/register_response.json \
        -X POST "${SERVER_URL}/api/v1/auth/register" \
        -H "Content-Type: application/json" \
        -d "${USER_DATA}")
    
    if [[ "$RESPONSE" == "201" || "$RESPONSE" == "422" ]]; then
        print_success "Test user ready"
    else
        print_warning "User creation response: $RESPONSE"
        print_warning "Continuing anyway (user might already exist)"
    fi
}

# Test login endpoint
test_login() {
    print_header "Testing Login Endpoint"
    
    LOGIN_DATA=$(cat <<EOF
{
    "email": "${TEST_USER_EMAIL}",
    "password": "${TEST_USER_PASSWORD}"
}
EOF
)
    
    echo "Testing login for: ${TEST_USER_EMAIL}"
    
    RESPONSE=$(curl -s -w "%{http_code}" -o /tmp/login_response.json \
        -X POST "${SERVER_URL}/api/v1/auth/login" \
        -H "Content-Type: application/json" \
        -d "${LOGIN_DATA}")
    
    if [[ "$RESPONSE" == "200" ]]; then
        print_success "Login test successful"
        
        # Extract token for further tests
        TOKEN=$(cat /tmp/login_response.json | grep -o '"token":"[^"]*"' | cut -d'"' -f4)
        echo "Token extracted: ${TOKEN:0:20}..."
    else
        print_error "Login test failed with response: $RESPONSE"
        cat /tmp/login_response.json
        exit 1
    fi
}

# Run wrk load test
run_wrk_test() {
    print_header "Running wrk Load Test"
    
    if ! command -v wrk &> /dev/null; then
        print_warning "wrk not found. Please install wrk for HTTP load testing."
        print_warning "macOS: brew install wrk"
        print_warning "Ubuntu: sudo apt-get install wrk"
        return
    fi
    
    # Create wrk script for login
    cat > /tmp/login.lua <<EOF
wrk.method = "POST"
wrk.body = '{"email": "${TEST_USER_EMAIL}", "password": "${TEST_USER_PASSWORD}"}'
wrk.headers["Content-Type"] = "application/json"
wrk.headers["Accept"] = "application/json"

request = function()
    return wrk.format(nil, "/api/v1/auth/login")
end

response = function(status, headers, body)
    if status ~= 200 then
        print("Error: " .. status .. " - " .. body)
    end
end
EOF
    
    echo "Target: ${TARGET_RPS} RPS for ${DURATION}"
    echo "Connections: ${CONNECTIONS}, Threads: ${THREADS}"
    echo "URL: ${SERVER_URL}/api/v1/auth/login"
    echo ""
    
    # Run wrk
    wrk -t${THREADS} -c${CONNECTIONS} -d${DURATION} -R${TARGET_RPS} \
        --script=/tmp/login.lua \
        --latency \
        "${SERVER_URL}/api/v1/auth/login" | tee /tmp/wrk_results.txt
    
    print_success "wrk load test completed"
    echo "Results saved to: /tmp/wrk_results.txt"
}

# Run curl-based test
run_curl_test() {
    print_header "Running curl Parallel Test"
    
    echo "Running 1000 parallel curl requests..."
    
    LOGIN_DATA='{"email": "'${TEST_USER_EMAIL}'", "password": "'${TEST_USER_PASSWORD}'"}'
    
    # Create temporary script for parallel execution
    cat > /tmp/curl_test.sh <<EOF
#!/bin/bash
for i in {1..10}; do
    curl -s -o /dev/null -w "%{http_code},%{time_total}\\n" \\
        -X POST "${SERVER_URL}/api/v1/auth/login" \\
        -H "Content-Type: application/json" \\
        -d '${LOGIN_DATA}'
done
EOF
    
    chmod +x /tmp/curl_test.sh
    
    # Run 100 parallel processes with 10 requests each = 1000 total
    START_TIME=$(date +%s.%3N)
    
    for i in {1..100}; do
        /tmp/curl_test.sh &
    done
    
    wait
    
    END_TIME=$(date +%s.%3N)
    DURATION=$(echo "$END_TIME - $START_TIME" | bc -l)
    
    print_success "curl test completed in ${DURATION} seconds"
    echo "Average RPS: $(echo "scale=2; 1000 / $DURATION" | bc -l)"
}

# Run Apache Bench test
run_ab_test() {
    print_header "Running Apache Bench Test"
    
    if ! command -v ab &> /dev/null; then
        print_warning "ab (Apache Bench) not found. Skipping this test."
        print_warning "Install with: sudo apt-get install apache2-utils (Ubuntu)"
        return
    fi
    
    # Create POST data file
    echo '{"email": "'${TEST_USER_EMAIL}'", "password": "'${TEST_USER_PASSWORD}'"}' > /tmp/login_data.json
    
    echo "Running Apache Bench with 10,000 requests, 100 concurrent"
    
    ab -n 10000 -c 100 \
       -p /tmp/login_data.json \
       -T "application/json" \
       -H "Accept: application/json" \
       "${SERVER_URL}/api/v1/auth/login" | tee /tmp/ab_results.txt
    
    print_success "Apache Bench test completed"
    echo "Results saved to: /tmp/ab_results.txt"
}

# Generate summary report
generate_report() {
    print_header "Generating Summary Report"
    
    TIMESTAMP=$(date '+%Y-%m-%d_%H-%M-%S')
    REPORT_FILE="load_test_report_${TIMESTAMP}.txt"
    
    cat > "$REPORT_FILE" <<EOF
AuthService Load Test Report
============================
Timestamp: $(date)
Server URL: ${SERVER_URL}
Test User: ${TEST_USER_EMAIL}
Target Duration: ${DURATION}
Target RPS: ${TARGET_RPS}
Connections: ${CONNECTIONS}
Threads: ${THREADS}

Test Results:
============

EOF
    
    if [[ -f /tmp/wrk_results.txt ]]; then
        echo "wrk Load Test Results:" >> "$REPORT_FILE"
        echo "=====================" >> "$REPORT_FILE"
        cat /tmp/wrk_results.txt >> "$REPORT_FILE"
        echo "" >> "$REPORT_FILE"
    fi
    
    if [[ -f /tmp/ab_results.txt ]]; then
        echo "Apache Bench Results:" >> "$REPORT_FILE"
        echo "====================" >> "$REPORT_FILE"
        cat /tmp/ab_results.txt >> "$REPORT_FILE"
        echo "" >> "$REPORT_FILE"
    fi
    
    print_success "Report generated: $REPORT_FILE"
}

# Cleanup
cleanup() {
    print_header "Cleaning Up"
    
    rm -f /tmp/login.lua /tmp/curl_test.sh /tmp/login_data.json
    rm -f /tmp/register_response.json /tmp/login_response.json
    
    print_success "Cleanup completed"
}

# Main execution
main() {
    print_header "AuthService External Load Test"
    echo "Target: 3 million login requests in 3 minutes"
    echo "Expected RPS: ${TARGET_RPS}"
    echo ""
    
    check_server
    setup_test_user
    test_login
    
    echo ""
    echo "Choose test type:"
    echo "1) wrk load test (recommended)"
    echo "2) curl parallel test"
    echo "3) Apache Bench test"
    echo "4) All tests"
    echo ""
    
    if [[ -z "$1" ]]; then
        read -p "Enter choice (1-4): " choice
    else
        choice="$1"
    fi
    
    case $choice in
        1)
            run_wrk_test
            ;;
        2)
            run_curl_test
            ;;
        3)
            run_ab_test
            ;;
        4)
            run_wrk_test
            echo ""
            run_curl_test
            echo ""
            run_ab_test
            ;;
        *)
            print_error "Invalid choice"
            exit 1
            ;;
    esac
    
    generate_report
    cleanup
    
    print_success "Load testing completed!"
}

# Parse command line arguments
case "${1:-}" in
    --help|-h)
        echo "Usage: $0 [test_type]"
        echo ""
        echo "Test types:"
        echo "  1 - wrk load test"
        echo "  2 - curl parallel test"
        echo "  3 - Apache Bench test"
        echo "  4 - All tests"
        echo ""
        echo "Environment variables:"
        echo "  SERVER_URL (default: http://localhost:4000)"
        echo "  DURATION (default: 3m)"
        echo "  CONNECTIONS (default: 1000)"
        echo "  THREADS (default: 100)"
        exit 0
        ;;
    *)
        main "$1"
        ;;
esac