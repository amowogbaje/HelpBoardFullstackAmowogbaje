#!/bin/bash

# Comprehensive diagnosis and fix for database and SSL issues
# This script checks everything and fixes problems systematically

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

COMPOSE_FILE="docker-compose.dev.yml"
DOMAIN="helpboard.selfany.com"

# Check if database container is running
check_database_container() {
    log_step "Checking database container status..."
    
    # Check if database container exists and is running
    if docker compose -f "$COMPOSE_FILE" ps | grep -q "db.*Up"; then
        log_success "Database container is running"
        
        # Check container health
        local container_id=$(docker compose -f "$COMPOSE_FILE" ps -q db)
        if [ -n "$container_id" ]; then
            log_info "Database container ID: $container_id"
            
            # Check if PostgreSQL is running inside container
            if docker exec "$container_id" pg_isready -U helpboard_user > /dev/null 2>&1; then
                log_success "PostgreSQL is ready inside container"
            else
                log_error "PostgreSQL not responding inside container"
                return 1
            fi
            
            # Check database processes
            log_info "PostgreSQL processes in container:"
            docker exec "$container_id" ps aux | grep postgres || true
            
            # Check database logs
            log_info "Recent database logs:"
            docker compose -f "$COMPOSE_FILE" logs --tail=10 db
            
        else
            log_error "Could not get database container ID"
            return 1
        fi
    else
        log_error "Database container is not running"
        
        # Show all containers
        log_info "Current containers:"
        docker compose -f "$COMPOSE_FILE" ps
        
        return 1
    fi
}

# Fix database container issues
fix_database_container() {
    log_step "Fixing database container..."
    
    # Stop all containers
    docker compose -f "$COMPOSE_FILE" down
    
    # Remove any orphaned containers
    docker container prune -f
    
    # Start database first
    log_info "Starting database container..."
    docker compose -f "$COMPOSE_FILE" up -d db
    
    # Wait and check
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if docker compose -f "$COMPOSE_FILE" ps | grep -q "db.*Up"; then
            log_info "Database container started, checking PostgreSQL..."
            
            local container_id=$(docker compose -f "$COMPOSE_FILE" ps -q db)
            if docker exec "$container_id" pg_isready -U helpboard_user > /dev/null 2>&1; then
                log_success "Database is ready"
                return 0
            fi
        fi
        
        log_info "Waiting for database... attempt $attempt/$max_attempts"
        sleep 3
        ((attempt++))
    done
    
    log_error "Database failed to start properly"
    return 1
}

# Test database connectivity
test_database_connectivity() {
    log_step "Testing database connectivity..."
    
    local container_id=$(docker compose -f "$COMPOSE_FILE" ps -q db)
    
    if [ -n "$container_id" ]; then
        # Test connection from inside container
        if docker exec "$container_id" psql -U helpboard_user -d helpboard -c "SELECT 1;" > /dev/null 2>&1; then
            log_success "Database connection from inside container works"
        else
            log_error "Database connection from inside container failed"
        fi
        
        # Test connection from app container (if running)
        if docker compose -f "$COMPOSE_FILE" ps | grep -q "app.*Up"; then
            if docker compose -f "$COMPOSE_FILE" exec -T app psql "$DATABASE_URL" -c "SELECT 1;" > /dev/null 2>&1; then
                log_success "Database connection from app container works"
            else
                log_error "Database connection from app container failed"
            fi
        fi
        
        # Show database info
        log_info "Database info:"
        docker exec "$container_id" psql -U helpboard_user -d helpboard -c "SELECT version();" 2>/dev/null || log_error "Could not get database version"
        
        # List tables
        log_info "Database tables:"
        docker exec "$container_id" psql -U helpboard_user -d helpboard -c "\dt" 2>/dev/null || log_info "No tables found or connection failed"
        
    else
        log_error "Database container not found"
        return 1
    fi
}

