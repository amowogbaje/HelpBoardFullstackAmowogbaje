import { useState, useEffect } from "react";
import { useLocation } from "wouter";
import { isAuthenticated, loadAuthFromStorage } from "@/lib/auth";
import { useWebSocket } from "@/hooks/use-websocket";
import Sidebar from "@/components/sidebar";
import ConversationList from "@/components/conversation-list";
import ChatArea from "@/components/chat-area";
import CustomerInfo from "@/components/customer-info";
import CustomerWidget from "@/components/customer-widget";

interface Conversation {
  id: number;
  customerId: number;
  assignedAgentId: number | null;
  status: string;
  createdAt: string;
  updatedAt: string;
  customer: {
    id: number;
    name: string;
    email: string;
    country?: string;
  };
  assignedAgent?: {
    id: number;
    name: string;
  };
  lastMessage?: {
    id: number;
    content: string;
    senderType: string;
    createdAt: string;
  };
  unreadCount: number;
  messageCount: number;
}

export default function Dashboard() {
  const [, setLocation] = useLocation();
  const [selectedConversation, setSelectedConversation] = useState<Conversation | null>(null);
  const { isConnected } = useWebSocket();

  useEffect(() => {
    // Check authentication on mount
    const hasStoredAuth = loadAuthFromStorage();
    if (!hasStoredAuth && !isAuthenticated()) {
      setLocation("/login");
      return;
    }
  }, [setLocation]);

  const handleConversationSelect = (conversation: Conversation) => {
    console.log("Selecting conversation:", conversation);
    setSelectedConversation(conversation);
  };

  if (!isAuthenticated()) {
    return null; // Will redirect to login
  }

  return (
    <div className="flex h-screen bg-slate-50">
      <Sidebar />
      
      <div className="flex-1 flex">
        <ConversationList
          selectedConversationId={selectedConversation?.id}
          onConversationSelect={handleConversationSelect}
        />
        
        <ChatArea conversationId={selectedConversation?.id || null} />
        
        <CustomerInfo customer={selectedConversation?.customer ? {
          ...selectedConversation.customer,
          createdAt: new Date().toISOString()
        } : null} />
      </div>

      {/* Customer Widget for testing */}
      <CustomerWidget />

      {/* Connection status indicator */}
      <div className="fixed top-4 right-4 z-40">
        <div className={`px-3 py-1 rounded-full text-xs font-medium ${
          isConnected 
            ? "bg-green-100 text-green-800" 
            : "bg-red-100 text-red-800"
        }`}>
          {isConnected ? "Connected" : "Disconnected"}
        </div>
      </div>
    </div>
  );
}
