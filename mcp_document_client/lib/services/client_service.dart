import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Import mcp_client package
import 'package:mcp_client/mcp_client.dart';

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

  // ...remaining code unchanged...
