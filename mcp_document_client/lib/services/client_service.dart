import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Import MCP client package
import 'package:mcp_client/mcp_client.dart' hide Logger;

// Local imports
import '../models/client_config.dart';
import '../models/chat_message.dart';

class ClientService {
  // Logger setup
  final Logger _logger = Logger('ClientService');

  // MCP client instance
  Client? _mcpClient;
  ClientTransport? _transport;

  // Connection status
  bool _isConnected = false;
  String _connectionStatus = 'Not connected';

  // Tools and resources
  List<Tool> _availableTools = [];
  List<Resource> _availableResources = [];

  // Chat history
  List<ChatMessage> _chatHistory = [];

  // Stream controllers
  final _statusStreamController = StreamController<Map<String, dynamic>>.broadcast();
  final _messageStreamController = StreamController<ChatMessage>.broadcast();
  final _toolsStreamController = StreamController<List<Tool>>.broadcast();
  final _resourcesStreamController = StreamController<List<Resource>>.broadcast();

  // Getters
  bool get isConnected => _isConnected;
  String get connectionStatus => _connectionStatus;
  List<Tool> get availableTools => _availableTools;
  List<Resource> get availableResources => _availableResources;
  List<ChatMessage> get chatHistory => _chatHistory;
  Client? get mcpClient => _mcpClient;

  Stream<Map<String, dynamic>> get statusStream => _statusStreamController.stream;
  Stream<ChatMessage> get messageStream => _messageStreamController.stream;
  Stream<List<Tool>> get toolsStream => _toolsStreamController.stream;
  Stream<List<Resource>> get resourcesStream => _resourcesStreamController.stream;

  // Initialization
  Future<void> initialize() async {
    _logger.info('Initializing ClientService');

    // Load chat history
    await _loadChatHistory();
  }

  // Connect to server
  Future<bool> connect(ClientConfig config) async {
    if (_isConnected) {
      _logger.warning('Already connected to server');
      return true;
    }

    try {
      _updateStatus('Connecting to server...', false);
      _logger.info('Connecting to server: ${config.serverUrl}');

      // Create MCP client
      final client = McpClient.createClient(
        name: 'MCP Document Client',
        version: '1.0.0',
        capabilities: ClientCapabilities(
          sampling: true,
        ),
      );

      // Set headers (authentication token)
      Map<String, String>? headers;
      if (config.authToken != null && config.authToken!.isNotEmpty) {
        headers = {'Authorization': 'Bearer ${config.authToken}'};
      }

      // Create transport layer
      final transport = await McpClient.createSseTransport(
        serverUrl: config.serverUrl,
        headers: headers,
      );

      // Connect client
      await client.connectWithRetry(transport, maxRetries: 3);

      // Initialize
      await client.initialize();

      // Fetch tools and resources
      _availableTools = await client.listTools();
      _toolsStreamController.add(_availableTools);

      try {
        _availableResources = await client.listResources();
        _resourcesStreamController.add(_availableResources);
      } catch (e) {
        _logger.warning('Failed to get resources: $e. Resource capability may not be enabled.');
        _availableResources = [];
      }

      // Log server info
      _logger.info('Connected to server: ${config.serverUrl}');
      _logger.info('Available tools: ${_availableTools.map((t) => t.name).join(', ')}');
      _logger.info('Available resources: ${_availableResources.map((r) => r.name).join(', ')}');

      // Register event listeners
      client.onToolsListChanged(() {
        _refreshTools();
      });

      client.onResourcesListChanged(() {
        _refreshResources();
      });

      // Update state
      _mcpClient = client;
      _transport = transport;
      _isConnected = true;
      _connectionStatus = 'Connected to server';
      _updateStatus(_connectionStatus, true);

      // Save settings
      _saveSettings(config);

      // Add system message for successful connection
      _addSystemMessage('Connected to server: ${config.serverUrl}');

      return true;
    } catch (e, stackTrace) {
      _logger.severe('Error connecting to server: $e');
      _logger.severe('Stack trace: $stackTrace');

      _isConnected = false;
      _connectionStatus = 'Connection failed: $e';
      _updateStatus(_connectionStatus, false);

      return false;
    }
  }

