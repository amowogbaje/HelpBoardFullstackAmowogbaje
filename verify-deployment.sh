#!/bin/bash

# HelpBoard Deployment Verification Script
# Comprehensive testing for production deployment

set -e

# Configuration
DOMAIN="helpboard.selfany.com"
IP="161.35.58.110"
COMPOSE_FILE="docker-compose.prod.yml"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0
TOTAL_TESTS=0

# Logging functions
log_test() {
    echo -e "${BLUE}[TEST]${NC} $1"
    ((TOTAL_TESTS++))
}

log_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((TESTS_PASSED++))
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((TESTS_FAILED++))
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Test Docker services are running
test_docker_services() {
    log_test "Checking Docker services status"
    
    services=("app" "db" "redis" "nginx")
    for service in "${services[@]}"; do
        if docker-compose -f "$COMPOSE_FILE" ps "$service" | grep -q "Up"; then
            log_pass "$service container is running"
        else
            log_fail "$service container is not running"
        fi
    done
}

# Test service health checks
test_health_checks() {
    log_test "Testing service health checks"
    
    # App health check
    if docker-compose -f "$COMPOSE_FILE" exec -T app node healthcheck.js; then
        log_pass "Application health check passed"
    else
        log_fail "Application health check failed"
    fi
    
    # Database health check
    if docker-compose -f "$COMPOSE_FILE" exec -T db pg_isready -U helpboard_user -d helpboard; then
        log_pass "Database health check passed"
    else
        log_fail "Database health check failed"
    fi
    
    # Redis health check
    if docker-compose -f "$COMPOSE_FILE" exec -T redis redis-cli ping | grep -q "PONG"; then
        log_pass "Redis health check passed"
    else
        log_fail "Redis health check failed"
    fi
}

# Test HTTP endpoints
test_http_endpoints() {
    log_test "Testing HTTP endpoints"
    
    # Test HTTP redirect to HTTPS
    if curl -s -o /dev/null -w "%{http_code}" "http://$DOMAIN" | grep -q "301"; then
        log_pass "HTTP to HTTPS redirect working"
    else
        log_fail "HTTP to HTTPS redirect not working"
    fi
    
    # Test HTTPS health endpoint
    if curl -k -s "https://$DOMAIN/health" | grep -q "ok"; then
        log_pass "HTTPS health endpoint accessible"
    else
        log_fail "HTTPS health endpoint not accessible"
    fi
    
    # Test API endpoint
    if curl -k -s "https://$DOMAIN/api/health" | grep -q "ok"; then
        log_pass "API health endpoint accessible"
    else
        log_fail "API health endpoint not accessible"
    fi
    
    # Test widget endpoint
    if curl -k -s -o /dev/null -w "%{http_code}" "https://$DOMAIN/widget.js" | grep -q "200"; then
        log_pass "Widget.js endpoint accessible"
    else
        log_fail "Widget.js endpoint not accessible"
    fi
}

# Test SSL certificate
test_ssl_certificate() {
    log_test "Testing SSL certificate"
    
    # Check certificate validity
    if echo | openssl s_client -servername "$DOMAIN" -connect "$DOMAIN:443" 2>/dev/null | openssl x509 -noout -dates 2>/dev/null; then
        log_pass "SSL certificate is valid"
        
        # Check certificate expiry (within 30 days)
        expiry_date=$(echo | openssl s_client -servername "$DOMAIN" -connect "$DOMAIN:443" 2>/dev/null | openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2)
        expiry_epoch=$(date -d "$expiry_date" +%s)
        current_epoch=$(date +%s)
        days_until_expiry=$(( (expiry_epoch - current_epoch) / 86400 ))
        
        if [ "$days_until_expiry" -gt 30 ]; then
            log_pass "SSL certificate valid for $days_until_expiry days"
        else
            log_fail "SSL certificate expires in $days_until_expiry days - renewal needed"
        fi
    else
        log_fail "SSL certificate validation failed"
    fi
}

