#!/bin/bash

# HelpBoard Deployment Debugging Script
# This script helps diagnose and fix 502 errors

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🔍 HelpBoard Deployment Debugger${NC}"
echo "=================================="

# Function to check service status
check_service() {
    local service=$1
    echo -e "\n${BLUE}Checking $service service...${NC}"
    
    if docker-compose ps $service | grep -q "Up"; then
        echo -e "${GREEN}✅ $service is running${NC}"
        return 0
    else
        echo -e "${RED}❌ $service is not running${NC}"
        return 1
    fi
}

# Function to test connectivity
test_connectivity() {
    local service=$1
    local port=$2
    local path=${3:-""}
    
    echo -e "\n${BLUE}Testing $service connectivity...${NC}"
    
    if docker-compose exec $service curl -f -s http://localhost:$port$path > /dev/null 2>&1; then
        echo -e "${GREEN}✅ $service responds on port $port${NC}"
        return 0
    else
        echo -e "${RED}❌ $service not responding on port $port${NC}"
        return 1
    fi
}

# Check if Docker is running
echo -e "\n${BLUE}Checking Docker status...${NC}"
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}❌ Docker is not running. Start it with: systemctl start docker${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Docker is running${NC}"

# Check if in correct directory
if [ ! -f "docker-compose.yml" ]; then
    echo -e "${RED}❌ docker-compose.yml not found. Run this script from the project directory.${NC}"
    exit 1
fi

# Check environment file
echo -e "\n${BLUE}Checking environment configuration...${NC}"
if [ ! -f ".env" ]; then
    echo -e "${RED}❌ .env file not found${NC}"
    echo "Creating .env from template..."
    cp .env.example .env
    echo -e "${YELLOW}⚠️  Please edit .env file and add your OpenAI API key${NC}"
fi

# Check required environment variables
if [ -f ".env" ]; then
    source .env
    
    if [ -z "$POSTGRES_PASSWORD" ]; then
        echo -e "${RED}❌ POSTGRES_PASSWORD not set in .env${NC}"
        echo "Generating secure password..."
        echo "POSTGRES_PASSWORD=$(openssl rand -base64 32)" >> .env
    fi
    
    if [ -z "$OPENAI_API_KEY" ] || [ "$OPENAI_API_KEY" = "your_openai_api_key_here" ]; then
        echo -e "${YELLOW}⚠️  OPENAI_API_KEY not configured in .env${NC}"
    fi
fi

# Check SSL certificates
echo -e "\n${BLUE}Checking SSL certificates...${NC}"
mkdir -p ssl
if [ ! -f "ssl/cert.pem" ] || [ ! -f "ssl/key.pem" ]; then
    echo -e "${YELLOW}⚠️  SSL certificates not found. Creating self-signed certificates...${NC}"
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout ssl/key.pem \
        -out ssl/cert.pem \
        -subj "/C=US/ST=State/L=City/O=HelpBoard/CN=localhost" 2>/dev/null
    echo -e "${GREEN}✅ Self-signed SSL certificates created${NC}"
fi

# Stop existing containers
echo -e "\n${BLUE}Stopping existing containers...${NC}"
docker-compose down --remove-orphans

# Start services one by one
echo -e "\n${BLUE}Starting PostgreSQL...${NC}"
docker-compose up -d postgres

# Wait for PostgreSQL
echo "Waiting for PostgreSQL to be ready..."
for i in {1..30}; do
    if docker-compose exec postgres pg_isready -U helpboard -d helpboard >/dev/null 2>&1; then
        echo -e "${GREEN}✅ PostgreSQL is ready${NC}"
        break
    fi
    sleep 2
    if [ $i -eq 30 ]; then
        echo -e "${RED}❌ PostgreSQL failed to start${NC}"
        echo "PostgreSQL logs:"
        docker-compose logs postgres
        exit 1
    fi
done

# Build and start application
echo -e "\n${BLUE}Building application...${NC}"
if ! docker-compose build app; then
    echo -e "${RED}❌ Application build failed${NC}"
    exit 1
fi

echo -e "\n${BLUE}Starting application...${NC}"
docker-compose up -d app

# Wait for application
echo "Waiting for application to be ready..."
for i in {1..60}; do
    if docker-compose exec app curl -f -s http://localhost:5000/api/health >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Application is ready${NC}"
        break
    fi
    sleep 2
    if [ $i -eq 60 ]; then
        echo -e "${RED}❌ Application failed to start${NC}"
        echo "Application logs:"
        docker-compose logs app
        exit 1
    fi
done

# Start Nginx
echo -e "\n${BLUE}Starting Nginx...${NC}"
docker-compose up -d nginx

# Wait for Nginx
echo "Waiting for Nginx to be ready..."
sleep 5

# Test services
echo -e "\n${BLUE}Testing service connectivity...${NC}"

# Test PostgreSQL
if check_service "postgres"; then
    docker-compose exec postgres pg_isready -U helpboard -d helpboard
fi

# Test Application
if check_service "app"; then
    test_connectivity "app" "5000" "/api/health"
fi

# Test Nginx
if check_service "nginx"; then
    echo -e "\n${BLUE}Testing Nginx proxy...${NC}"
    
    # Test HTTP
    if curl -f -s -k http://localhost/api/health >/dev/null 2>&1; then
        echo -e "${GREEN}✅ HTTP proxy working${NC}"
    else
        echo -e "${RED}❌ HTTP proxy not working${NC}"
        echo "Nginx logs:"
        docker-compose logs nginx | tail -20
    fi
    
    # Test HTTPS
    if curl -f -s -k https://localhost/api/health >/dev/null 2>&1; then
        echo -e "${GREEN}✅ HTTPS proxy working${NC}"
    else
        echo -e "${RED}❌ HTTPS proxy not working${NC}"
        echo "Nginx logs:"
        docker-compose logs nginx | tail -20
    fi
fi

# Show final status
echo -e "\n${BLUE}Final Status Check${NC}"
echo "==================="
docker-compose ps

# Test final endpoints
echo -e "\n${BLUE}Testing endpoints...${NC}"
echo "HTTP Health Check:"
curl -s -k http://localhost/api/health 2>/dev/null || echo "Failed"

echo -e "\nHTTPS Health Check:"
curl -s -k https://localhost/api/health 2>/dev/null || echo "Failed"

echo -e "\n${BLUE}Troubleshooting Commands:${NC}"
echo "========================="
echo "View all logs: docker-compose logs -f"
echo "View app logs: docker-compose logs -f app"
echo "View nginx logs: docker-compose logs -f nginx"
echo "View postgres logs: docker-compose logs -f postgres"
echo "Restart services: docker-compose restart"
echo "Rebuild app: docker-compose build --no-cache app"
echo ""
echo "If still having issues:"
echo "1. Check .env file has correct values"
echo "2. Ensure ports 80, 443, 5000, 5432 are not in use"
echo "3. Check firewall settings"
echo "4. Verify SSL certificates in ssl/ directory"