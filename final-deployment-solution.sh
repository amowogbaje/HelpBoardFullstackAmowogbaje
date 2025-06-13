#!/bin/bash

# Final HelpBoard Deployment Solution - Complete Authentication Fix
set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    local level=$1
    shift
    case $level in
        "INFO") echo -e "${GREEN}[INFO]${NC} $*" ;;
        "WARN") echo -e "${YELLOW}[WARN]${NC} $*" ;;
        "ERROR") echo -e "${RED}[ERROR]${NC} $*" ;;
    esac
}

# Comprehensive authentication system replacement
fix_authentication_system() {
    log "INFO" "Implementing comprehensive authentication fix..."
    
    # Backup existing files
    cp server/routes.ts server/routes.ts.backup.$(date +%s)
    cp client/src/lib/auth.ts client/src/lib/auth.ts.backup.$(date +%s)
    
    # Create enhanced routes with proper session management
    cat > server/routes.ts << 'EOFROUTES'
import express, { type Request, Response, NextFunction } from "express";
import { registerRoutes as registerViteRoutes } from "./vite";
import { nanoid } from "nanoid";
import bcrypt from "bcryptjs";
import { storage } from "./database-storage";
import { initializeWebSocket } from "./websocket";
import {
  loginSchema,
  customerInitiateSchema,
  createAgentSchema,
  updateAgentSchema,
  changePasswordSchema,
  adminUpdateAgentSchema,
  type Agent,
  type Customer,
  type Conversation,
  type Message,
} from "@shared/schema";
import { Server } from "http";

// Enhanced session interface
interface SessionData {
  agentId: number;
  agent: Agent;
  expiresAt: Date;
  lastActivity: Date;
}

const sessions = new Map<string, SessionData>();

// Session cleanup interval
setInterval(() => {
  const now = new Date();
  for (const [token, session] of sessions.entries()) {
    if (session.expiresAt <= now) {
      sessions.delete(token);
      storage.deleteSession(token).catch(console.error);
    }
  }
}, 60000);

// Enhanced authentication middleware
async function requireAuth(req: any, res: any, next: any) {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith("Bearer ")) {
    return res.status(401).json({ message: "Authorization required" });
  }

  const token = authHeader.slice(7);
  
  try {
    let session = sessions.get(token);
    
    if (!session) {
      const dbSession = await storage.getSession(token);
      if (dbSession && dbSession.agentId && (!dbSession.expiresAt || dbSession.expiresAt > new Date())) {
        const agent = await storage.getAgent(dbSession.agentId);
        if (agent && agent.isActive) {
          session = {
            agentId: dbSession.agentId,
            agent,
            expiresAt: dbSession.expiresAt || new Date(Date.now() + 24 * 60 * 60 * 1000),
            lastActivity: new Date()
          };
          sessions.set(token, session);
        }
      }
    }

    if (!session || session.expiresAt <= new Date()) {
      sessions.delete(token);
      return res.status(401).json({ message: "Invalid or expired session" });
    }

    session.lastActivity = new Date();
    req.agentId = session.agentId;
    req.agent = session.agent;
    next();
  } catch (error) {
    console.error("Authentication error:", error);
    return res.status(401).json({ message: "Authentication failed" });
  }
}

async function getCustomerFromSession(req: any, res: any, next: any) {
  const sessionId = req.headers['x-session-id'] || req.query.sessionId;
  if (sessionId) {
    try {
      const customer = await storage.getCustomerBySessionId(sessionId);
      req.customer = customer;
    } catch (error) {
      console.error("Customer lookup error:", error);
    }
  }
  next();
}

function getClientIP(req: any): string {
  return req.headers['x-forwarded-for']?.split(',')[0]?.trim() ||
         req.headers['x-real-ip'] ||
         req.connection?.remoteAddress ||
         req.socket?.remoteAddress ||
         req.ip ||
         '127.0.0.1';
}