# Test database connectivity
test_database_connectivity() {
    log_test "Testing database connectivity"
    
    # Test database connection from app
    if docker-compose -f "$COMPOSE_FILE" exec -T app node -e "
        const { Pool } = require('@neondatabase/serverless');
        const pool = new Pool({ connectionString: process.env.DATABASE_URL });
        pool.query('SELECT 1').then(() => {
            console.log('Database connection successful');
            process.exit(0);
        }).catch(err => {
            console.error('Database connection failed:', err.message);
            process.exit(1);
        });
    "; then
        log_pass "Database connectivity from app successful"
    else
        log_fail "Database connectivity from app failed"
    fi
    
    # Test database tables exist
    if docker-compose -f "$COMPOSE_FILE" exec -T db psql -U helpboard_user helpboard -c "\dt" | grep -q "agents\|customers\|conversations\|messages"; then
        log_pass "Database tables exist"
    else
        log_fail "Database tables missing"
    fi
}

# Test WebSocket connectivity
test_websocket_connectivity() {
    log_test "Testing WebSocket connectivity"
    
    # Create a simple WebSocket test
    cat > /tmp/ws_test.js << 'EOF'
const WebSocket = require('ws');
const ws = new WebSocket('wss://helpboard.selfany.com', {
    rejectUnauthorized: false
});

ws.on('open', function open() {
    console.log('WebSocket connection established');
    ws.close();
    process.exit(0);
});

ws.on('error', function error(err) {
    console.error('WebSocket connection failed:', err.message);
    process.exit(1);
});

setTimeout(() => {
    console.error('WebSocket connection timeout');
    process.exit(1);
}, 10000);
EOF
    
    if docker-compose -f "$COMPOSE_FILE" exec -T app node /tmp/ws_test.js; then
        log_pass "WebSocket connectivity successful"
    else
        log_fail "WebSocket connectivity failed"
    fi
    
    rm -f /tmp/ws_test.js
}

# Test performance and resources
test_performance() {
    log_test "Testing performance and resource usage"
    
    # Check container resource usage
    docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}" | while read line; do
        if [[ "$line" =~ helpboard.*app ]]; then
            cpu=$(echo "$line" | awk '{print $2}' | sed 's/%//')
            mem=$(echo "$line" | awk '{print $3}' | cut -d'/' -f1 | sed 's/MiB//')
            
            if (( $(echo "$cpu < 80" | bc -l) )); then
                log_pass "App CPU usage acceptable: ${cpu}%"
            else
                log_fail "App CPU usage high: ${cpu}%"
            fi
            
            if (( $(echo "$mem < 800" | bc -l) )); then
                log_pass "App memory usage acceptable: ${mem}MiB"
            else
                log_fail "App memory usage high: ${mem}MiB"
            fi
        fi
    done
    
    # Test response time
    response_time=$(curl -k -s -o /dev/null -w "%{time_total}" "https://$DOMAIN/api/health")
    if (( $(echo "$response_time < 2.0" | bc -l) )); then
        log_pass "API response time acceptable: ${response_time}s"
    else
        log_fail "API response time slow: ${response_time}s"
    fi
}

# Test security headers
test_security_headers() {
    log_test "Testing security headers"
    
    headers_to_check=(
        "Strict-Transport-Security"
        "X-Frame-Options"
        "X-Content-Type-Options"
        "X-XSS-Protection"
    )
    
    for header in "${headers_to_check[@]}"; do
        if curl -k -s -I "https://$DOMAIN" | grep -i "$header"; then
            log_pass "Security header $header present"
        else
            log_fail "Security header $header missing"
        fi
    done
}

# Test backup and restore functionality
test_backup_restore() {
    log_test "Testing backup functionality"
    
    # Create a test backup
    if docker-compose -f "$COMPOSE_FILE" exec -T db pg_dump -U helpboard_user helpboard > /tmp/test_backup.sql 2>/dev/null; then
        if [ -s /tmp/test_backup.sql ]; then
            log_pass "Database backup creation successful"
            rm -f /tmp/test_backup.sql
        else
            log_fail "Database backup file is empty"
        fi
    else
        log_fail "Database backup creation failed"
    fi
}

# Test log collection
test_logging() {
    log_test "Testing log collection"
    
    # Check if logs are being generated
    if docker-compose -f "$COMPOSE_FILE" logs --tail=10 app | grep -q "express"; then
        log_pass "Application logs are being generated"
    else
        log_fail "Application logs not found"
    fi
    
    # Check nginx logs
    if docker-compose -f "$COMPOSE_FILE" logs --tail=10 nginx | grep -q "nginx"; then
        log_pass "Nginx logs are being generated"
    else
        log_fail "Nginx logs not found"
    fi
}

