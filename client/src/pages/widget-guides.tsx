import { useState } from "react";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Badge } from "@/components/ui/badge";
import { Separator } from "@/components/ui/separator";
import { Copy, ExternalLink, Code, Palette, Settings, Globe } from "lucide-react";
import { useToast } from "@/hooks/use-toast";

export default function WidgetGuides() {
  const [copiedCode, setCopiedCode] = useState<string>("");
  const { toast } = useToast();

  const copyToClipboard = (code: string, type: string) => {
    navigator.clipboard.writeText(code);
    setCopiedCode(type);
    toast({
      title: "Copied to clipboard",
      description: `${type} code copied successfully`,
      duration: 2000,
    });
    setTimeout(() => setCopiedCode(""), 2000);
  };

  const basicEmbedCode = `<!-- HelpBoard Chat Widget -->
<script>
  (function() {
    var script = document.createElement('script');
    script.src = '${window.location.origin}/widget.js';
    script.async = true;
    script.onload = function() {
      HelpBoard.init({
        apiUrl: '${window.location.origin}',
        theme: 'light',
        position: 'bottom-right',
        companyName: 'Your Company',
        welcomeMessage: 'Hi! How can we help you today?'
      });
    };
    document.head.appendChild(script);
  })();
</script>`;

  const customizedEmbedCode = `<!-- HelpBoard Chat Widget - Customized -->
<script>
  (function() {
    var script = document.createElement('script');
    script.src = '${window.location.origin}/widget.js';
    script.async = true;
    script.onload = function() {
      HelpBoard.init({
        apiUrl: '${window.location.origin}',
        theme: 'dark',
        accentColor: '#3b82f6',
        position: 'bottom-left',
        companyName: 'Acme Corp',
        welcomeMessage: 'Welcome to Acme! Our AI assistant is here to help.',
        embedded: true
      });
    };
    document.head.appendChild(script);
  })();
</script>`;

  const reactEmbedCode = `import { useEffect } from 'react';

function ChatWidget() {
  useEffect(() => {
    // Load HelpBoard widget script
    const script = document.createElement('script');
    script.src = '${window.location.origin}/widget.js';
    script.async = true;
    script.onload = () => {
      window.HelpBoard.init({
        apiUrl: '${window.location.origin}',
        theme: 'light',
        position: 'bottom-right',
        companyName: 'Your Company',
        welcomeMessage: 'Hi! How can we help you today?'
      });
    };
    document.head.appendChild(script);

    return () => {
      // Cleanup on unmount
      const existingScript = document.querySelector('script[src*="widget.js"]');
      if (existingScript) {
        existingScript.remove();
      }
    };
  }, []);

  return null;
}

export default ChatWidget;`;

  const wordpressCode = `// Add this to your theme's functions.php file
function add_helpboard_widget() {
    ?>
    <script>
      (function() {
        var script = document.createElement('script');
        script.src = '${window.location.origin}/widget.js';
        script.async = true;
        script.onload = function() {
          HelpBoard.init({
            apiUrl: '${window.location.origin}',
            theme: 'light',
            position: 'bottom-right',
            companyName: '<?php echo get_bloginfo('name'); ?>',
            welcomeMessage: 'How can we help you today?'
          });
        };
        document.head.appendChild(script);
      })();
    </script>
    <?php
}
add_action('wp_footer', 'add_helpboard_widget');`;

  const shopifyCode = `<!-- Add this to your theme.liquid file before </body> -->
<script>
  (function() {
    var script = document.createElement('script');
    script.src = '${window.location.origin}/widget.js';
    script.async = true;
    script.onload = function() {
      HelpBoard.init({
        apiUrl: '${window.location.origin}',
        theme: 'light',
        position: 'bottom-right',
        companyName: '{{ shop.name }}',
        welcomeMessage: 'Need help with your order? We\\'re here to assist!'
      });
    };
    document.head.appendChild(script);
  })();
</script>`;

  return (
    <div className="flex-1 space-y-6 p-6">
      <div>
        <h1 className="text-3xl font-bold tracking-tight">Widget Embedding Guide</h1>
        <p className="text-muted-foreground mt-2">
          Learn how to embed the HelpBoard chat widget on your website with comprehensive guides and examples.
        </p>
      </div>

      <Tabs defaultValue="basic" className="space-y-4">
        <TabsList className="grid w-full grid-cols-6">
          <TabsTrigger value="basic">Basic Setup</TabsTrigger>
          <TabsTrigger value="custom">Customization</TabsTrigger>
          <TabsTrigger value="react">React</TabsTrigger>
          <TabsTrigger value="wordpress">WordPress</TabsTrigger>
          <TabsTrigger value="shopify">Shopify</TabsTrigger>
          <TabsTrigger value="advanced">Advanced</TabsTrigger>
        </TabsList>

        <TabsContent value="basic" className="space-y-4">
          <Card>
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <Code className="h-5 w-5" />
                Basic Embedding
              </CardTitle>
              <CardDescription>
                The simplest way to add HelpBoard to your website. Just paste this code before the closing &lt;/body&gt; tag.
              </CardDescription>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="relative">
                <pre className="bg-gray-50 p-4 rounded-lg overflow-x-auto text-sm">
                  <code>{basicEmbedCode}</code>
                </pre>
                <Button
                  size="sm"
                  variant="outline"
                  className="absolute top-2 right-2"
                  onClick={() => copyToClipboard(basicEmbedCode, "Basic embed")}
                >
                  <Copy className="h-4 w-4" />
                  {copiedCode === "Basic embed" ? "Copied!" : "Copy"}
                </Button>
              </div>
              
              <div className="space-y-2">
                <h4 className="font-semibold">What this does:</h4>
                <ul className="list-disc list-inside space-y-1 text-sm text-muted-foreground">
                  <li>Loads the HelpBoard widget asynchronously</li>
                  <li>Positions the chat button in the bottom-right corner</li>
                  <li>Uses light theme by default</li>
                  <li>Connects to your HelpBoard dashboard automatically</li>
                </ul>
              </div>
            </CardContent>
          </Card>

          <Card>
            <CardHeader>
              <CardTitle>Quick Start Checklist</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="space-y-3">
                <div className="flex items-center gap-2">
                  <Badge variant="outline">1</Badge>
                  <span className="text-sm">Copy the embed code above</span>
                </div>
                <div className="flex items-center gap-2">
                  <Badge variant="outline">2</Badge>
                  <span className="text-sm">Paste it before the &lt;/body&gt; tag on your website</span>
                </div>
                <div className="flex items-center gap-2">
                  <Badge variant="outline">3</Badge>
                  <span className="text-sm">Test the widget by visiting your website</span>
                </div>
                <div className="flex items-center gap-2">
                  <Badge variant="outline">4</Badge>
                  <span className="text-sm">Monitor conversations in your HelpBoard dashboard</span>
                </div>
              </div>
            </CardContent>
          </Card>
        </TabsContent>

        <TabsContent value="custom" className="space-y-4">
          <Card>
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <Palette className="h-5 w-5" />
                Customization Options
              </CardTitle>
              <CardDescription>
                Customize the widget appearance and behavior to match your brand.
              </CardDescription>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="relative">
                <pre className="bg-gray-50 p-4 rounded-lg overflow-x-auto text-sm">
                  <code>{customizedEmbedCode}</code>
                </pre>
                <Button
                  size="sm"
                  variant="outline"
                  className="absolute top-2 right-2"
                  onClick={() => copyToClipboard(customizedEmbedCode, "Customized embed")}
                >
                  <Copy className="h-4 w-4" />
                  {copiedCode === "Customized embed" ? "Copied!" : "Copy"}
                </Button>
              </div>
            </CardContent>
          </Card>

          <Card>
            <CardHeader>
              <CardTitle>Configuration Options</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="space-y-4">
                <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                  <div className="space-y-2">
                    <h4 className="font-semibold text-sm">theme</h4>
                    <p className="text-xs text-muted-foreground">
                      <code>"light"</code> or <code>"dark"</code>
                    </p>
                  </div>
                  <div className="space-y-2">
                    <h4 className="font-semibold text-sm">accentColor</h4>
                    <p className="text-xs text-muted-foreground">
                      Any valid CSS color (e.g., <code>"#3b82f6"</code>)
                    </p>
                  </div>
                  <div className="space-y-2">
                    <h4 className="font-semibold text-sm">position</h4>
                    <p className="text-xs text-muted-foreground">
                      <code>"bottom-right"</code>, <code>"bottom-left"</code>, <code>"top-right"</code>, <code>"top-left"</code>
                    </p>
                  </div>
                  <div className="space-y-2">
                    <h4 className="font-semibold text-sm">companyName</h4>
                    <p className="text-xs text-muted-foreground">
                      Your company name displayed in the widget
                    </p>
                  </div>
                  <div className="space-y-2">
                    <h4 className="font-semibold text-sm">welcomeMessage</h4>
                    <p className="text-xs text-muted-foreground">
                      First message shown to customers
                    </p>
                  </div>
                  <div className="space-y-2">
                    <h4 className="font-semibold text-sm">embedded</h4>
                    <p className="text-xs text-muted-foreground">
                      Set to <code>true</code> for external websites
                    </p>
                  </div>
                </div>
              </div>
            </CardContent>
          </Card>
        </TabsContent>

        <TabsContent value="react" className="space-y-4">
          <Card>
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <ExternalLink className="h-5 w-5" />
                React Integration
              </CardTitle>
              <CardDescription>
                How to integrate HelpBoard into your React application.
              </CardDescription>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="relative">
                <pre className="bg-gray-50 p-4 rounded-lg overflow-x-auto text-sm">
                  <code>{reactEmbedCode}</code>
                </pre>
                <Button
                  size="sm"
                  variant="outline"
                  className="absolute top-2 right-2"
                  onClick={() => copyToClipboard(reactEmbedCode, "React component")}
                >
                  <Copy className="h-4 w-4" />
                  {copiedCode === "React component" ? "Copied!" : "Copy"}
                </Button>
              </div>

              <div className="space-y-2">
                <h4 className="font-semibold">Usage:</h4>
                <pre className="bg-gray-50 p-2 rounded text-sm">
                  <code>{`import ChatWidget from './ChatWidget';

function App() {
  return (
    <div>
      {/* Your app content */}
      <ChatWidget />
    </div>
  );
}`}</code>
                </pre>
              </div>
            </CardContent>
          </Card>

          <Card>
            <CardHeader>
              <CardTitle>TypeScript Support</CardTitle>
            </CardHeader>
            <CardContent>
              <p className="text-sm text-muted-foreground mb-3">
                Add TypeScript definitions for better development experience:
              </p>
              <div className="relative">
                <pre className="bg-gray-50 p-4 rounded-lg overflow-x-auto text-sm">
                  <code>{`// types/helpboard.d.ts
declare global {
  interface Window {
    HelpBoard: {
      init: (config: {
        apiUrl: string;
        theme?: 'light' | 'dark';
        accentColor?: string;
        position?: 'bottom-right' | 'bottom-left' | 'top-right' | 'top-left';
        companyName?: string;
        welcomeMessage?: string;
        embedded?: boolean;
      }) => void;
    };
  }
}

export {};`}</code>
                </pre>
                <Button
                  size="sm"
                  variant="outline"
                  className="absolute top-2 right-2"
                  onClick={() => copyToClipboard("TypeScript definitions", "TypeScript")}
                >
                  <Copy className="h-4 w-4" />
                  {copiedCode === "TypeScript" ? "Copied!" : "Copy"}
                </Button>
              </div>
            </CardContent>
          </Card>
        </TabsContent>

        <TabsContent value="wordpress" className="space-y-4">
          <Card>
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <Globe className="h-5 w-5" />
                WordPress Integration
              </CardTitle>
              <CardDescription>
                Add HelpBoard to your WordPress website with automatic theme integration.
              </CardDescription>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="relative">
                <pre className="bg-gray-50 p-4 rounded-lg overflow-x-auto text-sm">
                  <code>{wordpressCode}</code>
                </pre>
                <Button
                  size="sm"
                  variant="outline"
                  className="absolute top-2 right-2"
                  onClick={() => copyToClipboard(wordpressCode, "WordPress")}
                >
                  <Copy className="h-4 w-4" />
                  {copiedCode === "WordPress" ? "Copied!" : "Copy"}
                </Button>
              </div>

              <div className="space-y-2">
                <h4 className="font-semibold">Installation Steps:</h4>
                <ol className="list-decimal list-inside space-y-1 text-sm text-muted-foreground">
                  <li>Access your WordPress admin dashboard</li>
                  <li>Go to Appearance → Theme Editor</li>
                  <li>Select functions.php from the file list</li>
                  <li>Add the code above at the end of the file</li>
                  <li>Click "Update File" to save changes</li>
                </ol>
              </div>
            </CardContent>
          </Card>

          <Card>
            <CardHeader>
              <CardTitle>Plugin Alternative</CardTitle>
            </CardHeader>
            <CardContent>
              <p className="text-sm text-muted-foreground mb-3">
                For easier management, you can also use a custom plugin approach:
              </p>
              <div className="space-y-2">
                <ol className="list-decimal list-inside space-y-1 text-sm text-muted-foreground">
                  <li>Create a new file: <code>wp-content/plugins/helpboard-widget/helpboard-widget.php</code></li>
                  <li>Add the plugin header and activation hook</li>
                  <li>Include the widget code in the plugin</li>
                  <li>Activate the plugin from the WordPress admin</li>
                </ol>
              </div>
            </CardContent>
          </Card>
        </TabsContent>

        <TabsContent value="shopify" className="space-y-4">
          <Card>
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <ExternalLink className="h-5 w-5" />
                Shopify Integration
              </CardTitle>
              <CardDescription>
                Add customer support to your Shopify store with order-aware assistance.
              </CardDescription>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="relative">
                <pre className="bg-gray-50 p-4 rounded-lg overflow-x-auto text-sm">
                  <code>{shopifyCode}</code>
                </pre>
                <Button
                  size="sm"
                  variant="outline"
                  className="absolute top-2 right-2"
                  onClick={() => copyToClipboard(shopifyCode, "Shopify")}
                >
                  <Copy className="h-4 w-4" />
                  {copiedCode === "Shopify" ? "Copied!" : "Copy"}
                </Button>
              </div>

              <div className="space-y-2">
                <h4 className="font-semibold">Installation Steps:</h4>
                <ol className="list-decimal list-inside space-y-1 text-sm text-muted-foreground">
                  <li>Go to your Shopify admin → Online Store → Themes</li>
                  <li>Click "Actions" → "Edit code" on your current theme</li>
                  <li>Find and open the theme.liquid file</li>
                  <li>Paste the code above before the closing &lt;/body&gt; tag</li>
                  <li>Click "Save" to publish the changes</li>
                </ol>
              </div>
            </CardContent>
          </Card>

          <Card>
            <CardHeader>
              <CardTitle>E-commerce Features</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="space-y-2">
                <h4 className="font-semibold text-sm">Enhanced for Shopify:</h4>
                <ul className="list-disc list-inside space-y-1 text-sm text-muted-foreground">
                  <li>Automatic store name integration</li>
                  <li>Order-specific customer support</li>
                  <li>Product recommendation capabilities</li>
                  <li>Shipping and return policy assistance</li>
                </ul>
              </div>
            </CardContent>
          </Card>
        </TabsContent>

        <TabsContent value="advanced" className="space-y-4">
          <Card>
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <Settings className="h-5 w-5" />
                Advanced Configuration
              </CardTitle>
              <CardDescription>
                Advanced setup options for enterprise and custom implementations.
              </CardDescription>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="space-y-4">
                <div>
                  <h4 className="font-semibold mb-2">Custom CSS Styling</h4>
                  <pre className="bg-gray-50 p-4 rounded-lg overflow-x-auto text-sm">
                    <code>{`/* Custom CSS for HelpBoard widget */
.helpboard-widget {
  --helpboard-primary: #your-brand-color;
  --helpboard-radius: 8px;
  --helpboard-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
}

.helpboard-widget .chat-button {
  background: var(--helpboard-primary);
  border-radius: var(--helpboard-radius);
  box-shadow: var(--helpboard-shadow);
}`}</code>
                  </pre>
                </div>

                <div>
                  <h4 className="font-semibold mb-2">Event Listeners</h4>
                  <pre className="bg-gray-50 p-4 rounded-lg overflow-x-auto text-sm">
                    <code>{`// Listen for widget events
document.addEventListener('helpboard:ready', function() {
  console.log('HelpBoard widget loaded');
});

document.addEventListener('helpboard:chat-opened', function() {
  // Track chat opens in analytics
  gtag('event', 'chat_opened', {
    event_category: 'engagement'
  });
});

document.addEventListener('helpboard:message-sent', function(event) {
  // Track customer messages
  console.log('Customer message:', event.detail.message);
});`}</code>
                  </pre>
                </div>

                <div>
                  <h4 className="font-semibold mb-2">Conditional Loading</h4>
                  <pre className="bg-gray-50 p-4 rounded-lg overflow-x-auto text-sm">
                    <code>{`// Only load widget on specific pages
if (window.location.pathname.includes('/support') || 
    window.location.pathname.includes('/contact')) {
  // Load HelpBoard widget
  (function() {
    var script = document.createElement('script');
    script.src = '${window.location.origin}/widget.js';
    script.async = true;
    script.onload = function() {
      HelpBoard.init({
        apiUrl: '${window.location.origin}',
        theme: 'light',
        position: 'bottom-right'
      });
    };
    document.head.appendChild(script);
  })();
}`}</code>
                  </pre>
                </div>
              </div>
            </CardContent>
          </Card>

          <Card>
            <CardHeader>
              <CardTitle>Security & Performance</CardTitle>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="space-y-2">
                <h4 className="font-semibold text-sm">Security Best Practices:</h4>
                <ul className="list-disc list-inside space-y-1 text-sm text-muted-foreground">
                  <li>Widget loads over HTTPS automatically</li>
                  <li>Customer data is encrypted in transit</li>
                  <li>No sensitive information stored in browser</li>
                  <li>GDPR compliant by design</li>
                </ul>
              </div>

              <Separator />

              <div className="space-y-2">
                <h4 className="font-semibold text-sm">Performance Features:</h4>
                <ul className="list-disc list-inside space-y-1 text-sm text-muted-foreground">
                  <li>Asynchronous loading prevents blocking</li>
                  <li>Lazy loading of chat interface</li>
                  <li>Optimized for mobile devices</li>
                  <li>Minimal impact on page speed</li>
                </ul>
              </div>
            </CardContent>
          </Card>
        </TabsContent>
      </Tabs>

      <Card>
        <CardHeader>
          <CardTitle>Need Help?</CardTitle>
          <CardDescription>
            Having trouble with the widget integration? We're here to help!
          </CardDescription>
        </CardHeader>
        <CardContent>
          <div className="flex flex-col sm:flex-row gap-4">
            <Button variant="outline" className="flex-1">
              <ExternalLink className="h-4 w-4 mr-2" />
              View Live Demo
            </Button>
            <Button variant="outline" className="flex-1">
              <Code className="h-4 w-4 mr-2" />
              Test Integration
            </Button>
            <Button className="flex-1">
              Contact Support
            </Button>
          </div>
        </CardContent>
      </Card>
    </div>
  );
}