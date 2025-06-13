#!/bin/bash

# SSL Troubleshooting Script for HelpBoard Single Domain Deployment
# Diagnoses and fixes common SSL/certbot issues on Digital Ocean

set -e

DOMAIN="helpboard.selfany.com"
IP="161.35.58.110"
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Test DNS resolution
test_dns() {
    log_info "Testing DNS resolution for $DOMAIN..."
    
    local resolved_ip=$(dig +short $DOMAIN | tail -n1)
    if [ "$resolved_ip" = "$IP" ]; then
        log_info "✅ DNS correctly resolves to $IP"
        return 0
    else
        log_error "❌ DNS resolution failed"
        log_error "Expected: $IP, Got: $resolved_ip"
        return 1
    fi
}

# Test port accessibility
test_ports() {
    log_info "Testing port accessibility..."
    
    # Test port 80
    if timeout 5 nc -z $IP 80 2>/dev/null; then
        log_info "✅ Port 80 is accessible"
    else
        log_error "❌ Port 80 is not accessible"
        log_error "Check firewall: sudo ufw allow 80"
        return 1
    fi
    
    # Test port 443
    if timeout 5 nc -z $IP 443 2>/dev/null; then
        log_info "✅ Port 443 is accessible"
    else
        log_warn "⚠️ Port 443 is not accessible (expected before SSL setup)"
    fi
}

# Check Let's Encrypt rate limits
check_rate_limits() {
    log_info "Checking Let's Encrypt rate limits for $DOMAIN..."
    
    local cert_count=$(curl -s "https://crt.sh/?q=$DOMAIN&output=json" | jq '. | length' 2>/dev/null || echo "0")
    local recent_certs=$(curl -s "https://crt.sh/?q=$DOMAIN&output=json" | jq '[.[] | select(.not_before > "'"$(date -d '1 week ago' -u +%Y-%m-%dT%H:%M:%S.000Z')"'")]' 2>/dev/null || echo "[]")
    local recent_count=$(echo "$recent_certs" | jq '. | length' 2>/dev/null || echo "0")
    
    log_info "Total certificates issued: $cert_count"
    log_info "Certificates in last week: $recent_count"
    
    if [ "$recent_count" -gt 5 ]; then
        log_warn "⚠️ Rate limit may be reached ($recent_count certificates in last week)"
        log_warn "Consider waiting or using staging environment"
        return 1
    else
        log_info "✅ Rate limits OK"
        return 0
    fi
}

# Test HTTP connectivity
test_http() {
    log_info "Testing HTTP connectivity..."
    
    # Test direct IP access
    if timeout 10 curl -s -o /dev/null -w "%{http_code}" "http://$IP/" | grep -q "200\|301\|302"; then
        log_info "✅ HTTP access via IP works"
    else
        log_warn "⚠️ HTTP access via IP failed"
    fi
    
    # Test domain access
    if timeout 10 curl -s -o /dev/null -w "%{http_code}" "http://$DOMAIN/" | grep -q "200\|301\|302"; then
        log_info "✅ HTTP access via domain works"
    else
        log_error "❌ HTTP access via domain failed"
        return 1
    fi
}

# Check existing certificates
check_existing_certs() {
    log_info "Checking existing SSL certificates..."
    
    if [ -f "ssl/fullchain.pem" ] && [ -f "ssl/privkey.pem" ]; then
        log_info "Found existing certificates"
        
        # Check certificate validity
        local cert_domain=$(openssl x509 -in ssl/fullchain.pem -text -noout | grep -A1 "Subject Alternative Name" | grep -o "$DOMAIN" || echo "")
        if [ "$cert_domain" = "$DOMAIN" ]; then
            log_info "✅ Certificate is valid for $DOMAIN"
        else
            log_warn "⚠️ Certificate may not be valid for $DOMAIN"
        fi
        
        # Check expiration
        local expiry_date=$(openssl x509 -in ssl/fullchain.pem -noout -enddate | cut -d= -f2)
        local expiry_epoch=$(date -d "$expiry_date" +%s)
        local current_epoch=$(date +%s)
        local days_until_expiry=$(( (expiry_epoch - current_epoch) / 86400 ))
        
        if [ $days_until_expiry -gt 30 ]; then
            log_info "✅ Certificate expires in $days_until_expiry days"
        else
            log_warn "⚠️ Certificate expires in $days_until_expiry days (consider renewal)"
        fi
    else
        log_info "No existing certificates found"
    fi
}

# Fix common firewall issues
fix_firewall() {
    log_info "Checking and fixing firewall configuration..."
    
    # Check UFW status
    if command -v ufw >/dev/null 2>&1; then
        local ufw_status=$(sudo ufw status | head -1)
        log_info "UFW Status: $ufw_status"
        
        # Ensure required ports are open
        sudo ufw allow 22/tcp >/dev/null 2>&1  # SSH
        sudo ufw allow 80/tcp >/dev/null 2>&1  # HTTP
        sudo ufw allow 443/tcp >/dev/null 2>&1 # HTTPS
        
        log_info "✅ Firewall rules updated"
    fi
    
    # Check iptables (Digital Ocean droplets)
    if command -v iptables >/dev/null 2>&1; then
        local port80_rule=$(sudo iptables -L INPUT -n | grep ":80 " || echo "")
        if [ -z "$port80_rule" ]; then
            log_warn "⚠️ No explicit iptables rule for port 80"
        fi
    fi
}

