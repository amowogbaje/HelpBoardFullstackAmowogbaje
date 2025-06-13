# Multi-stage build for HelpBoard
FROM node:20-alpine AS base

# Install dependencies only when needed
FROM base AS deps
RUN apk add --no-cache libc6-compat python3 make g++
WORKDIR /app

# Copy package files
COPY package*.json ./

# Install all dependencies (including dev dependencies for build)
RUN npm ci

# Build the application
FROM base AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .

# Set environment variables for build
ENV NODE_ENV=production
ENV VITE_API_URL=""

# Ensure directories exist and build
RUN mkdir -p client/dist server/dist
RUN npm run build

# Verify build outputs exist
RUN ls -la && ls -la dist/ || echo "Build verification..."
RUN test -d dist/public || (echo "Frontend build failed - dist/public not found" && exit 1)
RUN test -f dist/index.js || (echo "Backend build failed - dist/index.js not found" && exit 1)

# Production image
FROM node:20-alpine AS runner
WORKDIR /app

# Create non-root user for security
RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 helpboard

# Install production dependencies
COPY --from=deps --chown=helpboard:nodejs /app/node_modules ./node_modules
COPY --from=builder --chown=helpboard:nodejs /app/dist ./dist
COPY --from=builder --chown=helpboard:nodejs /app/client/public ./client/public
COPY --from=builder --chown=helpboard:nodejs /app/package.json ./package.json
COPY --from=builder --chown=helpboard:nodejs /app/drizzle.config.ts ./drizzle.config.ts

# Install production-only packages
RUN npm install --only=production --ignore-scripts

# Set up health check script
COPY --chown=helpboard:nodejs healthcheck.js ./

# Switch to non-root user
USER helpboard

# Expose port
EXPOSE 5000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD node healthcheck.js

# Start the application
CMD ["node", "dist/index.js"]