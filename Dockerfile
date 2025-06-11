FROM node:18-alpine

# Install curl for health checks
RUN apk add --no-cache curl

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install ALL dependencies for build
RUN npm ci

# Copy source code
COPY . .

# Build the application (client + server)
RUN npm run build

# Keep ALL dependencies in production (simpler approach)
# This includes dev dependencies but ensures everything works

# Create non-root user
RUN addgroup --system --gid 1001 nodejs && \
    adduser --system --uid 1001 helpboard

# Change ownership
RUN chown -R helpboard:nodejs /app

# Switch to non-root user
USER helpboard

# Expose port
EXPOSE 5000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD curl -f http://localhost:5000/api/health || exit 1

# Use the production server that doesn't import vite
CMD ["node", "-r", "tsx/esm", "server/production.ts"]