# 502 Error Troubleshooting Guide

## Quick Fix Commands

Run these commands on your DigitalOcean droplet to diagnose and fix the 502 error:

```bash
cd /opt/helpboard

# 1. Run the debugging script
./debug-deployment.sh

# 2. If that doesn't work, try manual steps below
```

## Manual Troubleshooting Steps

### Step 1: Check Service Status
```bash
docker-compose ps
```
Expected output: All services should show "Up"

### Step 2: Check Application Health
```bash
# Test if app container responds
docker-compose exec app curl -f http://localhost:5000/api/health

# If the above fails, check app logs
docker-compose logs app
```

### Step 3: Check Nginx Configuration
```bash
# Test nginx configuration
docker-compose exec nginx nginx -t

# Check nginx logs
docker-compose logs nginx
```

### Step 4: Verify Network Connectivity
```bash
# Check if nginx can reach the app container
docker-compose exec nginx nc -zv app 5000
```

## Common Issues and Solutions

### Issue 1: Application Not Starting
**Symptoms:** App container exits immediately or shows unhealthy status

**Solution:**
```bash
# Check environment variables
cat .env

# Rebuild application
docker-compose build --no-cache app
docker-compose up -d app

# Check logs
docker-compose logs -f app
```

### Issue 2: Database Connection Error
**Symptoms:** App logs show database connection errors

**Solution:**
```bash
# Check postgres status
docker-compose exec postgres pg_isready -U helpboard -d helpboard

# If postgres is down
docker-compose up -d postgres

# Wait 30 seconds then restart app
sleep 30
docker-compose restart app
```

### Issue 3: Port Conflicts
**Symptoms:** "Address already in use" errors

**Solution:**
```bash
# Check what's using the ports
sudo netstat -tulpn | grep :5000
sudo netstat -tulpn | grep :80
sudo netstat -tulpn | grep :443

# Stop conflicting services or change ports in docker-compose.yml
```

### Issue 4: SSL Certificate Issues
**Symptoms:** HTTPS not working, SSL errors in nginx logs

**Solution:**
```bash
# Check SSL files exist
ls -la ssl/

# Recreate self-signed certificates
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout ssl/key.pem -out ssl/cert.pem \
  -subj "/C=US/ST=State/L=City/O=HelpBoard/CN=localhost"

# Restart nginx
docker-compose restart nginx
```

### Issue 5: Nginx Can't Reach App
**Symptoms:** 502 Bad Gateway specifically

**Solution:**
```bash
# Check if app is listening on correct port
docker-compose exec app netstat -tlnp | grep 5000

# Verify app service name in nginx config
grep "upstream" nginx.conf

# Check docker network
docker network ls
docker network inspect helpboard_helpboard-network
```

## Complete Reset Procedure

If all else fails, use this nuclear option:

```bash
# Stop everything
docker-compose down -v

# Remove all containers and images
docker system prune -af

# Remove volumes (WARNING: This deletes data)
docker volume prune -f

# Rebuild from scratch
docker-compose build --no-cache
docker-compose up -d
```

## Environment Configuration Check

Verify your `.env` file has these required variables:

```env
DATABASE_URL=postgresql://helpboard:your_password@postgres:5432/helpboard
POSTGRES_PASSWORD=your_password
OPENAI_API_KEY=sk-your-real-api-key
NODE_ENV=production
PORT=5000
```

## Testing Commands

After fixing issues, test with these commands:

```bash
# Test HTTP
curl -v http://localhost/api/health

# Test HTTPS
curl -v -k https://localhost/api/health

# Test from outside the server
curl -v -k https://YOUR_DROPLET_IP/api/health
```

## Get Help

If you're still experiencing issues:

1. Run the debug script: `./debug-deployment.sh`
2. Collect logs: `docker-compose logs > helpboard-logs.txt`
3. Check system resources: `htop` or `top`
4. Verify firewall: `ufw status`

## Expected Healthy Response

When everything works correctly, you should see:

```json
{
  "status": "healthy",
  "timestamp": "2024-01-01T12:00:00.000Z",
  "uptime": 123.456,
  "version": "1.0.0"
}
```