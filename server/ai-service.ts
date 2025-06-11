import OpenAI from "openai";

// the newest OpenAI model is "gpt-4o" which was released May 13, 2024. do not change this unless explicitly requested by the user
const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
});

interface TrainingData {
  question: string;
  answer: string;
  category: string;
  context?: string;
}

interface AISettings {
  responseDelay: number;
  enableAutoResponse: boolean;
  agentTakeoverThreshold: number;
  maxResponseLength: number;
  temperature: number;
  model: string;
}

export class AIService {
  private conversationHistory: Map<number, Array<{ role: "user" | "assistant"; content: string }>> = new Map();
  private trainingData: TrainingData[] = [];
  private settings: AISettings = {
    responseDelay: 2000, // 2 seconds for natural feel
    enableAutoResponse: true,
    agentTakeoverThreshold: 3, // After 3 failed attempts
    maxResponseLength: 300,
    temperature: 0.7,
    model: "gpt-4o"
  };

  constructor() {
    this.loadDefaultTrainingData();
  }

  private loadDefaultTrainingData() {
    this.trainingData = [
      {
        question: "What are your business hours?",
        answer: "Our customer support team is available 24/7. However, our live agents are typically online Monday through Friday, 9 AM to 6 PM EST. Outside these hours, I'm here to help you with most questions!",
        category: "general"
      },
      {
        question: "How do I reset my password?",
        answer: "To reset your password, click on the 'Forgot Password' link on the login page, enter your email address, and you'll receive a reset link within a few minutes. If you don't see the email, please check your spam folder.",
        category: "account"
      },
      {
        question: "How can I track my order?",
        answer: "You can track your order by logging into your account and visiting the 'My Orders' section. You'll find tracking information and delivery updates there. If you need immediate assistance, please provide your order number.",
        category: "orders"
      },
      {
        question: "What is your refund policy?",
        answer: "We offer a 30-day money-back guarantee on most items. To request a refund, please contact us with your order number and reason for return. Refunds are typically processed within 5-7 business days.",
        category: "billing"
      },
      {
        question: "How do I cancel my subscription?",
        answer: "You can cancel your subscription anytime from your account settings under 'Billing & Subscriptions'. Your access will continue until the end of your current billing period. Would you like me to guide you through the cancellation process?",
        category: "billing"
      }
    ];
  }

  async generateResponse(conversationId: number, customerMessage: string, customerName?: string, customerInfo?: any): Promise<string> {
    try {
      // Get or initialize conversation history
      let history = this.conversationHistory.get(conversationId) || [];
      
      // Add customer message to history
      history.push({ role: "user", content: customerMessage });
      
      // Build context from training data
      const relevantTraining = this.findRelevantTraining(customerMessage);
      const trainingContext = relevantTraining.map(t => `Q: ${t.question}\nA: ${t.answer}`).join('\n\n');
      
      // Enhanced system message with training data
      const systemMessage = {
        role: "system" as const,
        content: `You are an advanced AI customer support assistant for HelpBoard. You handle 90% of customer inquiries autonomously.

PERSONALITY & TONE:
- Be professional, empathetic, and solution-focused
- Use a friendly but efficient tone
- Show genuine care for customer satisfaction
- Be proactive in offering help

KNOWLEDGE BASE:
${trainingContext}

CUSTOMER CONTEXT:
${customerName ? `Customer name: ${customerName}` : 'Anonymous customer'}
${customerInfo?.email ? `Email: ${customerInfo.email}` : ''}
${customerInfo?.country ? `Location: ${customerInfo.country}` : ''}
${customerInfo?.timezone ? `Timezone: ${customerInfo.timezone}` : ''}

GUIDELINES:
1. Always try to solve the customer's problem first
2. Provide specific, actionable solutions
3. If you cannot help, explain why and offer to connect them with a human agent
4. Keep responses under ${this.settings.maxResponseLength} words
5. Ask follow-up questions to better understand complex issues
6. Be proactive about related issues they might face

ESCALATION TRIGGERS:
- Complex technical issues requiring system access
- Billing disputes or refund requests over $100
- Account security concerns
- Customer explicitly requests human agent
- Complaints about service quality

If escalation is needed, say: "I'd like to connect you with one of our specialist agents who can better assist with this specific issue. They'll be with you shortly."`
      };

      // Generate response using GPT-4o
      const completion = await openai.chat.completions.create({
        model: this.settings.model,
        messages: [
          systemMessage,
          ...history.slice(-8), // Keep last 8 messages for context
        ],
        max_tokens: Math.ceil(this.settings.maxResponseLength * 1.5),
        temperature: this.settings.temperature,
      });

      const response = completion.choices[0]?.message?.content || "I apologize, but I'm having trouble processing your request right now. Let me connect you with one of our human agents who can better assist you.";

      // Add AI response to history
      history.push({ role: "assistant", content: response });
      this.conversationHistory.set(conversationId, history);

      return response;
    } catch (error) {
      console.error("AI Service Error:", error);
      return "I'm experiencing some technical difficulties at the moment. Let me connect you with one of our human agents who can help you right away.";
    }
  }

