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

export class MemStorage implements IStorage {
  private agents: Map<number, Agent> = new Map();
  private customers: Map<number, Customer> = new Map();
  private conversations: Map<number, Conversation> = new Map();
  private messages: Map<number, Message> = new Map();
  private sessions: Map<string, Session> = new Map();
  private currentId = 1;

  constructor() {
    this.seedData();
  }

  private async seedData() {
    // Create default agent
    const hashedPassword = await bcrypt.hash("password123", 10);
    const agent: Agent = {
      id: this.currentId++,
      email: "agent@helpboard.com",
      name: "Sarah Johnson",
      password: hashedPassword,
      isAvailable: true,
      createdAt: new Date(),
    };
    this.agents.set(agent.id, agent);

    // Create sample customer
    const customer: Customer = {
      id: this.currentId++,
      sessionId: nanoid(),
      name: "Emily Rodriguez",
      email: "emily.rodriguez@email.com",
      phone: "+1 (555) 123-4567",
      address: "123 Main St, San Francisco, CA",
      country: "United States",
      ipAddress: "192.168.1.100",
      userAgent: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)",
      timezone: "America/Los_Angeles",
      language: "en",
      platform: "MacIntel",
      pageUrl: "https://example.com/support",
      pageTitle: "Support - Example.com",
      referrer: "https://google.com",
      isIdentified: true,
      lastSeen: new Date(),
      createdAt: new Date(),
    };
    this.customers.set(customer.id, customer);

    // Create sample conversation
    const conversation: Conversation = {
      id: this.currentId++,
      customerId: customer.id,
      assignedAgentId: null,
      status: "open",
      createdAt: new Date(),
      updatedAt: new Date(),
    };
    this.conversations.set(conversation.id, conversation);