# Clean and prepare for fresh SSL attempt
clean_ssl_setup() {
    log_info "Cleaning SSL setup for fresh attempt..."
    
    # Stop any running services
    docker-compose -f docker-compose.prod.yml stop nginx 2>/dev/null || true
    docker stop nginx-temp 2>/dev/null || true
    docker rm nginx-temp 2>/dev/null || true
    
    # Clean SSL directories
    sudo rm -rf ssl/* certbot/*
    mkdir -p ssl certbot/www certbot/conf
    
    log_info "✅ SSL directories cleaned"
}

# Create minimal nginx for ACME challenge
setup_acme_server() {
    log_info "Setting up minimal ACME challenge server..."
    
    # Create minimal nginx config
    cat > nginx-acme-test.conf << 'EOF'
events { worker_connections 1024; }
http {
    server {
        listen 80;
        server_name helpboard.selfany.com;
        
        location /.well-known/acme-challenge/ {
            root /var/www/certbot;
            try_files $uri $uri/ =404;
        }
        
        location / {
            return 200 'ACME Test Server Ready';
            add_header Content-Type text/plain;
        }
    }
}
EOF
    
    # Start test server
    docker run -d --name nginx-acme-test \
        -p 80:80 \
        -v "$(pwd)/certbot/www:/var/www/certbot:ro" \
        -v "$(pwd)/nginx-acme-test.conf:/etc/nginx/nginx.conf:ro" \
        nginx:alpine
    
    sleep 3
    
    # Test ACME server
    if curl -s "http://$DOMAIN/" | grep -q "ACME Test Server Ready"; then
        log_info "✅ ACME challenge server is working"
        docker stop nginx-acme-test && docker rm nginx-acme-test
        rm nginx-acme-test.conf
        return 0
    else
        log_error "❌ ACME challenge server failed"
        docker logs nginx-acme-test
        docker stop nginx-acme-test && docker rm nginx-acme-test
        rm nginx-acme-test.conf
        return 1
    fi
}

# Run comprehensive SSL troubleshooting
run_diagnostics() {
    log_info "Running comprehensive SSL diagnostics for $DOMAIN..."
    echo
    
    local issues=0
    
    # Test DNS
    if ! test_dns; then
        ((issues++))
        log_error "Fix DNS configuration before proceeding"
    fi
    echo
    
    # Test ports
    if ! test_ports; then
        ((issues++))
        log_error "Fix firewall/port configuration"
    fi
    echo
    
    # Check rate limits
    if ! check_rate_limits; then
        ((issues++))
        log_warn "Consider waiting due to rate limits"
    fi
    echo
    
    # Test HTTP connectivity
    if ! test_http; then
        ((issues++))
        log_error "Fix HTTP connectivity issues"
    fi
    echo
    
    # Check existing certificates
    check_existing_certs
    echo
    
    # Test ACME challenge capability
    if ! setup_acme_server; then
        ((issues++))
        log_error "ACME challenge setup failed"
    fi
    echo
    
    # Summary
    if [ $issues -eq 0 ]; then
        log_info "🎉 All diagnostics passed! SSL generation should work."
        log_info "Run: sudo ./deploy-single-domain.sh ssl"
        return 0
    else
        log_error "❌ Found $issues issue(s) that need to be resolved first"
        return 1
    fi
}

# Attempt automatic fix of common issues
auto_fix() {
    log_info "Attempting automatic fixes for common SSL issues..."
    
    # Fix firewall
    fix_firewall
    
    # Clean SSL setup
    clean_ssl_setup
    
    # Wait for any DNS propagation
    log_info "Waiting 30 seconds for any recent DNS changes to propagate..."
    sleep 30
    
    log_info "✅ Automatic fixes completed"
    log_info "Re-run diagnostics to verify: ./ssl-troubleshoot.sh"
}

# Show usage
show_usage() {
    cat << EOF
SSL Troubleshooting Script for HelpBoard

Usage: $0 [COMMAND]

Commands:
    check       Run comprehensive SSL diagnostics
    fix         Attempt automatic fixes for common issues
    clean       Clean SSL setup for fresh attempt
    help        Show this help message

Examples:
    $0 check    # Diagnose SSL issues
    $0 fix      # Try automatic fixes
    $0 clean    # Clean for fresh SSL attempt

EOF
}

# Main function
main() {
    case "$1" in
        "check"|"")
            run_diagnostics
            ;;
        "fix")
            auto_fix
            ;;
        "clean")
            clean_ssl_setup
            ;;
        "help"|"--help"|"-h")
            show_usage
            ;;
        *)
            log_error "Unknown command: $1"
            show_usage
            exit 1
            ;;
    esac
}

main "$@"