  private findRelevantTraining(customerMessage: string): TrainingData[] {
    const message = customerMessage.toLowerCase();
    return this.trainingData
      .filter(item => {
        const question = item.question.toLowerCase();
        const keywords = question.split(' ');
        return keywords.some(keyword => message.includes(keyword)) || 
               message.includes(item.category);
      })
      .slice(0, 3); // Return top 3 most relevant
  }

  async shouldAIRespond(conversationStatus: string, hasAssignedAgent: boolean, timeSinceLastMessage: number): Promise<boolean> {
    // AI responds immediately for 90% automation
    if (conversationStatus === "closed") return false;
    
    // Allow AI to respond even if agent is assigned (they can take over if needed)
    if (hasAssignedAgent && timeSinceLastMessage < 30000) return false; // Give agent 30s to respond
    
    return this.settings.enableAutoResponse && timeSinceLastMessage >= this.settings.responseDelay;
  }

  // Training management methods
  addTrainingData(question: string, answer: string, category: string, context?: string): void {
    this.trainingData.push({ question, answer, category, context });
  }

  removeTrainingData(index: number): void {
    if (index >= 0 && index < this.trainingData.length) {
      this.trainingData.splice(index, 1);
    }
  }

  updateTrainingData(index: number, data: TrainingData): void {
    if (index >= 0 && index < this.trainingData.length) {
      this.trainingData[index] = data;
    }
  }

  getTrainingData(): TrainingData[] {
    return [...this.trainingData];
  }

  async trainFromConversation(conversationId: number, customerMessages: string[], agentResponses: string[]): Promise<void> {
    if (customerMessages.length !== agentResponses.length) return;
    
    for (let i = 0; i < customerMessages.length; i++) {
      // Only add high-quality training data
      if (agentResponses[i].length > 10 && !agentResponses[i].includes("I don't know")) {
        this.addTrainingData(
          customerMessages[i],
          agentResponses[i],
          "conversation_learned",
          `Learned from conversation ${conversationId}`
        );
      }
    }
  }

  // Settings management
  updateSettings(newSettings: Partial<AISettings>): void {
    this.settings = { ...this.settings, ...newSettings };
  }

  getSettings(): AISettings {
    return { ...this.settings };
  }

  clearHistory(conversationId: number): void {
    this.conversationHistory.delete(conversationId);
  }

  getStats(): { 
    totalExamples: number; 
    conversationPatterns: number; 
    trainingDataCount: number;
    categoriesCount: number;
    averageResponseLength: number;
  } {
    const categories = new Set(this.trainingData.map(t => t.category));
    const avgLength = this.trainingData.reduce((sum, t) => sum + t.answer.length, 0) / this.trainingData.length || 0;
    
    return {
      totalExamples: Array.from(this.conversationHistory.values()).reduce((total, history) => total + history.length, 0),
      conversationPatterns: this.conversationHistory.size,
      trainingDataCount: this.trainingData.length,
      categoriesCount: categories.size,
      averageResponseLength: Math.round(avgLength),
    };
  }

  async analyzeConversationSentiment(messages: string[]): Promise<{ sentiment: string; confidence: number; suggestions: string[] }> {
    try {
      const conversation = messages.join('\n');
      
      const response = await openai.chat.completions.create({
        model: this.settings.model,
        messages: [
          {
            role: "system",
            content: "Analyze the sentiment of this customer support conversation and provide suggestions for improvement. Respond with JSON format: { \"sentiment\": \"positive/neutral/negative\", \"confidence\": 0.0-1.0, \"suggestions\": [\"suggestion1\", \"suggestion2\"] }"
          },
          {
            role: "user",
            content: conversation
          }
        ],
        response_format: { type: "json_object" },
        temperature: 0.3,
      });

      const result = JSON.parse(response.choices[0].message.content || '{}');
      return {
        sentiment: result.sentiment || 'neutral',
        confidence: result.confidence || 0.5,
        suggestions: result.suggestions || []
      };
    } catch (error) {
      console.error("Sentiment analysis error:", error);
      return {
        sentiment: 'neutral',
        confidence: 0.5,
        suggestions: ['Unable to analyze conversation sentiment']
      };
    }
  }
}

export const aiService = new AIService();
