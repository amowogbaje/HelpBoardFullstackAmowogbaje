# Multi-stage build for HelpBoard
FROM node:20-alpine AS base

# Install dependencies only when needed
FROM base AS deps
RUN apk add --no-cache libc6-compat
WORKDIR /app

# Copy package files
COPY package*.json ./
COPY package-lock.json ./

# Install dependencies with exact versions
RUN npm ci --only=production --ignore-scripts

# Development dependencies for build
FROM base AS build-deps
RUN apk add --no-cache libc6-compat
WORKDIR /app
COPY package*.json ./
COPY package-lock.json ./
RUN npm ci --ignore-scripts

# Build the application
FROM base AS builder
WORKDIR /app
COPY --from=build-deps /app/node_modules ./node_modules
COPY . .

# Set environment variables for build
ENV NODE_ENV=production
ENV VITE_API_URL=""

# Build the application
RUN npm run build

# Production image
FROM node:20-alpine AS runner
WORKDIR /app

# Create non-root user for security
RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 helpboard

# Install production dependencies
COPY --from=deps --chown=helpboard:nodejs /app/node_modules ./node_modules
COPY --from=builder --chown=helpboard:nodejs /app/dist ./dist
COPY --from=builder --chown=helpboard:nodejs /app/client/dist ./client/dist
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