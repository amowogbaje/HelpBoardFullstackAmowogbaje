import { useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Badge } from "@/components/ui/badge";
import { 
  BarChart3, 
  TrendingUp, 
  MessageSquare, 
  Clock, 
  Users, 
  Bot,
  Target,
  Zap,
  Calendar,
  ThumbsUp,
  ThumbsDown
} from "lucide-react";

export default function Analytics() {
  const [timeRange, setTimeRange] = useState("7d");

  // Mock analytics data
  const analyticsData = {
    overview: {
      totalConversations: 247,
      totalMessages: 1834,
      avgResponseTime: "2.3 minutes",
      aiResolutionRate: "89%",
      customerSatisfaction: "4.6/5",
      activeAgents: 3
    },
    aiPerformance: {
      automationRate: 91,
      avgResponseTime: 1.8,
      successfulResolutions: 156,
      escalations: 18,
      trainingDataUsed: 340,
      modelAccuracy: 94
    },
    conversationMetrics: {
      byHour: [
        { hour: "00:00", conversations: 12, messages: 45 },
        { hour: "01:00", conversations: 8, messages: 32 },
        { hour: "02:00", conversations: 6, messages: 24 },
        { hour: "03:00", conversations: 4, messages: 18 },
        { hour: "04:00", conversations: 3, messages: 12 },
        { hour: "05:00", conversations: 7, messages: 28 },
        { hour: "06:00", conversations: 15, messages: 62 },
        { hour: "07:00", conversations: 23, messages: 89 },
        { hour: "08:00", conversations: 31, messages: 124 },
        { hour: "09:00", conversations: 42, messages: 168 },
        { hour: "10:00", conversations: 38, messages: 152 },
        { hour: "11:00", conversations: 35, messages: 140 },
        { hour: "12:00", conversations: 29, messages: 116 },
        { hour: "13:00", conversations: 33, messages: 132 },
        { hour: "14:00", conversations: 36, messages: 144 },
        { hour: "15:00", conversations: 32, messages: 128 },
        { hour: "16:00", conversations: 28, messages: 112 },
        { hour: "17:00", conversations: 24, messages: 96 },
        { hour: "18:00", conversations: 19, messages: 76 },
        { hour: "19:00", conversations: 16, messages: 64 },
        { hour: "20:00", conversations: 14, messages: 56 },
        { hour: "21:00", conversations: 11, messages: 44 },
        { hour: "22:00", conversations: 9, messages: 36 },
        { hour: "23:00", conversations: 7, messages: 28 }
      ],
      categories: [
        { name: "Billing", count: 89, percentage: 36 },
        { name: "Technical Support", count: 67, percentage: 27 },
        { name: "General Inquiry", count: 45, percentage: 18 },
        { name: "Account Issues", count: 31, percentage: 13 },
        { name: "Product Questions", count: 15, percentage: 6 }
      ]
    },
    sentiment: {
      positive: 156,
      neutral: 67,
      negative: 24,
      totalAnalyzed: 247
    }
  };

  const getSentimentColor = (type: string) => {
    switch (type) {
      case "positive": return "text-green-600";
      case "neutral": return "text-yellow-600";
      case "negative": return "text-red-600";
      default: return "text-slate-600";
    }
  };

  const formatPercentage = (value: number, total: number) => {
    return ((value / total) * 100).toFixed(1);
  };

  return (
    <div className="flex h-screen bg-slate-50">
      <div className="flex-1 p-6 overflow-y-auto">
        <div className="max-w-7xl mx-auto space-y-6">
          {/* Header */}
          <div className="flex items-center justify-between">
            <div>
              <h1 className="text-2xl font-bold text-slate-900 flex items-center">
                <BarChart3 className="h-8 w-8 mr-3 text-primary" />
                Analytics Dashboard
              </h1>
              <p className="text-slate-600 mt-1">
                Track performance metrics and insights across your support operations
              </p>
            </div>
            <Select value={timeRange} onValueChange={setTimeRange}>
              <SelectTrigger className="w-48">
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="24h">Last 24 Hours</SelectItem>
                <SelectItem value="7d">Last 7 Days</SelectItem>
                <SelectItem value="30d">Last 30 Days</SelectItem>
                <SelectItem value="90d">Last 90 Days</SelectItem>
              </SelectContent>
            </Select>
          </div>

          {/* Overview Stats */}
          <div className="grid grid-cols-1 md:grid-cols-6 gap-4">
            <Card>
              <CardContent className="p-4">
                <div className="flex items-center justify-between">
                  <div>
                    <p className="text-sm font-medium text-slate-600">Conversations</p>
                    <p className="text-2xl font-bold text-slate-900">{analyticsData.overview.totalConversations}</p>
                  </div>
                  <MessageSquare className="h-8 w-8 text-blue-500" />
                </div>
              </CardContent>
            </Card>
            
            <Card>
              <CardContent className="p-4">
                <div className="flex items-center justify-between">
                  <div>
                    <p className="text-sm font-medium text-slate-600">Messages</p>
                    <p className="text-2xl font-bold text-slate-900">{analyticsData.overview.totalMessages}</p>
                  </div>
                  <MessageSquare className="h-8 w-8 text-green-500" />
                </div>
              </CardContent>
            </Card>
            
            <Card>
              <CardContent className="p-4">
                <div className="flex items-center justify-between">
                  <div>
                    <p className="text-sm font-medium text-slate-600">Avg Response</p>
                    <p className="text-2xl font-bold text-slate-900">{analyticsData.overview.avgResponseTime}</p>
                  </div>
                  <Clock className="h-8 w-8 text-orange-500" />
                </div>
              </CardContent>
            </Card>
            
            <Card>
              <CardContent className="p-4">
                <div className="flex items-center justify-between">
                  <div>
                    <p className="text-sm font-medium text-slate-600">AI Resolution</p>
                    <p className="text-2xl font-bold text-slate-900">{analyticsData.overview.aiResolutionRate}</p>
                  </div>
                  <Bot className="h-8 w-8 text-purple-500" />
                </div>
              </CardContent>
            </Card>
            
            <Card>
              <CardContent className="p-4">
                <div className="flex items-center justify-between">
                  <div>
                    <p className="text-sm font-medium text-slate-600">Satisfaction</p>
                    <p className="text-2xl font-bold text-slate-900">{analyticsData.overview.customerSatisfaction}</p>
                  </div>
                  <ThumbsUp className="h-8 w-8 text-pink-500" />
                </div>
              </CardContent>
            </Card>
            
            <Card>
              <CardContent className="p-4">
                <div className="flex items-center justify-between">
                  <div>
                    <p className="text-sm font-medium text-slate-600">Active Agents</p>
                    <p className="text-2xl font-bold text-slate-900">{analyticsData.overview.activeAgents}</p>
                  </div>
                  <Users className="h-8 w-8 text-indigo-500" />
                </div>
              </CardContent>
            </Card>
          </div>

          <Tabs defaultValue="conversations" className="space-y-6">
            <TabsList>
              <TabsTrigger value="conversations">Conversations</TabsTrigger>
              <TabsTrigger value="ai-performance">AI Performance</TabsTrigger>
              <TabsTrigger value="sentiment">Sentiment Analysis</TabsTrigger>
            </TabsList>

            <TabsContent value="conversations" className="space-y-6">
              {/* Conversation Volume Chart */}
              <Card>
                <CardHeader>
                  <CardTitle>Conversation Volume by Hour</CardTitle>
                  <CardDescription>
                    Track conversation patterns throughout the day
                  </CardDescription>
                </CardHeader>
                <CardContent>
                  <div className="h-64 flex items-end justify-between space-x-1">
                    {analyticsData.conversationMetrics.byHour.map((item, index) => {
                      const maxConversations = Math.max(...analyticsData.conversationMetrics.byHour.map(h => h.conversations));
                      const height = (item.conversations / maxConversations) * 100;
                      
                      return (
                        <div key={index} className="flex flex-col items-center flex-1">
                          <div
                            className="bg-primary rounded-t-sm w-full transition-all hover:bg-primary/80 cursor-pointer"
                            style={{ height: `${height}%` }}
                            title={`${item.hour}: ${item.conversations} conversations, ${item.messages} messages`}
                          />
                          <span className="text-xs text-slate-500 mt-2 transform -rotate-45 origin-top">
                            {item.hour}
                          </span>
                        </div>
                      );
                    })}
                  </div>
                </CardContent>
              </Card>

              {/* Category Breakdown */}
              <Card>
                <CardHeader>
                  <CardTitle>Conversation Categories</CardTitle>
                  <CardDescription>
                    Most common support topics and their frequency
                  </CardDescription>
                </CardHeader>
                <CardContent>
                  <div className="space-y-4">
                    {analyticsData.conversationMetrics.categories.map((category, index) => (
                      <div key={index} className="flex items-center justify-between">
                        <div className="flex items-center space-x-3">
                          <div className="w-4 h-4 bg-primary rounded-sm" />
                          <span className="font-medium text-slate-900">{category.name}</span>
                        </div>
                        <div className="flex items-center space-x-3">
                          <div className="w-32 bg-slate-200 rounded-full h-2">
                            <div
                              className="bg-primary h-2 rounded-full"
                              style={{ width: `${category.percentage}%` }}
                            />
                          </div>
                          <span className="text-sm text-slate-600 w-12 text-right">
                            {category.count}
                          </span>
                          <span className="text-sm text-slate-500 w-8 text-right">
                            {category.percentage}%
                          </span>
                        </div>
                      </div>
                    ))}
                  </div>
                </CardContent>
              </Card>
            </TabsContent>

            <TabsContent value="ai-performance" className="space-y-6">
              <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
                <Card>
                  <CardHeader>
                    <CardTitle className="flex items-center">
                      <Target className="h-5 w-5 mr-2 text-green-500" />
                      Automation Rate
                    </CardTitle>
                  </CardHeader>
                  <CardContent>
                    <div className="text-center">
                      <div className="text-3xl font-bold text-green-600 mb-2">
                        {analyticsData.aiPerformance.automationRate}%
                      </div>
                      <p className="text-sm text-slate-600">
                        of conversations handled by AI
                      </p>
                    </div>
                  </CardContent>
                </Card>

                <Card>
                  <CardHeader>
                    <CardTitle className="flex items-center">
                      <Zap className="h-5 w-5 mr-2 text-blue-500" />
                      AI Response Time
                    </CardTitle>
                  </CardHeader>
                  <CardContent>
                    <div className="text-center">
                      <div className="text-3xl font-bold text-blue-600 mb-2">
                        {analyticsData.aiPerformance.avgResponseTime}s
                      </div>
                      <p className="text-sm text-slate-600">
                        average AI response time
                      </p>
                    </div>
                  </CardContent>
                </Card>

                <Card>
                  <CardHeader>
                    <CardTitle className="flex items-center">
                      <Bot className="h-5 w-5 mr-2 text-purple-500" />
                      Model Accuracy
                    </CardTitle>
                  </CardHeader>
                  <CardContent>
                    <div className="text-center">
                      <div className="text-3xl font-bold text-purple-600 mb-2">
                        {analyticsData.aiPerformance.modelAccuracy}%
                      </div>
                      <p className="text-sm text-slate-600">
                        prediction accuracy
                      </p>
                    </div>
                  </CardContent>
                </Card>
              </div>

              <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                <Card>
                  <CardHeader>
                    <CardTitle>AI Resolution vs Escalation</CardTitle>
                  </CardHeader>
                  <CardContent>
                    <div className="space-y-4">
                      <div className="flex items-center justify-between">
                        <span className="text-slate-600">Successful Resolutions</span>
                        <div className="flex items-center space-x-2">
                          <div className="w-32 bg-slate-200 rounded-full h-2">
                            <div className="bg-green-500 h-2 rounded-full" style={{ width: '90%' }} />
                          </div>
                          <span className="font-medium">{analyticsData.aiPerformance.successfulResolutions}</span>
                        </div>
                      </div>
                      <div className="flex items-center justify-between">
                        <span className="text-slate-600">Escalations to Human</span>
                        <div className="flex items-center space-x-2">
                          <div className="w-32 bg-slate-200 rounded-full h-2">
                            <div className="bg-orange-500 h-2 rounded-full" style={{ width: '10%' }} />
                          </div>
                          <span className="font-medium">{analyticsData.aiPerformance.escalations}</span>
                        </div>
                      </div>
                    </div>
                  </CardContent>
                </Card>

                <Card>
                  <CardHeader>
                    <CardTitle>Training Data Usage</CardTitle>
                  </CardHeader>
                  <CardContent>
                    <div className="text-center">
                      <div className="text-3xl font-bold text-indigo-600 mb-2">
                        {analyticsData.aiPerformance.trainingDataUsed}
                      </div>
                      <p className="text-sm text-slate-600 mb-4">
                        training examples utilized
                      </p>
                      <Badge className="bg-indigo-100 text-indigo-800">
                        Continuously Learning
                      </Badge>
                    </div>
                  </CardContent>
                </Card>
              </div>
            </TabsContent>

            <TabsContent value="sentiment" className="space-y-6">
              <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                <Card>
                  <CardHeader>
                    <CardTitle>Customer Sentiment Overview</CardTitle>
                    <CardDescription>
                      Sentiment analysis of {analyticsData.sentiment.totalAnalyzed} conversations
                    </CardDescription>
                  </CardHeader>
                  <CardContent>
                    <div className="space-y-4">
                      <div className="flex items-center justify-between">
                        <div className="flex items-center space-x-2">
                          <ThumbsUp className="h-4 w-4 text-green-500" />
                          <span className="text-slate-600">Positive</span>
                        </div>
                        <div className="flex items-center space-x-3">
                          <div className="w-32 bg-slate-200 rounded-full h-2">
                            <div
                              className="bg-green-500 h-2 rounded-full"
                              style={{ width: `${formatPercentage(analyticsData.sentiment.positive, analyticsData.sentiment.totalAnalyzed)}%` }}
                            />
                          </div>
                          <span className="font-medium w-8 text-right">{analyticsData.sentiment.positive}</span>
                          <span className="text-sm text-slate-500 w-12 text-right">
                            {formatPercentage(analyticsData.sentiment.positive, analyticsData.sentiment.totalAnalyzed)}%
                          </span>
                        </div>
                      </div>

                      <div className="flex items-center justify-between">
                        <div className="flex items-center space-x-2">
                          <div className="h-4 w-4 bg-yellow-500 rounded-sm" />
                          <span className="text-slate-600">Neutral</span>
                        </div>
                        <div className="flex items-center space-x-3">
                          <div className="w-32 bg-slate-200 rounded-full h-2">
                            <div
                              className="bg-yellow-500 h-2 rounded-full"
                              style={{ width: `${formatPercentage(analyticsData.sentiment.neutral, analyticsData.sentiment.totalAnalyzed)}%` }}
                            />
                          </div>
                          <span className="font-medium w-8 text-right">{analyticsData.sentiment.neutral}</span>
                          <span className="text-sm text-slate-500 w-12 text-right">
                            {formatPercentage(analyticsData.sentiment.neutral, analyticsData.sentiment.totalAnalyzed)}%
                          </span>
                        </div>
                      </div>

                      <div className="flex items-center justify-between">
                        <div className="flex items-center space-x-2">
                          <ThumbsDown className="h-4 w-4 text-red-500" />
                          <span className="text-slate-600">Negative</span>
                        </div>
                        <div className="flex items-center space-x-3">
                          <div className="w-32 bg-slate-200 rounded-full h-2">
                            <div
                              className="bg-red-500 h-2 rounded-full"
                              style={{ width: `${formatPercentage(analyticsData.sentiment.negative, analyticsData.sentiment.totalAnalyzed)}%` }}
                            />
                          </div>
                          <span className="font-medium w-8 text-right">{analyticsData.sentiment.negative}</span>
                          <span className="text-sm text-slate-500 w-12 text-right">
                            {formatPercentage(analyticsData.sentiment.negative, analyticsData.sentiment.totalAnalyzed)}%
                          </span>
                        </div>
                      </div>
                    </div>
                  </CardContent>
                </Card>

                <Card>
                  <CardHeader>
                    <CardTitle>Sentiment Trends</CardTitle>
                    <CardDescription>
                      Track customer satisfaction over time
                    </CardDescription>
                  </CardHeader>
                  <CardContent>
                    <div className="space-y-4">
                      <div className="text-center">
                        <div className="text-2xl font-bold text-green-600 mb-1">
                          {formatPercentage(analyticsData.sentiment.positive, analyticsData.sentiment.totalAnalyzed)}%
                        </div>
                        <p className="text-sm text-slate-600">Overall Positive Rate</p>
                      </div>
                      
                      <div className="pt-4 border-t border-slate-200">
                        <div className="flex justify-between items-center text-sm">
                          <span className="text-slate-600">Customer Satisfaction Score</span>
                          <span className="font-bold text-slate-900">4.6/5.0</span>
                        </div>
                        <div className="w-full bg-slate-200 rounded-full h-2 mt-2">
                          <div className="bg-green-500 h-2 rounded-full" style={{ width: '92%' }} />
                        </div>
                      </div>
                    </div>
                  </CardContent>
                </Card>
              </div>
            </TabsContent>
          </Tabs>
        </div>
      </div>
    </div>
  );
}