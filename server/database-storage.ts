import {
  agents,
  customers,
  conversations,
  messages,
  sessions,
  type Agent,
  type Customer,
  type Conversation,
  type Message,
  type Session,
  type InsertAgent,
  type InsertCustomer,
  type InsertConversation,
  type InsertMessage,
  type InsertSession,
} from "@shared/schema";
import { db } from "./db";
import { eq, desc, and, isNull, count, sql, or } from "drizzle-orm";
import { nanoid } from "nanoid";
import bcrypt from "bcryptjs";

export interface IStorage {
  // Agents
  getAgent(id: number): Promise<Agent | undefined>;
  getAgentByEmail(email: string): Promise<Agent | undefined>;
  createAgent(agent: InsertAgent): Promise<Agent>;
  updateAgentAvailability(id: number, isAvailable: boolean): Promise<Agent | undefined>;

  // Customers
  getCustomer(id: number): Promise<Customer | undefined>;
  getCustomerBySessionId(sessionId: string): Promise<Customer | undefined>;
  getCustomerByEmail(email: string): Promise<Customer | undefined>;
  getCustomerByIp(ipAddress: string): Promise<Customer | undefined>;
  createCustomer(customer: InsertCustomer): Promise<Customer>;
  updateCustomer(id: number, updates: Partial<InsertCustomer>): Promise<Customer | undefined>;

  // Conversations
  getConversations(): Promise<(Conversation & { customer: Customer; assignedAgent?: Agent; lastMessage?: Message; unreadCount: number; messageCount: number })[]>;
  getConversation(id: number): Promise<(Conversation & { customer: Customer; messages: (Message & { sender?: Customer | Agent })[] }) | undefined>;
  createConversation(conversation: InsertConversation): Promise<Conversation>;
  updateConversation(id: number, updates: Partial<InsertConversation>): Promise<Conversation | undefined>;
  assignConversation(id: number, agentId: number): Promise<Conversation | undefined>;
  closeConversation(id: number): Promise<Conversation | undefined>;

  // Messages
  getMessage(id: number): Promise<Message | undefined>;
  getMessagesByConversation(conversationId: number): Promise<(Message & { sender?: Customer | Agent })[]>;
  createMessage(message: InsertMessage): Promise<Message>;
  getUnreadCount(conversationId: number): Promise<number>;

  // Sessions
  getSession(id: string): Promise<Session | undefined>;
  createSession(session: InsertSession): Promise<Session>;
  deleteSession(id: string): Promise<void>;

  // Auth helpers
  validateAgent(email: string, password: string): Promise<Agent | null>;
}

export class DatabaseStorage implements IStorage {
  constructor() {
    this.seedData();
  }

  private async seedData() {
    try {
      console.log("Seeding initial data...");
      
      // Check if agent already exists
      const existingAgent = await db.select().from(agents).where(eq(agents.email, "agent@helpboard.com")).limit(1);
      
      if (existingAgent.length === 0) {
        // Create sample agent
        await db.insert(agents).values({
          name: "Support Agent",
          email: "agent@helpboard.com",
          password: await bcrypt.hash("password123", 10),
          isAvailable: true,
          createdAt: new Date(),
        });
        console.log("Initial agent created");
      }

      console.log("Database seeding completed");
    } catch (error) {
      console.error("Error seeding data:", error);
    }
  }

  // Agent methods
  async getAgent(id: number): Promise<Agent | undefined> {
    const [agent] = await db.select().from(agents).where(eq(agents.id, id));
    return agent || undefined;
  }

  async getAgentByEmail(email: string): Promise<Agent | undefined> {
    const [agent] = await db.select().from(agents).where(eq(agents.email, email));
    return agent || undefined;
  }

  async createAgent(insertAgent: InsertAgent): Promise<Agent> {
    const [agent] = await db.insert(agents).values(insertAgent).returning();
    return agent;
  }

  async updateAgentAvailability(id: number, isAvailable: boolean): Promise<Agent | undefined> {
    const [agent] = await db
      .update(agents)
      .set({ isAvailable })
      .where(eq(agents.id, id))
      .returning();
    return agent || undefined;
  }

  // Customer methods with enhanced identification
  async getCustomer(id: number): Promise<Customer | undefined> {
    const [customer] = await db.select().from(customers).where(eq(customers.id, id));
    return customer || undefined;
  }

  async getCustomerBySessionId(sessionId: string): Promise<Customer | undefined> {
    const [customer] = await db.select().from(customers).where(eq(customers.sessionId, sessionId));
    return customer || undefined;
  }

  async getCustomerByEmail(email: string): Promise<Customer | undefined> {
    const [customer] = await db.select().from(customers).where(eq(customers.email, email));
    return customer || undefined;
  }

  async getCustomerByIp(ipAddress: string): Promise<Customer | undefined> {
    const [customer] = await db.select().from(customers)
      .where(and(eq(customers.ipAddress, ipAddress), eq(customers.isIdentified, false)))
      .orderBy(desc(customers.lastSeen))
      .limit(1);
    return customer || undefined;
  }

  async createCustomer(insertCustomer: InsertCustomer): Promise<Customer> {
    const [customer] = await db.insert(customers).values({
      ...insertCustomer,
      createdAt: new Date(),
      lastSeen: new Date(),
    }).returning();
    return customer;
  }

  async updateCustomer(id: number, updates: Partial<InsertCustomer>): Promise<Customer | undefined> {
    const [customer] = await db
      .update(customers)
      .set({ ...updates, lastSeen: new Date() })
      .where(eq(customers.id, id))
      .returning();
    return customer || undefined;
  }

