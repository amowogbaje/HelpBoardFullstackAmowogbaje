import { pgTable, text, serial, integer, boolean, timestamp, jsonb } from "drizzle-orm/pg-core";
import { createInsertSchema } from "drizzle-zod";
import { z } from "zod";

export const agents = pgTable("agents", {
  id: serial("id").primaryKey(),
  email: text("email").notNull().unique(),
  name: text("name").notNull(),
  password: text("password").notNull(),
  isAvailable: boolean("is_available").default(true),
  createdAt: timestamp("created_at").defaultNow(),
});

export const customers = pgTable("customers", {
  id: serial("id").primaryKey(),
  sessionId: text("session_id").notNull().unique(),
  name: text("name"),
  email: text("email"),
  phone: text("phone"),
  address: text("address"),
  country: text("country"),
  ipAddress: text("ip_address"),
  userAgent: text("user_agent"),
  timezone: text("timezone"),
  language: text("language"),
  platform: text("platform"),
  pageUrl: text("page_url"),
  pageTitle: text("page_title"),
  referrer: text("referrer"),
  isIdentified: boolean("is_identified").default(false),
  lastSeen: timestamp("last_seen").defaultNow(),
  createdAt: timestamp("created_at").defaultNow(),
});

export const conversations = pgTable("conversations", {
  id: serial("id").primaryKey(),
  customerId: integer("customer_id").notNull().references(() => customers.id),
  assignedAgentId: integer("assigned_agent_id").references(() => agents.id),
  status: text("status").notNull().default("open"), // open, assigned, closed
  lastAgentInterventionAt: timestamp("last_agent_intervention_at"),
  createdAt: timestamp("created_at").defaultNow(),
  updatedAt: timestamp("updated_at").defaultNow(),
});

export const messages = pgTable("messages", {
  id: serial("id").primaryKey(),
  conversationId: integer("conversation_id").notNull().references(() => conversations.id),
  senderId: integer("sender_id"), // null for system messages, -1 for AI
  senderType: text("sender_type").notNull(), // customer, agent, system, ai
  content: text("content").notNull(),
  createdAt: timestamp("created_at").defaultNow(),
});

export const sessions = pgTable("sessions", {
  id: text("id").primaryKey(),
  agentId: integer("agent_id").references(() => agents.id),
  customerId: integer("customer_id").references(() => customers.id),
  data: jsonb("data"),
  expiresAt: timestamp("expires_at"),
  createdAt: timestamp("created_at").defaultNow(),
});

// Insert schemas
export const insertAgentSchema = createInsertSchema(agents).omit({
  id: true,
  createdAt: true,
});

export const insertCustomerSchema = createInsertSchema(customers).omit({
  id: true,
  createdAt: true,
  lastSeen: true,
});

export const insertConversationSchema = createInsertSchema(conversations).omit({
  id: true,
  createdAt: true,
  updatedAt: true,
});

export const insertMessageSchema = createInsertSchema(messages).omit({
  id: true,
  createdAt: true,
});

export const insertSessionSchema = createInsertSchema(sessions).omit({
  createdAt: true,
});

// Login schema
export const loginSchema = z.object({
  email: z.string().email(),
  password: z.string().min(1),
});

// Customer initiate schema
export const customerInitiateSchema = z.object({
  name: z.string().optional(),
  email: z.string().email().optional(),
  phone: z.string().optional(),
  address: z.string().optional(),
  country: z.string().optional(),
  timezone: z.string().optional(),
  language: z.string().optional(),
  userAgent: z.string().optional(),
  platform: z.string().optional(),
  pageUrl: z.string().optional(),
  pageTitle: z.string().optional(),
  referrer: z.string().optional(),
});

// Types
export type Agent = typeof agents.$inferSelect;
export type Customer = typeof customers.$inferSelect;
export type Conversation = typeof conversations.$inferSelect;
export type Message = typeof messages.$inferSelect;
export type Session = typeof sessions.$inferSelect;

export type InsertAgent = z.infer<typeof insertAgentSchema>;
export type InsertCustomer = z.infer<typeof insertCustomerSchema>;
export type InsertConversation = z.infer<typeof insertConversationSchema>;
export type InsertMessage = z.infer<typeof insertMessageSchema>;
export type InsertSession = z.infer<typeof insertSessionSchema>;

export type LoginRequest = z.infer<typeof loginSchema>;
export type CustomerInitiateRequest = z.infer<typeof customerInitiateSchema>;