export async function registerRoutes(app: express.Application): Promise<Server> {
  const httpServer = await registerViteRoutes(app);
  initializeWebSocket(httpServer);

  // Health check
  app.get("/api/health", (req, res) => {
    res.json({ status: "ok", timestamp: new Date().toISOString() });
  });

  // Enhanced login endpoint
  app.post("/api/auth/login", async (req, res) => {
    try {
      const { email, password } = loginSchema.parse(req.body);
      
      const agent = await storage.validateAgent(email, password);
      if (!agent || !agent.isActive) {
        return res.status(401).json({ message: "Invalid credentials" });
      }

      const sessionToken = nanoid();
      const expiresAt = new Date(Date.now() + 24 * 60 * 60 * 1000);
      
      const sessionData: SessionData = {
        agentId: agent.id,
        agent,
        expiresAt,
        lastActivity: new Date()
      };
      
      sessions.set(sessionToken, sessionData);
      
      await storage.createSession({
        id: sessionToken,
        agentId: agent.id,
        data: { email: agent.email, role: agent.role },
        expiresAt,
      });

      res.json({
        message: "Login successful",
        sessionToken,
        agent: {
          id: agent.id,
          email: agent.email,
          name: agent.name,
          role: agent.role || "agent",
          isAvailable: agent.isAvailable || true,
        },
      });
    } catch (error: any) {
      console.error("Login error:", error);
      res.status(500).json({ message: "Login failed" });
    }
  });

  app.post("/api/logout", requireAuth, async (req, res) => {
    const authHeader = req.headers.authorization;
    if (authHeader) {
      const token = authHeader.slice(7);
      sessions.delete(token);
      try {
        await storage.deleteSession(token);
      } catch (error) {
        console.error("Session cleanup error:", error);
      }
    }
    res.json({ message: "Logged out successfully" });
  });

  // Session validation
  app.get("/api/auth/validate", requireAuth, async (req, res) => {
    res.json({
      valid: true,
      agent: req.agent
    });
  });

  // Customer initiation
  app.post("/api/customer/initiate", getCustomerFromSession, async (req, res) => {
    try {
      const customerData = customerInitiateSchema.parse(req.body);
      const sessionId = nanoid();
      const ipAddress = getClientIP(req);
      
      let existingCustomer = null;
      if (customerData.email) {
        existingCustomer = await storage.getCustomerByEmail(customerData.email);
      }
      if (!existingCustomer) {
        existingCustomer = await storage.getCustomerByIp(ipAddress);
      }
      
      let customer;
      if (existingCustomer) {
        customer = await storage.updateCustomer(existingCustomer.id, {
          ...customerData,
          sessionId,
          ipAddress,
        });
      } else {
        const name = customerData.name || `Visitor ${Math.floor(Math.random() * 1000)}`;
        
        customer = await storage.createCustomer({
          ...customerData,
          name,
          sessionId,
          ipAddress,
          isIdentified: !!customerData.email,
        });
      }

      if (!customer) {
        return res.status(500).json({ message: "Failed to create customer session" });
      }

      res.json({
        message: "Customer session initiated",
        sessionId,
        customer: {
          id: customer.id,
          name: customer.name,
          email: customer.email,
        },
      });
    } catch (error: any) {
      console.error("Customer initiation error:", error);
      res.status(500).json({ message: "Failed to initiate customer session" });
    }
  });

  // API endpoints with proper authentication
  app.get("/api/conversations", requireAuth, async (req, res) => {
    try {
      const conversations = await storage.getConversations();
      res.json(conversations);
    } catch (error) {
      console.error("Error fetching conversations:", error);
      res.status(500).json({ message: "Failed to fetch conversations" });
    }
  });

  app.get("/api/conversations/:id", requireAuth, async (req, res) => {
    try {
      const id = parseInt(req.params.id);
      if (isNaN(id)) {
        return res.status(400).json({ message: "Invalid conversation ID" });
      }

      const conversation = await storage.getConversation(id);
      if (!conversation) {
        return res.status(404).json({ message: "Conversation not found" });
      }

      res.json(conversation);
    } catch (error) {
      console.error("Error fetching conversation:", error);
      res.status(500).json({ message: "Failed to fetch conversation" });
    }
  });

  app.post("/api/conversations/:id/assign", requireAuth, async (req, res) => {
    try {
      const id = parseInt(req.params.id);
      const agentId = req.agentId;

      const conversation = await storage.assignConversation(id, agentId);
      if (!conversation) {
        return res.status(404).json({ message: "Conversation not found" });
      }

      res.json({ message: "Conversation assigned successfully", conversation });
    } catch (error) {
      console.error("Error assigning conversation:", error);
      res.status(500).json({ message: "Failed to assign conversation" });
    }
  });

  app.post("/api/conversations/:id/close", requireAuth, async (req, res) => {
    try {
      const id = parseInt(req.params.id);
      
      const conversation = await storage.closeConversation(id);
      if (!conversation) {
        return res.status(404).json({ message: "Conversation not found" });
      }

      res.json({ message: "Conversation closed successfully", conversation });
    } catch (error) {
      console.error("Error closing conversation:", error);
      res.status(500).json({ message: "Failed to close conversation" });
    }
  });

  app.get("/api/conversations/:id/messages", requireAuth, async (req, res) => {
    try {
      const conversationId = parseInt(req.params.id);
      if (isNaN(conversationId)) {
        return res.status(400).json({ message: "Invalid conversation ID" });
      }

      const messages = await storage.getMessagesByConversation(conversationId);
      res.json(messages);
    } catch (error) {
      console.error("Error fetching messages:", error);
      res.status(500).json({ message: "Failed to fetch messages" });
    }
  });

  // Agent management
  app.get("/api/agents", requireAuth, async (req, res) => {
    try {
      if (req.agent.role !== 'admin') {
        return res.status(403).json({ message: "Admin access required" });
      }
      
      const agents = await storage.getAllAgentsWithStats();
      res.json(agents);
    } catch (error) {
      console.error("Error fetching agents:", error);
      res.status(500).json({ message: "Failed to fetch agents" });
    }
  });

  app.post("/api/agents", requireAuth, async (req, res) => {
    try {
      if (req.agent.role !== 'admin') {
        return res.status(403).json({ message: "Admin access required" });
      }

      const agentData = createAgentSchema.parse(req.body);
      const agent = await storage.createAgent(agentData);
      
      res.status(201).json({ message: "Agent created successfully", agent });
    } catch (error: any) {
      console.error("Error creating agent:", error);
      res.status(500).json({ message: "Failed to create agent" });
    }
  });

  app.put("/api/agents/:id", requireAuth, async (req, res) => {
    try {
      if (req.agent.role !== 'admin') {
        return res.status(403).json({ message: "Admin access required" });
      }

      const id = parseInt(req.params.id);
      const updates = adminUpdateAgentSchema.parse(req.body);
      
      const agent = await storage.adminUpdateAgent(id, updates);
      if (!agent) {
        return res.status(404).json({ message: "Agent not found" });
      }
      
      res.json({ message: "Agent updated successfully", agent });
    } catch (error: any) {
      console.error("Error updating agent:", error);
      res.status(500).json({ message: "Failed to update agent" });
    }
  });

  app.delete("/api/agents/:id", requireAuth, async (req, res) => {
    try {
      if (req.agent.role !== 'admin') {
        return res.status(403).json({ message: "Admin access required" });
      }

      const id = parseInt(req.params.id);
      const success = await storage.deleteAgent(id);
      
      if (!success) {
        return res.status(404).json({ message: "Agent not found" });
      }
      
      res.json({ message: "Agent deleted successfully" });
    } catch (error) {
      console.error("Error deleting agent:", error);
      res.status(500).json({ message: "Failed to delete agent" });
    }
  });

  // Profile management
  app.get("/api/profile", requireAuth, async (req, res) => {
    res.json(req.agent);
  });

  app.put("/api/profile", requireAuth, async (req, res) => {
    try {
      const updates = updateAgentSchema.parse(req.body);
      const agent = await storage.updateAgent(req.agentId, updates);
      
      if (!agent) {
        return res.status(404).json({ message: "Agent not found" });
      }
      
      // Update session data
      const authHeader = req.headers.authorization;
      if (authHeader) {
        const token = authHeader.slice(7);
        const session = sessions.get(token);
        if (session) {
          session.agent = agent;
        }
      }
      
      res.json({ message: "Profile updated successfully", agent });
    } catch (error: any) {
      console.error("Error updating profile:", error);
      res.status(500).json({ message: "Failed to update profile" });
    }
  });

  app.post("/api/profile/change-password", requireAuth, async (req, res) => {
    try {
      const { currentPassword, newPassword } = changePasswordSchema.parse(req.body);
      
      const success = await storage.changeAgentPassword(req.agentId, currentPassword, newPassword);
      if (!success) {
        return res.status(400).json({ message: "Current password is incorrect" });
      }
      
      res.json({ message: "Password changed successfully" });
    } catch (error: any) {
      console.error("Error changing password:", error);
      res.status(500).json({ message: "Failed to change password" });
    }
  });

  return httpServer;
}
EOFROUTES

    # Create enhanced frontend authentication
    cat > client/src/lib/auth-fixed.ts << 'EOFAUTH'
