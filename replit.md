# HelpBoard - Customer Support Platform

## Overview

HelpBoard is a comprehensive customer support platform that combines AI-powered assistance with live agent capabilities. The system provides real-time chat functionality, conversation management, AI training capabilities, and embeddable widgets for external websites.

## System Architecture

### Frontend Architecture
- **React 18** with TypeScript for the main application
- **Vite** for build tooling and development server
- **Tailwind CSS** with shadcn/ui components for styling
- **Wouter** for client-side routing
- **TanStack Query** for server state management
- **WebSocket** client for real-time communication

### Backend Architecture  
- **Node.js** with Express.js REST API
- **WebSocket** server for real-time messaging
- **TypeScript** throughout the stack
- **Multi-stage Docker** builds for production deployment

### Database Layer
- **PostgreSQL** as primary database (configurable with Neon serverless)
- **Drizzle ORM** for database operations and migrations
- **Redis** for session storage and caching
- Database initialization with proper permissions and extensions

## Key Components

### Core Services
1. **Authentication Service** - JWT-based session management with localStorage persistence
2. **WebSocket Service** - Real-time messaging, typing indicators, and conversation updates
3. **AI Service** - OpenAI integration with customizable training data and response automation
4. **Storage Service** - Database abstraction layer for all data operations

### Main Features
1. **Dashboard** - Central hub for agents to manage conversations
2. **Conversation Management** - Real-time chat with customers, message history, and status tracking
3. **AI Assistant** - Automated responses with configurable settings and training
4. **Customer Widgets** - Embeddable chat widgets for external websites
5. **Analytics** - Performance metrics and conversation insights
6. **Customer Management** - Customer profiles and interaction history

### UI Components
- **Sidebar Navigation** - Main application navigation with agent status
- **Conversation List** - Real-time list of active conversations with unread counts
- **Chat Area** - Message interface with typing indicators and file attachments
- **Customer Info Panel** - Customer details and conversation metadata
- **Embeddable Widget** - Customer-facing chat interface for external sites

## Data Flow

### Authentication Flow
1. Agent login with email/password
2. Server validates credentials and creates session token
3. Token stored in localStorage and included in API requests
4. WebSocket authentication using same token

### Conversation Flow
1. Customer initiates chat through widget
2. System creates customer record and conversation
3. AI responds automatically or conversation assigned to agent
4. Real-time message exchange via WebSocket
5. Conversation status updates broadcast to all connected agents

### AI Integration Flow
1. Customer message triggers AI service
2. AI analyzes message against training data
3. Generates contextual response using OpenAI
4. Response sent with configurable delay for natural feel
5. Escalation to human agent based on confidence thresholds

## External Dependencies

### Core Dependencies
- **OpenAI API** - AI response generation and conversation analysis
- **PostgreSQL** - Primary data storage
- **Redis** - Session management and caching
- **WebSocket** - Real-time communication

### Development Tools
- **Drizzle Kit** - Database migrations and schema management
- **ESBuild** - Production server bundling
- **Docker** - Containerization and deployment

### UI Libraries
- **Radix UI** - Accessible component primitives
- **Lucide React** - Icon library
- **TailwindCSS** - Utility-first styling
- **React Hook Form** - Form state management

## Deployment Strategy

### Development Environment
- **Replit** integration with live reload
- **Docker Compose** for local services (PostgreSQL, Redis)
- **Vite dev server** with HMR and error overlay

### Production Deployment
- **Multi-stage Docker builds** for optimized images
- **Docker Compose** orchestration with health checks
- **Nginx** reverse proxy with SSL termination
- **Environment-based configuration** with secrets management

### Monitoring and Operations
- **Prometheus** metrics collection
- **Grafana** dashboards for visualization
- **Health check endpoints** for container orchestration
- **Automated deployment scripts** with rollback capability

## Changelog
- June 14, 2025. Initial setup

## User Preferences

Preferred communication style: Simple, everyday language.