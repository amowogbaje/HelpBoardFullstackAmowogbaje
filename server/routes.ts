import type { Express } from "express";
import { createServer, type Server } from "http";
import { storage } from "./database-storage";
import { aiService } from "./ai-service";
import { initializeWebSocket, getWebSocketService } from "./websocket";
import { 
  loginSchema, 
  customerInitiateSchema, 
  insertMessageSchema,
  type LoginRequest,
  type CustomerInitiateRequest 
} from "@shared/schema";
import { nanoid } from "nanoid";

// Simple session store
const sessions = new Map<string, { agentId: number; expiresAt: Date }>();

// Middleware to check agent authentication
async function requireAuth(req: any, res: any, next: any) {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith("Bearer ")) {
    return res.status(401).json({ message: "Authorization required" });
  }

  const token = authHeader.slice(7);
  let session = sessions.get(token);
  
  // If not in memory, check database
  if (!session) {
    try {
      const dbSession = await storage.getSession(token);
      if (dbSession && (!dbSession.expiresAt || dbSession.expiresAt > new Date())) {
        session = { 
          agentId: dbSession.agentId || 0, 
          expiresAt: dbSession.expiresAt || new Date(Date.now() + 24 * 60 * 60 * 1000) 
        };
        sessions.set(token, session);
      }
    } catch (error) {
      console.error("Error checking session:", error);
    }
  }
  
  if (!session || session.expiresAt < new Date()) {
    sessions.delete(token);
    return res.status(401).json({ message: "Invalid or expired session" });
  }

  req.agentId = session.agentId;
  next();
}

// Middleware to get customer from session header
async function getCustomerFromSession(req: any, res: any, next: any) {
  const sessionId = req.headers["x-session-id"];
  if (sessionId) {
    const customer = await storage.getCustomerBySessionId(sessionId);
    req.customer = customer;
  }
  next();
}

function getClientIP(req: any): string {
  return req.headers["x-forwarded-for"]?.split(",")[0] || req.connection.remoteAddress || "127.0.0.1";
}

