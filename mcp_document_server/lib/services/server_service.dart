import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

// Import MCP server and MCP LLM packages
import 'package:mcp_server/mcp_server.dart' hide Logger;
import 'package:mcp_llm/mcp_llm.dart' hide Logger;

// Local imports
import '../plugins/document_plugin.dart';
import '../plugins/search_plugin.dart';
import '../plugins/resource_plugin.dart';
import 'document_service.dart';

class ServerService {
  // Logger configuration
  final Logger _logger = Logger('ServerService');

  // MCP server-related instances
  Server? _mcpServer;
  LlmServer? _llmServer;

  // MCP plugins
  DocumentPlugin? _documentPlugin;
  SearchPlugin? _searchPlugin;
  ResourcePlugin? _resourcePlugin;

  // Document service
  DocumentService? _documentService;

  // Server status
  bool _isRunning = false;
  String _statusMessage = 'Server not running';
  int _connectedClients = 0;
  List<String> _sessionIds = [];

  // Performance metrics
  Map<String, dynamic> _metrics = {};
  Timer? _metricsTimer;

  // Stream controllers
  final _logStreamController = StreamController<String>.broadcast();
  final _statusStreamController = StreamController<Map<String, dynamic>>.broadcast();

  // Getters
  bool get isRunning => _isRunning;
  String get statusMessage => _statusMessage;
  int get connectedClients => _connectedClients;
  List<String> get sessionIds => _sessionIds;
  Map<String, dynamic> get metrics => _metrics;
  Stream<String> get logStream => _logStreamController.stream;
  Stream<Map<String, dynamic>> get statusStream => _statusStreamController.stream;

  Server? get mcpServer => _mcpServer;
  DocumentService? get documentService => _documentService;

  // Initialize and start the server
  Future<bool> startServer() async {
    if (_isRunning) {
      _logger.warning('Server already running');
      return true;
    }

    try {
      _log('Starting MCP Document Server...');

      // Check API keys
      final openAiApiKey = dotenv.env['OPENAI_API_KEY'];
      final claudeApiKey = dotenv.env['CLAUDE_API_KEY'];

      if ((openAiApiKey == null || openAiApiKey.isEmpty) &&
          (claudeApiKey == null || claudeApiKey.isEmpty)) {
        _log('Error: No API keys found. Please set OPENAI_API_KEY or CLAUDE_API_KEY in .env file');
        return false;
      }

      // 1. Create data directory
      final appDir = await getApplicationDocumentsDirectory();
      final dataDir = Directory(path.join(appDir.path, 'mcp_documents'));
      if (!await dataDir.exists()) {
        await dataDir.create(recursive: true);
      }
      _log('Data directory created: ${dataDir.path}');

      // 2. Initialize DocumentService
      _documentService = DocumentService(dataDir.path);
      await _documentService!.initialize();
      _log('Document service initialized');

      // 3. Create MCP server
      final mcpServer = McpServer.createServer(
        name: 'MCP Document Server',
        version: '1.0.0',
        capabilities: ServerCapabilities(
          tools: true,
          toolsListChanged: true,
          resources: true,
          resourcesListChanged: true,
          prompts: true,
          promptsListChanged: true,
          sampling: true,
        ),
      );
      _log('MCP server created');

      // 4. Initialize LLM
      final McpLlm mcpLlm = McpLlm();

      // Register providers only if API keys are available
      if (openAiApiKey != null && openAiApiKey.isNotEmpty) {
        mcpLlm.registerProvider('openai', OpenAiProviderFactory());
        _log('OpenAI provider registered');
      }

      if (claudeApiKey != null && claudeApiKey.isNotEmpty) {
        mcpLlm.registerProvider('claude', ClaudeProviderFactory());
        _log('Claude provider registered');
      }

      // 5. Create LLM server
      final providerName = openAiApiKey != null && openAiApiKey.isNotEmpty ? 'openai' : 'claude';
      final apiKey = providerName == 'openai' ? openAiApiKey : claudeApiKey;
      final modelName = providerName == 'openai' ? 'gpt-4o' : 'claude-3-sonnet-20240229';

      final llmServer = await mcpLlm.createServer(
        providerName: providerName,
        config: LlmConfiguration(
          apiKey: apiKey!,
          model: modelName,
        ),
      );
      _log('LLM server created with $providerName provider using $modelName model');

      // 6. Connect LlmServer with MCP server
      llmServer.addMcpServer('main', mcpServer);
      _log('LLM server connected to MCP server');

      // 7. Create plugins
      _documentPlugin = DocumentPlugin(documentService: _documentService!);
      _searchPlugin = SearchPlugin(documentService: _documentService!);
      _resourcePlugin = ResourcePlugin();
      _log('Plugins created');

      // 8. Register plugins
      await llmServer.pluginManager.registerPlugin(_documentPlugin!);
      await llmServer.pluginManager.registerPlugin(_searchPlugin!);
      await llmServer.pluginManager.registerPlugin(_resourcePlugin!);
      _log('Plugins registered with LLM server');

      // 9. Register plugin tools with the server
      await llmServer.registerPluginsWithServer(targetServer: mcpServer);
      _log('Plugins registered with MCP server');

      // 10. Configure transport layer
      final port = int.tryParse(dotenv.env['SERVER_PORT'] ?? '8999') ?? 8999;
      final authToken = dotenv.env['MCP_AUTH_TOKEN'];

      final transport = McpServer.createSseTransport(
        endpoint: '/sse',
        messagesEndpoint: '/messages',
        port: port,
        fallbackPorts: [port + 1, port + 2],
        authToken: authToken,
      );
      _log('Transport created on port $port');

      // 11. Set up session connection handlers
      mcpServer.onNotification('session/connected', (params) {
        final sessionId = params['sessionId'] as String;
        _connectedClients++;
        _sessionIds.add(sessionId);
        _log('Client connected: $sessionId');
        _updateStatus();
      });

      mcpServer.onNotification('session/disconnected', (params) {
        final sessionId = params['sessionId'] as String;
        _connectedClients--;
        _sessionIds.remove(sessionId);
        _log('Client disconnected: $sessionId');
        _updateStatus();
      });

      // 12. Set up performance monitoring timer
      _metricsTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        _updateMetrics();
      });

