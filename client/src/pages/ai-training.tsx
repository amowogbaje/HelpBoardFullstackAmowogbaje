import { useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { useToast } from "@/hooks/use-toast";
import { apiRequest } from "@/lib/queryClient";
import { 
  Upload, 
  FileText, 
  MessageSquare, 
  Database, 
  Zap, 
  Download,
  Trash2,
  Brain,
  Target,
  RefreshCw,
  CheckCircle,
  AlertCircle
} from "lucide-react";

export default function AITraining() {
  const { toast } = useToast();
  const queryClient = useQueryClient();

  // State for different training methods
  const [fileContent, setFileContent] = useState("");
  const [fileFormat, setFileFormat] = useState<"csv" | "json" | "txt">("csv");
  const [faqContent, setFaqContent] = useState("");
  const [knowledgeBase, setKnowledgeBase] = useState("");
  const [bulkData, setBulkData] = useState("");

  // File upload training mutation
  const fileTrainingMutation = useMutation({
    mutationFn: async ({ content, format }: { content: string; format: string }) => {
      return await apiRequest("/api/ai/train/file", {
        method: "POST",
        body: JSON.stringify({ content, format }),
      });
    },
    onSuccess: (data) => {
      toast({
        title: "File Training Complete",
        description: `Successfully trained AI with ${data.success} entries`,
      });
      setFileContent("");
      queryClient.invalidateQueries({ queryKey: ["/api/ai/stats"] });
      queryClient.invalidateQueries({ queryKey: ["/api/ai/training-data"] });
    },
    onError: (error: any) => {
      toast({
        title: "Training Failed",
        description: error.message || "Failed to train from file",
        variant: "destructive",
      });
    },
  });

  // FAQ training mutation
  const faqTrainingMutation = useMutation({
    mutationFn: async (faqData: any[]) => {
      return await apiRequest("/api/ai/train/faq", {
        method: "POST",
        body: JSON.stringify({ faqData }),
      });
    },
    onSuccess: (data) => {
      toast({
        title: "FAQ Training Complete",
        description: `Added ${data.count} FAQ entries`,
      });
      setFaqContent("");
      queryClient.invalidateQueries({ queryKey: ["/api/ai/stats"] });
    },
    onError: (error: any) => {
      toast({
        title: "FAQ Training Failed",
        description: error.message || "Failed to import FAQ data",
        variant: "destructive",
      });
    },
  });

  // Knowledge base training mutation
  const knowledgeBaseTrainingMutation = useMutation({
    mutationFn: async (articles: any[]) => {
      return await apiRequest("/api/ai/train/knowledge-base", {
        method: "POST",
        body: JSON.stringify({ articles }),
      });
    },
    onSuccess: (data) => {
      toast({
        title: "Knowledge Base Training Complete",
        description: `Added ${data.count} knowledge entries`,
      });
      setKnowledgeBase("");
      queryClient.invalidateQueries({ queryKey: ["/api/ai/stats"] });
    },
    onError: (error: any) => {
      toast({
        title: "Knowledge Base Training Failed",
        description: error.message || "Failed to train from knowledge base",
        variant: "destructive",
      });
    },
  });

  // Bulk training mutation
  const bulkTrainingMutation = useMutation({
    mutationFn: async (conversations: any[]) => {
      return await apiRequest("/api/ai/train/bulk", {
        method: "POST",
        body: JSON.stringify({ conversations }),
      });
    },
    onSuccess: (data) => {
      toast({
        title: "Bulk Training Complete",
        description: `Trained ${data.count} conversation pairs`,
      });
      setBulkData("");
      queryClient.invalidateQueries({ queryKey: ["/api/ai/stats"] });
    },
    onError: (error: any) => {
      toast({
        title: "Bulk Training Failed",
        description: error.message || "Failed to perform bulk training",
        variant: "destructive",
      });
    },
  });

  // Optimize training data mutation
  const optimizeMutation = useMutation({
    mutationFn: async () => {
      return await apiRequest("/api/ai/optimize", {
        method: "POST",
      });
    },
    onSuccess: (data) => {
      toast({
        title: "Optimization Complete",
        description: `Removed ${data.removed} duplicates, optimized ${data.optimized} entries`,
      });
      queryClient.invalidateQueries({ queryKey: ["/api/ai/stats"] });
      queryClient.invalidateQueries({ queryKey: ["/api/ai/training-data"] });
    },
    onError: (error: any) => {
      toast({
        title: "Optimization Failed",
        description: error.message || "Failed to optimize training data",
        variant: "destructive",
      });
    },
  });

  // Retrain from conversations mutation
  const retrainMutation = useMutation({
    mutationFn: async () => {
      return await apiRequest("/api/ai/retrain", {
        method: "POST",
      });
    },
    onSuccess: (data) => {
      toast({
        title: "Retraining Complete",
        description: `AI retrained with ${data.trainedCount} conversations`,
      });
      queryClient.invalidateQueries({ queryKey: ["/api/ai/stats"] });
    },
    onError: (error: any) => {
      toast({
        title: "Retraining Failed",
        description: error.message || "Failed to retrain AI",
        variant: "destructive",
      });
    },
  });

  // Handle file training
  const handleFileTraining = () => {
    if (!fileContent.trim()) return;
    fileTrainingMutation.mutate({ content: fileContent, format: fileFormat });
  };

  // Handle FAQ training
  const handleFAQTraining = () => {
    if (!faqContent.trim()) return;
    try {
      const faqData = JSON.parse(faqContent);
      faqTrainingMutation.mutate(Array.isArray(faqData) ? faqData : [faqData]);
    } catch (error) {
      toast({
        title: "Invalid JSON",
        description: "Please provide valid JSON format for FAQ data",
        variant: "destructive",
      });
    }
  };

  // Handle knowledge base training
  const handleKnowledgeBaseTraining = () => {
    if (!knowledgeBase.trim()) return;
    try {
      const articles = JSON.parse(knowledgeBase);
      knowledgeBaseTrainingMutation.mutate(Array.isArray(articles) ? articles : [articles]);
    } catch (error) {
      toast({
        title: "Invalid JSON",
        description: "Please provide valid JSON format for knowledge base articles",
        variant: "destructive",
      });
    }
  };

  // Handle bulk training
  const handleBulkTraining = () => {
    if (!bulkData.trim()) return;
    try {
      const conversations = JSON.parse(bulkData);
      bulkTrainingMutation.mutate(Array.isArray(conversations) ? conversations : [conversations]);
    } catch (error) {
      toast({
        title: "Invalid JSON",
        description: "Please provide valid JSON format for bulk conversation data",
        variant: "destructive",
      });
    }
  };

  // Get file format examples
  const getFileFormatExample = () => {
    switch (fileFormat) {
      case "csv":
        return `Question,Answer,Category
"What are your hours?","We are open 9 AM to 6 PM EST","general"
"How do I reset my password?","Click 'Forgot Password' on the login page","account"`;
      case "json":
        return `[
  {
    "question": "What are your hours?",
    "answer": "We are open 9 AM to 6 PM EST",
    "category": "general"
  }
]`;
      case "txt":
        return `Q: What are your hours?
A: We are open 9 AM to 6 PM EST

Q: How do I reset my password?
A: Click 'Forgot Password' on the login page`;
      default:
        return "";
    }
  };

  // Handle export
  const handleExport = (format: "csv" | "json") => {
    const link = document.createElement("a");
    link.href = `/api/ai/export/${format}`;
    link.download = `training-data-${Date.now()}.${format}`;
    link.click();
  };

  return (
    <div className="container mx-auto py-6 space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold">AI Training Center</h1>
          <p className="text-muted-foreground">
            Advanced training methods to enhance AI performance
          </p>
        </div>
        <div className="flex gap-2">
          <Button onClick={() => handleExport("csv")} variant="outline" size="sm">
            <Download className="h-4 w-4 mr-2" />
            Export CSV
          </Button>
          <Button onClick={() => handleExport("json")} variant="outline" size="sm">
            <Download className="h-4 w-4 mr-2" />
            Export JSON
          </Button>
        </div>
      </div>

      <Tabs defaultValue="file" className="space-y-6">
        <TabsList className="grid w-full grid-cols-5">
          <TabsTrigger value="file">File Upload</TabsTrigger>
          <TabsTrigger value="faq">FAQ Import</TabsTrigger>
          <TabsTrigger value="knowledge">Knowledge Base</TabsTrigger>
          <TabsTrigger value="bulk">Bulk Training</TabsTrigger>
          <TabsTrigger value="optimize">Optimize</TabsTrigger>
        </TabsList>

        {/* File Upload Training */}
        <TabsContent value="file" className="space-y-4">
          <Card>
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <Upload className="h-5 w-5" />
                File Upload Training
              </CardTitle>
              <CardDescription>
                Upload CSV, JSON, or TXT files with training data
              </CardDescription>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="space-y-2">
                <Label>File Format</Label>
                <Select value={fileFormat} onValueChange={(value: any) => setFileFormat(value)}>
                  <SelectTrigger>
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="csv">CSV (Question, Answer, Category)</SelectItem>
                    <SelectItem value="json">JSON Array</SelectItem>
                    <SelectItem value="txt">Text (Q: A: format)</SelectItem>
                  </SelectContent>
                </Select>
              </div>
              <div className="space-y-2">
                <Label>File Content</Label>
                <Textarea
                  placeholder={getFileFormatExample()}
                  value={fileContent}
                  onChange={(e) => setFileContent(e.target.value)}
                  rows={8}
                  className="font-mono text-sm"
                />
              </div>
              <Button 
                onClick={handleFileTraining}
                disabled={fileTrainingMutation.isPending || !fileContent.trim()}
                className="w-full"
              >
                {fileTrainingMutation.isPending ? "Processing..." : "Train from File"}
              </Button>
            </CardContent>
          </Card>
        </TabsContent>

        {/* FAQ Training */}
        <TabsContent value="faq" className="space-y-4">
          <Card>
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <MessageSquare className="h-5 w-5" />
                FAQ Training
              </CardTitle>
              <CardDescription>
                Import frequently asked questions and answers
              </CardDescription>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="space-y-2">
                <Label>FAQ Data (JSON Format)</Label>
                <Textarea
                  placeholder={`[
  {
    "question": "What are your business hours?",
    "answer": "We are open 9 AM to 6 PM EST, Monday through Friday",
    "category": "general"
  },
  {
    "question": "How do I contact support?",
    "answer": "You can reach our support team via email at support@company.com or through this chat",
    "category": "support"
  }
]`}
                  value={faqContent}
                  onChange={(e) => setFaqContent(e.target.value)}
                  rows={10}
                  className="font-mono text-sm"
                />
              </div>
              <Button 
                onClick={handleFAQTraining}
                disabled={faqTrainingMutation.isPending || !faqContent.trim()}
                className="w-full"
              >
                {faqTrainingMutation.isPending ? "Importing..." : "Import FAQ Data"}
              </Button>
            </CardContent>
          </Card>
        </TabsContent>

        {/* Knowledge Base Training */}
        <TabsContent value="knowledge" className="space-y-4">
          <Card>
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <Database className="h-5 w-5" />
                Knowledge Base Training
              </CardTitle>
              <CardDescription>
                Train AI from knowledge base articles and documentation
              </CardDescription>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="space-y-2">
                <Label>Knowledge Base Articles (JSON Format)</Label>
                <Textarea
                  placeholder={`[
  {
    "title": "Getting Started Guide",
    "content": "Welcome to our platform. This guide will help you get started with all the basic features. First, create your account by clicking the sign-up button. Then, verify your email address to activate your account.",
    "category": "onboarding"
  },
  {
    "title": "Account Management",
    "content": "You can manage your account settings from the dashboard. Update your profile information, change your password, and configure your preferences in the settings section.",
    "category": "account"
  }
]`}
                  value={knowledgeBase}
                  onChange={(e) => setKnowledgeBase(e.target.value)}
                  rows={10}
                  className="font-mono text-sm"
                />
              </div>
              <Button 
                onClick={handleKnowledgeBaseTraining}
                disabled={knowledgeBaseTrainingMutation.isPending || !knowledgeBase.trim()}
                className="w-full"
              >
                {knowledgeBaseTrainingMutation.isPending ? "Processing..." : "Train from Knowledge Base"}
              </Button>
            </CardContent>
          </Card>
        </TabsContent>

        {/* Bulk Training */}
        <TabsContent value="bulk" className="space-y-4">
          <Card>
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <Brain className="h-5 w-5" />
                Bulk Conversation Training
              </CardTitle>
              <CardDescription>
                Train AI from multiple conversation examples
              </CardDescription>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="space-y-2">
                <Label>Conversation Data (JSON Format)</Label>
                <Textarea
                  placeholder={`[
  {
    "customerMessages": ["Hello", "I need help with my order"],
    "agentResponses": ["Hi! How can I help you today?", "I'd be happy to help you with your order. Can you provide your order number?"]
  },
  {
    "customerMessages": ["What's your refund policy?"],
    "agentResponses": ["We offer a 30-day refund policy for all purchases. You can request a refund through your account dashboard or by contacting our support team."]
  }
]`}
                  value={bulkData}
                  onChange={(e) => setBulkData(e.target.value)}
                  rows={10}
                  className="font-mono text-sm"
                />
              </div>
              <Button 
                onClick={handleBulkTraining}
                disabled={bulkTrainingMutation.isPending || !bulkData.trim()}
                className="w-full"
              >
                {bulkTrainingMutation.isPending ? "Processing..." : "Bulk Train Conversations"}
              </Button>
            </CardContent>
          </Card>
        </TabsContent>

        {/* Optimization Tools */}
        <TabsContent value="optimize" className="space-y-4">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <Card>
              <CardHeader>
                <CardTitle className="flex items-center gap-2">
                  <Target className="h-5 w-5" />
                  Optimize Training Data
                </CardTitle>
                <CardDescription>
                  Remove duplicates and improve data quality
                </CardDescription>
              </CardHeader>
              <CardContent>
                <Button 
                  onClick={() => optimizeMutation.mutate()}
                  disabled={optimizeMutation.isPending}
                  className="w-full"
                >
                  {optimizeMutation.isPending ? "Optimizing..." : "Optimize Training Data"}
                </Button>
              </CardContent>
            </Card>

            <Card>
              <CardHeader>
                <CardTitle className="flex items-center gap-2">
                  <RefreshCw className="h-5 w-5" />
                  Retrain from Conversations
                </CardTitle>
                <CardDescription>
                  Learn from all existing agent-customer conversations
                </CardDescription>
              </CardHeader>
              <CardContent>
                <Button 
                  onClick={() => retrainMutation.mutate()}
                  disabled={retrainMutation.isPending}
                  className="w-full"
                >
                  {retrainMutation.isPending ? "Retraining..." : "Retrain from Conversations"}
                </Button>
              </CardContent>
            </Card>
          </div>

          <Card>
            <CardHeader>
              <CardTitle>Training Guidelines</CardTitle>
            </CardHeader>
            <CardContent className="space-y-3">
              <div className="flex items-start gap-2">
                <CheckCircle className="h-5 w-5 text-green-500 mt-0.5" />
                <div>
                  <p className="font-medium">High-Quality Data</p>
                  <p className="text-sm text-muted-foreground">Use clear, specific questions and comprehensive answers</p>
                </div>
              </div>
              <div className="flex items-start gap-2">
                <CheckCircle className="h-5 w-5 text-green-500 mt-0.5" />
                <div>
                  <p className="font-medium">Consistent Format</p>
                  <p className="text-sm text-muted-foreground">Maintain consistent formatting across all training data</p>
                </div>
              </div>
              <div className="flex items-start gap-2">
                <AlertCircle className="h-5 w-5 text-orange-500 mt-0.5" />
                <div>
                  <p className="font-medium">Regular Updates</p>
                  <p className="text-sm text-muted-foreground">Update training data regularly based on new conversations</p>
                </div>
              </div>
            </CardContent>
          </Card>
        </TabsContent>
      </Tabs>
    </div>
  );
}