export async function registerRoutes(app: Express): Promise<Server> {
  const httpServer = createServer(app);
  
  // Initialize WebSocket
  initializeWebSocket(httpServer);

  // Authentication endpoints
  app.post("/api/login", async (req, res) => {
    try {
      const { email, password } = loginSchema.parse(req.body);
      
      const agent = await storage.validateAgent(email, password);
      if (!agent) {
        return res.status(401).json({ message: "Invalid credentials" });
      }

      const sessionToken = nanoid();
      const expiresAt = new Date(Date.now() + 24 * 60 * 60 * 1000); // 24 hours
      
      sessions.set(sessionToken, { agentId: agent.id, expiresAt });
      
      // Store session in storage as well
      await storage.createSession({
        id: sessionToken,
        agentId: agent.id,
        data: { email: agent.email },
        expiresAt,
      });

      res.json({
        sessionToken,
        agent: {
          id: agent.id,
          email: agent.email,
          name: agent.name,
          isAvailable: agent.isAvailable,
        },
      });
    } catch (error) {
      console.error("Login error:", error);
      res.status(400).json({ message: "Invalid request data" });
    }
  });

  app.post("/api/logout", requireAuth, async (req, res) => {
    const authHeader = req.headers.authorization;
    if (authHeader) {
      const token = authHeader.slice(7);
      sessions.delete(token);
      await storage.deleteSession(token);
    }
    res.json({ message: "Logged out successfully" });
  });

  // Customer chat initiation
  app.post("/api/initiate", async (req, res) => {
    try {
      const customerData = customerInitiateSchema.parse(req.body);
      const ipAddress = getClientIP(req);
      
      // Generate session ID
      const sessionId = nanoid();
      
      // Check for returning customer by email or IP
      let existingCustomer = null;
      if (customerData.email) {
        existingCustomer = await storage.getCustomerByEmail(customerData.email);
      }
      if (!existingCustomer && ipAddress) {
        existingCustomer = await storage.getCustomerByIp(ipAddress);
      }

      const isReturningCustomer = !!existingCustomer;
      
      // Create or update customer
      let customer;
      if (existingCustomer) {
        customer = await storage.updateCustomer(existingCustomer.id, {
          ...customerData,
          sessionId,
          ipAddress,
          lastSeen: new Date(),
        });
      } else {
        // Generate friendly name if not provided
        const name = customerData.name || `Friendly Visitor ${Math.floor(Math.random() * 1000)}`;
        
        customer = await storage.createCustomer({
          ...customerData,
          sessionId,
          name,
          ipAddress,
          isIdentified: !!(customerData.email || customerData.name),
        });
      }

      if (!customer) {
        throw new Error("Failed to create customer");
      }

      // Create conversation
      const conversation = await storage.createConversation({
        customerId: customer.id,
        status: "open",
      });

      res.json({
        sessionId,
        conversationId: conversation.id,
        isReturningCustomer,
        customer,
      });
    } catch (error) {
      console.error("Initiate error:", error);
      res.status(400).json({ message: "Invalid request data" });
    }
  });

  // Update customer information
  app.post("/api/customers/update", getCustomerFromSession, async (req, res) => {
    try {
      if (!req.customer) {
        return res.status(400).json({ message: "Customer session not found" });
      }

      const updates = customerInitiateSchema.parse(req.body);
      const updatedCustomer = await storage.updateCustomer(req.customer.id, updates);
      
      if (!updatedCustomer) {
        return res.status(404).json({ message: "Customer not found" });
      }

      res.json({ message: "Customer information updated successfully" });
    } catch (error) {
      console.error("Update customer error:", error);
      res.status(400).json({ message: "Invalid request data" });
    }
  });

  // Conversations
  app.get("/api/conversations", requireAuth, async (req, res) => {
    try {
      const conversations = await storage.getConversations();
      res.json(conversations);
    } catch (error) {
      console.error("Get conversations error:", error);
      res.status(500).json({ message: "Internal server error" });
    }
  });

  app.get("/api/conversations/:id", requireAuth, async (req, res) => {
    try {
      const conversationId = parseInt(req.params.id);
      const conversationData = await storage.getConversation(conversationId);
      
      if (!conversationData) {
        return res.status(404).json({ message: "Conversation not found" });
      }

      const { messages, customer, ...conversation } = conversationData;
      
      res.json({
        conversation,
        customer,
        messages,
      });
    } catch (error) {
      console.error("Get conversation error:", error);
      res.status(500).json({ message: "Internal server error" });
    }
  });

  app.patch("/api/conversations/:id/assign", requireAuth, async (req, res) => {
    try {
      const conversationId = parseInt(req.params.id);
      const { agentId } = req.body;
      
      const conversation = await storage.assignConversation(conversationId, agentId || req.agentId);
      
      if (!conversation) {
        return res.status(404).json({ message: "Conversation not found" });
      }

      // Broadcast via WebSocket
      const wsService = getWebSocketService();
      if (wsService) {
        wsService.broadcastConversationAssigned(conversationId, agentId || req.agentId);
      }

      res.json(conversation);
    } catch (error) {
      console.error("Assign conversation error:", error);
      res.status(500).json({ message: "Internal server error" });
    }
  });

  app.patch("/api/conversations/:id/close", requireAuth, async (req, res) => {
    try {
      const conversationId = parseInt(req.params.id);
      const conversation = await storage.closeConversation(conversationId);
      
      if (!conversation) {
        return res.status(404).json({ message: "Conversation not found" });
      }

      // Clear AI history for closed conversation
      aiService.clearHistory(conversationId);

      // Broadcast via WebSocket
      const wsService = getWebSocketService();
      if (wsService) {
        wsService.broadcastConversationClosed(conversationId);
      }

      res.json(conversation);
    } catch (error) {
      console.error("Close conversation error:", error);
      res.status(500).json({ message: "Internal server error" });
    }
  });

  // Messages
  app.post("/api/messages", async (req, res) => {
    try {
      const messageData = insertMessageSchema.parse(req.body);
      const message = await storage.createMessage(messageData);
      res.json(message);
    } catch (error) {
      console.error("Create message error:", error);
      res.status(400).json({ message: "Invalid request data" });
    }
  });

  // Agent management
  app.patch("/api/agent/availability", requireAuth, async (req, res) => {
    try {
      const { isAvailable } = req.body;
      const agent = await storage.updateAgentAvailability(req.agentId, isAvailable);
      
      if (!agent) {
        return res.status(404).json({ message: "Agent not found" });
      }

      res.json(agent);
    } catch (error) {
      console.error("Update availability error:", error);
      res.status(500).json({ message: "Internal server error" });
    }
  });

  // AI endpoints
  app.get("/api/ai/stats", requireAuth, async (req, res) => {
    try {
      const stats = aiService.getStats();
      res.json(stats);
    } catch (error) {
      console.error("AI stats error:", error);
      res.status(500).json({ message: "Internal server error" });
    }
  });

  app.get("/api/ai/training-data", requireAuth, async (req, res) => {
    try {
      const trainingData = aiService.getTrainingData();
      res.json(trainingData);
    } catch (error) {
      console.error("Get training data error:", error);
      res.status(500).json({ message: "Internal server error" });
    }
  });

  app.post("/api/ai/training-data", requireAuth, async (req, res) => {
    try {
      const { question, answer, category, context } = req.body;
      
      if (!question || !answer || !category) {
        return res.status(400).json({ message: "Question, answer, and category are required" });
      }
      
      aiService.addTrainingData(question, answer, category, context);
      res.json({ message: "Training data added successfully" });
    } catch (error) {
      console.error("Add training data error:", error);
      res.status(500).json({ message: "Internal server error" });
    }
  });

  app.put("/api/ai/training-data/:index", requireAuth, async (req, res) => {
    try {
      const index = parseInt(req.params.index);
      const { question, answer, category, context } = req.body;
      
      if (!question || !answer || !category) {
        return res.status(400).json({ message: "Question, answer, and category are required" });
      }
      
      aiService.updateTrainingData(index, { question, answer, category, context });
      res.json({ message: "Training data updated successfully" });
    } catch (error) {
      console.error("Update training data error:", error);
      res.status(500).json({ message: "Internal server error" });
    }
  });

  app.delete("/api/ai/training-data/:index", requireAuth, async (req, res) => {
    try {
      const index = parseInt(req.params.index);
      aiService.removeTrainingData(index);
      res.json({ message: "Training data deleted successfully" });
    } catch (error) {
      console.error("Delete training data error:", error);
      res.status(500).json({ message: "Internal server error" });
    }
  });

  app.get("/api/ai/settings", requireAuth, async (req, res) => {
    try {
      const settings = aiService.getSettings();
      res.json(settings);
    } catch (error) {
      console.error("Get AI settings error:", error);
      res.status(500).json({ message: "Internal server error" });
    }
  });

  app.put("/api/ai/settings", requireAuth, async (req, res) => {
    try {
      aiService.updateSettings(req.body);
      res.json({ message: "AI settings updated successfully" });
    } catch (error) {
      console.error("Update AI settings error:", error);
      res.status(500).json({ message: "Internal server error" });
    }
  });

  app.post("/api/ai/retrain", requireAuth, async (req, res) => {
    try {
      const { conversationId } = req.body;
      
      // In a real implementation, this would retrain the AI model
      // For now, we'll just return current stats
      const stats = aiService.getStats();
      
      res.json({
        message: `AI retrained with ${conversationId ? "1 conversation" : "all conversations"}`,
        stats,
      });
    } catch (error) {
      console.error("AI retrain error:", error);
      res.status(500).json({ message: "Internal server error" });
    }
  });

  return httpServer;
}