  // Conversation methods
  async getConversations(): Promise<(Conversation & { customer: Customer; assignedAgent?: Agent; lastMessage?: Message; unreadCount: number; messageCount: number })[]> {
    const conversationsQuery = await db
      .select({
        conversation: conversations,
        customer: customers,
        agent: agents,
      })
      .from(conversations)
      .leftJoin(customers, eq(conversations.customerId, customers.id))
      .leftJoin(agents, eq(conversations.assignedAgentId, agents.id))
      .orderBy(desc(conversations.updatedAt));

    const result = [];
    for (const row of conversationsQuery) {
      if (!row.customer) continue;

      // Get last message
      const [lastMessage] = await db
        .select()
        .from(messages)
        .where(eq(messages.conversationId, row.conversation.id))
        .orderBy(desc(messages.createdAt))
        .limit(1);

      // Get message count
      const [messageCountResult] = await db
        .select({ count: count() })
        .from(messages)
        .where(eq(messages.conversationId, row.conversation.id));

      result.push({
        ...row.conversation,
        customer: row.customer,
        assignedAgent: row.agent || undefined,
        lastMessage: lastMessage || undefined,
        unreadCount: 0, // We'll implement proper unread counting later
        messageCount: messageCountResult?.count || 0,
      });
    }

    return result;
  }

  async getConversation(id: number): Promise<(Conversation & { customer: Customer; messages: (Message & { sender?: Customer | Agent })[] }) | undefined> {
    const [conversationData] = await db
      .select({
        conversation: conversations,
        customer: customers,
      })
      .from(conversations)
      .leftJoin(customers, eq(conversations.customerId, customers.id))
      .where(eq(conversations.id, id));

    if (!conversationData?.conversation || !conversationData?.customer) {
      return undefined;
    }

    // Get messages with sender information
    const messagesData = await db
      .select({
        message: messages,
        customer: customers,
        agent: agents,
      })
      .from(messages)
      .leftJoin(customers, and(eq(messages.senderId, customers.id), eq(messages.senderType, "customer")))
      .leftJoin(agents, and(eq(messages.senderId, agents.id), eq(messages.senderType, "agent")))
      .where(eq(messages.conversationId, id))
      .orderBy(messages.createdAt);

    const messagesWithSender = messagesData.map(row => ({
      ...row.message,
      sender: row.customer || row.agent || undefined,
    }));

    return {
      ...conversationData.conversation,
      customer: conversationData.customer,
      messages: messagesWithSender,
    };
  }

  async createConversation(insertConversation: InsertConversation): Promise<Conversation> {
    const [conversation] = await db.insert(conversations).values({
      ...insertConversation,
      status: "open",
      createdAt: new Date(),
      updatedAt: new Date(),
    }).returning();
    return conversation;
  }

  async updateConversation(id: number, updates: Partial<InsertConversation>): Promise<Conversation | undefined> {
    const [conversation] = await db
      .update(conversations)
      .set({ ...updates, updatedAt: new Date() })
      .where(eq(conversations.id, id))
      .returning();
    return conversation || undefined;
  }

  async assignConversation(id: number, agentId: number): Promise<Conversation | undefined> {
    const [conversation] = await db
      .update(conversations)
      .set({ assignedAgentId: agentId, updatedAt: new Date() })
      .where(eq(conversations.id, id))
      .returning();
    return conversation || undefined;
  }

  async closeConversation(id: number): Promise<Conversation | undefined> {
    const [conversation] = await db
      .update(conversations)
      .set({ status: "closed", updatedAt: new Date() })
      .where(eq(conversations.id, id))
      .returning();
    return conversation || undefined;
  }

  // Message methods
  async getMessage(id: number): Promise<Message | undefined> {
    const [message] = await db.select().from(messages).where(eq(messages.id, id));
    return message || undefined;
  }

  async getMessagesByConversation(conversationId: number): Promise<(Message & { sender?: Customer | Agent })[]> {
    const messagesData = await db
      .select({
        message: messages,
        customer: customers,
        agent: agents,
      })
      .from(messages)
      .leftJoin(customers, and(eq(messages.senderId, customers.id), eq(messages.senderType, "customer")))
      .leftJoin(agents, and(eq(messages.senderId, agents.id), eq(messages.senderType, "agent")))
      .where(eq(messages.conversationId, conversationId))
      .orderBy(messages.createdAt);

    return messagesData.map(row => ({
      ...row.message,
      sender: row.customer || row.agent || undefined,
    }));
  }

  async createMessage(insertMessage: InsertMessage): Promise<Message> {
    const [message] = await db.insert(messages).values({
      ...insertMessage,
      createdAt: new Date(),
    }).returning();

    // Update conversation timestamp
    await db
      .update(conversations)
      .set({ updatedAt: new Date() })
      .where(eq(conversations.id, insertMessage.conversationId));

    return message;
  }

  async getUnreadCount(conversationId: number): Promise<number> {
    // For now, return 0. We can implement proper unread tracking later
    return 0;
  }

  // Session methods
  async getSession(id: string): Promise<Session | undefined> {
    const [session] = await db.select().from(sessions).where(eq(sessions.id, id));
    return session || undefined;
  }

  async createSession(insertSession: InsertSession): Promise<Session> {
    const [session] = await db.insert(sessions).values({
      ...insertSession,
      data: insertSession.data || {},
      createdAt: new Date(),
    }).returning();
    return session;
  }

  async deleteSession(id: string): Promise<void> {
    await db.delete(sessions).where(eq(sessions.id, id));
  }

  // Auth methods
  async validateAgent(email: string, password: string): Promise<Agent | null> {
    const agent = await this.getAgentByEmail(email);
    if (!agent) return null;

    const isValid = await bcrypt.compare(password, agent.password);
    return isValid ? agent : null;
  }
}

export const storage = new DatabaseStorage();