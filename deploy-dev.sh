#!/bin/bash

# HelpBoard Development Mode Deployment Script
# Optimized for reliability and avoiding Vite build complexities

set -e

DOMAIN="helpboard.selfany.com"
EMAIL="admin@helpboard.selfany.com"
COMPOSE_FILE="docker-compose.dev.yml"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check prerequisites
check_prerequisites() {
    log_info "Checking deployment prerequisites..."
    
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed. Please run the setup script first."
        exit 1
    fi
    
    if ! docker compose version &> /dev/null && ! docker-compose --version &> /dev/null; then
        log_error "Docker Compose is not installed."
        exit 1
    fi
    
    # Use docker compose if available, fallback to docker-compose
    if docker compose version &> /dev/null; then
        DOCKER_COMPOSE="docker compose"
    else
        DOCKER_COMPOSE="docker-compose"
    fi
    
    log_info "Prerequisites check passed"
}

# Setup SSL certificates
setup_ssl() {
    log_info "Setting up SSL certificates..."
    
    mkdir -p ssl certbot/www certbot/conf
    
    if [ -f "ssl/fullchain.pem" ] && [ -f "ssl/privkey.pem" ]; then
        log_info "SSL certificates already exist"
        return 0
    fi
    
    # Stop any conflicting services
    $DOCKER_COMPOSE -f "$COMPOSE_FILE" stop nginx 2>/dev/null || true
    
    # Create temporary nginx for ACME challenge
    cat > nginx-acme.conf << 'EOF'
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
            return 200 'ACME Challenge Server';
            add_header Content-Type text/plain;
        }
    }
}
EOF
    
    # Start temporary nginx
    docker run -d --name ssl-nginx \
        -p 80:80 \
        -v "$(pwd)/certbot/www:/var/www/certbot:ro" \
        -v "$(pwd)/nginx-acme.conf:/etc/nginx/nginx.conf:ro" \
        nginx:alpine
    
    sleep 5
    
    # Request certificate
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
    
    # Cleanup
    docker stop ssl-nginx && docker rm ssl-nginx
    rm nginx-acme.conf
    
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

# Deploy application in development mode
deploy_application() {
    log_info "Deploying HelpBoard in development mode..."
    
    # Load environment
    if [ ! -f ".env" ]; then
        log_error ".env file not found"
        exit 1
    fi
    
    source .env
    
    # Check required variables
    if [ -z "$OPENAI_API_KEY" ] || [ "$OPENAI_API_KEY" = "your_openai_api_key_here" ]; then
        log_error "OPENAI_API_KEY is not set in .env file"
        exit 1
    fi
    
    # Pull latest images
    $DOCKER_COMPOSE -f "$COMPOSE_FILE" pull
    
    # Build application (no cache to avoid issues)
    log_info "Building application in development mode..."
    $DOCKER_COMPOSE -f "$COMPOSE_FILE" build --no-cache app
    
    # Start services
    log_info "Starting services..."
    $DOCKER_COMPOSE -f "$COMPOSE_FILE" up -d
    
    # Wait for services
    log_info "Waiting for services to start..."
    sleep 30
    
    # Run database migration
    log_info "Running database migration..."
    if $DOCKER_COMPOSE -f "$COMPOSE_FILE" exec -T db pg_isready -U helpboard_user; then
        npm run db:push
        log_info "Database schema updated successfully"
    else
        log_warn "Database not ready, skipping migration"
    fi
    
    # Health check
    local max_attempts=20
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if curl -k -s "https://$DOMAIN/api/health" | grep -q "ok\|healthy\|status.*ok"; then
            log_info "Application is healthy and running"
            return 0
        fi
        
        log_info "Health check attempt $attempt/$max_attempts..."
        sleep 15
        ((attempt++))
    done
    
    log_error "Application failed to become healthy"
    log_error "Checking logs..."
    $DOCKER_COMPOSE -f "$COMPOSE_FILE" logs app | tail -20
    return 1
}

# Complete deployment
full_deployment() {
    log_info "Starting development mode deployment..."
    
    check_prerequisites
    
    # Setup SSL
    if ! setup_ssl; then
        log_warn "SSL setup failed, continuing anyway..."
    fi
    
    # Deploy application
    deploy_application
    
    log_info "Development deployment completed!"
    log_info "Application available at: https://$DOMAIN"
    log_info "Running in development mode for better reliability"
}

# Show deployment status
show_status() {
    log_info "HelpBoard Development Deployment Status"
    echo
    
    echo "=== Services ==="
    $DOCKER_COMPOSE -f "$COMPOSE_FILE" ps
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
    if curl -k -s "https://$DOMAIN/api/health" | grep -q "ok\|healthy"; then
        echo "✓ Application is healthy"
    else
        echo "✗ Application health check failed"
    fi
    echo
    
    echo "=== Development Mode Notes ==="
    echo "- Application runs with hot reload enabled"
    echo "- No build step required - faster deployments"
    echo "- Logs are more verbose for debugging"
    echo "- File changes are reflected immediately"
}

# Clean deployment
clean_deployment() {
    log_info "Cleaning development deployment..."
    
    $DOCKER_COMPOSE -f "$COMPOSE_FILE" down -v
    docker system prune -f
    
    log_info "Deployment cleaned"
}

# Show usage
show_usage() {
    cat << EOF
HelpBoard Development Mode Deployment

Usage: $0 [COMMAND]

Commands:
    deploy      Full deployment in development mode
    ssl         SSL certificates only  
    status      Show deployment status
    logs        Show application logs
    clean       Clean deployment and volumes
    restart     Restart all services
    help        Show this help

Development mode benefits:
- No complex Vite build process
- Faster deployments and restarts
- Hot reload for development
- Better error visibility

EOF
}

# Main execution
case "$1" in
    "deploy"|"")
        full_deployment
        ;;
    "ssl")
        setup_ssl
        ;;
    "status")
        show_status
        ;;
    "logs")
        $DOCKER_COMPOSE -f "$COMPOSE_FILE" logs -f app
        ;;
    "clean")
        clean_deployment
        ;;
    "restart")
        $DOCKER_COMPOSE -f "$COMPOSE_FILE" restart
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