# Test rate limiting
test_rate_limiting() {
    log_test "Testing rate limiting"
    
    # Test API rate limiting
    success_count=0
    for i in {1..15}; do
        if curl -k -s -o /dev/null -w "%{http_code}" "https://$DOMAIN/api/health" | grep -q "200"; then
            ((success_count++))
        fi
    done
    
    if [ "$success_count" -lt 15 ]; then
        log_pass "Rate limiting is working (some requests blocked)"
    else
        log_fail "Rate limiting may not be working (all requests succeeded)"
    fi
}

# Test domain and IP access
test_domain_ip_access() {
    log_test "Testing domain and IP access"
    
    # Test domain access
    if curl -k -s "https://$DOMAIN/health" | grep -q "ok"; then
        log_pass "Domain access working"
    else
        log_fail "Domain access not working"
    fi
    
    # Test IP redirect to domain
    if curl -k -s -L "https://$IP/health" | grep -q "ok"; then
        log_pass "IP access redirects to domain"
    else
        log_fail "IP access not redirecting properly"
    fi
}

# Main test execution
run_all_tests() {
    log_info "Starting HelpBoard deployment verification..."
    echo "========================================================"
    
    test_docker_services
    echo "--------------------------------------------------------"
    
    test_health_checks
    echo "--------------------------------------------------------"
    
    test_http_endpoints
    echo "--------------------------------------------------------"
    
    test_ssl_certificate
    echo "--------------------------------------------------------"
    
    test_database_connectivity
    echo "--------------------------------------------------------"
    
    test_websocket_connectivity
    echo "--------------------------------------------------------"
    
    test_performance
    echo "--------------------------------------------------------"
    
    test_security_headers
    echo "--------------------------------------------------------"
    
    test_backup_restore
    echo "--------------------------------------------------------"
    
    test_logging
    echo "--------------------------------------------------------"
    
    test_rate_limiting
    echo "--------------------------------------------------------"
    
    test_domain_ip_access
    echo "========================================================"
    
    # Summary
    echo
    log_info "Verification Summary:"
    echo "Total Tests: $TOTAL_TESTS"
    echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Failed: ${RED}$TESTS_FAILED${NC}"
    
    if [ "$TESTS_FAILED" -eq 0 ]; then
        echo -e "\n${GREEN}All tests passed! Deployment is ready for production.${NC}"
        exit 0
    else
        echo -e "\n${RED}Some tests failed. Please review and fix issues before production use.${NC}"
        exit 1
    fi
}

# Run tests based on argument
case "${1:-all}" in
    "docker")
        test_docker_services
        ;;
    "health")
        test_health_checks
        ;;
    "http")
        test_http_endpoints
        ;;
    "ssl")
        test_ssl_certificate
        ;;
    "database")
        test_database_connectivity
        ;;
    "websocket")
        test_websocket_connectivity
        ;;
    "performance")
        test_performance
        ;;
    "security")
        test_security_headers
        ;;
    "backup")
        test_backup_restore
        ;;
    "logs")
        test_logging
        ;;
    "rate-limit")
        test_rate_limiting
        ;;
    "domain")
        test_domain_ip_access
        ;;
    "all")
        run_all_tests
        ;;
    *)
        echo "Usage: $0 [docker|health|http|ssl|database|websocket|performance|security|backup|logs|rate-limit|domain|all]"
        echo
        echo "Test categories:"
        echo "  docker      - Test Docker container status"
        echo "  health      - Test service health checks"
        echo "  http        - Test HTTP/HTTPS endpoints"
        echo "  ssl         - Test SSL certificate"
        echo "  database    - Test database connectivity"
        echo "  websocket   - Test WebSocket functionality"
        echo "  performance - Test performance metrics"
        echo "  security    - Test security headers"
        echo "  backup      - Test backup functionality"
        echo "  logs        - Test log collection"
        echo "  rate-limit  - Test rate limiting"
        echo "  domain      - Test domain and IP access"
        echo "  all         - Run all tests (default)"
        exit 1
        ;;
esac