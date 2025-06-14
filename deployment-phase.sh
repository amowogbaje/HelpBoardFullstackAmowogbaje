#!/bin/bash

# HelpBoard Deployment Phase - Digital Ocean Droplet
# This script deploys the application after .env is configured

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[DEPLOY]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${GREEN}[STEP]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

DOMAIN="helpboard.selfany.com"
DEPLOY_DIR="/opt/helpboard"
COMPOSE_FILE="docker-compose.dev.yml"

# Check if running in correct directory
check_deployment_directory() {
    if [ ! -f ".env" ]; then
        log_error "No .env file found. Run setup-phase.sh first and configure .env"
        exit 1
    fi
    
    if [ ! -f "package.json" ]; then
        log_error "No package.json found. Ensure all application files are present"
        exit 1
    fi
    
    log_success "Deployment directory validated"
}

# Verify .env configuration
verify_env_config() {
    log_step "Verifying .env configuration..."
    
    # Source the .env file
    source .env
    
    # Check critical variables
    if [ "$OPENAI_API_KEY" = "your_openai_api_key_here" ]; then
        log_error "OPENAI_API_KEY not configured in .env file"
        log_info "Edit .env file and add your OpenAI API key"
        exit 1
    fi
    
    if [ -z "$DATABASE_URL" ]; then
        log_error "DATABASE_URL not set in .env"
        exit 1
    fi
    
    if [ -z "$SESSION_SECRET" ]; then
        log_error "SESSION_SECRET not set in .env"
        exit 1
    fi
    
    log_success ".env configuration validated"
}

# Ensure all ports are free
free_all_ports() {
    log_step "Ensuring all required ports are free..."
    
    # Stop any running Docker containers
    docker stop $(docker ps -aq) 2>/dev/null || true
    docker rm $(docker ps -aq) 2>/dev/null || true
    
    # Kill processes on required ports
    local ports=(80 443 5000 5432 6379)
    for port in "${ports[@]}"; do
        local pids=$(lsof -ti:$port 2>/dev/null || true)
        if [ -n "$pids" ]; then
            log_info "Freeing port $port"
            echo "$pids" | xargs -r kill -9 2>/dev/null || true
            sleep 2
        fi
    done
    
    # Verify ports are free
    for port in "${ports[@]}"; do
        if lsof -i:$port > /dev/null 2>&1; then
            log_error "Port $port is still in use"
            lsof -i:$port
            exit 1
        fi
    done
    
    log_success "All required ports are free"
}

# Create optimized Docker Compose configuration
create_docker_compose() {
    log_step "Creating optimized Docker Compose configuration..."
    
    cat > "$COMPOSE_FILE" << 'EOF'
version: '3.8'

services:
  db:
    image: postgres:15-alpine
    container_name: helpboard_db
    restart: unless-stopped
    environment:
      POSTGRES_DB: ${PGDATABASE}
      POSTGRES_USER: ${PGUSER}
      POSTGRES_PASSWORD: ${PGPASSWORD}
      POSTGRES_INITDB_ARGS: "--encoding=UTF-8"
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./init-db.sql:/docker-entrypoint-initdb.d/init-db.sql
    ports:
      - "5432:5432"
    networks:
      - helpboard_network
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${PGUSER} -d ${PGDATABASE}"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 30s

  app:
    build:
      context: .
      dockerfile: Dockerfile.dev
    container_name: helpboard_app
    restart: unless-stopped
    environment:
      - NODE_ENV=development
      - DATABASE_URL=${DATABASE_URL}
      - OPENAI_API_KEY=${OPENAI_API_KEY}
      - SESSION_SECRET=${SESSION_SECRET}
      - PORT=5000
      - PGHOST=db
      - PGPORT=5432
      - PGDATABASE=${PGDATABASE}
      - PGUSER=${PGUSER}
      - PGPASSWORD=${PGPASSWORD}
    ports:
      - "5000:5000"
    volumes:
      - .:/app
      - /app/node_modules
    networks:
      - helpboard_network
    depends_on:
      db:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:5000/api/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

  nginx:
    image: nginx:alpine
    container_name: helpboard_nginx
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
      - ./ssl:/etc/nginx/ssl:ro
      - ./certbot/www:/var/www/certbot:ro
    networks:
      - helpboard_network
    depends_on:
      - app
    healthcheck:
      test: ["CMD", "nginx", "-t"]
      interval: 30s
      timeout: 10s
      retries: 3

volumes:
  postgres_data:
    driver: local

networks:
  helpboard_network:
    driver: bridge
EOF
    
    log_success "Docker Compose configuration created"
}

