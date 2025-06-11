# HelpBoard Deployment Guide for DigitalOcean

## Prerequisites

1. **DigitalOcean Droplet** (minimum 2GB RAM, 1 vCPU)
2. **Domain name** pointed to your droplet IP
3. **SSH access** to your droplet

## Step 1: Initial Server Setup

```bash
# Connect to your droplet
ssh root@YOUR_DROPLET_IP

# Update system
apt update && apt upgrade -y

# Install Docker and Docker Compose
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
apt install docker-compose-plugin -y

# Install curl and other utilities
apt install curl git nginx certbot python3-certbot-nginx -y

# Create application directory
mkdir -p /opt/helpboard
cd /opt/helpboard
```

## Step 2: Clone and Setup Application

```bash
# Clone your repository (replace with your actual repo)
git clone https://github.com/YOUR_USERNAME/helpboard.git .

# Or upload files manually if no git repository
# scp -r ./* root@YOUR_DROPLET_IP:/opt/helpboard/
```

## Step 3: Environment Configuration

```bash
# Create environment file
cat > .env << 'EOF'
NODE_ENV=production
PORT=5000
DATABASE_URL=postgresql://helpboard:helpboard123@postgres:5432/helpboard
POSTGRES_DB=helpboard
POSTGRES_USER=helpboard
POSTGRES_PASSWORD=helpboard123
OPENAI_API_KEY=your_openai_api_key_here
EOF

# Set proper permissions
chmod 600 .env
```

## Step 4: SSL Certificate Setup

```bash
# Get SSL certificate (replace example.com with your domain)
certbot --nginx -d yourdomain.com

# Or use self-signed for testing
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/ssl/private/helpboard.key \
  -out /etc/ssl/certs/helpboard.crt \
  -subj "/C=US/ST=State/L=City/O=Organization/CN=yourdomain.com"
```

## Step 5: Deploy Application

```bash
# Build and start services
docker compose build --no-cache
docker compose up -d postgres

# Wait for database to initialize
sleep 20

# Start application
docker compose up -d app

# Wait for application to start
sleep 30

# Start nginx
docker compose up -d nginx

# Check status
docker compose ps
```

## Step 6: Verify Deployment

```bash
# Test health endpoint
curl -f http://localhost:5000/api/health

# Test through nginx (HTTP)
curl -f http://localhost/api/health

# Test HTTPS (if SSL configured)
curl -f https://yourdomain.com/api/health
```

## Step 7: Configure Firewall

```bash
# Allow necessary ports
ufw allow 22/tcp    # SSH
ufw allow 80/tcp    # HTTP
ufw allow 443/tcp   # HTTPS
ufw --force enable
```

## Troubleshooting

### If containers fail to start:

```bash
# Check logs
docker compose logs postgres
docker compose logs app
docker compose logs nginx

# Restart services
docker compose restart
```

### If SSL issues persist:

```bash
# Use HTTP first to verify application works
curl http://YOUR_DROPLET_IP/api/health

# Check nginx configuration
nginx -t
systemctl status nginx
```

### If database connection fails:

```bash
# Check database logs
docker compose logs postgres

# Connect to database manually
docker compose exec postgres psql -U helpboard -d helpboard
```

## Quick Deployment Script

Save this as `deploy.sh` and run `chmod +x deploy.sh && ./deploy.sh`:

```bash
#!/bin/bash
set -e

echo "🚀 Deploying HelpBoard..."

# Stop existing containers
docker compose down --remove-orphans 2>/dev/null || true

# Build and deploy
docker compose build --no-cache app
docker compose up -d postgres
sleep 20
docker compose up -d app
sleep 30
docker compose up -d nginx

# Test deployment
if curl -f http://localhost/api/health >/dev/null 2>&1; then
    echo "✅ Deployment successful!"
    echo "🌐 Application running at: https://$(curl -s ifconfig.me)"
else
    echo "❌ Deployment failed. Check logs:"
    docker compose logs app | tail -20
fi

docker compose ps
```

## Production Features

Your HelpBoard deployment includes:

- **AI-Powered Support**: 90% automated customer support with intelligent agent takeover
- **Real-time Communication**: WebSocket-based live chat
- **Embeddable Widget**: Can be embedded on any website
- **Admin Dashboard**: Complete agent management interface
- **AI Training Center**: Multiple training methods (file upload, FAQ, knowledge base)
- **Customer Analytics**: Comprehensive tracking and reporting
- **Scalable Architecture**: Docker-based deployment ready for scaling

## Performance Optimization

For production use:

1. **Use a managed database** (DigitalOcean Managed PostgreSQL)
2. **Set up load balancing** for multiple app containers
3. **Configure CDN** for static assets
4. **Enable database connection pooling**
5. **Set up monitoring** with health checks

## Support

If you encounter issues:

1. Check container logs: `docker compose logs [service]`
2. Verify network connectivity: `curl http://localhost:5000/api/health`
3. Check SSL certificates: `openssl s_client -connect yourdomain.com:443`
4. Review nginx configuration: `nginx -t`

Your HelpBoard platform is now ready for production use!