import { apiRequest } from "./queryClient";

export interface Agent {
  id: number;
  email: string;
  name: string;
  role: string;
  isAvailable: boolean;
}

export interface LoginResponse {
  sessionToken: string;
  agent: Agent;
}

let currentAgent: Agent | null = null;
let sessionToken: string | null = null;

export function getCurrentAgent(): Agent | null {
  return currentAgent;
}

export function getSessionToken(): string | null {
  return sessionToken;
}

export function setAuth(token: string, agent: Agent): void {
  sessionToken = token;
  currentAgent = agent;
  localStorage.setItem("helpboard_token", token);
  localStorage.setItem("helpboard_agent", JSON.stringify(agent));
}

export function clearAuth(): void {
  sessionToken = null;
  currentAgent = null;
  localStorage.removeItem("helpboard_token");
  localStorage.removeItem("helpboard_agent");
}

export async function validateSession(): Promise<boolean> {
  if (!sessionToken) return false;
  
  try {
    const response = await apiRequest("GET", "/api/auth/validate");
    const data = await response.json();
    
    if (data.valid && data.agent) {
      currentAgent = data.agent;
      localStorage.setItem("helpboard_agent", JSON.stringify(data.agent));
      return true;
    }
  } catch (error) {
    console.error("Session validation failed:", error);
    clearAuth();
  }
  
  return false;
}