    // Create sample message
    const message: Message = {
      id: this.currentId++,
      conversationId: conversation.id,
      senderId: customer.id,
      senderType: "customer",
      content: "Hi! I'm having trouble with my recent order #12345. I received it yesterday but one of the items was damaged during shipping. Could you help me with a replacement or refund?",
      createdAt: new Date(),
    };
    this.messages.set(message.id, message);
  }

  // Agents
  async getAgent(id: number): Promise<Agent | undefined> {
    return this.agents.get(id);
  }

  async getAgentByEmail(email: string): Promise<Agent | undefined> {
    return Array.from(this.agents.values()).find(agent => agent.email === email);
  }

  async createAgent(insertAgent: InsertAgent): Promise<Agent> {
    const hashedPassword = await bcrypt.hash(insertAgent.password, 10);
    const agent: Agent = {
      ...insertAgent,
      id: this.currentId++,
      password: hashedPassword,
      createdAt: new Date(),
    };
    this.agents.set(agent.id, agent);
    return agent;
  }

  async updateAgentAvailability(id: number, isAvailable: boolean): Promise<Agent | undefined> {
    const agent = this.agents.get(id);
    if (!agent) return undefined;
    
    const updated = { ...agent, isAvailable };
    this.agents.set(id, updated);
    return updated;
  }

  // Customers
  async getCustomer(id: number): Promise<Customer | undefined> {
    return this.customers.get(id);
  }

  async getCustomerBySessionId(sessionId: string): Promise<Customer | undefined> {
    return Array.from(this.customers.values()).find(customer => customer.sessionId === sessionId);
  }

  async getCustomerByEmail(email: string): Promise<Customer | undefined> {
    return Array.from(this.customers.values()).find(customer => customer.email === email);
  }

  async getCustomerByIp(ipAddress: string): Promise<Customer | undefined> {
    return Array.from(this.customers.values()).find(customer => customer.ipAddress === ipAddress);
  }

  async createCustomer(insertCustomer: InsertCustomer): Promise<Customer> {
    const customer: Customer = {
      ...insertCustomer,
      id: this.currentId++,
      lastSeen: new Date(),
      createdAt: new Date(),
    };
    this.customers.set(customer.id, customer);
    return customer;
  }

  async updateCustomer(id: number, updates: Partial<InsertCustomer>): Promise<Customer | undefined> {
    const customer = this.customers.get(id);
    if (!customer) return undefined;
    
    const updated = { ...customer, ...updates, lastSeen: new Date() };
    this.customers.set(id, updated);
    return updated;
  }

  // Conversations
  async getConversations(): Promise<(Conversation & { customer: Customer; assignedAgent?: Agent; lastMessage?: Message; unreadCount: number; messageCount: number })[]> {
    const result = [];
    
    for (const conversation of this.conversations.values()) {
      const customer = this.customers.get(conversation.customerId);
      const assignedAgent = conversation.assignedAgentId ? this.agents.get(conversation.assignedAgentId) : undefined;
      
      const conversationMessages = Array.from(this.messages.values())
        .filter(m => m.conversationId === conversation.id)
        .sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime());
      
      const lastMessage = conversationMessages[0];
      const unreadCount = conversationMessages.filter(m => m.senderType === "customer").length;
      const messageCount = conversationMessages.length;
      
      if (customer) {
        result.push({
          ...conversation,
          customer,
          assignedAgent,
          lastMessage,
          unreadCount,
          messageCount,
        });
      }
    }
    
    return result.sort((a, b) => b.updatedAt.getTime() - a.updatedAt.getTime());
  }

  async getConversation(id: number): Promise<(Conversation & { customer: Customer; messages: (Message & { sender?: Customer | Agent })[] }) | undefined> {
    const conversation = this.conversations.get(id);
    if (!conversation) return undefined;
    
    const customer = this.customers.get(conversation.customerId);
    if (!customer) return undefined;
    
    const conversationMessages = Array.from(this.messages.values())
      .filter(m => m.conversationId === id)
      .sort((a, b) => a.createdAt.getTime() - b.createdAt.getTime());
    
    const messages = conversationMessages.map(message => {
      let sender: Customer | Agent | undefined;
      if (message.senderType === "customer" && message.senderId) {
        sender = this.customers.get(message.senderId);
      } else if (message.senderType === "agent" && message.senderId && message.senderId > 0) {
        sender = this.agents.get(message.senderId);
      } else if (message.senderId === -1) {
        // AI agent
        sender = {
          id: -1,
          name: "HelpBoard AI Assistant",
          email: "ai@helpboard.com",
        } as Agent;
      }
      
      return { ...message, sender };
    });
    
    return {
      ...conversation,
      customer,
      messages,
    };
  }

  async createConversation(insertConversation: InsertConversation): Promise<Conversation> {
    const conversation: Conversation = {
      ...insertConversation,
      id: this.currentId++,
      createdAt: new Date(),
      updatedAt: new Date(),
    };
    this.conversations.set(conversation.id, conversation);
    return conversation;
  }

  async updateConversation(id: number, updates: Partial<InsertConversation>): Promise<Conversation | undefined> {
    const conversation = this.conversations.get(id);
    if (!conversation) return undefined;
    
    const updated = { ...conversation, ...updates, updatedAt: new Date() };
    this.conversations.set(id, updated);
    return updated;
  }

  async assignConversation(id: number, agentId: number): Promise<Conversation | undefined> {
    return this.updateConversation(id, { assignedAgentId: agentId, status: "assigned" });
  }

  async closeConversation(id: number): Promise<Conversation | undefined> {
    return this.updateConversation(id, { status: "closed" });
  }

  // Messages
  async getMessage(id: number): Promise<Message | undefined> {
    return this.messages.get(id);
  }

  async getMessagesByConversation(conversationId: number): Promise<(Message & { sender?: Customer | Agent })[]> {
    const conversationMessages = Array.from(this.messages.values())
      .filter(m => m.conversationId === conversationId)
      .sort((a, b) => a.createdAt.getTime() - b.createdAt.getTime());
    
    return conversationMessages.map(message => {
      let sender: Customer | Agent | undefined;
      if (message.senderType === "customer" && message.senderId) {
        sender = this.customers.get(message.senderId);
      } else if (message.senderType === "agent" && message.senderId && message.senderId > 0) {
        sender = this.agents.get(message.senderId);
      } else if (message.senderId === -1) {
        sender = {
          id: -1,
          name: "HelpBoard AI Assistant",
          email: "ai@helpboard.com",
        } as Agent;
      }
      
      return { ...message, sender };
    });
  }

  async createMessage(insertMessage: InsertMessage): Promise<Message> {
    const message: Message = {
      ...insertMessage,
      id: this.currentId++,
      createdAt: new Date(),
    };
    this.messages.set(message.id, message);
    
    // Update conversation timestamp
    if (this.conversations.has(message.conversationId)) {
      const conversation = this.conversations.get(message.conversationId)!;
      this.conversations.set(message.conversationId, {
        ...conversation,
        updatedAt: new Date(),
      });
    }
    
    return message;
  }

  async getUnreadCount(conversationId: number): Promise<number> {
    return Array.from(this.messages.values())
      .filter(m => m.conversationId === conversationId && m.senderType === "customer")
      .length;
  }

  // Sessions
  async getSession(id: string): Promise<Session | undefined> {
    const session = this.sessions.get(id);
    if (session && session.expiresAt && session.expiresAt < new Date()) {
      this.sessions.delete(id);
      return undefined;
    }
    return session;
  }

  async createSession(insertSession: InsertSession): Promise<Session> {
    const session: Session = {
      ...insertSession,
      createdAt: new Date(),
    };
    this.sessions.set(session.id, session);
    return session;
  }

  async deleteSession(id: string): Promise<void> {
    this.sessions.delete(id);
  }

  // Auth helpers
  async validateAgent(email: string, password: string): Promise<Agent | null> {
    const agent = await this.getAgentByEmail(email);
    if (!agent) return null;
    
    const isValid = await bcrypt.compare(password, agent.password);
    return isValid ? agent : null;
  }
}

export const storage = new MemStorage();