  // Disconnect from server
  Future<void> disconnect() async {
    if (!_isConnected || _mcpClient == null) {
      _logger.warning('Not connected to server');
      return;
    }

    try {
      _logger.info('Disconnecting from server');

      // Disconnect client
      _mcpClient!.disconnect();

      // Update state
      _mcpClient = null;
      _transport = null;
      _isConnected = false;
      _connectionStatus = 'Disconnected from server';
      _availableTools = [];
      _availableResources = [];

      _updateStatus(_connectionStatus, false);
      _toolsStreamController.add(_availableTools);
      _resourcesStreamController.add(_availableResources);

      // Add system message for disconnection
      _addSystemMessage('Disconnected from server');

      _logger.info('Disconnected from server');
    } catch (e) {
      _logger.severe('Error disconnecting from server: $e');
    }
  }

  // Refresh tools list
  Future<void> _refreshTools() async {
    if (!_isConnected || _mcpClient == null) return;

    try {
      _availableTools = await _mcpClient!.listTools();
      _toolsStreamController.add(_availableTools);
      _logger.info('Tools list refreshed: ${_availableTools.length} tools available');
    } catch (e) {
      _logger.warning('Error refreshing tools: $e');
    }
  }

  // Refresh resources list
  Future<void> _refreshResources() async {
    if (!_isConnected || _mcpClient == null) return;

    try {
      _availableResources = await _mcpClient!.listResources();
      _resourcesStreamController.add(_availableResources);
      _logger.info('Resources list refreshed: ${_availableResources.length} resources available');
    } catch (e) {
      _logger.warning('Error refreshing resources: $e');
    }
  }

  // Send a chat message
  Future<void> sendChatMessage(String message) async {
    if (!_isConnected || _mcpClient == null) {
      throw Exception('Not connected to server');
    }

    // Add user message to history
    final userMessage = ChatMessage.user(message);
    _addMessage(userMessage);

    try {
      _logger.info('Sending message: $message');

      // Call sampling API if available
      if (_mcpClient!.serverCapabilities?.sampling == true) {
        // Create message request
        final request = CreateMessageRequest(
          messages: [
            Message(
              role: 'user',
              content: TextContent(text: message),
            ),
          ],
        );

        // Request model sampling
        final result = await _mcpClient!.createMessage(request);

        // Process response
        if (result.content is TextContent) {
          final textContent = result.content as TextContent;
          final assistantMessage = ChatMessage.assistant(textContent.text);
          _addMessage(assistantMessage);
          _logger.info('Received assistant response');
        } else {
          _logger.warning('Received non-text response from model');
          _addSystemMessage('Received non-text response from the model');
        }
      } else {
        // Fallback to tool call if sampling is not available
        final toolResult = await _mcpClient!.callTool('chat', {
          'message': message,
        });

        // Process tool response
        if (toolResult.content.isNotEmpty) {
          final content = toolResult.content.first;
          if (content is TextContent) {
            final assistantMessage = ChatMessage.assistant(content.text);
            _addMessage(assistantMessage);
            _logger.info('Received assistant response via tool');
          } else {
            _logger.warning('Received non-text response from tool');
            _addSystemMessage('Received non-text response from the chat tool');
          }
        } else {
          _logger.warning('Received empty response from chat tool');
          _addSystemMessage('Received empty response from the chat tool');
        }
      }
    } catch (e, stackTrace) {
      _logger.severe('Error sending message: $e');
      _logger.severe('Stack trace: $stackTrace');

      // Add error message
      _addMessage(ChatMessage.error('Error sending message: $e'));

      // Rethrow for UI handling
      rethrow;
    }
  }

