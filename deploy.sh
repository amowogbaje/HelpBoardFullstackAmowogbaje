#!/bin/bash

# HelpBoard Deployment Script for DigitalOcean
# This script automates the deployment process

set -e

echo "🚀 Starting HelpBoard deployment..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# Build and start services
deploy() {
    echo "🔨 Building Docker images..."
    docker-compose build --no-cache
    
    echo "🗄️ Setting up database..."
    docker-compose up -d postgres
    sleep 10
    
    echo "🚀 Starting all services..."
    docker-compose up -d
    
    echo "⏳ Waiting for services to be ready..."
    sleep 30
    
    # Check if services are running
    if docker-compose ps | grep -q "Up"; then
        echo -e "${GREEN}✅ Deployment successful!${NC}"
        echo "🌐 Your HelpBoard application is now running"
        echo "📊 Access the dashboard at: https://your-domain.com"
        echo "🔧 Check logs with: docker-compose logs -f"
    else
        echo -e "${RED}❌ Deployment failed. Check logs with: docker-compose logs${NC}"
        exit 1
    fi
}

# Main execution
check_files
deploy