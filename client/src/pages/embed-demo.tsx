import { useState } from "react";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Badge } from "@/components/ui/badge";
import CustomerWidget from "@/components/customer-widget";
import { Code, Copy, ExternalLink, Settings, Palette, MapPin } from "lucide-react";

export default function EmbedDemo() {
  const [widgetConfig, setWidgetConfig] = useState({
    theme: "light",
    accentColor: "#2563EB",
    position: "bottom-right",
    companyName: "Demo Company",
    welcomeMessage: "Hi! How can we help you today?"
  });
  const [showWidget, setShowWidget] = useState(true);

  const generateEmbedCode = () => {
    return `<!-- HelpBoard Chat Widget -->
<script>
  window.HelpBoardConfig = {
    apiUrl: "${window.location.origin}",
    theme: "${widgetConfig.theme}",
    accentColor: "${widgetConfig.accentColor}",
    position: "${widgetConfig.position}",
    companyName: "${widgetConfig.companyName}",
    welcomeMessage: "${widgetConfig.welcomeMessage}"
  };
</script>
<script src="${window.location.origin}/widget.js" async></script>`;
  };

  const generateReactCode = () => {
    return `import CustomerWidget from './CustomerWidget';

function App() {
  return (
    <div>
      {/* Your existing app content */}
      
      <CustomerWidget
        apiUrl="${window.location.origin}"
        theme="${widgetConfig.theme}"
        accentColor="${widgetConfig.accentColor}"
        position="${widgetConfig.position}"
        companyName="${widgetConfig.companyName}"
        welcomeMessage="${widgetConfig.welcomeMessage}"
        embedded={true}
      />
    </div>
  );
}`;
  };

  const copyToClipboard = (text: string) => {
    navigator.clipboard.writeText(text);
  };

  const presetThemes = [
    { name: "Default Blue", color: "#2563EB" },
    { name: "Success Green", color: "#16A34A" },
    { name: "Warning Orange", color: "#EA580C" },
    { name: "Purple", color: "#9333EA" },
    { name: "Pink", color: "#EC4899" },
    { name: "Teal", color: "#0D9488" }
  ];

  return (
    <div className="flex h-screen bg-slate-50">
      <div className="flex-1 p-6 overflow-y-auto">
        <div className="max-w-6xl mx-auto space-y-6">
          {/* Header */}
          <div className="flex items-center justify-between">
            <div>
              <h1 className="text-2xl font-bold text-slate-900 flex items-center">
                <Code className="h-8 w-8 mr-3 text-primary" />
                Widget Embed Demo
              </h1>
              <p className="text-slate-600 mt-1">
                Customize and embed the HelpBoard chat widget on any website
              </p>
            </div>
            <div className="flex space-x-3">
              <Button
                variant="outline"
                onClick={() => setShowWidget(!showWidget)}
              >
                {showWidget ? "Hide Widget" : "Show Widget"}
              </Button>
              <Button>
                <ExternalLink className="h-4 w-4 mr-2" />
                Live Demo
              </Button>
            </div>
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
            {/* Configuration Panel */}
            <div className="space-y-6">
              <Card>
                <CardHeader>
                  <CardTitle className="flex items-center">
                    <Settings className="h-5 w-5 mr-2" />
                    Widget Configuration
                  </CardTitle>
                  <CardDescription>
                    Customize the appearance and behavior of your chat widget
                  </CardDescription>
                </CardHeader>
                <CardContent className="space-y-4">
                  <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                    <div className="space-y-2">
                      <Label htmlFor="theme">Theme</Label>
                      <Select
                        value={widgetConfig.theme}
                        onValueChange={(value) => setWidgetConfig(prev => ({ ...prev, theme: value }))}
                      >
                        <SelectTrigger>
                          <SelectValue />
                        </SelectTrigger>
                        <SelectContent>
                          <SelectItem value="light">Light</SelectItem>
                          <SelectItem value="dark">Dark</SelectItem>
                        </SelectContent>
                      </Select>
                    </div>
                    
                    <div className="space-y-2">
                      <Label htmlFor="position">Position</Label>
                      <Select
                        value={widgetConfig.position}
                        onValueChange={(value) => setWidgetConfig(prev => ({ ...prev, position: value }))}
                      >
                        <SelectTrigger>
                          <SelectValue />
                        </SelectTrigger>
                        <SelectContent>
                          <SelectItem value="bottom-right">Bottom Right</SelectItem>
                          <SelectItem value="bottom-left">Bottom Left</SelectItem>
                          <SelectItem value="top-right">Top Right</SelectItem>
                          <SelectItem value="top-left">Top Left</SelectItem>
                        </SelectContent>
                      </Select>
                    </div>
                  </div>
                  
                  <div className="space-y-2">
                    <Label htmlFor="companyName">Company Name</Label>
                    <Input
                      id="companyName"
                      value={widgetConfig.companyName}
                      onChange={(e) => setWidgetConfig(prev => ({ ...prev, companyName: e.target.value }))}
                      placeholder="Your Company Name"
                    />
                  </div>
                  
                  <div className="space-y-2">
                    <Label htmlFor="welcomeMessage">Welcome Message</Label>
                    <Input
                      id="welcomeMessage"
                      value={widgetConfig.welcomeMessage}
                      onChange={(e) => setWidgetConfig(prev => ({ ...prev, welcomeMessage: e.target.value }))}
                      placeholder="Hi! How can we help you today?"
                    />
                  </div>
                  
                  <div className="space-y-2">
                    <Label className="flex items-center">
                      <Palette className="h-4 w-4 mr-2" />
                      Accent Color
                    </Label>
                    <div className="flex items-center space-x-2">
                      <Input
                        type="color"
                        value={widgetConfig.accentColor}
                        onChange={(e) => setWidgetConfig(prev => ({ ...prev, accentColor: e.target.value }))}
                        className="w-16 h-10 p-1 border rounded"
                      />
                      <Input
                        value={widgetConfig.accentColor}
                        onChange={(e) => setWidgetConfig(prev => ({ ...prev, accentColor: e.target.value }))}
                        placeholder="#2563EB"
                        className="flex-1"
                      />
                    </div>
                    <div className="flex flex-wrap gap-2 mt-2">
                      {presetThemes.map((theme) => (
                        <button
                          key={theme.name}
                          onClick={() => setWidgetConfig(prev => ({ ...prev, accentColor: theme.color }))}
                          className="w-8 h-8 rounded-full border-2 border-slate-200 hover:border-slate-400 transition-colors"
                          style={{ backgroundColor: theme.color }}
                          title={theme.name}
                        />
                      ))}
                    </div>
                  </div>
                </CardContent>
              </Card>

              {/* Preview */}
              <Card>
                <CardHeader>
                  <CardTitle>Live Preview</CardTitle>
                  <CardDescription>
                    See how your widget will look on a website
                  </CardDescription>
                </CardHeader>
                <CardContent>
                  <div className="relative bg-gradient-to-br from-blue-50 to-indigo-100 rounded-lg p-8 min-h-64 overflow-hidden">
                    <div className="text-center text-slate-600">
                      <h3 className="text-lg font-semibold mb-2">Sample Website</h3>
                      <p className="text-sm">This is how your chat widget will appear to visitors</p>
                    </div>
                    
                    {showWidget && (
                      <CustomerWidget
                        {...widgetConfig}
                        embedded={true}
                      />
                    )}
                  </div>
                </CardContent>
              </Card>
            </div>

            {/* Implementation Code */}
            <div className="space-y-6">
              <Tabs defaultValue="html" className="w-full">
                <TabsList className="grid w-full grid-cols-2">
                  <TabsTrigger value="html">HTML/JavaScript</TabsTrigger>
                  <TabsTrigger value="react">React Component</TabsTrigger>
                </TabsList>
                
                <TabsContent value="html" className="space-y-4">
                  <Card>
                    <CardHeader>
                      <CardTitle className="flex items-center justify-between">
                        HTML Embed Code
                        <Button
                          variant="outline"
                          size="sm"
                          onClick={() => copyToClipboard(generateEmbedCode())}
                        >
                          <Copy className="h-4 w-4 mr-2" />
                          Copy
                        </Button>
                      </CardTitle>
                      <CardDescription>
                        Add this code before the closing &lt;/body&gt; tag of your website
                      </CardDescription>
                    </CardHeader>
                    <CardContent>
                      <pre className="bg-slate-900 text-slate-100 p-4 rounded-lg text-sm overflow-x-auto">
                        <code>{generateEmbedCode()}</code>
                      </pre>
                    </CardContent>
                  </Card>
                </TabsContent>
                
                <TabsContent value="react" className="space-y-4">
                  <Card>
                    <CardHeader>
                      <CardTitle className="flex items-center justify-between">
                        React Integration
                        <Button
                          variant="outline"
                          size="sm"
                          onClick={() => copyToClipboard(generateReactCode())}
                        >
                          <Copy className="h-4 w-4 mr-2" />
                          Copy
                        </Button>
                      </CardTitle>
                      <CardDescription>
                        Import and use the CustomerWidget component in your React app
                      </CardDescription>
                    </CardHeader>
                    <CardContent>
                      <pre className="bg-slate-900 text-slate-100 p-4 rounded-lg text-sm overflow-x-auto">
                        <code>{generateReactCode()}</code>
                      </pre>
                    </CardContent>
                  </Card>
                </TabsContent>
              </Tabs>

              {/* Features */}
              <Card>
                <CardHeader>
                  <CardTitle>Widget Features</CardTitle>
                  <CardDescription>
                    What your customers will experience
                  </CardDescription>
                </CardHeader>
                <CardContent>
                  <div className="space-y-3">
                    <div className="flex items-center space-x-3">
                      <Badge className="bg-green-100 text-green-800">
                        AI-Powered
                      </Badge>
                      <span className="text-sm text-slate-600">
                        90% of conversations handled automatically
                      </span>
                    </div>
                    
                    <div className="flex items-center space-x-3">
                      <Badge className="bg-blue-100 text-blue-800">
                        Real-time
                      </Badge>
                      <span className="text-sm text-slate-600">
                        Instant responses with WebSocket connection
                      </span>
                    </div>
                    
                    <div className="flex items-center space-x-3">
                      <Badge className="bg-purple-100 text-purple-800">
                        Typing Indicators
                      </Badge>
                      <span className="text-sm text-slate-600">
                        Shows when AI or agents are responding
                      </span>
                    </div>
                    
                    <div className="flex items-center space-x-3">
                      <Badge className="bg-orange-100 text-orange-800">
                        Mobile Friendly
                      </Badge>
                      <span className="text-sm text-slate-600">
                        Responsive design for all devices
                      </span>
                    </div>
                    
                    <div className="flex items-center space-x-3">
                      <Badge className="bg-indigo-100 text-indigo-800">
                        Customizable
                      </Badge>
                      <span className="text-sm text-slate-600">
                        Match your brand colors and position
                      </span>
                    </div>
                  </div>
                </CardContent>
              </Card>

              {/* Setup Instructions */}
              <Card>
                <CardHeader>
                  <CardTitle>Quick Setup Guide</CardTitle>
                </CardHeader>
                <CardContent>
                  <ol className="space-y-3 text-sm">
                    <li className="flex items-start space-x-3">
                      <span className="flex-shrink-0 w-6 h-6 bg-primary text-white rounded-full flex items-center justify-center text-xs font-medium">
                        1
                      </span>
                      <span className="text-slate-600">
                        Customize the widget appearance using the configuration panel
                      </span>
                    </li>
                    
                    <li className="flex items-start space-x-3">
                      <span className="flex-shrink-0 w-6 h-6 bg-primary text-white rounded-full flex items-center justify-center text-xs font-medium">
                        2
                      </span>
                      <span className="text-slate-600">
                        Copy the embed code for your platform (HTML or React)
                      </span>
                    </li>
                    
                    <li className="flex items-start space-x-3">
                      <span className="flex-shrink-0 w-6 h-6 bg-primary text-white rounded-full flex items-center justify-center text-xs font-medium">
                        3
                      </span>
                      <span className="text-slate-600">
                        Add the code to your website before the closing &lt;/body&gt; tag
                      </span>
                    </li>
                    
                    <li className="flex items-start space-x-3">
                      <span className="flex-shrink-0 w-6 h-6 bg-primary text-white rounded-full flex items-center justify-center text-xs font-medium">
                        4
                      </span>
                      <span className="text-slate-600">
                        Test the widget and train your AI assistant from the dashboard
                      </span>
                    </li>
                  </ol>
                </CardContent>
              </Card>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}