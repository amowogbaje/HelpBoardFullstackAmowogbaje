FROM node:18-alpine

# Install curl for health checks and other utilities
RUN apk add --no-cache curl

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install ALL dependencies (including dev dependencies for build)
RUN npm ci && npm cache clean --force

# Copy source code
COPY . .

# Build the application
RUN npm run build

# Remove dev dependencies after build (keep only production dependencies)
RUN npm ci --only=production && npm cache clean --force

# Create non-root user for security
RUN addgroup --system --gid 1001 nodejs && \
    adduser --system --uid 1001 helpboard

# Change ownership of app directory
RUN chown -R helpboard:nodejs /app

# Switch to non-root user
USER helpboard

# Expose port
EXPOSE 5000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD curl -f http://localhost:5000/api/health || exit 1

# Start the application
CMD ["npm", "start"]