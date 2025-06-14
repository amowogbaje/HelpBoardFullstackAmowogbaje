# HelpBoard Digital Ocean Deployment Guide

## Two-Phase Deployment Process

This guide provides a comprehensive, bulletproof deployment process for HelpBoard on Digital Ocean droplets, addressing all common issues including port conflicts, SSL problems, database connectivity, and HSTS errors.

## Phase 1: Setup

### Prerequisites
- Digital Ocean droplet (minimum 2GB RAM, 1 vCPU)
- Domain `helpboard.selfany.com` pointing to droplet IP
- Root access to droplet
- OpenAI API key

### Step 1: Download Files
Upload all HelpBoard files to your droplet at `/opt/helpboard/` or clone from repository.

### Step 2: Run Setup Phase
```bash
ssh root@your-droplet-ip
cd /opt/helpboard
chmod +x setup-phase.sh
./setup-phase.sh
```

### What Setup Does:
- ✅ Cleans any previous installations completely
- ✅ Installs Docker and Docker Compose (latest versions)
- ✅ Configures firewall (ports 22, 80, 443)
- ✅ Generates secure passwords automatically
- ✅ Creates `.env` template with security configurations
- ✅ Frees all required ports (80, 443, 5000, 5432)
- ✅ Verifies Digital Ocean environment

### Step 3: Configure Environment
Edit the `.env` file to add your OpenAI API key:
```bash
nano /opt/helpboard/.env
```

Update this line:
```
OPENAI_API_KEY=your_actual_openai_api_key_here
```

**Important**: Do not proceed to Phase 2 until this is configured!

## Phase 2: Deployment

### Step 1: Run Deployment Phase
```bash
cd /opt/helpboard
./deployment-phase.sh
```

### What Deployment Does:
- ✅ Validates `.env` configuration
- ✅ Ensures all ports are completely free
- ✅ Creates optimized Docker Compose configuration
- ✅ Builds application with proper health checks
- ✅ Generates SSL certificates (Let's Encrypt or self-signed)
- ✅ Deploys database with proper initialization
- ✅ Starts application with database migration
- ✅ Configures nginx with rate limiting and security headers
- ✅ Tests all components thoroughly
- ✅ Provides comprehensive status report

## Expected Results

After successful deployment:

### Application Access
- **HTTP**: http://helpboard.selfany.com (redirects to HTTPS)
- **HTTPS**: https://helpboard.selfany.com (main application)

### Default Credentials
- **Admin**: admin@helpboard.com / admin123
- **Agent**: agent@helpboard.com / password123

### Container Status
All containers should be running:
- `helpboard_db` (PostgreSQL)
- `helpboard_app` (Node.js application)
- `helpboard_nginx` (Reverse proxy)

## Troubleshooting

### If HSTS Errors Persist
Clear browser HSTS cache:
- **Chrome**: chrome://net-internals/#hsts → Delete domain
- **Firefox**: Use private browsing mode
- **Safari**: Clear website data for domain

### View Application Logs
```bash
cd /opt/helpboard
docker compose -f docker-compose.dev.yml logs app
docker compose -f docker-compose.dev.yml logs db
docker compose -f docker-compose.dev.yml logs nginx
```

### Restart Services
```bash
cd /opt/helpboard
docker compose -f docker-compose.dev.yml restart
```

### Check Service Status
```bash
cd /opt/helpboard
docker compose -f docker-compose.dev.yml ps
```

## Security Features

### SSL/HTTPS
- Automatic Let's Encrypt certificate generation
- Self-signed fallback if Let's Encrypt fails
- Strong cipher suites and TLS 1.2+
- HSTS headers for security

### Database Security
- Randomly generated secure passwords
- Database user with limited privileges
- Network isolation within Docker

### Application Security
- Rate limiting on API endpoints
- Security headers (XSS, clickjacking protection)
- CORS configuration for widget embedding

## Monitoring

### Health Checks
- Application: http://helpboard.selfany.com/api/health
- Database: Built-in PostgreSQL health monitoring
- Nginx: Configuration validation

### Resource Monitoring
```bash
docker stats
htop
df -h
```

## Maintenance

### Update Application
```bash
cd /opt/helpboard
git pull origin main
docker compose -f docker-compose.dev.yml restart app
```

### Backup Database
```bash
docker compose -f docker-compose.dev.yml exec db pg_dump -U helpboard_user helpboard_db > backup.sql
```

### SSL Certificate Renewal
Certificates auto-renew. Manual renewal:
```bash
docker run --rm -v "$(pwd)/certbot/conf:/etc/letsencrypt" -v "$(pwd)/certbot/www:/var/www/certbot" certbot/certbot renew
docker compose -f docker-compose.dev.yml restart nginx
```

This deployment process has been tested and addresses all common Digital Ocean deployment issues including port conflicts, SSL configuration, database connectivity, and browser HSTS cache problems.