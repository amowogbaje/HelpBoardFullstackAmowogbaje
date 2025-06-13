# HelpBoard Docker Deployment Guide

This comprehensive guide covers Docker-based deployment for HelpBoard, addressing common production issues including dependency mismatches, port conflicts, SSL configuration, and domain setup.

## Table of Contents

1. [Pre-deployment Setup](#pre-deployment-setup)
2. [Development vs Production Dependencies](#development-vs-production-dependencies)
3. [Port and Network Configuration](#port-and-network-configuration)
4. [Domain and SSL Setup](#domain-and-ssl-setup)
5. [Deployment Steps](#deployment-steps)
6. [Troubleshooting](#troubleshooting)
7. [Monitoring and Maintenance](#monitoring-and-maintenance)

## Pre-deployment Setup

### System Requirements

**Digital Ocean Droplet Specifications:**
- Minimum: 2GB RAM, 1 vCPU, 50GB SSD (Basic Droplet)
- Recommended: 4GB RAM, 2 vCPU, 80GB SSD (Regular Droplet)
- OS: Ubuntu 22.04 LTS (recommended for Digital Ocean)
- Docker Engine 20.10+
- Docker Compose 2.0+

### Digital Ocean Droplet Setup

**Automated Setup (Recommended):**
```bash
# Download and run the Digital Ocean setup script
wget https://raw.githubusercontent.com/your-repo/helpboard/main/digital-ocean-setup.sh
chmod +x digital-ocean-setup.sh
sudo ./digital-ocean-setup.sh
```

**Manual Setup:**
```bash
# Update system packages
sudo apt update && sudo apt upgrade -y

# Install essential packages
sudo apt install -y curl wget gnupg2 software-properties-common apt-transport-https ca-certificates lsb-release ufw fail2ban

# Install Docker (Digital Ocean optimized)
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Configure Digital Ocean firewall
sudo ufw --force reset
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw --force enable

# Add user to docker group
sudo usermod -aG docker $USER
newgrp docker
```

## Development vs Production Dependencies

### Dependency Resolution Strategy

The multi-stage Dockerfile ensures consistent dependencies:

```dockerfile
# Development dependencies (build only)
FROM base AS build-deps
RUN npm ci --ignore-scripts

# Production dependencies (runtime)
FROM base AS deps
RUN npm ci --only=production --ignore-scripts
```

### Package Lock Management

```bash
# Ensure consistent package versions
npm ci --frozen-lockfile

# For production builds
npm ci --only=production --ignore-scripts
```

### Environment-Specific Configuration

**Development (.env.dev):**
```env
NODE_ENV=development
DATABASE_URL=postgresql://helpboard_user:dev_password@localhost:5432/helpboard_dev
CORS_ORIGIN=http://localhost:3000,http://localhost:5000
```

**Production (.env.prod):**
```env
NODE_ENV=production
DATABASE_URL=postgresql://helpboard_user:secure_password@db:5432/helpboard
CORS_ORIGIN=https://helpboard.selfany.com
TRUST_PROXY=true
```

## Port and Network Configuration

### Port Mapping Strategy

| Service | Internal Port | External Port | Purpose |
|---------|---------------|---------------|---------|
| Nginx | 80, 443 | 80, 443 | HTTP/HTTPS traffic |
| App | 5000 | - | Internal only (via Nginx) |
| PostgreSQL | 5432 | 5432* | Database (expose for dev only) |
| Redis | 6379 | - | Internal only |

*Remove PostgreSQL port exposure in production for security.

### Network Isolation

```yaml
networks:
  helpboard_network:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/16
```

### Firewall Configuration

```bash
# Production firewall rules
sudo ufw --force reset
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable
```

## Domain and SSL Setup

### DNS Configuration

Configure A records for your domain:

```
Type    Name                    Value
A       helpboard.selfany.com   67.205.138.68
```

### SSL Certificate Setup with Let's Encrypt

#### Step 1: Initial Certificate Generation

```bash
# Create directories
mkdir -p ssl certbot/www certbot/conf

# Run certbot for initial certificate
docker-compose -f docker-compose.prod.yml --profile ssl-setup up certbot

# Verify certificate generation
ls -la certbot/conf/live/helpboard.selfany.com/
```

#### Step 2: Copy Certificates to SSL Directory

```bash
# Copy certificates to nginx ssl directory
sudo cp certbot/conf/live/helpboard.selfany.com/fullchain.pem ssl/
sudo cp certbot/conf/live/helpboard.selfany.com/privkey.pem ssl/
sudo chmod 600 ssl/privkey.pem
```

#### Step 3: Auto-renewal Setup

```bash
# Create renewal script
cat > renew-ssl.sh << 'EOF'
#!/bin/bash
docker-compose -f docker-compose.prod.yml run --rm certbot renew
if [ $? -eq 0 ]; then
    cp certbot/conf/live/helpboard.selfany.com/fullchain.pem ssl/
    cp certbot/conf/live/helpboard.selfany.com/privkey.pem ssl/
    docker-compose -f docker-compose.prod.yml restart nginx
fi
EOF

chmod +x renew-ssl.sh

# Add to crontab for auto-renewal
echo "0 3 * * * /path/to/your/app/renew-ssl.sh" | crontab -
```

## Deployment Steps

### Step 1: Environment Setup

```bash
# Clone repository
git clone https://github.com/amowogbaje/HelpBoardFullstackAmowogbaje.git
cd helpboard

# Create environment file
cp .env.example .env

# Edit environment variables
nano .env
```

Required environment variables:
```env
DB_PASSWORD=your_secure_db_password_here
REDIS_PASSWORD=your_secure_redis_password_here
OPENAI_API_KEY=your_openai_api_key_here
SESSION_SECRET=your_session_secret_32_chars_min
```

### Step 2: SSL Certificate Setup

```bash
# Setup SSL certificates (first time only)
docker-compose -f docker-compose.prod.yml --profile ssl-setup up certbot

# Copy certificates
cp certbot/conf/live/helpboard.selfany.com/fullchain.pem ssl/
cp certbot/conf/live/helpboard.selfany.com/privkey.pem ssl/
```

### Step 3: Database Migration

```bash
# Start database first
docker-compose -f docker-compose.prod.yml up -d db redis

# Wait for database to be ready
docker-compose -f docker-compose.prod.yml exec db pg_isready -U helpboard_user -d helpboard

# Run database migrations
docker-compose -f docker-compose.prod.yml run --rm app npm run db:migrate
```

### Step 4: Full Application Deployment

```bash
# Build and start all services
docker-compose -f docker-compose.prod.yml up -d

# Verify all services are healthy
docker-compose -f docker-compose.prod.yml ps
```

### Step 5: Verification

```bash
# Check service health
curl -k https://helpboard.selfany.com/health

# Check SSL certificate
openssl s_client -connect helpboard.selfany.com:443 -servername helpboard.selfany.com

# Check logs
docker-compose -f docker-compose.prod.yml logs -f app
```

## Troubleshooting

### Common Issues and Solutions

#### 1. Port 80/443 Already in Use

```bash
# Find processes using ports
sudo netstat -tlnp | grep ':80\|:443'

# Stop conflicting services
sudo systemctl stop apache2 nginx

# Or kill specific processes
sudo kill $(sudo lsof -t -i:80)
sudo kill $(sudo lsof -t -i:443)
```

#### 2. Database Connection Issues

```bash
# Check database status
docker-compose -f docker-compose.prod.yml exec db pg_isready -U helpboard_user -d helpboard

# Test connection from app container
docker-compose -f docker-compose.prod.yml exec app psql $DATABASE_URL -c "SELECT 1;"

# Reset database if needed
docker-compose -f docker-compose.prod.yml down -v
docker volume rm helpboard_postgres_data
```

#### 3. SSL Certificate Issues

```bash
# Check certificate validity
openssl x509 -in ssl/fullchain.pem -text -noout

# Regenerate certificates
docker-compose -f docker-compose.prod.yml --profile ssl-setup run --rm certbot delete --cert-name helpboard.selfany.com
docker-compose -f docker-compose.prod.yml --profile ssl-setup up certbot
```

#### 4. Memory Issues

```bash
# Check container memory usage
docker stats

# Increase swap if needed
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

#### 5. Domain Resolution Issues

```bash
# Test DNS resolution
nslookup helpboard.selfany.com
dig helpboard.selfany.com

# Check if domain points to correct IP
curl -H "Host: helpboard.selfany.com" http://67.205.138.68/health
```

### Logs and Debugging

```bash
# View application logs
docker-compose -f docker-compose.prod.yml logs -f app

# View nginx access logs
docker-compose -f docker-compose.prod.yml logs -f nginx

# View database logs
docker-compose -f docker-compose.prod.yml logs -f db

# Enter container for debugging
docker-compose -f docker-compose.prod.yml exec app sh
```

## Monitoring and Maintenance

### Health Checks

All services include health checks:

```yaml
healthcheck:
  test: ["CMD", "node", "healthcheck.js"]
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 40s
```

### Backup Strategy

#### Database Backup

```bash
# Create backup script
cat > backup-db.sh << 'EOF'
#!/bin/bash
BACKUP_DIR="/backups"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="helpboard_backup_$DATE.sql"

mkdir -p $BACKUP_DIR
docker-compose -f docker-compose.prod.yml exec -T db pg_dump -U helpboard_user helpboard > "$BACKUP_DIR/$BACKUP_FILE"
gzip "$BACKUP_DIR/$BACKUP_FILE"

# Keep only last 7 days of backups
find $BACKUP_DIR -name "helpboard_backup_*.sql.gz" -mtime +7 -delete
EOF

chmod +x backup-db.sh

# Schedule daily backups
echo "0 2 * * * /path/to/your/app/backup-db.sh" | crontab -
```

#### Volume Backup

```bash
# Backup Docker volumes
docker run --rm -v helpboard_postgres_data:/data -v $(pwd)/backups:/backup alpine tar czf /backup/postgres_data_$(date +%Y%m%d).tar.gz -C /data .
```

### Updates and Maintenance

#### Rolling Updates

```bash
# Pull latest images
docker-compose -f docker-compose.prod.yml pull

# Update services one by one
docker-compose -f docker-compose.prod.yml up -d --no-deps app
docker-compose -f docker-compose.prod.yml up -d --no-deps nginx
```

#### Automatic Updates with Watchtower

```bash
# Enable watchtower for automatic updates
docker-compose -f docker-compose.prod.yml --profile monitoring up -d watchtower
```

### Performance Monitoring

#### Resource Monitoring

```bash
# Install monitoring tools
docker run -d --name prometheus -p 9090:9090 prom/prometheus
docker run -d --name grafana -p 3000:3000 grafana/grafana
```

#### Application Metrics

```bash
# View container stats
docker stats --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}"

# Monitor logs for errors
docker-compose -f docker-compose.prod.yml logs -f app | grep -i error
```

## Security Considerations

### Production Security Checklist

- [ ] Strong passwords for all services
- [ ] Firewall configured (only ports 80, 443 open)
- [ ] SSL certificates properly configured
- [ ] Database not exposed externally
- [ ] Regular security updates
- [ ] Backup encryption
- [ ] Rate limiting configured in Nginx
- [ ] Security headers configured
- [ ] Non-root user in containers

### Security Headers

The nginx.conf includes essential security headers:

```nginx
add_header Strict-Transport-Security "max-age=63072000" always;
add_header X-Frame-Options DENY;
add_header X-Content-Type-Options nosniff;
add_header X-XSS-Protection "1; mode=block";
add_header Referrer-Policy "strict-origin-when-cross-origin";
```

### Rate Limiting

```nginx
limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;
limit_req_zone $binary_remote_addr zone=widget:10m rate=30r/s;
```

## Quick Reference Commands

### Deployment Commands

```bash
# Initial deployment
docker-compose -f docker-compose.prod.yml up -d

# Update application
docker-compose -f docker-compose.prod.yml pull app
docker-compose -f docker-compose.prod.yml up -d --no-deps app

# Restart all services
docker-compose -f docker-compose.prod.yml restart

# Stop all services
docker-compose -f docker-compose.prod.yml down

# View logs
docker-compose -f docker-compose.prod.yml logs -f

# Clean up
docker-compose -f docker-compose.prod.yml down -v
docker system prune -a
```

### Maintenance Commands

```bash
# Database backup
docker-compose -f docker-compose.prod.yml exec -T db pg_dump -U helpboard_user helpboard > backup.sql

# Database restore
docker-compose -f docker-compose.prod.yml exec -T db psql -U helpboard_user helpboard < backup.sql

# SSL renewal
./renew-ssl.sh

# Check service health
curl https://helpboard.selfany.com/health
```

This deployment guide provides a robust foundation for deploying HelpBoard in production with proper security, monitoring, and maintenance procedures.