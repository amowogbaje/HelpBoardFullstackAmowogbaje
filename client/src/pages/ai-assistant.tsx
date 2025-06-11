import { useState, useEffect } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Switch } from "@/components/ui/switch";
import { Slider } from "@/components/ui/slider";
import { useToast } from "@/hooks/use-toast";
import { apiRequest } from "@/lib/queryClient";
import { 
  Bot, 
  Brain, 
  Settings, 
  Plus, 
  Trash2, 
  Edit, 
  Save, 
  BarChart3,
  MessageSquare,
  Zap,
  Target,
  TrendingUp
} from "lucide-react";

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

interface AIStats {
  totalExamples: number;
  conversationPatterns: number;
  trainingDataCount: number;
  categoriesCount: number;
  averageResponseLength: number;
}

export default function AIAssistant() {
  const [newTraining, setNewTraining] = useState<TrainingData>({
    question: "",
    answer: "",
    category: "general",
    context: ""
  });
  const [editingIndex, setEditingIndex] = useState<number | null>(null);
  const [settings, setSettings] = useState<AISettings>({
    responseDelay: 2000,
    enableAutoResponse: true,
    agentTakeoverThreshold: 3,
    maxResponseLength: 300,
    temperature: 0.7,
    model: "gpt-4o"
  });
  const { toast } = useToast();
  const queryClient = useQueryClient();

  const { data: aiStats } = useQuery<AIStats>({
    queryKey: ["/api/ai/stats"],
    refetchInterval: 10000,
  });

  const { data: trainingData = [], refetch: refetchTraining } = useQuery<TrainingData[]>({
    queryKey: ["/api/ai/training-data"],
  });

  const { data: aiSettings } = useQuery<AISettings>({
    queryKey: ["/api/ai/settings"],
    onSuccess: (data) => {
      if (data) setSettings(data);
    }
  });

  const addTrainingMutation = useMutation({
    mutationFn: async (data: TrainingData) => {
      const response = await apiRequest("POST", "/api/ai/training-data", data);
      return response.json();
    },
    onSuccess: () => {
      toast({ title: "Training data added successfully" });
      setNewTraining({ question: "", answer: "", category: "general", context: "" });
      refetchTraining();
    },
    onError: () => {
      toast({ title: "Failed to add training data", variant: "destructive" });
    }
  });

  const updateTrainingMutation = useMutation({
    mutationFn: async ({ index, data }: { index: number; data: TrainingData }) => {
      const response = await apiRequest("PUT", `/api/ai/training-data/${index}`, data);
      return response.json();
    },
    onSuccess: () => {
      toast({ title: "Training data updated successfully" });
      setEditingIndex(null);
      refetchTraining();
    },
    onError: () => {
      toast({ title: "Failed to update training data", variant: "destructive" });
    }
  });

  const deleteTrainingMutation = useMutation({
    mutationFn: async (index: number) => {
      const response = await apiRequest("DELETE", `/api/ai/training-data/${index}`);
      return response.json();
    },
    onSuccess: () => {
      toast({ title: "Training data deleted successfully" });
      refetchTraining();
    },
    onError: () => {
      toast({ title: "Failed to delete training data", variant: "destructive" });
    }
  });

  const updateSettingsMutation = useMutation({
    mutationFn: async (newSettings: AISettings) => {
      const response = await apiRequest("PUT", "/api/ai/settings", newSettings);
      return response.json();
    },
    onSuccess: () => {
      toast({ title: "AI settings updated successfully" });
      queryClient.invalidateQueries({ queryKey: ["/api/ai/settings"] });
    },
    onError: () => {
      toast({ title: "Failed to update AI settings", variant: "destructive" });
    }
  });

  const retrainMutation = useMutation({
    mutationFn: async () => {
      const response = await apiRequest("POST", "/api/ai/retrain");
      return response.json();
    },
    onSuccess: (data) => {
      toast({ title: "AI retrained successfully", description: data.message });
      queryClient.invalidateQueries({ queryKey: ["/api/ai/stats"] });
    },
    onError: () => {
      toast({ title: "Failed to retrain AI", variant: "destructive" });
    }
  });

  const handleAddTraining = () => {
    if (!newTraining.question.trim() || !newTraining.answer.trim()) {
      toast({ title: "Please fill in question and answer", variant: "destructive" });
      return;
    }
    addTrainingMutation.mutate(newTraining);
  };

  const handleUpdateSettings = () => {
    updateSettingsMutation.mutate(settings);
  };

  const getCategoryColor = (category: string) => {
    const colors = {
      general: "bg-blue-100 text-blue-800",
      account: "bg-green-100 text-green-800",
      orders: "bg-yellow-100 text-yellow-800",
      billing: "bg-red-100 text-red-800",
      technical: "bg-purple-100 text-purple-800",
      conversation_learned: "bg-indigo-100 text-indigo-800"
    };
    return colors[category as keyof typeof colors] || "bg-slate-100 text-slate-800";
  };

  return (
    <div className="flex h-screen bg-slate-50">
      <div className="flex-1 p-6 overflow-y-auto">
        <div className="max-w-6xl mx-auto space-y-6">
          {/* Header */}
          <div className="flex items-center justify-between">
            <div>
              <h1 className="text-2xl font-bold text-slate-900 flex items-center">
                <Bot className="h-8 w-8 mr-3 text-primary" />
                AI Assistant Management
              </h1>
              <p className="text-slate-600 mt-1">
                Train and configure your AI assistant to handle 90% of customer support
              </p>
            </div>
            <Button
              onClick={() => retrainMutation.mutate()}
              disabled={retrainMutation.isPending}
              className="bg-primary hover:bg-primary/90"
            >
              <Brain className="h-4 w-4 mr-2" />
              {retrainMutation.isPending ? "Retraining..." : "Retrain AI"}
            </Button>
          </div>

          {/* Stats Cards */}
          {aiStats && (
            <div className="grid grid-cols-1 md:grid-cols-5 gap-4">
              <Card>
                <CardContent className="p-4">
                  <div className="flex items-center justify-between">
                    <div>
                      <p className="text-sm font-medium text-slate-600">Training Examples</p>
                      <p className="text-2xl font-bold text-slate-900">{aiStats.trainingDataCount}</p>
                    </div>
                    <MessageSquare className="h-8 w-8 text-blue-500" />
                  </div>
                </CardContent>
              </Card>
              
              <Card>
                <CardContent className="p-4">
                  <div className="flex items-center justify-between">
                    <div>
                      <p className="text-sm font-medium text-slate-600">Categories</p>
                      <p className="text-2xl font-bold text-slate-900">{aiStats.categoriesCount}</p>
                    </div>
                    <Target className="h-8 w-8 text-green-500" />
                  </div>
                </CardContent>
              </Card>
              
              <Card>
                <CardContent className="p-4">
                  <div className="flex items-center justify-between">
                    <div>
                      <p className="text-sm font-medium text-slate-600">Conversations</p>
                      <p className="text-2xl font-bold text-slate-900">{aiStats.conversationPatterns}</p>
                    </div>
                    <TrendingUp className="h-8 w-8 text-purple-500" />
                  </div>
                </CardContent>
              </Card>
              
              <Card>
                <CardContent className="p-4">
                  <div className="flex items-center justify-between">
                    <div>
                      <p className="text-sm font-medium text-slate-600">Total Examples</p>
                      <p className="text-2xl font-bold text-slate-900">{aiStats.totalExamples}</p>
                    </div>
                    <BarChart3 className="h-8 w-8 text-orange-500" />
                  </div>
                </CardContent>
              </Card>
              
              <Card>
                <CardContent className="p-4">
                  <div className="flex items-center justify-between">
                    <div>
                      <p className="text-sm font-medium text-slate-600">Avg Length</p>
                      <p className="text-2xl font-bold text-slate-900">{aiStats.averageResponseLength}</p>
                    </div>
                    <Zap className="h-8 w-8 text-red-500" />
                  </div>
                </CardContent>
              </Card>
            </div>
          )}

          <Tabs defaultValue="training" className="space-y-6">
            <TabsList>
              <TabsTrigger value="training">Training Data</TabsTrigger>
              <TabsTrigger value="settings">AI Settings</TabsTrigger>
            </TabsList>

            <TabsContent value="training" className="space-y-6">
              {/* Add New Training Data */}
              <Card>
                <CardHeader>
                  <CardTitle className="flex items-center">
                    <Plus className="h-5 w-5 mr-2" />
                    Add New Training Data
                  </CardTitle>
                  <CardDescription>
                    Train your AI assistant with new question-answer pairs
                  </CardDescription>
                </CardHeader>
                <CardContent className="space-y-4">
                  <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                    <div className="space-y-2">
                      <Label htmlFor="category">Category</Label>
                      <Select
                        value={newTraining.category}
                        onValueChange={(value) => setNewTraining(prev => ({ ...prev, category: value }))}
                      >
                        <SelectTrigger>
                          <SelectValue />
                        </SelectTrigger>
                        <SelectContent>
                          <SelectItem value="general">General</SelectItem>
                          <SelectItem value="account">Account</SelectItem>
                          <SelectItem value="orders">Orders</SelectItem>
                          <SelectItem value="billing">Billing</SelectItem>
                          <SelectItem value="technical">Technical</SelectItem>
                        </SelectContent>
                      </Select>
                    </div>
                    <div className="space-y-2">
                      <Label htmlFor="context">Context (Optional)</Label>
                      <Input
                        id="context"
                        placeholder="Additional context for this training"
                        value={newTraining.context}
                        onChange={(e) => setNewTraining(prev => ({ ...prev, context: e.target.value }))}
                      />
                    </div>
                  </div>
                  
                  <div className="space-y-2">
                    <Label htmlFor="question">Customer Question</Label>
                    <Input
                      id="question"
                      placeholder="What would a customer ask?"
                      value={newTraining.question}
                      onChange={(e) => setNewTraining(prev => ({ ...prev, question: e.target.value }))}
                    />
                  </div>
                  
                  <div className="space-y-2">
                    <Label htmlFor="answer">AI Response</Label>
                    <Textarea
                      id="answer"
                      placeholder="How should the AI respond?"
                      rows={4}
                      value={newTraining.answer}
                      onChange={(e) => setNewTraining(prev => ({ ...prev, answer: e.target.value }))}
                    />
                  </div>
                  
                  <Button 
                    onClick={handleAddTraining}
                    disabled={addTrainingMutation.isPending}
                    className="w-full"
                  >
                    <Plus className="h-4 w-4 mr-2" />
                    {addTrainingMutation.isPending ? "Adding..." : "Add Training Data"}
                  </Button>
                </CardContent>
              </Card>

              {/* Training Data List */}
              <Card>
                <CardHeader>
                  <CardTitle>Training Data ({trainingData.length})</CardTitle>
                  <CardDescription>
                    Manage your AI assistant's knowledge base
                  </CardDescription>
                </CardHeader>
                <CardContent>
                  <div className="space-y-4">
                    {trainingData.map((item, index) => (
                      <div key={index} className="border border-slate-200 rounded-lg p-4">
                        {editingIndex === index ? (
                          <div className="space-y-4">
                            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                              <Select
                                value={item.category}
                                onValueChange={(value) => {
                                  const updated = [...trainingData];
                                  updated[index] = { ...item, category: value };
                                }}
                              >
                                <SelectTrigger>
                                  <SelectValue />
                                </SelectTrigger>
                                <SelectContent>
                                  <SelectItem value="general">General</SelectItem>
                                  <SelectItem value="account">Account</SelectItem>
                                  <SelectItem value="orders">Orders</SelectItem>
                                  <SelectItem value="billing">Billing</SelectItem>
                                  <SelectItem value="technical">Technical</SelectItem>
                                </SelectContent>
                              </Select>
                              <Input
                                placeholder="Context"
                                value={item.context || ""}
                                onChange={(e) => {
                                  const updated = [...trainingData];
                                  updated[index] = { ...item, context: e.target.value };
                                }}
                              />
                            </div>
                            <Input
                              placeholder="Question"
                              value={item.question}
                              onChange={(e) => {
                                const updated = [...trainingData];
                                updated[index] = { ...item, question: e.target.value };
                              }}
                            />
                            <Textarea
                              placeholder="Answer"
                              rows={3}
                              value={item.answer}
                              onChange={(e) => {
                                const updated = [...trainingData];
                                updated[index] = { ...item, answer: e.target.value };
                              }}
                            />
                            <div className="flex space-x-2">
                              <Button
                                size="sm"
                                onClick={() => updateTrainingMutation.mutate({ index, data: item })}
                                disabled={updateTrainingMutation.isPending}
                              >
                                <Save className="h-4 w-4 mr-1" />
                                Save
                              </Button>
                              <Button
                                size="sm"
                                variant="outline"
                                onClick={() => setEditingIndex(null)}
                              >
                                Cancel
                              </Button>
                            </div>
                          </div>
                        ) : (
                          <div>
                            <div className="flex items-start justify-between mb-2">
                              <Badge className={getCategoryColor(item.category)}>
                                {item.category}
                              </Badge>
                              <div className="flex space-x-2">
                                <Button
                                  size="sm"
                                  variant="ghost"
                                  onClick={() => setEditingIndex(index)}
                                >
                                  <Edit className="h-4 w-4" />
                                </Button>
                                <Button
                                  size="sm"
                                  variant="ghost"
                                  onClick={() => deleteTrainingMutation.mutate(index)}
                                  disabled={deleteTrainingMutation.isPending}
                                >
                                  <Trash2 className="h-4 w-4 text-red-500" />
                                </Button>
                              </div>
                            </div>
                            <div className="space-y-2">
                              <p className="font-medium text-slate-900">Q: {item.question}</p>
                              <p className="text-slate-600">A: {item.answer}</p>
                              {item.context && (
                                <p className="text-xs text-slate-500">Context: {item.context}</p>
                              )}
                            </div>
                          </div>
                        )}
                      </div>
                    ))}
                  </div>
                </CardContent>
              </Card>
            </TabsContent>

            <TabsContent value="settings" className="space-y-6">
              <Card>
                <CardHeader>
                  <CardTitle className="flex items-center">
                    <Settings className="h-5 w-5 mr-2" />
                    AI Configuration
                  </CardTitle>
                  <CardDescription>
                    Fine-tune your AI assistant's behavior and performance
                  </CardDescription>
                </CardHeader>
                <CardContent className="space-y-6">
                  <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                    <div className="space-y-4">
                      <div className="flex items-center justify-between">
                        <Label htmlFor="autoResponse">Enable Auto Response</Label>
                        <Switch
                          id="autoResponse"
                          checked={settings.enableAutoResponse}
                          onCheckedChange={(checked) => 
                            setSettings(prev => ({ ...prev, enableAutoResponse: checked }))
                          }
                        />
                      </div>
                      
                      <div className="space-y-2">
                        <Label htmlFor="model">AI Model</Label>
                        <Select
                          value={settings.model}
                          onValueChange={(value) => setSettings(prev => ({ ...prev, model: value }))}
                        >
                          <SelectTrigger>
                            <SelectValue />
                          </SelectTrigger>
                          <SelectContent>
                            <SelectItem value="gpt-4o">GPT-4o (Recommended)</SelectItem>
                            <SelectItem value="gpt-3.5-turbo">GPT-3.5 Turbo</SelectItem>
                          </SelectContent>
                        </Select>
                      </div>
                      
                      <div className="space-y-2">
                        <Label htmlFor="responseDelay">Response Delay (ms): {settings.responseDelay}</Label>
                        <Slider
                          id="responseDelay"
                          min={500}
                          max={5000}
                          step={100}
                          value={[settings.responseDelay]}
                          onValueChange={([value]) => 
                            setSettings(prev => ({ ...prev, responseDelay: value }))
                          }
                        />
                      </div>
                    </div>
                    
                    <div className="space-y-4">
                      <div className="space-y-2">
                        <Label htmlFor="maxLength">Max Response Length: {settings.maxResponseLength}</Label>
                        <Slider
                          id="maxLength"
                          min={100}
                          max={500}
                          step={25}
                          value={[settings.maxResponseLength]}
                          onValueChange={([value]) => 
                            setSettings(prev => ({ ...prev, maxResponseLength: value }))
                          }
                        />
                      </div>
                      
                      <div className="space-y-2">
                        <Label htmlFor="temperature">Creativity (Temperature): {settings.temperature}</Label>
                        <Slider
                          id="temperature"
                          min={0}
                          max={1}
                          step={0.1}
                          value={[settings.temperature]}
                          onValueChange={([value]) => 
                            setSettings(prev => ({ ...prev, temperature: value }))
                          }
                        />
                      </div>
                      
                      <div className="space-y-2">
                        <Label htmlFor="takeover">Agent Takeover Threshold: {settings.agentTakeoverThreshold}</Label>
                        <Slider
                          id="takeover"
                          min={1}
                          max={10}
                          step={1}
                          value={[settings.agentTakeoverThreshold]}
                          onValueChange={([value]) => 
                            setSettings(prev => ({ ...prev, agentTakeoverThreshold: value }))
                          }
                        />
                      </div>
                    </div>
                  </div>
                  
                  <Button 
                    onClick={handleUpdateSettings}
                    disabled={updateSettingsMutation.isPending}
                    className="w-full"
                  >
                    <Save className="h-4 w-4 mr-2" />
                    {updateSettingsMutation.isPending ? "Saving..." : "Save Settings"}
                  </Button>
                </CardContent>
              </Card>
            </TabsContent>
          </Tabs>
        </div>
      </div>
    </div>
  );
}