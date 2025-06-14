#!/bin/bash

# Fix SSL certificate issues for helpboard.selfany.com
# This script handles common SSL setup problems

set -e

DOMAIN="helpboard.selfany.com"
EMAIL="admin@helpboard.selfany.com"
COMPOSE_FILE="docker-compose.dev.yml"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${GREEN}[STEP]${NC} $1"; }

# Check if we can reach the domain
check_domain() {
    log_step "Checking domain accessibility..."
    
    # Get current server IP
    local server_ip=$(curl -s ipinfo.io/ip)
    log_info "Server IP: $server_ip"
    
    # Check DNS resolution
    local domain_ip=$(dig +short $DOMAIN | tail -n1)
    log_info "Domain resolves to: $domain_ip"
    
    if [ "$server_ip" = "$domain_ip" ]; then
        log_success "Domain correctly points to this server"
        return 0
    else
        log_error "Domain DNS mismatch. Update your DNS settings."
        log_info "Set A record: $DOMAIN -> $server_ip"
        return 1
    fi
}

# Stop conflicting services
stop_conflicts() {
    log_step "Stopping conflicting services..."
    
    # Stop any services using port 80/443
    sudo systemctl stop apache2 2>/dev/null || true
    sudo systemctl stop nginx 2>/dev/null || true
    
    # Kill any processes using these ports
    sudo pkill -f "nginx" 2>/dev/null || true
    sudo lsof -ti:80 | xargs -r sudo kill -9 2>/dev/null || true
    sudo lsof -ti:443 | xargs -r sudo kill -9 2>/dev/null || true
    
    # Stop Docker containers that might use these ports
    docker stop ssl-nginx 2>/dev/null || true
    docker rm ssl-nginx 2>/dev/null || true
    docker compose -f "$COMPOSE_FILE" stop nginx 2>/dev/null || true
    
    log_success "Conflicting services stopped"
}

# Generate SSL certificates using standalone mode
generate_ssl_standalone() {
    log_step "Generating SSL certificates using standalone mode..."
    
    mkdir -p ssl certbot/www certbot/conf
    
    # Use standalone mode which doesn't require a web server
    if docker run --rm \
        -p 80:80 \
        -v "$(pwd)/certbot/conf:/etc/letsencrypt" \
        certbot/certbot certonly \
        --standalone \
        --email "$EMAIL" \
        --agree-tos \
        --no-eff-email \
        --non-interactive \
        --force-renewal \
        -d "$DOMAIN"; then
        
        log_success "SSL certificate generated successfully"
    else
        log_error "SSL certificate generation failed"
        return 1
    fi
}

# Copy certificates to ssl directory
copy_certificates() {
    log_step "Copying certificates..."
    
    if [ -d "certbot/conf/live/$DOMAIN" ]; then
        cp "certbot/conf/live/$DOMAIN/fullchain.pem" ssl/
        cp "certbot/conf/live/$DOMAIN/privkey.pem" ssl/
        chmod 644 ssl/fullchain.pem
        chmod 600 ssl/privkey.pem
        log_success "Certificates copied successfully"
    else
        log_error "Certificate directory not found"
        return 1
    fi
}

# Create self-signed certificates as fallback
create_self_signed() {
    log_step "Creating self-signed certificates as fallback..."
    
    mkdir -p ssl
    
    # Generate self-signed certificate
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout ssl/privkey.pem \
        -out ssl/fullchain.pem \
        -subj "/C=US/ST=State/L=City/O=HelpBoard/OU=IT/CN=$DOMAIN"
    
    chmod 644 ssl/fullchain.pem
    chmod 600 ssl/privkey.pem
    
    log_success "Self-signed certificates created"
    log_info "Note: Browsers will show security warnings with self-signed certificates"
}

# Verify certificates
verify_certificates() {
    log_step "Verifying certificates..."
    
    if [ -f "ssl/fullchain.pem" ] && [ -f "ssl/privkey.pem" ]; then
        # Check certificate validity
        local expiry=$(openssl x509 -in ssl/fullchain.pem -noout -enddate | cut -d= -f2)
        log_success "Certificate expires: $expiry"
        
        # Check if it's self-signed
        if openssl x509 -in ssl/fullchain.pem -noout -issuer | grep -q "HelpBoard"; then
            log_info "Using self-signed certificate"
        else
            log_info "Using Let's Encrypt certificate"
        fi
        
        return 0
    else
        log_error "Certificate files not found"
        return 1
    fi
}

# Start services with SSL
start_with_ssl() {
    log_step "Starting services with SSL..."
    
    # Start the application
    docker compose -f "$COMPOSE_FILE" up -d
    
    # Wait for services
    sleep 15
    
    # Test HTTPS
    if curl -k -s "https://$DOMAIN/api/health" > /dev/null; then
        log_success "HTTPS is working"
    else
        log_info "HTTPS test failed, but HTTP might work"
    fi
}

# Main SSL setup
main() {
    log_info "Starting SSL setup for $DOMAIN..."
    
    stop_conflicts
    
    if check_domain; then
        # Try Let's Encrypt first
        if generate_ssl_standalone && copy_certificates; then
            log_success "Let's Encrypt certificates installed"
        else
            log_info "Let's Encrypt failed, using self-signed certificates"
            create_self_signed
        fi
    else
        log_info "Domain issues detected, using self-signed certificates"
        create_self_signed
    fi
    
    verify_certificates
    start_with_ssl
    
    log_success "SSL setup completed!"
    echo ""
    log_info "Your application should be accessible at:"
    echo "  HTTPS: https://$DOMAIN"
    echo "  HTTP:  http://$DOMAIN"
    echo ""
    
    if openssl x509 -in ssl/fullchain.pem -noout -issuer | grep -q "HelpBoard"; then
        log_info "Note: Using self-signed certificate. Browsers will show warnings."
        log_info "To get proper SSL, ensure DNS points to this server and run again."
    fi
}

# Handle different modes
case "${1:-auto}" in
    "lets-encrypt")
        check_domain && generate_ssl_standalone && copy_certificates
        ;;
    "self-signed")
        create_self_signed
        ;;
    "verify")
        verify_certificates
        ;;
    "auto"|*)
        main
        ;;
esac