  // Execute a tool
  Future<void> executeTool(String toolName, Map<String, dynamic> arguments) async {
    if (!_isConnected || _mcpClient == null) {
      throw Exception('Not connected to server');
    }

    // Add tool call message
    final toolCallMessage = ChatMessage.tool(
      toolName,
      'Executing tool: $toolName',
      arguments: arguments,
    );
    _addMessage(toolCallMessage);

    try {
      _logger.info('Executing tool: $toolName with arguments: $arguments');

      // Call the tool
      final result = await _mcpClient!.callTool(toolName, arguments);

      // Process result
      if (result.content.isNotEmpty) {
        final content = result.content.first;
        if (content is TextContent) {
          final toolResultMessage = ChatMessage.tool(toolName, content.text);
          _addMessage(toolResultMessage);
          _logger.info('Received tool result');
        } else {
          _logger.warning('Received non-text response from tool');
          _addSystemMessage('Received non-text response from the tool');
        }
      } else {
        _logger.warning('Received empty response from tool');
        _addSystemMessage('Received empty response from the tool');
      }
    } catch (e, stackTrace) {
      _logger.severe('Error executing tool: $e');
      _logger.severe('Stack trace: $stackTrace');

      // Add error message
      _addMessage(ChatMessage.error('Error executing tool $toolName: $e'));

      // Rethrow for UI handling
      rethrow;
    }
  }

  // Read a resource
  Future<String> readResource(String uri) async {
    if (!_isConnected || _mcpClient == null) {
      throw Exception('Not connected to server');
    }

    try {
      _logger.info('Reading resource: $uri');

      // Read the resource
      final result = await _mcpClient!.readResource(uri);

      // Process result
      if (result.contents.isNotEmpty) {
        for (final content in result.contents) {
          if (content.text != null) {
            _logger.info('Received resource content');
            return content.text!;
          }
        }
      }

      throw Exception('Resource has no text content');
    } catch (e, stackTrace) {
      _logger.severe('Error reading resource: $e');
      _logger.severe('Stack trace: $stackTrace');
      rethrow;
    }
  }

  // Clear chat history
  Future<void> clearChatHistory() async {
    _logger.info('Clearing chat history');

    _chatHistory.clear();

    // Save empty history
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('chat_history', jsonEncode([]));

    // Add system message
    _addSystemMessage('Chat history cleared');
  }

  // Add a message to chat history
  void _addMessage(ChatMessage message) {
    _chatHistory.add(message);
    _messageStreamController.add(message);

    // Save chat history asynchronously
    _saveChatHistory();
  }

  // Add a system message
  void _addSystemMessage(String content) {
    final message = ChatMessage.system(content);
    _addMessage(message);
  }

  // Load chat history from storage
  Future<void> _loadChatHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getString('chat_history');

      if (historyJson != null && historyJson.isNotEmpty) {
        final List<dynamic> historyList = jsonDecode(historyJson);

        _chatHistory = historyList
            .map((item) => ChatMessage.fromJson(item))
            .toList();

        _logger.info('Loaded ${_chatHistory.length} messages from history');
      } else {
        _chatHistory = [];
        _logger.info('No chat history found');
      }
    } catch (e) {
      _logger.warning('Error loading chat history: $e');
      _chatHistory = [];
    }
  }

  // Save chat history to storage
  Future<void> _saveChatHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Limit history size (keep last 100 messages)
      final historyToSave = _chatHistory.length > 100
          ? _chatHistory.sublist(_chatHistory.length - 100)
          : _chatHistory;

      final historyJson = jsonEncode(
        historyToSave.map((msg) => msg.toJson()).toList(),
      );

      await prefs.setString('chat_history', historyJson);
    } catch (e) {
      _logger.warning('Error saving chat history: $e');
    }
  }

  // Save connection settings
  Future<void> _saveSettings(ClientConfig config) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('server_url', config.serverUrl);

      if (config.authToken != null) {
        await prefs.setString('auth_token', config.authToken!);
      }

      await prefs.setBool('auto_connect', config.autoConnect);

      _logger.info('Saved connection settings');
    } catch (e) {
      _logger.warning('Error saving settings: $e');
    }
  }

  // Update connection status
  void _updateStatus(String status, bool isConnected) {
    _connectionStatus = status;
    _isConnected = isConnected;

    _statusStreamController.add({
      'status': status,
      'isConnected': isConnected,
    });
  }

  // Dispose resources
  void dispose() {
    // Close streams
    _statusStreamController.close();
    _messageStreamController.close();
    _toolsStreamController.close();
    _resourcesStreamController.close();

    // Disconnect if connected
    if (_isConnected) {
      disconnect();
    }

    _logger.info('ClientService disposed');
  }
}