export function loadAuthFromStorage(): boolean {
  const token = localStorage.getItem("helpboard_token");
  const agentData = localStorage.getItem("helpboard_agent");
  
  if (token && agentData) {
    try {
      const agent = JSON.parse(agentData);
      sessionToken = token;
      currentAgent = agent;
      
      // Validate session in background
      validateSession().catch(() => {
        clearAuth();
      });
      
      return true;
    } catch (error) {
      console.error("Failed to parse stored agent data:", error);
      clearAuth();
    }
  }
  
  return false;
}

export async function login(email: string, password: string): Promise<LoginResponse> {
  const response = await apiRequest("POST", "/api/auth/login", { email, password });
  const data: LoginResponse = await response.json();
  
  setAuth(data.sessionToken, data.agent);
  return data;
}

export async function logout(): Promise<void> {
  if (sessionToken) {
    try {
      await apiRequest("POST", "/api/logout");
    } catch (error) {
      console.error("Logout error:", error);
    }
  }
  clearAuth();
}

export function isAuthenticated(): boolean {
  return !!sessionToken && !!currentAgent;
}
EOFAUTH

    # Update import paths
    sed -i 's|from "./auth"|from "./auth-fixed"|g' client/src/App.tsx
    sed -i 's|from "./auth"|from "./auth-fixed"|g' client/src/pages/login.tsx
    
    log "INFO" "Authentication system completely overhauled"
}

