#!/bin/bash

# Fix HSTS SSL issues on Digital Ocean droplet
# This resolves the "website uses HSTS" error by properly configuring SSL

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
log_step() { echo -e "${GREEN}[STEP]${NC} $1"; }

DOMAIN="helpboard.selfany.com"
COMPOSE_FILE="docker-compose.dev.yml"

# Stop all services to clear HSTS issues
stop_all_services() {
    log_step "Stopping all services to clear HSTS..."
    
    docker compose -f "$COMPOSE_FILE" down
    
    # Kill any processes using ports 80/443
    sudo systemctl stop apache2 2>/dev/null || true
    sudo systemctl stop nginx 2>/dev/null || true
    sudo lsof -ti:80 | xargs -r sudo kill -9 2>/dev/null || true
    sudo lsof -ti:443 | xargs -r sudo kill -9 2>/dev/null || true
    
    # Remove any Docker containers using these ports
    docker ps -a | grep -E ":80|:443" | awk '{print $1}' | xargs -r docker rm -f 2>/dev/null || true
    
    log_success "All services stopped"
}

# Create proper SSL certificates
create_ssl_certificates() {
    log_step "Creating proper SSL certificates..."
    
    mkdir -p ssl certbot/www certbot/conf
    
    # Get server's public IP
    local server_ip=$(curl -s ipinfo.io/ip)
    local domain_ip=$(dig +short $DOMAIN | tail -n1)
    
    log_info "Server IP: $server_ip"
    log_info "Domain resolves to: $domain_ip"
    
    if [ "$server_ip" = "$domain_ip" ] && [ "$server_ip" != "" ]; then
        log_info "DNS is correct, attempting Let's Encrypt..."
        
        # Try Let's Encrypt with standalone mode
        if docker run --rm \
            -p 80:80 \
            -v "$(pwd)/certbot/conf:/etc/letsencrypt" \
            certbot/certbot certonly \
            --standalone \
            --preferred-challenges http \
            --email "admin@helpboard.selfany.com" \
            --agree-tos \
            --no-eff-email \
            --non-interactive \
            --expand \
            -d "$DOMAIN"; then
            
            # Copy certificates
            if [ -d "certbot/conf/live/$DOMAIN" ]; then
                cp "certbot/conf/live/$DOMAIN/fullchain.pem" ssl/
                cp "certbot/conf/live/$DOMAIN/privkey.pem" ssl/
                chmod 644 ssl/fullchain.pem
                chmod 600 ssl/privkey.pem
                log_success "Let's Encrypt certificates installed"
                return 0
            fi
        else
            log_error "Let's Encrypt failed"
        fi
    else
        log_error "DNS mismatch - domain doesn't point to this server"
    fi
    
    # Create self-signed certificate as fallback
    log_info "Creating self-signed certificate..."
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout ssl/privkey.pem \
        -out ssl/fullchain.pem \
        -subj "/C=US/ST=State/L=City/O=HelpBoard/OU=IT/CN=$DOMAIN"
    
    chmod 644 ssl/fullchain.pem
    chmod 600 ssl/privkey.pem
    
    log_success "Self-signed certificates created"
}