# Check SSL certificate issues
check_ssl_issues() {
    log_step "Checking SSL certificate issues..."
    
    # Check if SSL certificates exist
    if [ -f "ssl/fullchain.pem" ] && [ -f "ssl/privkey.pem" ]; then
        log_success "SSL certificate files exist"
        
        # Check certificate validity
        local expiry=$(openssl x509 -in ssl/fullchain.pem -noout -enddate 2>/dev/null | cut -d= -f2)
        if [ $? -eq 0 ]; then
            log_info "Certificate expires: $expiry"
            
            # Check if certificate is self-signed
            if openssl x509 -in ssl/fullchain.pem -noout -issuer 2>/dev/null | grep -q "HelpBoard"; then
                log_info "Using self-signed certificate"
            else
                log_info "Using Let's Encrypt certificate"
            fi
        else
            log_error "Certificate file is corrupted"
            return 1
        fi
    else
        log_error "SSL certificate files missing"
        return 1
    fi
}

# Fix SSL certificate issues
fix_ssl_issues() {
    log_step "Fixing SSL certificate issues..."
    
    mkdir -p ssl certbot/www certbot/conf
    
    # Stop any conflicting services
    sudo systemctl stop apache2 2>/dev/null || true
    sudo systemctl stop nginx 2>/dev/null || true
    docker stop ssl-nginx 2>/dev/null || true
    docker rm ssl-nginx 2>/dev/null || true
    
    # Kill processes using ports 80/443
    sudo lsof -ti:80 | xargs -r sudo kill -9 2>/dev/null || true
    sudo lsof -ti:443 | xargs -r sudo kill -9 2>/dev/null || true
    
    # Check if domain resolves correctly
    local server_ip=$(curl -s ipinfo.io/ip || echo "unknown")
    local domain_ip=$(dig +short $DOMAIN | tail -n1 || echo "unknown")
    
    log_info "Server IP: $server_ip"
    log_info "Domain resolves to: $domain_ip"
    
    if [ "$server_ip" = "$domain_ip" ] && [ "$server_ip" != "unknown" ]; then
        log_info "DNS is correct, trying Let's Encrypt..."
        
        # Try Let's Encrypt with standalone mode
        if docker run --rm \
            -p 80:80 \
            -v "$(pwd)/certbot/conf:/etc/letsencrypt" \
            certbot/certbot certonly \
            --standalone \
            --email "admin@helpboard.selfany.com" \
            --agree-tos \
            --no-eff-email \
            --non-interactive \
            --force-renewal \
            -d "$DOMAIN" 2>/dev/null; then
            
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
    fi
    
    # Fallback to self-signed certificate
    log_info "Creating self-signed certificate as fallback..."
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout ssl/privkey.pem \
        -out ssl/fullchain.pem \
        -subj "/C=US/ST=State/L=City/O=HelpBoard/OU=IT/CN=$DOMAIN" 2>/dev/null
    
    chmod 644 ssl/fullchain.pem
    chmod 600 ssl/privkey.pem
    
    log_success "Self-signed certificates created"
}

# Test HTTPS connectivity
test_https() {
    log_step "Testing HTTPS connectivity..."
    
    # Start nginx if not running
    if ! docker compose -f "$COMPOSE_FILE" ps | grep -q "nginx.*Up"; then
        docker compose -f "$COMPOSE_FILE" up -d nginx
        sleep 10
    fi
    
    # Test HTTP first
    if curl -s "http://localhost/api/health" > /dev/null 2>&1; then
        log_success "HTTP connection works"
    else
        log_error "HTTP connection failed"
    fi
    
    # Test HTTPS
    if curl -k -s "https://localhost/api/health" > /dev/null 2>&1; then
        log_success "HTTPS connection works"
    else
        log_error "HTTPS connection failed"
        
        # Check nginx logs
        log_info "Nginx logs:"
        docker compose -f "$COMPOSE_FILE" logs --tail=5 nginx
    fi
    
    # Test external domain
    if curl -k -s "https://$DOMAIN/api/health" > /dev/null 2>&1; then
        log_success "External HTTPS works"
    else
        log_error "External HTTPS failed"
    fi
}

