#!/bin/bash

# HelpBoard Deployment Script - Fixed for Vite Issues
# This script automates the deployment process and fixes common issues

set -e

echo "🚀 Starting HelpBoard deployment (Fixed Version)..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if required files exist
check_files() {
    echo "📋 Checking required files..."
    required_files=("Dockerfile" "docker-compose.yml" ".env")
    
    for file in "${required_files[@]}"; do
        if [ ! -f "$file" ]; then
            echo -e "${RED}❌ Missing required file: $file${NC}"
            exit 1
        fi
    done
    echo -e "${GREEN}✅ All required files found${NC}"
}

# Fix environment file
fix_env() {
    echo "🔧 Checking environment configuration..."
    
    if [ ! -f ".env" ]; then
        echo "Creating .env from template..."
        cp .env.example .env
    fi
    
    # Source environment variables
    source .env
    
    if [ -z "$POSTGRES_PASSWORD" ]; then
        echo "Generating secure database password..."
        echo "POSTGRES_PASSWORD=$(openssl rand -base64 32)" >> .env
        source .env
    fi
    
    if [ -z "$OPENAI_API_KEY" ] || [ "$OPENAI_API_KEY" = "your_openai_api_key_here" ]; then
        echo -e "${YELLOW}⚠️  OPENAI_API_KEY not configured. Please edit .env file.${NC}"
    fi
    
    echo -e "${GREEN}✅ Environment configuration checked${NC}"
}

# Create SSL certificates
setup_ssl() {
    echo "🔒 Setting up SSL certificates..."
    mkdir -p ssl
    
    if [ ! -f "ssl/cert.pem" ] || [ ! -f "ssl/key.pem" ]; then
        echo "Creating self-signed SSL certificates..."
        openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
            -keyout ssl/key.pem \
            -out ssl/cert.pem \
            -subj "/C=US/ST=State/L=City/O=HelpBoard/CN=localhost" 2>/dev/null
        echo -e "${GREEN}✅ SSL certificates created${NC}"
    fi
}

# Stop existing containers
cleanup() {
    echo "🧹 Cleaning up existing containers..."
    docker-compose down --remove-orphans || true
    docker system prune -f
}

# Build and start services with proper error handling
deploy() {
    echo "🔨 Building Docker images with fixed configuration..."
    
    # Build application with verbose output
    if ! docker-compose build --no-cache app; then
        echo -e "${RED}❌ Application build failed${NC}"
        echo "Checking for common issues..."
        
        # Check if build fails due to dependencies
        echo "Building with debug output..."
        docker-compose build --no-cache --progress=plain app
        exit 1
    fi
    
    echo "🗄️ Starting PostgreSQL..."
    docker-compose up -d postgres
    
    # Wait for PostgreSQL to be ready
    echo "Waiting for PostgreSQL..."
    for i in {1..30}; do
        if docker-compose exec postgres pg_isready -U helpboard -d helpboard >/dev/null 2>&1; then
            echo -e "${GREEN}✅ PostgreSQL is ready${NC}"
            break
        fi
        sleep 2
        if [ $i -eq 30 ]; then
            echo -e "${RED}❌ PostgreSQL failed to start${NC}"
            docker-compose logs postgres
            exit 1
        fi
    done
    
    echo "🚀 Starting application..."
    docker-compose up -d app
    
    # Wait for application with detailed checking
    echo "Waiting for application..."
    for i in {1..60}; do
        if docker-compose exec app curl -f -s http://localhost:5000/api/health >/dev/null 2>&1; then
            echo -e "${GREEN}✅ Application is ready${NC}"
            break
        fi
        
        # Show app logs every 10 seconds if still failing
        if [ $((i % 10)) -eq 0 ]; then
            echo "Application logs (attempt $i/60):"
            docker-compose logs --tail=10 app
        fi
        
        sleep 2
        if [ $i -eq 60 ]; then
            echo -e "${RED}❌ Application failed to start${NC}"
            echo "Full application logs:"
            docker-compose logs app
            exit 1
        fi
    done
    
    echo "🌐 Starting Nginx..."
    docker-compose up -d nginx
    
    echo "⏳ Final system check..."
    sleep 10
    
    # Test all endpoints
    test_deployment
}

# Test deployment
test_deployment() {
    echo -e "${BLUE}🧪 Testing deployment...${NC}"
    
    # Test HTTP health check
    if curl -f -s http://localhost/api/health >/dev/null 2>&1; then
        echo -e "${GREEN}✅ HTTP health check passed${NC}"
    else
        echo -e "${RED}❌ HTTP health check failed${NC}"
        echo "Nginx logs:"
        docker-compose logs nginx | tail -10
    fi
    
    # Test HTTPS health check
    if curl -f -s -k https://localhost/api/health >/dev/null 2>&1; then
        echo -e "${GREEN}✅ HTTPS health check passed${NC}"
    else
        echo -e "${RED}❌ HTTPS health check failed${NC}"
    fi
    
    # Show final status
    echo -e "\n${BLUE}📊 Final Status:${NC}"
    docker-compose ps
    
    echo -e "\n${GREEN}✅ Deployment completed!${NC}"
    echo "🌐 Access your application at:"
    echo "   • HTTP:  http://$(curl -s ifconfig.me)/api/health"
    echo "   • HTTPS: https://$(curl -s ifconfig.me)/api/health"
    echo ""
    echo "🔧 Useful commands:"
    echo "   • View logs: docker-compose logs -f"
    echo "   • Restart: docker-compose restart"
    echo "   • Monitor: ./monitor.sh"
}

# Main execution
echo "Starting deployment process..."
check_files
fix_env
setup_ssl
cleanup
deploy