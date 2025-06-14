#!/bin/bash

# HelpBoard Single Domain Deployment Script
# Optimized for helpboard.selfany.com without www subdomain
# Addresses common SSL/certbot issues on Digital Ocean

set -e

# Configuration
DOMAIN="helpboard.selfany.com"
EMAIL="admin@helpboard.selfany.com"
COMPOSE_FILE="docker-compose.prod.yml"
BACKUP_DIR="backups"
LOG_FILE="deployment.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

log_debug() {
    echo -e "${BLUE}[DEBUG]${NC} $1" | tee -a "$LOG_FILE"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking deployment prerequisites..."
    
    # Check if running as root or with sudo
    if [ "$EUID" -ne 0 ]; then
        log_error "Please run as root or with sudo"
        exit 1
    fi
    
    # Check if Docker is installed and running
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed"
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        log_error "Docker is not running"
        exit 1
    fi
    
    # Check if Docker Compose is available
    if ! docker compose version &> /dev/null && ! docker-compose --version &> /dev/null; then
        log_error "Docker Compose is not installed"
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

# Check DNS resolution
check_dns() {
    log_info "Checking DNS resolution for $DOMAIN..."
    
    # Check if domain resolves to correct IP
    RESOLVED_IP=$(dig +short $DOMAIN | tail -n1)
    EXPECTED_IP="67.205.138.68"
    
    if [ "$RESOLVED_IP" = "$EXPECTED_IP" ]; then
        log_info "DNS correctly resolves $DOMAIN to $EXPECTED_IP"
    else
        log_warn "DNS resolution issue: $DOMAIN resolves to '$RESOLVED_IP', expected '$EXPECTED_IP'"
        log_warn "SSL certificate generation may fail. Please verify DNS settings."
    fi
    
    # Test HTTP connectivity
    log_info "Testing HTTP connectivity to $DOMAIN..."
    if timeout 10 curl -s -I "http://$DOMAIN" &> /dev/null; then
        log_info "HTTP connectivity test passed"
    else
        log_warn "HTTP connectivity test failed - this is expected before deployment"
    fi
}

# Prepare SSL certificate generation
prepare_ssl_challenge() {
    log_info "Preparing for SSL certificate challenge..."
    
    # Create necessary directories
    mkdir -p ssl certbot/www certbot/conf
    
    # Stop any existing nginx
    $DOCKER_COMPOSE -f "$COMPOSE_FILE" stop nginx 2>/dev/null || true
    docker stop nginx-temp 2>/dev/null || true
    docker rm nginx-temp 2>/dev/null || true
    
    # Create minimal nginx config for ACME challenge
    cat > nginx-acme.conf << 'EOF'
events {
    worker_connections 1024;
}

http {
    server {
        listen 80;
        server_name helpboard.selfany.com;
        
        location /.well-known/acme-challenge/ {
            root /var/www/certbot;
            try_files $uri $uri/ =404;
        }
        
        location / {
            return 200 'ACME Challenge Server Ready';
            add_header Content-Type text/plain;
        }
    }
}
EOF
    
    # Start temporary nginx for ACME challenge
    log_info "Starting temporary nginx for ACME challenge..."
    docker run -d --name nginx-temp \
        -p 80:80 \
        -v "$(pwd)/certbot/www:/var/www/certbot:ro" \
        -v "$(pwd)/nginx-acme.conf:/etc/nginx/nginx.conf:ro" \
        nginx:alpine
    
    # Wait for nginx to start
    sleep 5
    
    # Test ACME challenge endpoint
    if curl -s "http://$DOMAIN/" | grep -q "ACME Challenge Server Ready"; then
        log_info "ACME challenge server is ready"
    else
        log_error "ACME challenge server is not responding correctly"
        docker logs nginx-temp
        exit 1
    fi
}

# Generate SSL certificates
generate_ssl() {
    log_info "Generating SSL certificate for $DOMAIN..."
    
    # Check if certificates already exist
    if [ -f "ssl/fullchain.pem" ] && [ -f "ssl/privkey.pem" ]; then
        log_warn "SSL certificates already exist. Skipping generation."
        log_warn "Use './deploy-single-domain.sh renew-ssl' to renew certificates."
        return 0
    fi
    
    # Request certificate from Let's Encrypt
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
        --verbose \
        -d "$DOMAIN"
    
    # Check if certificate was generated
    if [ -d "certbot/conf/live/$DOMAIN" ]; then
        log_info "Certificate generated successfully"
        
        # Copy certificates to ssl directory
        cp "certbot/conf/live/$DOMAIN/fullchain.pem" ssl/
        cp "certbot/conf/live/$DOMAIN/privkey.pem" ssl/
        
        # Set correct permissions
        chmod 644 ssl/fullchain.pem
        chmod 600 ssl/privkey.pem
        
        log_info "SSL certificates installed for $DOMAIN"
    else
        log_error "SSL certificate generation failed"
        log_error "Common causes:"
        log_error "1. Domain $DOMAIN not pointing to this server"
        log_error "2. Port 80 blocked by firewall"
        log_error "3. Rate limiting from Let's Encrypt"
        
        # Show certbot logs for debugging
        if [ -f "certbot/conf/logs/letsencrypt.log" ]; then
            log_error "Recent certbot logs:"
            tail -20 "certbot/conf/logs/letsencrypt.log"
        fi
        
        exit 1
    fi
}

# Cleanup temporary resources
cleanup_temp() {
    log_info "Cleaning up temporary resources..."
    
    # Stop and remove temporary nginx
    docker stop nginx-temp 2>/dev/null || true
    docker rm nginx-temp 2>/dev/null || true
    
    # Remove temporary config
    rm -f nginx-acme.conf
}

# Deploy application
deploy_application() {
    log_info "Deploying HelpBoard application..."
    
    # Load environment variables
    if [ ! -f ".env" ]; then
        log_error ".env file not found. Please create one based on .env.example"
        exit 1
    fi
    
    # Check required environment variables
    source .env
    required_vars=("DB_PASSWORD" "OPENAI_API_KEY" "SESSION_SECRET")
    
    for var in "${required_vars[@]}"; do
        if [ -z "${!var}" ]; then
            log_error "Required environment variable $var is not set in .env"
            exit 1
        fi
    done
    
    # Build and start services
    log_info "Building application..."
    $DOCKER_COMPOSE -f "$COMPOSE_FILE" build
    
    log_info "Starting services..."
    $DOCKER_COMPOSE -f "$COMPOSE_FILE" up -d
    
    # Wait for services to be ready
    log_info "Waiting for services to start..."
    sleep 30
    
    # Check service health
    check_service_health
}

# Check service health
check_service_health() {
    log_info "Checking service health..."
    
    # Check if containers are running
    if ! $DOCKER_COMPOSE -f "$COMPOSE_FILE" ps | grep -q "Up"; then
        log_error "Some services failed to start"
        $DOCKER_COMPOSE -f "$COMPOSE_FILE" logs
        exit 1
    fi
    
    # Test application endpoint
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if curl -k -s "https://$DOMAIN/health" | grep -q "ok\|healthy"; then
            log_info "Application health check passed"
            break
        fi
        
        log_info "Waiting for application to be ready... (attempt $attempt/$max_attempts)"
        sleep 10
        ((attempt++))
    done
    
    if [ $attempt -gt $max_attempts ]; then
        log_error "Application failed to become healthy"
        log_error "Check application logs:"
        $DOCKER_COMPOSE -f "$COMPOSE_FILE" logs app
        exit 1
    fi
}

# Renew SSL certificates
renew_ssl() {
    log_info "Renewing SSL certificates..."
    
    # Renew certificates
    docker run --rm \
        -v "$(pwd)/certbot/www:/var/www/certbot" \
        -v "$(pwd)/certbot/conf:/etc/letsencrypt" \
        certbot/certbot renew \
        --webroot \
        --webroot-path=/var/www/certbot
    
    if [ $? -eq 0 ]; then
        # Copy renewed certificates
        if [ -d "certbot/conf/live/$DOMAIN" ]; then
            cp "certbot/conf/live/$DOMAIN/fullchain.pem" ssl/
            cp "certbot/conf/live/$DOMAIN/privkey.pem" ssl/
            chmod 644 ssl/fullchain.pem
            chmod 600 ssl/privkey.pem
        fi
        
        # Restart nginx to use new certificates
        $DOCKER_COMPOSE -f "$COMPOSE_FILE" restart nginx
        
        log_info "SSL certificates renewed successfully"
    else
        log_error "Failed to renew SSL certificates"
        exit 1
    fi
}

# Create database backup
backup_database() {
    log_info "Creating database backup..."
    
    mkdir -p "$BACKUP_DIR"
    
    local backup_file="$BACKUP_DIR/helpboard_backup_$(date +%Y%m%d_%H%M%S).sql"
    
    # Create backup
    $DOCKER_COMPOSE -f "$COMPOSE_FILE" exec -T db pg_dump -U helpboard_user helpboard > "$backup_file"
    
    if [ $? -eq 0 ]; then
        gzip "$backup_file"
        log_info "Database backup created: ${backup_file}.gz"
        
        # Keep only last 7 backups
        find "$BACKUP_DIR" -name "helpboard_backup_*.sql.gz" | sort -r | tail -n +8 | xargs rm -f
    else
        log_error "Failed to create database backup"
        exit 1
    fi
}

# Show deployment status
show_status() {
    log_info "HelpBoard Deployment Status"
    echo
    
    # Service status
    echo "=== Service Status ==="
    $DOCKER_COMPOSE -f "$COMPOSE_FILE" ps
    echo
    
    # SSL certificate status
    echo "=== SSL Certificate Status ==="
    if [ -f "ssl/fullchain.pem" ]; then
        local cert_expiry=$(openssl x509 -in ssl/fullchain.pem -noout -enddate | cut -d= -f2)
        echo "Certificate expires: $cert_expiry"
        
        # Check if certificate is valid for domain
        if openssl x509 -in ssl/fullchain.pem -text -noout | grep -q "$DOMAIN"; then
            echo "Certificate is valid for $DOMAIN"
        else
            echo "WARNING: Certificate may not be valid for $DOMAIN"
        fi
    else
        echo "No SSL certificate found"
    fi
    echo
    
    # Application URLs
    echo "=== Application URLs ==="
    echo "Main Application: https://$DOMAIN"
    echo "Health Check: https://$DOMAIN/health"
    echo "Widget Script: https://$DOMAIN/widget.js"
    echo
    
    # Quick health check
    echo "=== Quick Health Check ==="
    if curl -k -s "https://$DOMAIN/health" | grep -q "ok\|healthy"; then
        echo "✅ Application is healthy"
    else
        echo "❌ Application health check failed"
    fi
}

# Show usage information
show_usage() {
    cat << EOF
HelpBoard Single Domain Deployment Script

Usage: $0 [COMMAND]

Commands:
    init            Full deployment (SSL + application)
    ssl             Generate SSL certificates only
    renew-ssl       Renew existing SSL certificates
    deploy          Deploy application only (requires existing SSL)
    backup          Create database backup
    status          Show deployment status
    logs            Show application logs
    help            Show this help message

Examples:
    $0 init         # Fresh deployment with SSL
    $0 ssl          # Generate SSL certificates
    $0 deploy       # Deploy app with existing SSL
    $0 status       # Check deployment status

EOF
}

# Main execution
main() {
    case "$1" in
        "init")
            log_info "Starting full HelpBoard deployment for $DOMAIN..."
            check_prerequisites
            check_dns
            prepare_ssl_challenge
            generate_ssl
            cleanup_temp
            deploy_application
            show_status
            log_info "✅ Deployment completed successfully!"
            log_info "Access your application at: https://$DOMAIN"
            ;;
        "ssl")
            log_info "Generating SSL certificates for $DOMAIN..."
            check_prerequisites
            check_dns
            prepare_ssl_challenge
            generate_ssl
            cleanup_temp
            log_info "✅ SSL certificates generated successfully!"
            ;;
        "renew-ssl")
            check_prerequisites
            renew_ssl
            ;;
        "deploy")
            check_prerequisites
            deploy_application
            ;;
        "backup")
            check_prerequisites
            backup_database
            ;;
        "status")
            show_status
            ;;
        "logs")
            $DOCKER_COMPOSE -f "$COMPOSE_FILE" logs -f
            ;;
        "help"|"--help"|"-h")
            show_usage
            ;;
        "")
            log_error "No command specified"
            show_usage
            exit 1
            ;;
        *)
            log_error "Unknown command: $1"
            show_usage
            exit 1
            ;;
    esac
}

# Trap to ensure cleanup on exit
trap cleanup_temp EXIT

# Run main function
main "$@"