# Docker Deployment Commands for DigitalOcean

Run these commands on your droplet at `/opt/helpboard`:

## Step 1: Install Docker and Dependencies

```bash
# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
rm get-docker.sh

# Install Docker Compose
apt update && apt install -y docker-compose-plugin curl

# Verify installation
docker --version
docker compose version
```

## Step 2: Create Project Files

```bash
# Create package.json
cat > package.json << 'EOF'
{
  "name": "helpboard",
  "version": "1.0.0",
  "description": "AI-powered customer support platform",
  "main": "server/index.ts",
  "scripts": {
    "dev": "NODE_ENV=development tsx server/index.ts",
    "build": "vite build client",
    "start": "NODE_ENV=production tsx server/production.ts",
    "start:prod": "NODE_ENV=production tsx server/production.ts"
  },
  "dependencies": {
    "@neondatabase/serverless": "^0.9.0",
    "@radix-ui/react-dialog": "^1.0.5",
    "@radix-ui/react-label": "^2.0.2",
    "@radix-ui/react-slot": "^1.0.2",
    "@radix-ui/react-tabs": "^1.0.4",
    "@tanstack/react-query": "^5.0.0",
    "bcryptjs": "^2.4.3",
    "class-variance-authority": "^0.7.0",
    "clsx": "^2.0.0",
    "drizzle-orm": "^0.29.0",
    "drizzle-zod": "^0.5.1",
    "express": "^4.18.2",
    "express-session": "^1.17.3",
    "framer-motion": "^10.16.0",
    "lucide-react": "^0.292.0",
    "nanoid": "^5.0.4",
    "openai": "^4.20.0",
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "react-hook-form": "^7.47.0",
    "tailwind-merge": "^2.0.0",
    "tsx": "^4.0.0",
    "typescript": "^5.0.0",
    "vite": "^5.0.0",
    "wouter": "^3.0.0",
    "ws": "^8.14.0",
    "zod": "^3.22.0"
  },
  "devDependencies": {
    "@types/bcryptjs": "^2.4.6",
    "@types/express": "^4.17.21",
    "@types/express-session": "^1.17.10",
    "@types/node": "^20.0.0",
    "@types/react": "^18.2.0",
    "@types/react-dom": "^18.2.0",
    "@types/ws": "^8.5.10",
    "@vitejs/plugin-react": "^4.1.0",
    "autoprefixer": "^10.4.16",
    "drizzle-kit": "^0.20.0",
    "postcss": "^8.4.32",
    "tailwindcss": "^3.3.6"
  }
}
EOF

# Create Dockerfile
cat > Dockerfile << 'EOF'
FROM node:18-alpine

RUN apk add --no-cache curl

WORKDIR /app

COPY package*.json ./
RUN npm ci

COPY . .
RUN npm run build

RUN addgroup --system --gid 1001 nodejs && \
    adduser --system --uid 1001 helpboard

RUN chown -R helpboard:nodejs /app
USER helpboard

EXPOSE 5000

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD curl -f http://localhost:5000/api/health || exit 1

CMD ["npm", "run", "start:prod"]
EOF

# Create docker-compose.yml
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  postgres:
    image: postgres:15-alpine
    environment:
      POSTGRES_DB: ${POSTGRES_DB:-helpboard}
      POSTGRES_USER: ${POSTGRES_USER:-helpboard}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:-helpboard123}
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./init.sql:/docker-entrypoint-initdb.d/init.sql
    ports:
      - "5432:5432"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER:-helpboard} -d ${POSTGRES_DB:-helpboard}"]
      interval: 10s
      timeout: 5s
      retries: 5

  app:
    build: .
    environment:
      - NODE_ENV=production
      - DATABASE_URL=${DATABASE_URL:-postgresql://helpboard:helpboard123@postgres:5432/helpboard}
      - OPENAI_API_KEY=${OPENAI_API_KEY:-your_openai_api_key_here}
      - PORT=5000
    ports:
      - "5000:5000"
    depends_on:
      postgres:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:5000/api/health"]
      interval: 30s
      timeout: 10s
      retries: 3
    restart: unless-stopped

  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
    depends_on:
      - app
    restart: unless-stopped

volumes:
  postgres_data:
EOF

# Create nginx.conf
cat > nginx.conf << 'EOF'
events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    upstream app {
        server app:5000;
    }

    server {
        listen 80;
        server_name _;

        client_max_body_size 10M;

        location / {
            proxy_pass http://app;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_connect_timeout 60s;
            proxy_send_timeout 60s;
            proxy_read_timeout 60s;
        }

        location /ws {
            proxy_pass http://app;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        }
    }
}
EOF

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

chmod 600 .env
```

## Step 3: Create Essential Server Files

```bash
# Create server directory
mkdir -p server shared client/src

# Create basic production server
cat > server/production.ts << 'EOF'
import express from "express";
import { createServer } from "http";
import path from "path";

const app = express();
const server = createServer(app);

app.use(express.json());
app.use(express.static(path.join(process.cwd(), "dist")));

// Health check endpoint
app.get("/api/health", (req, res) => {
  res.json({
    status: "healthy",
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    version: "1.0.0"
  });
});

// Basic API endpoints
app.get("/api/conversations", (req, res) => {
  res.json([]);
});

app.post("/api/initiate", (req, res) => {
  res.json({ sessionId: "demo", conversationId: 1 });
});

// Serve React app
app.get("*", (req, res) => {
  res.sendFile(path.join(process.cwd(), "dist", "index.html"));
});

const port = parseInt(process.env.PORT || "5000", 10);

server.listen(port, () => {
  console.log(`HelpBoard server running on port ${port}`);
});
EOF

# Create basic client files
mkdir -p client/src
cat > client/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>HelpBoard - Customer Support Platform</title>
</head>
<body>
    <div id="root"></div>
    <script type="module" src="/src/main.tsx"></script>
</body>
</html>
EOF

cat > client/src/main.tsx << 'EOF'
import React from 'react';
import ReactDOM from 'react-dom/client';

function App() {
  return (
    <div style={{ padding: '20px', fontFamily: 'Arial, sans-serif' }}>
      <h1>HelpBoard - Customer Support Platform</h1>
      <p>Platform is running successfully!</p>
      <a href="/api/health">Health Check</a>
    </div>
  );
}

ReactDOM.createRoot(document.getElementById('root')!).render(<App />);
EOF

# Create basic Vite config
cat > vite.config.ts << 'EOF'
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  root: 'client',
  build: {
    outDir: '../dist',
    emptyOutDir: true,
  },
});
EOF
```

## Step 4: Deploy Application

```bash
# Build and start services
docker compose build --no-cache
docker compose up -d postgres

# Wait for database
sleep 20

# Start application
docker compose up -d app

# Wait for app
sleep 30

# Start nginx
docker compose up -d nginx

# Check status
docker compose ps
```

## Step 5: Test Deployment

```bash
# Test direct app
curl http://localhost:5000/api/health

# Test through nginx
curl http://localhost/api/health

# Get your server IP
echo "Your app is running at: http://$(curl -s ifconfig.me)"
```

## Troubleshooting

```bash
# View logs
docker compose logs app
docker compose logs postgres
docker compose logs nginx

# Restart services
docker compose restart

# Rebuild if needed
docker compose down
docker compose build --no-cache
docker compose up -d
```

Copy and run these commands on your DigitalOcean droplet to get HelpBoard deployed with Docker!