# Run database migration
run_database_migration() {
    log_step "Running database migration..."
    
    # Ensure app container is running
    docker compose -f "$COMPOSE_FILE" up -d app
    sleep 10
    
    # Run migration
    if npm run db:push; then
        log_success "Database migration completed"
        
        # Verify tables exist
        local container_id=$(docker compose -f "$COMPOSE_FILE" ps -q db)
        if docker exec "$container_id" psql -U helpboard_user -d helpboard -c "\dt" | grep -q "agents\|customers"; then
            log_success "Database tables created successfully"
        else
            log_error "Database tables not found after migration"
        fi
    else
        log_error "Database migration failed"
        return 1
    fi
}

# Test complete application
test_application() {
    log_step "Testing complete application..."
    
    # Start all services
    docker compose -f "$COMPOSE_FILE" up -d
    
    # Wait for everything to start
    sleep 20
    
    # Test health endpoint
    if curl -s "http://localhost:3000/api/health" > /dev/null 2>&1; then
        log_success "Application health check passed"
    else
        log_error "Application health check failed"
    fi
    
    # Test login endpoint
    local response=$(curl -s -w "%{http_code}" -X POST "http://localhost:3000/api/auth/login" \
        -H "Content-Type: application/json" \
        -d '{"email":"admin@helpboard.com","password":"admin123"}')
    
    local http_code="${response: -3}"
    
    if [ "$http_code" = "200" ]; then
        log_success "Login functionality works"
    else
        log_error "Login functionality failed (HTTP: $http_code)"
    fi
}

# Show comprehensive status
show_comprehensive_status() {
    log_step "Comprehensive deployment status:"
    echo ""
    
    echo "=== Docker Containers ==="
    docker compose -f "$COMPOSE_FILE" ps
    echo ""
    
    echo "=== Database Status ==="
    local container_id=$(docker compose -f "$COMPOSE_FILE" ps -q db)
    if [ -n "$container_id" ]; then
        echo "Database container: Running"
        if docker exec "$container_id" pg_isready -U helpboard_user > /dev/null 2>&1; then
            echo "PostgreSQL: Ready"
            docker exec "$container_id" psql -U helpboard_user -d helpboard -c "SELECT COUNT(*) as agent_count FROM agents;" 2>/dev/null || echo "Tables: Not accessible"
        else
            echo "PostgreSQL: Not ready"
        fi
    else
        echo "Database container: Not found"
    fi
    echo ""
    
    echo "=== SSL Status ==="
    if [ -f "ssl/fullchain.pem" ]; then
        local expiry=$(openssl x509 -in ssl/fullchain.pem -noout -enddate 2>/dev/null | cut -d= -f2)
        echo "SSL Certificate: Present (expires: $expiry)"
    else
        echo "SSL Certificate: Missing"
    fi
    echo ""
    
    echo "=== Network Connectivity ==="
    if curl -s "http://localhost:3000/api/health" > /dev/null 2>&1; then
        echo "HTTP: Working"
    else
        echo "HTTP: Failed"
    fi
    
    if curl -k -s "https://$DOMAIN/api/health" > /dev/null 2>&1; then
        echo "HTTPS: Working"
    else
        echo "HTTPS: Failed"
    fi
    echo ""
    
    echo "=== Access Information ==="
    echo "Domain: https://$DOMAIN"
    echo "Admin: admin@helpboard.com / admin123"
    echo "Agent: agent@helpboard.com / password123"
}

# Main execution
main() {
    log_info "Starting comprehensive diagnosis and fix..."
    
    # Check database container
    if ! check_database_container; then
        fix_database_container
    fi
    
    # Test database connectivity
    test_database_connectivity
    
    # Check SSL issues
    if ! check_ssl_issues; then
        fix_ssl_issues
    fi
    
    # Run database migration
    run_database_migration
    
    # Test HTTPS
    test_https
    
    # Test complete application
    test_application
    
    # Show final status
    show_comprehensive_status
    
    log_success "Comprehensive fix completed!"
}

main