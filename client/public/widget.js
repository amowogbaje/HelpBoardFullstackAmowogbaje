(function() {
  'use strict';

  // Prevent multiple initializations
  if (window.HelpBoard) {
    return;
  }

  // Widget configuration
  let config = {};
  let widget = null;
  let isOpen = false;
  let socket = null;
  let sessionId = null;
  let conversationId = null;

  // Generate unique session ID
  function generateSessionId() {
    return Math.random().toString(36).substr(2, 9) + '-' + 
           Math.random().toString(36).substr(2, 9) + '-' + 
           Math.random().toString(36).substr(2, 9);
  }

  // Get customer information from browser
  function getCustomerInfo() {
    return {
      userAgent: navigator.userAgent,
      language: navigator.language,
      platform: navigator.platform,
      timezone: Intl.DateTimeFormat().resolvedOptions().timeZone,
      pageUrl: window.location.href,
      pageTitle: document.title,
      referrer: document.referrer,
      screenResolution: screen.width + 'x' + screen.height
    };
  }

  // Create widget HTML
  function createWidget() {
    const widgetHTML = `
      <div id="helpboard-widget" style="
        position: fixed;
        z-index: 999999;
        font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
        ${getPositionStyles()}
      ">
        <!-- Chat Button -->
        <div id="helpboard-button" style="
          width: 60px;
          height: 60px;
          border-radius: 50%;
          background: ${config.accentColor || '#3b82f6'};
          box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
          cursor: pointer;
          display: flex;
          align-items: center;
          justify-content: center;
          transition: all 0.3s ease;
          border: none;
        ">
          <svg width="24" height="24" fill="white" viewBox="0 0 24 24">
            <path d="M20 2H4c-1.1 0-2 .9-2 2v12c0 1.1.9 2 2 2h4l4 4 4-4h4c1.1 0 2-.9 2-2V4c0-1.1-.9-2-2-2z"/>
          </svg>
        </div>

        <!-- Chat Window -->
        <div id="helpboard-chat" style="
          display: none;
          width: 350px;
          height: 500px;
          background: white;
          border-radius: 12px;
          box-shadow: 0 8px 24px rgba(0, 0, 0, 0.15);
          ${getChatPositionStyles()}
          ${config.theme === 'dark' ? 'background: #1a1a1a; color: white;' : ''}
        ">
          <!-- Header -->
          <div style="
            padding: 16px;
            border-bottom: 1px solid ${config.theme === 'dark' ? '#333' : '#e5e7eb'};
            display: flex;
            align-items: center;
            justify-content: space-between;
            background: ${config.accentColor || '#3b82f6'};
            color: white;
            border-radius: 12px 12px 0 0;
          ">
            <div>
              <h3 style="margin: 0; font-size: 16px; font-weight: 600;">
                ${config.companyName || 'Support'}
              </h3>
              <p style="margin: 0; font-size: 12px; opacity: 0.8;">
                We're here to help
              </p>
            </div>
            <button id="helpboard-close" style="
              background: none;
              border: none;
              color: white;
              cursor: pointer;
              padding: 4px;
              opacity: 0.8;
            ">
              <svg width="16" height="16" fill="currentColor" viewBox="0 0 24 24">
                <path d="M19 6.41L17.59 5 12 10.59 6.41 5 5 6.41 10.59 12 5 17.59 6.41 19 12 13.41 17.59 19 19 17.59 13.41 12z"/>
              </svg>
            </button>
          </div>

          <!-- Messages Area -->
          <div id="helpboard-messages" style="
            height: 360px;
            overflow-y: auto;
            padding: 16px;
            ${config.theme === 'dark' ? 'background: #1a1a1a;' : 'background: #f9fafb;'}
          ">
            <div style="
              background: ${config.theme === 'dark' ? '#333' : 'white'};
              padding: 12px;
              border-radius: 8px;
              margin-bottom: 12px;
              box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
            ">
              <div style="display: flex; align-items: center; margin-bottom: 8px;">
                <div style="
                  width: 24px;
                  height: 24px;
                  background: ${config.accentColor || '#3b82f6'};
                  border-radius: 50%;
                  display: flex;
                  align-items: center;
                  justify-content: center;
                  margin-right: 8px;
                ">
                  <svg width="12" height="12" fill="white" viewBox="0 0 24 24">
                    <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-2 15l-5-5 1.41-1.41L10 14.17l7.59-7.59L19 8l-9 9z"/>
                  </svg>
                </div>
                <span style="font-weight: 600; font-size: 14px;">AI Assistant</span>
              </div>
              <p style="margin: 0; font-size: 14px; line-height: 1.4;">
                ${config.welcomeMessage || 'Hi! How can I help you today?'}
              </p>
            </div>
          </div>

          <!-- Input Area -->
          <div style="
            padding: 16px;
            border-top: 1px solid ${config.theme === 'dark' ? '#333' : '#e5e7eb'};
            ${config.theme === 'dark' ? 'background: #1a1a1a;' : 'background: white;'}
          ">
            <div style="display: flex; gap: 8px;">
              <input
                id="helpboard-input"
                type="text"
                placeholder="Type your message..."
                style="
                  flex: 1;
                  padding: 8px 12px;
                  border: 1px solid ${config.theme === 'dark' ? '#333' : '#d1d5db'};
                  border-radius: 6px;
                  font-size: 14px;
                  outline: none;
                  ${config.theme === 'dark' ? 'background: #333; color: white;' : 'background: white;'}
                "
              />
              <button
                id="helpboard-send"
                style="
                  padding: 8px 16px;
                  background: ${config.accentColor || '#3b82f6'};
                  color: white;
                  border: none;
                  border-radius: 6px;
                  cursor: pointer;
                  font-size: 14px;
                  font-weight: 500;
                "
              >
                Send
              </button>
            </div>
          </div>
        </div>
      </div>
    `;

    document.body.insertAdjacentHTML('beforeend', widgetHTML);
    widget = document.getElementById('helpboard-widget');
    
    // Add event listeners
    setupEventListeners();
  }

  function getPositionStyles() {
    switch (config.position) {
      case 'bottom-left':
        return 'bottom: 20px; left: 20px;';
      case 'top-right':
        return 'top: 20px; right: 20px;';
      case 'top-left':
        return 'top: 20px; left: 20px;';
      default:
        return 'bottom: 20px; right: 20px;';
    }
  }

  function getChatPositionStyles() {
    switch (config.position) {
      case 'bottom-left':
        return 'position: absolute; bottom: 70px; left: 0;';
      case 'top-right':
        return 'position: absolute; top: 70px; right: 0;';
      case 'top-left':
        return 'position: absolute; top: 70px; left: 0;';
      default:
        return 'position: absolute; bottom: 70px; right: 0;';
    }
  }

  function setupEventListeners() {
    // Toggle chat
    document.getElementById('helpboard-button').addEventListener('click', toggleChat);
    document.getElementById('helpboard-close').addEventListener('click', closeChat);
    
    // Send message
    document.getElementById('helpboard-send').addEventListener('click', sendMessage);
    document.getElementById('helpboard-input').addEventListener('keypress', function(e) {
      if (e.key === 'Enter') {
        sendMessage();
      }
    });

    // Dispatch custom events
    document.dispatchEvent(new CustomEvent('helpboard:ready'));
  }

  function toggleChat() {
    if (isOpen) {
      closeChat();
    } else {
      openChat();
    }
  }

  function openChat() {
    document.getElementById('helpboard-chat').style.display = 'block';
    document.getElementById('helpboard-button').style.display = 'none';
    isOpen = true;
    
    // Initialize customer session if not already done
    if (!sessionId) {
      initializeSession();
    }

    document.dispatchEvent(new CustomEvent('helpboard:chat-opened'));
  }

  function closeChat() {
    document.getElementById('helpboard-chat').style.display = 'none';
    document.getElementById('helpboard-button').style.display = 'flex';
    isOpen = false;

    document.dispatchEvent(new CustomEvent('helpboard:chat-closed'));
  }

  function initializeSession() {
    sessionId = generateSessionId();
    connectWebSocket();
  }

  function connectWebSocket() {
    const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
    const wsUrl = `${protocol}//${new URL(config.apiUrl).host}`;
    
    socket = new WebSocket(wsUrl);
    
    socket.onopen = function() {
      // Send customer initialization
      socket.send(JSON.stringify({
        type: 'customer_init',
        sessionId: sessionId,
        customerInfo: getCustomerInfo()
      }));
    };

    socket.onmessage = function(event) {
      const message = JSON.parse(event.data);
      handleWebSocketMessage(message);
    };

    socket.onclose = function() {
      // Attempt to reconnect after 3 seconds
      setTimeout(connectWebSocket, 3000);
    };
  }

  function handleWebSocketMessage(message) {
    switch (message.type) {
      case 'customer_init_success':
        conversationId = message.conversationId;
        break;
      case 'new_message':
        displayMessage(message.message, false);
        break;
      case 'agent_typing':
        showTypingIndicator();
        break;
      case 'agent_stop_typing':
        hideTypingIndicator();
        break;
    }
  }

  function sendMessage() {
    const input = document.getElementById('helpboard-input');
    const messageText = input.value.trim();
    
    if (!messageText || !socket || socket.readyState !== WebSocket.OPEN) {
      return;
    }

    // Display user message
    displayMessage({ content: messageText, senderType: 'customer' }, true);
    
    // Send to server
    socket.send(JSON.stringify({
      type: 'chat_message',
      conversationId: conversationId,
      message: messageText
    }));

    // Clear input
    input.value = '';

    document.dispatchEvent(new CustomEvent('helpboard:message-sent', {
      detail: { message: messageText }
    }));
  }

  function displayMessage(message, isUser) {
    const messagesContainer = document.getElementById('helpboard-messages');
    
    const messageDiv = document.createElement('div');
    messageDiv.style.cssText = `
      background: ${isUser ? (config.accentColor || '#3b82f6') : (config.theme === 'dark' ? '#333' : 'white')};
      color: ${isUser ? 'white' : (config.theme === 'dark' ? 'white' : 'black')};
      padding: 12px;
      border-radius: 8px;
      margin-bottom: 12px;
      margin-left: ${isUser ? '20px' : '0'};
      margin-right: ${isUser ? '0' : '20px'};
      box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
    `;

    const senderIcon = !isUser ? `
      <div style="display: flex; align-items: center; margin-bottom: 8px;">
        <div style="
          width: 24px;
          height: 24px;
          background: ${config.accentColor || '#3b82f6'};
          border-radius: 50%;
          display: flex;
          align-items: center;
          justify-content: center;
          margin-right: 8px;
        ">
          <svg width="12" height="12" fill="white" viewBox="0 0 24 24">
            <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-2 15l-5-5 1.41-1.41L10 14.17l7.59-7.59L19 8l-9 9z"/>
          </svg>
        </div>
        <span style="font-weight: 600; font-size: 14px;">${message.senderType === 'ai' ? 'AI Assistant' : 'Support Agent'}</span>
      </div>
    ` : '';

    messageDiv.innerHTML = `
      ${senderIcon}
      <p style="margin: 0; font-size: 14px; line-height: 1.4;">
        ${message.content}
      </p>
    `;

    messagesContainer.appendChild(messageDiv);
    messagesContainer.scrollTop = messagesContainer.scrollHeight;
  }

  function showTypingIndicator() {
    const messagesContainer = document.getElementById('helpboard-messages');
    const existingIndicator = document.getElementById('typing-indicator');
    
    if (existingIndicator) return;

    const typingDiv = document.createElement('div');
    typingDiv.id = 'typing-indicator';
    typingDiv.style.cssText = `
      background: ${config.theme === 'dark' ? '#333' : 'white'};
      padding: 12px;
      border-radius: 8px;
      margin-bottom: 12px;
      margin-right: 20px;
      box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
    `;

    typingDiv.innerHTML = `
      <div style="display: flex; align-items: center;">
        <div style="
          width: 24px;
          height: 24px;
          background: ${config.accentColor || '#3b82f6'};
          border-radius: 50%;
          display: flex;
          align-items: center;
          justify-content: center;
          margin-right: 8px;
        ">
          <svg width="12" height="12" fill="white" viewBox="0 0 24 24">
            <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-2 15l-5-5 1.41-1.41L10 14.17l7.59-7.59L19 8l-9 9z"/>
          </svg>
        </div>
        <span style="font-style: italic; font-size: 14px; color: #6b7280;">typing...</span>
      </div>
    `;

    messagesContainer.appendChild(typingDiv);
    messagesContainer.scrollTop = messagesContainer.scrollHeight;
  }

  function hideTypingIndicator() {
    const indicator = document.getElementById('typing-indicator');
    if (indicator) {
      indicator.remove();
    }
  }

  // Main HelpBoard object
  window.HelpBoard = {
    init: function(options) {
      config = Object.assign({
        theme: 'light',
        position: 'bottom-right',
        companyName: 'Support',
        welcomeMessage: 'Hi! How can I help you today?',
        embedded: true
      }, options);

      if (!config.apiUrl) {
        console.error('HelpBoard: apiUrl is required');
        return;
      }

      // Wait for DOM to be ready
      if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', createWidget);
      } else {
        createWidget();
      }
    },

    open: openChat,
    close: closeChat,
    toggle: toggleChat,

    // Send a message programmatically
    sendMessage: function(text) {
      if (!socket || socket.readyState !== WebSocket.OPEN) {
        console.warn('HelpBoard: WebSocket not connected');
        return;
      }

      displayMessage({ content: text, senderType: 'customer' }, true);
      socket.send(JSON.stringify({
        type: 'chat_message',
        conversationId: conversationId,
        message: text
      }));
    }
  };

})();