# Database initialization with bulletproof error handling
initialize_database_bulletproof() {
    log "INFO" "Initializing database with bulletproof error handling..."
    
    # Wait for database with exponential backoff
    local max_attempts=60
    local attempt=1
    local wait_time=2
    
    while [ $attempt -le $max_attempts ]; do
        if docker compose -f docker-compose.dev.yml exec -T db pg_isready -U helpboard_user -d helpboard > /dev/null 2>&1; then
            log "INFO" "Database ready (attempt $attempt)"
            break
        fi
        
        log "INFO" "Waiting for database... attempt $attempt/$max_attempts (${wait_time}s)"
        sleep $wait_time
        
        wait_time=$((wait_time < 30 ? wait_time * 2 : 30))
        ((attempt++))
    done
    
    if [ $attempt -gt $max_attempts ]; then
        log "ERROR" "Database failed to become ready"
        return 1
    fi
    
    # Create schema with verification
    log "INFO" "Creating database schema..."
    if ! docker compose -f docker-compose.dev.yml exec -T app npm run db:push; then
        log "ERROR" "Schema creation failed"
        return 1
    fi
    
    # Verify schema
    local table_count
    table_count=$(docker compose -f docker-compose.dev.yml exec -T db psql -U helpboard_user -d helpboard -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';" | tr -d ' \n\r')
    
    if [ "$table_count" -lt 5 ]; then
        log "ERROR" "Schema incomplete. Expected ≥5 tables, found $table_count"
        return 1
    fi
    
    # Create default agents with conflict handling
    log "INFO" "Setting up default agents..."
    docker compose -f docker-compose.dev.yml exec -T db psql -U helpboard_user -d helpboard << 'EOSQL'
INSERT INTO agents (
    email, password, name, role, is_active, is_available,
    department, phone, created_at, updated_at, password_changed_at
) VALUES (
    'admin@helpboard.com',
    '$2a$12$HWTRhBUQ3O1l.zyQsZvx0.fJBMVqQNrxvSvJ1NbeGGD4gEB2g9VO6',
    'System Administrator', 'admin', true, true,
    'Administration', '+1-555-0100', NOW(), NOW(), NOW()
), (
    'agent@helpboard.com',
    '$2a$12$HWTRhBUQ3O1l.zyQsZvx0.fJBMVqQNrxvSvJ1NbeGGD4gEB2g9VO6',
    'Support Agent', 'agent', true, true,
    'Customer Support', '+1-555-0200', NOW(), NOW(), NOW()
) ON CONFLICT (email) DO UPDATE SET
    password = EXCLUDED.password,
    is_active = true,
    updated_at = NOW();
EOSQL
    
    # Verify agents
    local agent_count
    agent_count=$(docker compose -f docker-compose.dev.yml exec -T db psql -U helpboard_user -d helpboard -t -c "SELECT COUNT(*) FROM agents;" | tr -d ' \n\r')
    
    if [ "$agent_count" -lt 2 ]; then
        log "ERROR" "Agent creation failed. Expected ≥2, found $agent_count"
        return 1
    fi
    
    log "INFO" "Database initialization complete ($agent_count agents, $table_count tables)"
}

# Comprehensive health verification
verify_deployment_health() {
    log "INFO" "Performing comprehensive health verification..."
    
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        # Test health endpoint
        if curl -s http://localhost:3000/api/health | grep -q "ok"; then
            log "INFO" "Health check passed (attempt $attempt)"
            break
        fi
        
        log "INFO" "Health check attempt $attempt/$max_attempts..."
        sleep 10
        ((attempt++))
    done
    
    if [ $attempt -gt $max_attempts ]; then
        log "ERROR" "Health checks failed"
        return 1
    fi
    
    # Test authentication flow
    log "INFO" "Testing authentication flow..."
    local login_response
    login_response=$(curl -s -X POST http://localhost:3000/api/auth/login \
        -H "Content-Type: application/json" \
        -d '{"email":"admin@helpboard.com","password":"admin123"}')
    
    local token
    token=$(echo "$login_response" | grep -o '"sessionToken":"[^"]*"' | cut -d'"' -f4)
    
    if [ -n "$token" ]; then
        log "INFO" "Login successful, testing API access..."
        
        local api_response
        api_response=$(curl -s -H "Authorization: Bearer $token" \
            http://localhost:3000/api/conversations)
        
        if echo "$api_response" | grep -q "Invalid.*session"; then
            log "ERROR" "API authentication failed"
            return 1
        else
            log "INFO" "Authentication flow verified successfully"
        fi
    else
        log "ERROR" "Login failed"
        log "ERROR" "Response: $login_response"
        return 1
    fi
    
    log "INFO" "All health checks passed"
}

# Main deployment execution
main() {
    echo "=========================================="
    echo "Final HelpBoard Deployment Solution"
    echo "Comprehensive Authentication Fix"
    echo "=========================================="
    
    fix_authentication_system
    initialize_database_bulletproof
    verify_deployment_health
    
    echo ""
    echo "=========================================="
    echo -e "${GREEN}DEPLOYMENT SUCCESSFUL!${NC}"
    echo "=========================================="
    echo ""
    echo "✓ Authentication system completely overhauled"
    echo "✓ Session management enhanced with proper typing"
    echo "✓ Database initialized with bulletproof error handling"
    echo "✓ Health checks verified"
    echo ""
    echo "Application: http://localhost:3000"
    echo "Admin: admin@helpboard.com / admin123"
    echo "Agent: agent@helpboard.com / password123"
    echo ""
    echo "Authentication issues are now completely resolved."
}

main "$@"