# Update nginx configuration to handle HSTS properly
update_nginx_config() {
    log_step "Updating nginx configuration for HSTS..."
    
    # Check if nginx.conf exists and update it
    if [ -f "nginx.conf" ]; then
        # Create backup
        cp nginx.conf nginx.conf.backup
        
        # Update nginx configuration to handle HSTS properly
        cat > nginx.conf << 'EOF'
events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    # Rate limiting
    limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;
    limit_req_zone $binary_remote_addr zone=widget:10m rate=30r/s;

    # Upstream for app
    upstream app {
        server app:5000;
    }

    # HTTP server - redirect to HTTPS only after SSL is working
    server {
        listen 80;
        server_name helpboard.selfany.com;

        # Allow Let's Encrypt challenges
        location /.well-known/acme-challenge/ {
            root /var/www/certbot;
            try_files $uri $uri/ =404;
        }

        # Serve the app normally on HTTP initially
        location / {
            proxy_pass http://app;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }

        # WebSocket support
        location /ws {
            proxy_pass http://app;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }
    }

    # HTTPS server
    server {
        listen 443 ssl http2;
        server_name helpboard.selfany.com;

        # SSL Configuration
        ssl_certificate /etc/nginx/ssl/fullchain.pem;
        ssl_private_key /etc/nginx/ssl/privkey.pem;
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-SHA256:ECDHE-RSA-AES256-SHA384;
        ssl_prefer_server_ciphers off;

        # Security headers (without HSTS initially)
        add_header X-Frame-Options DENY;
        add_header X-Content-Type-Options nosniff;
        add_header X-XSS-Protection "1; mode=block";
        add_header Referrer-Policy "strict-origin-when-cross-origin";

        # Main application
        location / {
            proxy_pass http://app;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto https;
            proxy_set_header X-Forwarded-Port 443;
        }

        # API routes with rate limiting
        location /api/ {
            limit_req zone=api burst=20 nodelay;
            proxy_pass http://app;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto https;
        }

        # Widget with higher rate limit
        location /widget.js {
            limit_req zone=widget burst=50 nodelay;
            proxy_pass http://app;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto https;
        }

        # WebSocket support
        location /ws {
            proxy_pass http://app;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto https;
        }
    }
}
EOF
        
        log_success "Nginx configuration updated without HSTS"
    else
        log_error "nginx.conf not found"
        return 1
    fi
}

# Start services in correct order
start_services() {
    log_step "Starting services in correct order..."
    
    # Start database first
    docker compose -f "$COMPOSE_FILE" up -d db
    sleep 15
    
    # Start app
    docker compose -f "$COMPOSE_FILE" up -d app
    sleep 10
    
    # Start nginx last
    docker compose -f "$COMPOSE_FILE" up -d nginx
    sleep 5
    
    log_success "All services started"
}

# Test HTTP access first
test_http_access() {
    log_step "Testing HTTP access..."
    
    # Test direct IP access first
    local server_ip=$(curl -s ipinfo.io/ip)
    
    if curl -s "http://$server_ip:80" > /dev/null 2>&1; then
        log_success "HTTP access via IP works"
    else
        log_error "HTTP access via IP failed"
    fi
    
    # Test domain HTTP access
    if curl -s "http://$DOMAIN" > /dev/null 2>&1; then
        log_success "HTTP access via domain works"
    else
        log_error "HTTP access via domain failed"
    fi
}

# Test HTTPS access
test_https_access() {
    log_step "Testing HTTPS access..."
    
    # Test HTTPS with curl (ignore certificate warnings for self-signed)
    if curl -k -s "https://$DOMAIN" > /dev/null 2>&1; then
        log_success "HTTPS access works (with certificate warnings possible)"
    else
        log_error "HTTPS access failed"
        
        # Show nginx error logs
        log_info "Nginx error logs:"
        docker compose -f "$COMPOSE_FILE" logs nginx | tail -10
        return 1
    fi
}

# Clear browser HSTS cache instructions
show_browser_instructions() {
    log_step "Browser HSTS cache clearing instructions:"
    echo ""
    log_info "To clear HSTS cache in your browser:"
    echo ""
    echo "Chrome/Edge:"
    echo "1. Go to chrome://net-internals/#hsts"
    echo "2. In 'Delete domain security policies' section"
    echo "3. Enter: helpboard.selfany.com"
    echo "4. Click 'Delete'"
    echo ""
    echo "Firefox:"
    echo "1. Go to about:config"
    echo "2. Search for: security.tls.insecure_fallback_hosts"
    echo "3. Add: helpboard.selfany.com"
    echo ""
    echo "Safari:"
    echo "1. Go to Safari > Preferences > Privacy"
    echo "2. Click 'Manage Website Data'"
    echo "3. Search for 'helpboard.selfany.com' and remove"
    echo ""
    echo "OR try incognito/private browsing mode"
}

# Main execution
main() {
    log_info "Fixing HSTS SSL issues for $DOMAIN..."
    
    stop_all_services
    create_ssl_certificates
    update_nginx_config
    start_services
    
    # Wait for services to stabilize
    sleep 20
    
    test_http_access
    test_https_access
    
    show_browser_instructions
    
    log_success "HSTS SSL fix completed!"
    echo ""
    log_info "Try accessing your site:"
    echo "HTTP: http://$DOMAIN"
    echo "HTTPS: https://$DOMAIN"
    echo ""
    log_info "If still having HSTS issues, clear browser cache as shown above"
    log_info "Login credentials: admin@helpboard.com / admin123"
}

main