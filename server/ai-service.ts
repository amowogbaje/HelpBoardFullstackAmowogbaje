import OpenAI from "openai";

const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY || process.env.OPENAI_API_KEY_ENV_VAR || "default_key",
});

export class AIService {
  private conversationHistory: Map<number, Array<{ role: "user" | "assistant"; content: string }>> = new Map();

  async generateResponse(conversationId: number, customerMessage: string, customerName?: string): Promise<string> {
    try {
      // Get or initialize conversation history
      let history = this.conversationHistory.get(conversationId) || [];
      
      // Add customer message to history
      history.push({ role: "user", content: customerMessage });
      
      // Prepare system message
      const systemMessage = {
        role: "system" as const,
        content: `You are a helpful customer support assistant for HelpBoard. 
        Be professional, empathetic, and concise. 
        ${customerName ? `The customer's name is ${customerName}.` : ""}
        If you cannot help with a specific issue, politely direct them to a human agent.
        Keep responses under 200 words.`
      };

      // Generate response
      const completion = await openai.chat.completions.create({
        model: "gpt-3.5-turbo",
        messages: [
          systemMessage,
          ...history.slice(-10), // Keep last 10 messages for context
        ],
        max_tokens: 150,
        temperature: 0.7,
      });

      const response = completion.choices[0]?.message?.content || "I apologize, but I'm having trouble processing your request. Let me connect you with a human agent who can better assist you.";

      // Add AI response to history
      history.push({ role: "assistant", content: response });
      this.conversationHistory.set(conversationId, history);

      return response;
    } catch (error) {
      console.error("AI Service Error:", error);
      return "I apologize, but I'm experiencing technical difficulties. Let me connect you with a human agent who can assist you.";
    }
  }

  async shouldAIRespond(conversationStatus: string, hasAssignedAgent: boolean, timeSinceLastMessage: number): Promise<boolean> {
    // AI responds if:
    // 1. Conversation is open (not assigned to human agent)
    // 2. No agent is available
    // 3. Message has been waiting for more than 30 seconds
    
    if (conversationStatus === "closed") return false;
    if (hasAssignedAgent) return false;
    
    const aiResponseDelay = parseInt(process.env.AI_RESPONSE_DELAY || "30000", 10);
    const aiEnabled = process.env.AI_ENABLE_AUTO_RESPONSE !== "false";
    
    return aiEnabled && timeSinceLastMessage > aiResponseDelay;
  }

  clearHistory(conversationId: number): void {
    this.conversationHistory.delete(conversationId);
  }

  getStats(): { totalExamples: number; conversationPatterns: number } {
    return {
      totalExamples: Array.from(this.conversationHistory.values()).reduce((total, history) => total + history.length, 0),
      conversationPatterns: this.conversationHistory.size,
    };
  }
}

export const aiService = new AIService();
