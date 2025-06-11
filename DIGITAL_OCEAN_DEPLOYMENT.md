# HelpBoard Digital Ocean Production Deployment Guide

This guide provides step-by-step instructions for deploying HelpBoard on Digital Ocean infrastructure, addressing the specific requirements for domain `helpboard.selfany.com` and IP `161.35.58.110`.

## Quick Start for Digital Ocean

### 1. Create Digital Ocean Droplet

**Recommended Droplet Configuration:**
- **Size**: Regular (4GB RAM, 2 vCPU, 80GB SSD) - $24/month
- **Image**: Ubuntu 22.04 LTS x64
- **Region**: Choose closest to your users (e.g., NYC, SFO, LON)
- **Additional Options**: 
  - Enable monitoring
  - Add SSH keys
  - Enable backups (recommended)

### 2. Initial Server Setup

```bash
# SSH into your droplet
ssh root@161.35.58.110

# Run the automated setup script
wget https://raw.githubusercontent.com/your-repo/helpboard/main/digital-ocean-setup.sh
chmod +x digital-ocean-setup.sh
sudo ./digital-ocean-setup.sh
```

### 3. Deploy HelpBoard Application

```bash
# Navigate to application directory
cd /opt/helpboard

# Clone your repository
git clone https://github.com/your-org/helpboard.git .

# Configure environment
cp .env.example .env
nano .env
```

**Required Environment Variables for Digital Ocean:**
```env
# Database Configuration
DB_PASSWORD=your_secure_database_password_here
REDIS_PASSWORD=your_secure_redis_password_here

# OpenAI API Key
OPENAI_API_KEY=your_openai_api_key_here

# Session Security
SESSION_SECRET=your_session_secret_minimum_32_characters

# Digital Ocean Specific
CORS_ORIGIN=https://helpboard.selfany.com
TRUST_PROXY=true
NODE_ENV=production
```

### 4. SSL Certificate Setup

```bash
# Initial SSL certificate generation
./deploy.sh ssl

# Verify SSL installation
openssl s_client -connect helpboard.selfany.com:443 -servername helpboard.selfany.com
```

### 5. Deploy Application

```bash
# Run initial deployment
./deploy.sh init

# Verify deployment
./verify-deployment.sh
```

## Digital Ocean Specific Optimizations

### Firewall Configuration

Digital Ocean droplets come with a built-in firewall. Configure it properly:

```bash
# Configure UFW (Uncomplicated Firewall)
sudo ufw status
sudo ufw allow ssh
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable
```

### DNS Configuration

Configure your domain's DNS records:

```
Type    Name                      Value           TTL
A       helpboard.selfany.com     161.35.58.110   3600
A       www.helpboard.selfany.com 161.35.58.110   3600
CNAME   *.helpboard.selfany.com   helpboard.selfany.com   3600
```

### Digital Ocean Volumes (Optional)

For larger deployments, consider using Digital Ocean volumes:

```bash
# Create and attach a volume
doctl compute volume create helpboard-data --size 50GiB --region nyc1

# Mount the volume
sudo mkdir /mnt/helpboard-data
sudo mount -o discard,defaults /dev/disk/by-id/scsi-0DO_Volume_helpboard-data /mnt/helpboard-data
```

## Troubleshooting Digital Ocean Issues

### Common Port Issues

**Problem**: Ports 80/443 not accessible
```bash
# Check if ports are open
sudo ss -tlnp | grep -E ':80|:443'

# Check UFW status
sudo ufw status verbose

# Check if nginx is running
docker-compose -f docker-compose.prod.yml ps nginx
```

### Domain Resolution Issues

**Problem**: Domain not resolving to correct IP
```bash
# Test DNS resolution
dig helpboard.selfany.com
nslookup helpboard.selfany.com

# Test from different locations
curl -H "Host: helpboard.selfany.com" http://161.35.58.110/health
```

### SSL Certificate Issues

**Problem**: SSL certificate not working
```bash
# Check certificate files
ls -la ssl/

# Test SSL connection
openssl s_client -connect helpboard.selfany.com:443 -servername helpboard.selfany.com

# Regenerate certificates
rm -rf ssl/* certbot/*
./deploy.sh ssl
```

### Memory and Performance Issues

**Problem**: Application running out of memory
```bash
# Check memory usage
free -h
docker stats

# Enable swap if needed
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

### Database Connection Issues

**Problem**: Database connection failures
```bash
# Check database status
docker-compose -f docker-compose.prod.yml exec db pg_isready -U helpboard_user -d helpboard

# Check database logs
docker-compose -f docker-compose.prod.yml logs db

# Reset database if needed
docker-compose -f docker-compose.prod.yml down -v
docker volume rm helpboard_postgres_data
./deploy.sh init
```

## Digital Ocean Monitoring

### Enable Digital Ocean Monitoring

```bash
# Install monitoring agent
curl -sSL https://repos.insights.digitalocean.com/install.sh | sudo bash

# Configure monitoring
sudo systemctl enable do-agent
sudo systemctl start do-agent
```

### Custom Monitoring Setup

```bash
# Deploy monitoring stack
docker-compose -f monitoring.yml up -d

