# HelpBoard Digital Ocean Production Deployment Guide

This guide provides step-by-step instructions for deploying HelpBoard on Digital Ocean infrastructure, addressing the specific requirements for domain `helpboard.selfany.com` and IP `67.205.138.68`.

## Quick Start for Digital Ocean

### 1. Prerequisites Checklist

Before starting deployment, ensure:
- [ ] Digital Ocean droplet created (Ubuntu 22.04 LTS)
- [ ] DNS A record: `helpboard.selfany.com` → `67.205.138.68`
- [ ] SSH access to droplet configured
- [ ] Required API keys available (OpenAI, etc.)

**Recommended Droplet Configuration:**
- **Size**: Regular (4GB RAM, 2 vCPU, 80GB SSD) - $24/month
- **Image**: Ubuntu 22.04 LTS x64
- **Region**: Choose closest to your users (e.g., NYC, SFO, LON)
- **IP**: 67.205.138.68 (your assigned IP)
- **Additional Options**: 
  - Enable monitoring
  - Add SSH keys
  - Enable backups (recommended)

### 2. Complete Server Setup

```bash
# SSH into your droplet
ssh root@67.205.138.68

# Download and run the complete setup script
wget https://raw.githubusercontent.com/amowogbaje/HelpBoardFullstackAmowogbaje/main/complete-setup.sh
chmod +x complete-setup.sh
sudo ./complete-setup.sh
```

This script will:
- Install Node.js 20 LTS and npm
- Install Docker and Docker Compose
- Configure firewall and security settings
- Set up the application directory structure
- Clone repository files correctly
- Install application dependencies
- Test the build process
- Generate secure environment configuration

### 3. Configure and Deploy

After the setup script completes, configure your application:

```bash
# Navigate to application directory (created by setup script)
cd /opt/helpboard

# Edit environment configuration
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
DOMAIN=helpboard.selfany.com
```

### 4. Development Mode Deployment (Recommended)

Use the development mode deployment to avoid Vite build complexities:

```bash
# Make script executable
chmod +x deploy-dev.sh

# Run complete deployment in development mode
./deploy-dev.sh deploy
```

**Why Development Mode is Better:**
- Eliminates complex Vite build issues
- Faster deployment and restart times
- Hot reload capability for updates
- Better error visibility and debugging
- No build cache conflicts

This script will:
- Check DNS configuration for helpboard.selfany.com
- Set up SSL certificates specifically for single domain
- Deploy application in development mode (more reliable)
- Verify deployment health

### 5. SSL Troubleshooting (If Issues Occur)

If SSL certificate generation fails, use the troubleshooting tools:

```bash
# Run SSL diagnostics
chmod +x ssl-troubleshoot.sh
sudo ./ssl-troubleshoot.sh check

# Attempt automatic fixes
sudo ./ssl-troubleshoot.sh fix

# Manual SSL retry after fixes
sudo ./deploy-single-domain.sh ssl

# Check final status
sudo ./deploy-single-domain.sh status
```

**Quick SSL Issue Resolution:**
1. **DNS Problems**: Verify `dig helpboard.selfany.com` returns `67.205.138.68`
2. **Firewall Issues**: Ensure ports 80/443 are open with `sudo ufw status`
3. **Rate Limits**: Wait 1 hour if Let's Encrypt rate limited
4. **Certificate Conflicts**: Clean with `sudo ./ssl-troubleshoot.sh clean`

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

Configure your domain's DNS records (single domain setup):

```
Type    Name                      Value           TTL
A       helpboard.selfany.com     67.205.138.68   3600
```

**Note**: No www subdomain is configured. All traffic will use the single domain `helpboard.selfany.com`.

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
curl -H "Host: helpboard.selfany.com" http://67.205.138.68/health
```

### SSL Certificate Issues

**Problem**: SSL certificate not working
```bash
# Check certificate files
ls -la ssl/

# Test SSL connection
openssl s_client -connect helpboard.selfany.com:443 -servername helpboard.selfany.com

# Check DNS resolution
dig helpboard.selfany.com
nslookup helpboard.selfany.com

# Debug SSL generation
sudo ./deploy-single-domain.sh ssl

# If still failing, check Let's Encrypt rate limits
curl -s "https://crt.sh/?q=helpboard.selfany.com&output=json" | jq '.[0:5]'

# Clean regeneration
rm -rf ssl/* certbot/*
sudo ./deploy-single-domain.sh ssl
```

**Common SSL Issues and Solutions:**
1. **Rate Limiting**: Let's Encrypt has rate limits (5 failures per hour)
   ```bash
   # Wait 1 hour or use staging environment first
   # Check rate limit status at: https://letsencrypt.org/docs/rate-limits/
   ```

2. **DNS Propagation**: Domain not resolving correctly
   ```bash
   # Wait for DNS propagation (up to 48 hours)
   # Test from different locations: https://dnschecker.org/
   ```

3. **Firewall Issues**: Port 80 blocked
   ```bash
   sudo ufw status
   sudo ufw allow 80/tcp
   sudo systemctl restart ufw
   ```

4. **Domain Configuration**: Wrong domain in certbot
   ```bash
   # Ensure only helpboard.selfany.com is used, no www subdomain
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
# Prometheus: http://67.205.138.68:9090
# Grafana: http://67.205.138.68:3000 (admin/admin123)
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
doctl compute droplet-action snapshot 67.205.138.68 --snapshot-name "helpboard-$(date +%Y%m%d)"

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
  --droplet-ids 67.205.138.68
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