      // 13. Connect server
      _log('Connecting server to transport on port $port...');
      mcpServer.connect(transport);

      // 14. Save server state
      _mcpServer = mcpServer;
      _llmServer = llmServer;
      _isRunning = true;
      _statusMessage = 'Server running on port $port';
      _updateStatus();

      // Log server start details
      final health = mcpServer.getHealth();
      final tools = mcpServer.getTools();
      final resources = mcpServer.getResources();

      final registeredTools = tools.map((t) => t.name).join(', ');
      final registeredResources = resources.map((r) => r.name).join(', ');

      _log('Server started successfully:');
      _log('- Port: $port');
      _log('- Authentication: ${authToken != null ? 'Enabled' : 'Disabled'}');
      _log('- Registered tools: $registeredTools');
      _log('- Registered resources: $registeredResources');
      _log('- Tools count: ${health.registeredTools}');
      _log('- Resources count: ${health.registeredResources}');

      return true;
    } catch (e, stackTrace) {
      _log('Error starting server: $e');
      _log('Stack trace: $stackTrace');
      _statusMessage = 'Server start failed: $e';
      _updateStatus();
      return false;
    }
  }

  // Stop the server
  Future<void> stopServer() async {
    if (!_isRunning || _mcpServer == null) {
      _logger.warning('Server not running');
      return;
    }

    try {
      _log('Stopping server...');

      // Cancel timers
      _metricsTimer?.cancel();

      // Disconnect server
      _mcpServer!.disconnect();

      // Clean up document service
      _documentService?.dispose();
      _documentService = null;

      // Update status
      _isRunning = false;
      _connectedClients = 0;
      _sessionIds = [];
      _statusMessage = 'Server stopped';
      _updateStatus();

      _log('Server stopped');
    } catch (e) {
      _log('Error stopping server: $e');
    }
  }

  // Restart the server
  Future<bool> restartServer() async {
    await stopServer();
    return startServer();
  }

  // Update server status
  void _updateStatus() {
    _statusStreamController.add({
      'isRunning': _isRunning,
      'statusMessage': _statusMessage,
      'connectedClients': _connectedClients,
      'sessionIds': _sessionIds,
    });
  }

  // Update performance metrics
  void _updateMetrics() {
    if (!_isRunning || _mcpServer == null) return;

    try {
      final health = _mcpServer!.getHealth();
      _metrics = health.metrics;

      // Add additional metrics
      _metrics['uptime_hours'] = health.uptime.inHours;
      _metrics['uptime_minutes'] = health.uptime.inMinutes % 60;
      _metrics['connected_clients'] = _connectedClients;
      _metrics['registered_tools'] = health.registeredTools;
      _metrics['registered_resources'] = health.registeredResources;
      _metrics['registered_prompts'] = health.registeredPrompts;

      // Trigger UI update
      _updateStatus();
    } catch (e) {
      _logger.warning('Error updating metrics: $e');
    }
  }

  // Add log message
  void _log(String message) {
    _logger.info(message);
    _logStreamController.add(message);
  }

  // Clean up resources
  void dispose() {
    stopServer();
    _logStreamController.close();
    _statusStreamController.close();
  }
}