# Access monitoring
# Prometheus: http://161.35.58.110:9090
# Grafana: http://161.35.58.110:3000 (admin/admin123)
```

## Backup Strategy for Digital Ocean

### Database Backups

```bash
# Manual backup
./deploy.sh backup

# Automated backups with cron
echo "0 2 * * * cd /opt/helpboard && ./deploy.sh backup" | crontab -
```

### Volume Snapshots

```bash
# Create droplet snapshot
doctl compute droplet-action snapshot 161.35.58.110 --snapshot-name "helpboard-$(date +%Y%m%d)"

# Create volume snapshot
doctl compute volume-action snapshot helpboard-data --snapshot-name "helpboard-data-$(date +%Y%m%d)"
```

## Load Balancing and Scaling

### Digital Ocean Load Balancer

For high availability, consider using Digital Ocean's Load Balancer:

```bash
# Create load balancer
doctl compute load-balancer create \
  --name helpboard-lb \
  --forwarding-rules entry_protocol:https,entry_port:443,target_protocol:http,target_port:80 \
  --health-check protocol:http,port:80,path:/health \
  --region nyc1 \
  --droplet-ids 161.35.58.110
```

### Horizontal Scaling

```bash
# Scale application containers
docker-compose -f docker-compose.prod.yml up -d --scale app=3
```

## Security Best Practices for Digital Ocean

### Fail2Ban Configuration

```bash
# Check fail2ban status
sudo fail2ban-client status

# View banned IPs
sudo fail2ban-client status sshd
```

### Regular Security Updates

```bash
# Check for security updates
sudo apt list --upgradable

# Apply security updates
sudo unattended-upgrades -d
```

### Firewall Rules

```bash
# Review firewall rules
sudo ufw status numbered

# Block specific IP
sudo ufw deny from 192.168.1.100

# Limit SSH connections
sudo ufw limit ssh
```

## Performance Optimization

### Digital Ocean Droplet Optimization

```bash
# Check current performance
htop
iotop
nethogs

# Optimize kernel parameters
sudo sysctl -w net.core.rmem_max=16777216
sudo sysctl -w net.core.wmem_max=16777216
sudo sysctl -w net.ipv4.tcp_congestion_control=bbr
```

### Database Performance

```bash
# Monitor database performance
docker-compose -f docker-compose.prod.yml exec db psql -U helpboard_user helpboard -c "
SELECT 
  query,
  calls,
  total_time,
  mean_time,
  rows
FROM pg_stat_statements
ORDER BY mean_time DESC
LIMIT 10;"
```

## Maintenance Procedures

### Regular Maintenance Tasks

```bash
# Weekly maintenance script
cat > /opt/helpboard/weekly-maintenance.sh << 'EOF'
#!/bin/bash
cd /opt/helpboard

# Update system packages
sudo apt update && sudo apt upgrade -y

# Clean Docker resources
docker system prune -f

# Backup database
./deploy.sh backup

# Check SSL certificate expiry
openssl x509 -in ssl/fullchain.pem -noout -enddate

# Check disk usage
df -h

# Check logs for errors
docker-compose -f docker-compose.prod.yml logs --tail=100 app | grep -i error
EOF

chmod +x /opt/helpboard/weekly-maintenance.sh

# Schedule weekly maintenance
echo "0 3 * * 0 /opt/helpboard/weekly-maintenance.sh" | crontab -
```

### Emergency Procedures

```bash
# Emergency stop
docker-compose -f docker-compose.prod.yml down

# Emergency rollback
./deploy.sh rollback

# Emergency restart
docker-compose -f docker-compose.prod.yml restart

# Emergency logs
docker-compose -f docker-compose.prod.yml logs -f
```

## Cost Optimization

### Right-sizing Your Droplet

- **Development**: Basic (1GB RAM, 1 vCPU) - $6/month
- **Staging**: Regular (2GB RAM, 1 vCPU) - $12/month  
- **Production**: Regular (4GB RAM, 2 vCPU) - $24/month
- **High Traffic**: CPU-Optimized (8GB RAM, 4 vCPU) - $48/month

### Resource Monitoring

```bash
# Monitor resource usage over time
docker stats --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}"

# Check if you need more resources
if [[ $(free -m | awk '/^Mem:/{print $2}') -lt 1024 ]]; then
  echo "Consider upgrading droplet size"
fi
```

## Support and Troubleshooting

### Log Collection

```bash
# Collect all relevant logs
mkdir -p /tmp/helpboard-logs
docker-compose -f docker-compose.prod.yml logs > /tmp/helpboard-logs/docker-logs.txt
sudo dmesg > /tmp/helpboard-logs/kernel-logs.txt
sudo journalctl -u docker > /tmp/helpboard-logs/docker-service.txt
tar -czf helpboard-logs-$(date +%Y%m%d).tar.gz /tmp/helpboard-logs/
```

### Health Check Commands

```bash
# Quick health check
curl -s https://helpboard.selfany.com/health | jq .

# Comprehensive verification
./verify-deployment.sh all

# Service status
systemctl status docker
docker-compose -f docker-compose.prod.yml ps
```

This guide provides comprehensive coverage for deploying HelpBoard on Digital Ocean infrastructure with all the specific requirements addressed.