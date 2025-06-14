#!/bin/bash

# Simple SSL troubleshooting and fix for Digital Ocean deployment
# Addresses common SSL certificate generation failures

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

DOMAIN="helpboard.selfany.com"

# Check DNS resolution
check_dns() {
    log_info "Checking DNS resolution for $DOMAIN..."
    
    local server_ip=$(curl -s ipinfo.io/ip)
    local domain_ip=$(dig +short $DOMAIN @8.8.8.8 | tail -n1)
    
    log_info "Server IP: $server_ip"
    log_info "Domain IP: $domain_ip"
    
    if [ "$server_ip" = "$domain_ip" ]; then
        log_success "DNS resolution correct"
        return 0
    else
        log_error "DNS mismatch - domain doesn't point to this server"
        return 1
    fi
}

# Check port availability
check_ports() {
    log_info "Checking port availability..."
    
    local ports=(80 443)
    local blocked=0
    
    for port in "${ports[@]}"; do
        if lsof -i:$port > /dev/null 2>&1; then
            log_error "Port $port is in use"
            lsof -i:$port
            blocked=1
        else
            log_success "Port $port is free"
        fi
    done
    
    return $blocked
}

# Free required ports
free_ports() {
    log_info "Freeing required ports..."
    
    # Stop Docker containers
    docker stop $(docker ps -aq) 2>/dev/null || true
    
    # Kill processes on ports 80 and 443
    for port in 80 443; do
        local pids=$(lsof -ti:$port 2>/dev/null || true)
        if [ -n "$pids" ]; then
            log_info "Killing processes on port $port"
            echo "$pids" | xargs -r kill -9
            sleep 2
        fi
    done
    
    log_success "Ports freed"
}

# Generate SSL certificates
generate_certificates() {
    log_info "Generating SSL certificates..."
    
    mkdir -p ssl certbot/www certbot/conf
    
    # Try Let's Encrypt first
    if check_dns; then
        log_info "Attempting Let's Encrypt certificate..."
        
        # Start temporary web server for challenge
        docker run --rm -d \
            --name temp_nginx \
            -p 80:80 \
            -v "$(pwd)/certbot/www:/var/www/certbot" \
            nginx:alpine \
            sh -c 'echo "server { listen 80; location /.well-known/acme-challenge/ { root /var/www/certbot; } location / { return 200 \"OK\"; } }" > /etc/nginx/conf.d/default.conf && nginx -g "daemon off;"'
        
        sleep 5
        
        # Request certificate
        if docker run --rm \
            -v "$(pwd)/certbot/conf:/etc/letsencrypt" \
            -v "$(pwd)/certbot/www:/var/www/certbot" \
            certbot/certbot certonly \
            --webroot \
            --webroot-path=/var/www/certbot \
            --email "admin@$DOMAIN" \
            --agree-tos \
            --no-eff-email \
            --non-interactive \
            -d "$DOMAIN"; then
            
            docker stop temp_nginx
            
            # Copy certificates
            if [ -d "certbot/conf/live/$DOMAIN" ]; then
                cp "certbot/conf/live/$DOMAIN/fullchain.pem" ssl/
                cp "certbot/conf/live/$DOMAIN/privkey.pem" ssl/
                chmod 644 ssl/fullchain.pem
                chmod 600 ssl/privkey.pem
                log_success "Let's Encrypt certificates installed"
                return 0
            fi
        fi
        
        docker stop temp_nginx 2>/dev/null || true
    fi
    
    # Create self-signed certificate as fallback
    log_info "Creating self-signed certificate..."
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout ssl/privkey.pem \
        -out ssl/fullchain.pem \
        -subj "/C=US/ST=State/L=City/O=HelpBoard/CN=$DOMAIN"
    
    chmod 644 ssl/fullchain.pem
    chmod 600 ssl/privkey.pem
    
    log_success "Self-signed certificates created"
}

# Test SSL certificates
test_certificates() {
    log_info "Testing SSL certificates..."
    
    if [ -f "ssl/fullchain.pem" ] && [ -f "ssl/privkey.pem" ]; then
        # Check certificate validity
        if openssl x509 -in ssl/fullchain.pem -text -noout > /dev/null 2>&1; then
            local expiry=$(openssl x509 -in ssl/fullchain.pem -noout -enddate | cut -d= -f2)
            log_success "Certificate is valid until: $expiry"
            return 0
        else
            log_error "Certificate file is corrupted"
            return 1
        fi
    else
        log_error "Certificate files not found"
        return 1
    fi
}

# Main execution
main() {
    local action=${1:-"check"}
    
    case $action in
        "check")
            log_info "Running SSL diagnostics..."
            check_dns
            check_ports
            test_certificates
            ;;
        "fix")
            log_info "Fixing SSL issues..."
            free_ports
            generate_certificates
            test_certificates
            log_success "SSL fix completed"
            ;;
        "generate")
            log_info "Generating new certificates..."
            generate_certificates
            test_certificates
            ;;
        *)
            echo "Usage: $0 [check|fix|generate]"
            echo "  check    - Run diagnostics"
            echo "  fix      - Fix SSL issues"
            echo "  generate - Generate new certificates"
            exit 1
            ;;
    esac
}

main "$@"