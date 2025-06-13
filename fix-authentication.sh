#!/bin/bash

# Complete authentication fix for HelpBoard deployment
set -e

echo "=== Fixing Authentication Issues ==="

# Backup current routes file
cp server/routes.ts server/routes.ts.backup

# Fix session management and authentication flow
cat > server/routes.ts << 'EOF'
import express, { type Request, Response, NextFunction } from "express";
import { registerRoutes as registerViteRoutes } from "./vite";
import { nanoid } from "nanoid";
import bcrypt from "bcryptjs";
import { storage } from "./database-storage";
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

// Enhanced session store with proper typing
interface SessionData {
  agentId: number;
  agent: Agent;
  expiresAt: Date;
  lastActivity: Date;
}

const sessions = new Map<string, SessionData>();

// Clean expired sessions periodically
setInterval(() => {
  const now = new Date();
  for (const [token, session] of sessions.entries()) {
    if (session.expiresAt <= now) {
      sessions.delete(token);
      storage.deleteSession(token).catch(console.error);
    }
  }
}, 60000); // Clean every minute

// Enhanced authentication middleware
async function requireAuth(req: any, res: any, next: any) {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith("Bearer ")) {
    return res.status(401).json({ message: "Authorization required" });
  }

  const token = authHeader.slice(7);
  
  try {
    let session = sessions.get(token);
    
    // If not in memory, check database and verify agent
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

    // Update last activity
    session.lastActivity = new Date();
    
    req.agentId = session.agentId;
    req.agent = session.agent;
    next();
  } catch (error) {
    console.error("Authentication error:", error);
    return res.status(401).json({ message: "Authentication failed" });
  }
}

// Customer middleware for widget routes
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
  // Health check endpoint
  app.get("/api/health", (req, res) => {
    res.json({ status: "ok", timestamp: new Date().toISOString() });
  });

  // Enhanced login endpoint
  app.post("/api/auth/login", async (req, res) => {
    try {
      const { email, password } = loginSchema.parse(req.body);
      
      const agent = await storage.validateAgent(email, password);
      if (!agent) {
        return res.status(401).json({ message: "Invalid credentials" });
      }

      if (!agent.isActive) {
        return res.status(401).json({ message: "Account is disabled" });
      }

      const sessionToken = nanoid();
      const expiresAt = new Date(Date.now() + 24 * 60 * 60 * 1000); // 24 hours
      
      // Store in memory and database
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
        data: { email: agent.email },
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
      if (error?.name === "ZodError") {
        res.status(400).json({ message: "Invalid email or password format" });
      } else {
        res.status(500).json({ message: "Internal server error" });
      }
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

  // Customer initiation endpoint
  app.post("/api/customer/initiate", getCustomerFromSession, async (req, res) => {
    try {
      const customerData = customerInitiateSchema.parse(req.body);
      const sessionId = nanoid();
      const ipAddress = getClientIP(req);
      
      // Check for existing customer by email or IP
      let existingCustomer = null;
      if (customerData.email) {
        existingCustomer = await storage.getCustomerByEmail(customerData.email);
      }
      if (!existingCustomer) {
        existingCustomer = await storage.getCustomerByIp(ipAddress);
      }
      
      // Create or update customer
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

  // Conversations endpoint with proper authentication
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

  // Messages endpoint
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

  // Agent management endpoints
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
      if (error?.name === "ZodError") {
        res.status(400).json({ message: "Invalid agent data" });
      } else {
        res.status(500).json({ message: "Failed to create agent" });
      }
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

  // Session validation endpoint
  app.get("/api/auth/validate", requireAuth, async (req, res) => {
    res.json({
      valid: true,
      agent: req.agent
    });
  });

  return registerViteRoutes(app);
}
EOF

echo "✓ Fixed authentication routes"

# Create a complete authentication test script
cat > test-auth-complete.sh << 'EOF'
#!/bin/bash

echo "=== Complete Authentication Test ==="

# Test admin login
echo "Testing admin login..."
RESPONSE=$(curl -s -X POST "https://helpboard.selfany.com/api/auth/login" \
    -H "Content-Type: application/json" \
    -d '{"email":"admin@helpboard.com","password":"admin123"}')

echo "Login response: $RESPONSE"

# Extract token
TOKEN=$(echo "$RESPONSE" | grep -o '"sessionToken":"[^"]*"' | cut -d'"' -f4)

if [ -n "$TOKEN" ]; then
    echo "✓ Login successful, token: $TOKEN"
    
    # Test authenticated endpoint
    echo "Testing authenticated endpoint..."
    AUTH_RESPONSE=$(curl -s -H "Authorization: Bearer $TOKEN" \
        "https://helpboard.selfany.com/api/conversations")
    
    echo "Conversations response: $AUTH_RESPONSE"
    
    if echo "$AUTH_RESPONSE" | grep -q "message.*Invalid"; then
        echo "✗ Authentication still failing"
    else
        echo "✓ Authentication working correctly"
    fi
else
    echo "✗ Login failed"
fi
EOF

chmod +x test-auth-complete.sh

echo "✓ Created authentication test script"
echo ""
echo "Authentication fixes applied. Run ./test-auth-complete.sh to verify."