# Create optimized Dockerfile for development
create_dockerfile() {
    log_step "Creating optimized Dockerfile..."
    
    cat > "Dockerfile.dev" << 'EOF'
FROM node:20-alpine

# Install system dependencies
RUN apk add --no-cache \
    bash \
    curl \
    git \
    python3 \
    make \
    g++ \
    && rm -rf /var/cache/apk/*

# Create app directory
WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies with proper permissions
RUN npm ci --only=production && \
    npm cache clean --force

# Copy application code
COPY . .

# Create non-root user
RUN addgroup -g 1001 -S nodejs && \
    adduser -S helpboard -u 1001 -G nodejs

# Set proper permissions
RUN chown -R helpboard:nodejs /app
USER helpboard

# Health check endpoint
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:5000/api/health || exit 1

# Expose port
EXPOSE 5000

# Start application
CMD ["npm", "run", "dev"]
EOF
    
    log_success "Dockerfile created"
}

# Create nginx configuration
create_nginx_config() {
    log_step "Creating nginx configuration..."
    
    cat > "nginx.conf" << 'EOF'
events {
    worker_connections 1024;
    use epoll;
    multi_accept on;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    # Logging
    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log warn;

    # Performance optimizations
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types
        text/plain
        text/css
        text/xml
        text/javascript
        application/json
        application/javascript
        application/xml+rss
        application/atom+xml;

    # Rate limiting
    limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;
    limit_req_zone $binary_remote_addr zone=widget:10m rate=30r/s;

    # Upstream for app
    upstream app {
        server app:5000;
        keepalive 32;
    }

    # HTTP server
    server {
        listen 80;
        server_name helpboard.selfany.com;

        # Allow Let's Encrypt challenges
        location /.well-known/acme-challenge/ {
            root /var/www/certbot;
            try_files $uri $uri/ =404;
        }

        # Redirect to HTTPS (except for health checks)
        location /api/health {
            proxy_pass http://app;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }

        location / {
            return 301 https://$server_name$request_uri;
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
        ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384;
        ssl_prefer_server_ciphers off;
        ssl_session_cache shared:SSL:10m;
        ssl_session_timeout 1d;

        # Security headers
        add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
        add_header X-Frame-Options DENY always;
        add_header X-Content-Type-Options nosniff always;
        add_header X-XSS-Protection "1; mode=block" always;
        add_header Referrer-Policy "strict-origin-when-cross-origin" always;

        # Main application
        location / {
            proxy_pass http://app;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto https;
            proxy_set_header X-Forwarded-Port 443;
            proxy_set_header Connection "";
            proxy_http_version 1.1;
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
            
            # CORS headers for widget
            add_header Access-Control-Allow-Origin *;
            add_header Access-Control-Allow-Methods "GET, OPTIONS";
            add_header Access-Control-Allow-Headers "Content-Type";
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
    
    log_success "Nginx configuration created"
}

# Create database initialization script
create_db_init() {
    log_step "Creating database initialization script..."
    
    cat > "init-db.sql" << 'EOF'
-- Create database if not exists
SELECT 'CREATE DATABASE helpboard_db'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'helpboard_db')\gexec

-- Grant permissions
GRANT ALL PRIVILEGES ON DATABASE helpboard_db TO helpboard_user;
EOF
    
    log_success "Database initialization script created"
}

# Generate SSL certificates
generate_ssl_certificates() {
    log_step "Generating SSL certificates..."
    
    mkdir -p ssl certbot/www certbot/conf
    
    # Get server IP and check DNS
    local server_ip=$(curl -s ipinfo.io/ip)
    local domain_ip=$(dig +short $DOMAIN | tail -n1)
    
    log_info "Server IP: $server_ip"
    log_info "Domain resolves to: $domain_ip"
    
    if [ "$server_ip" = "$domain_ip" ] && [ "$server_ip" != "" ]; then
        log_info "DNS is correct, attempting Let's Encrypt..."
        
        # Start temporary nginx for Let's Encrypt challenge
        docker run --rm -d \
            --name temp_nginx \
            -p 80:80 \
            -v "$(pwd)/certbot/www:/var/www/certbot" \
            nginx:alpine \
            sh -c 'echo "server { listen 80; location /.well-known/acme-challenge/ { root /var/www/certbot; } }" > /etc/nginx/conf.d/default.conf && nginx -g "daemon off;"'
        
        sleep 5
        
        # Try Let's Encrypt
        if docker run --rm \
            -v "$(pwd)/certbot/conf:/etc/letsencrypt" \
            -v "$(pwd)/certbot/www:/var/www/certbot" \
            certbot/certbot certonly \
            --webroot \
            --webroot-path=/var/www/certbot \
            --email "admin@helpboard.selfany.com" \
            --agree-tos \
            --no-eff-email \
            --non-interactive \
            --expand \
            -d "$DOMAIN"; then
            
            # Stop temporary nginx
            docker stop temp_nginx 2>/dev/null || true
            
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
            docker stop temp_nginx 2>/dev/null || true
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

# Build and deploy application
deploy_application() {
    log_step "Building and deploying application..."
    
    # Build and start services in correct order
    log_info "Starting database..."
    docker compose -f "$COMPOSE_FILE" up -d db
    
    # Wait for database to be ready
    log_info "Waiting for database to be ready..."
    for i in {1..30}; do
        if docker compose -f "$COMPOSE_FILE" exec db pg_isready -U "$PGUSER" -d "$PGDATABASE" > /dev/null 2>&1; then
            log_success "Database is ready"
            break
        fi
        if [ $i -eq 30 ]; then
            log_error "Database failed to start"
            docker compose -f "$COMPOSE_FILE" logs db
            exit 1
        fi
        log_info "Waiting for database... ($i/30)"
        sleep 2
    done
    
    # Start application
    log_info "Starting application..."
    docker compose -f "$COMPOSE_FILE" up -d app
    
    # Wait for application to be ready
    log_info "Waiting for application to be ready..."
    for i in {1..30}; do
        if curl -f http://localhost:5000/api/health > /dev/null 2>&1; then
            log_success "Application is ready"
            break
        fi
        if [ $i -eq 30 ]; then
            log_error "Application failed to start"
            docker compose -f "$COMPOSE_FILE" logs app
            exit 1
        fi
        log_info "Waiting for application... ($i/30)"
        sleep 2
    done
    
    # Run database migration
    log_info "Running database migration..."
    docker compose -f "$COMPOSE_FILE" exec app npm run db:push
    
    # Start nginx
    log_info "Starting nginx..."
    docker compose -f "$COMPOSE_FILE" up -d nginx
    
    log_success "Application deployed successfully"
}

# Test deployment
test_deployment() {
    log_step "Testing deployment..."
    
    # Test HTTP access
    if curl -f "http://$DOMAIN/api/health" > /dev/null 2>&1; then
        log_success "HTTP health check passed"
    else
        log_error "HTTP health check failed"
    fi
    
    # Test HTTPS access
    if curl -k -f "https://$DOMAIN/api/health" > /dev/null 2>&1; then
        log_success "HTTPS health check passed"
    else
        log_error "HTTPS health check failed"
    fi
    
    # Test database connectivity
    if docker compose -f "$COMPOSE_FILE" exec app node -e "
        const { db } = require('./server/db.js');
        db.select().from('agents').limit(1).then(() => {
            console.log('Database connection successful');
            process.exit(0);
        }).catch(err => {
            console.error('Database connection failed:', err);
            process.exit(1);
        });
    "; then
        log_success "Database connectivity test passed"
    else
        log_error "Database connectivity test failed"
    fi
}

# Show deployment status
show_deployment_status() {
    log_step "Deployment Status:"
    echo ""
    
    # Service status
    docker compose -f "$COMPOSE_FILE" ps
    echo ""
    
    # Application URLs
    log_info "Application URLs:"
    echo "HTTP:  http://$DOMAIN"
    echo "HTTPS: https://$DOMAIN"
    echo ""
    
    # Default credentials
    log_info "Default login credentials:"
    echo "Admin: admin@helpboard.com / admin123"
    echo "Agent: agent@helpboard.com / password123"
    echo ""
    
    # Container logs location
    log_info "View logs with:"
    echo "docker compose -f $COMPOSE_FILE logs app"
    echo "docker compose -f $COMPOSE_FILE logs db"
    echo "docker compose -f $COMPOSE_FILE logs nginx"
    echo ""
    
    log_success "HelpBoard deployment completed successfully!"
}

# Main execution
main() {
    log_info "Starting HelpBoard Deployment Phase..."
    
    check_deployment_directory
    verify_env_config
    free_all_ports
    create_docker_compose
    create_dockerfile
    create_nginx_config
    create_db_init
    generate_ssl_certificates
    deploy_application
    test_deployment
    show_deployment_status
    
    log_success "Deployment phase completed!"
}

main