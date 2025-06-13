#!/bin/bash

# HelpBoard Fixed Deployment Script
# Addresses Docker build cache issues and ensures reliable deployment

set -e

DOMAIN="helpboard.selfany.com"
EMAIL="admin@helpboard.selfany.com"
COMPOSE_FILE="docker-compose.prod.yml"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Clean Docker cache and rebuild from scratch
clean_docker_build() {
    log_info "Cleaning Docker build cache..."
    
    # Stop all containers
    docker-compose -f "$COMPOSE_FILE" down 2>/dev/null || true
    
    # Remove existing images
    docker images | grep helpboard | awk '{print $3}' | xargs docker rmi -f 2>/dev/null || true
    
    # Clean build cache
    docker builder prune -f
    docker system prune -f
    
    log_info "Docker cache cleaned"
}

# Test local build before Docker
test_local_build() {
    log_info "Testing local build process..."
    
    # Install dependencies if needed
    if [ ! -d "node_modules" ]; then
        log_info "Installing dependencies..."
        npm ci
    fi
    
    # Test build locally
    log_info "Running local build test..."
    NODE_ENV=production npm run build
    
    # Verify build outputs
    if [ ! -d "dist/public" ]; then
        log_error "Frontend build failed - dist/public not found"
        exit 1
    fi
    
    if [ ! -f "dist/index.js" ]; then
        log_error "Backend build failed - dist/index.js not found"
        exit 1
    fi
    
    log_info "Local build test passed"
}

# Setup SSL with improved error handling
setup_ssl_robust() {
    log_info "Setting up SSL certificates with robust error handling..."
    
    # Create directories
    mkdir -p ssl certbot/www certbot/conf
    
    # Check if certificates exist
    if [ -f "ssl/fullchain.pem" ] && [ -f "ssl/privkey.pem" ]; then
        log_info "SSL certificates already exist"
        return 0
    fi
    
    # Stop any conflicting services
    docker-compose -f "$COMPOSE_FILE" stop nginx 2>/dev/null || true
    pkill -f nginx || true
    
    # Create temporary nginx for ACME challenge
    cat > nginx-ssl.conf << 'EOF'
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
            return 200 'SSL Setup Server';
            add_header Content-Type text/plain;
        }
    }
}
EOF
    
    # Start temporary nginx
    docker run -d --name ssl-nginx \
        -p 80:80 \
        -v "$(pwd)/certbot/www:/var/www/certbot:ro" \
        -v "$(pwd)/nginx-ssl.conf:/etc/nginx/nginx.conf:ro" \
        nginx:alpine
    
    sleep 5
    
    # Request certificate
    log_info "Requesting SSL certificate from Let's Encrypt..."
    docker run --rm \
        -v "$(pwd)/certbot/www:/var/www/certbot" \
        -v "$(pwd)/certbot/conf:/etc/letsencrypt" \
        certbot/certbot certonly \
        --webroot \
        --webroot-path=/var/www/certbot \
        --email "$EMAIL" \
        --agree-tos \
        --no-eff-email \
        --non-interactive \
        --force-renewal \
        -d "$DOMAIN"
    
    # Cleanup temporary nginx
    docker stop ssl-nginx && docker rm ssl-nginx
    rm nginx-ssl.conf
    
    # Copy certificates
    if [ -d "certbot/conf/live/$DOMAIN" ]; then
        cp "certbot/conf/live/$DOMAIN/fullchain.pem" ssl/
        cp "certbot/conf/live/$DOMAIN/privkey.pem" ssl/
        chmod 644 ssl/fullchain.pem
        chmod 600 ssl/privkey.pem
        log_info "SSL certificates installed successfully"
    else
        log_error "SSL certificate generation failed"
        return 1
    fi
}

# Deploy with build verification
deploy_with_verification() {
    log_info "Deploying application with build verification..."
    
    # Load environment
    if [ ! -f ".env" ]; then
        log_error ".env file not found"
        exit 1
    fi
    
    source .env
    
    # Check required variables
    if [ -z "$DB_PASSWORD" ] || [ -z "$OPENAI_API_KEY" ] || [ -z "$SESSION_SECRET" ]; then
        log_error "Missing required environment variables"
        exit 1
    fi
    
    # Build with no cache to avoid cache issues
    log_info "Building application (no cache)..."
    docker-compose -f "$COMPOSE_FILE" build --no-cache app
    
    # Start services
    log_info "Starting services..."
    docker-compose -f "$COMPOSE_FILE" up -d
    
    # Wait for services
    log_info "Waiting for services to start..."
    sleep 45
    
    # Health check
    local max_attempts=20
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if curl -k -s "https://$DOMAIN/health" | grep -q "ok\|healthy\|status.*ok"; then
            log_info "Application is healthy"
            return 0
        fi
        
        log_info "Health check attempt $attempt/$max_attempts..."
        sleep 15
        ((attempt++))
    done
    
    log_error "Application failed to become healthy"
    log_error "Checking logs..."
    docker-compose -f "$COMPOSE_FILE" logs app | tail -50
    return 1
}

# Complete deployment process
full_deployment() {
    log_info "Starting complete HelpBoard deployment..."
    
    # Step 1: Clean previous builds
    clean_docker_build
    
    # Step 2: Test local build
    test_local_build
    
    # Step 3: Setup SSL
    if ! setup_ssl_robust; then
        log_warn "SSL setup failed, continuing with deployment..."
    fi
    
    # Step 4: Deploy application
    deploy_with_verification
    
    log_info "Deployment completed successfully!"
    log_info "Application available at: https://$DOMAIN"
}

# Quick SSL-only setup
ssl_only() {
    log_info "Setting up SSL certificates only..."
    setup_ssl_robust
}

# Application-only deployment (assumes SSL exists)
app_only() {
    log_info "Deploying application only..."
    test_local_build
    deploy_with_verification
}

# Show deployment status
show_status() {
    log_info "HelpBoard Deployment Status"
    echo
    
    echo "=== Services ==="
    docker-compose -f "$COMPOSE_FILE" ps
    echo
    
    echo "=== SSL Status ==="
    if [ -f "ssl/fullchain.pem" ]; then
        local expiry=$(openssl x509 -in ssl/fullchain.pem -noout -enddate | cut -d= -f2)
        echo "SSL Certificate expires: $expiry"
    else
        echo "No SSL certificate found"
    fi
    echo
    
    echo "=== Health Check ==="
    if curl -k -s "https://$DOMAIN/health" | grep -q "ok\|healthy"; then
        echo "✓ Application is healthy"
    else
        echo "✗ Application health check failed"
    fi
}

# Show usage
show_usage() {
    cat << EOF
HelpBoard Fixed Deployment Script

Usage: $0 [COMMAND]

Commands:
    full        Complete deployment (clean + SSL + app)
    ssl         SSL certificates only
    app         Application only (requires SSL)
    clean       Clean Docker cache and rebuild
    status      Show deployment status
    logs        Show application logs
    help        Show this help

Examples:
    $0 full     # Complete fresh deployment
    $0 ssl      # SSL setup only
    $0 app      # App deployment only

EOF
}

# Main execution
case "$1" in
    "full"|"")
        full_deployment
        ;;
    "ssl")
        ssl_only
        ;;
    "app")
        app_only
        ;;
    "clean")
        clean_docker_build
        ;;
    "status")
        show_status
        ;;
    "logs")
        docker-compose -f "$COMPOSE_FILE" logs -f app
        ;;
    "help")
        show_usage
        ;;
    *)
        log_error "Unknown command: $1"
        show_usage
        exit 1
        ;;
esac