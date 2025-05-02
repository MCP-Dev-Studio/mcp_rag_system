import 'dart:async';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Local imports
import '../models/client_config.dart';
import '../models/chat_message.dart';
import '../widgets/chat_message_widget.dart';
import '../widgets/connection_status_bar.dart';
import 'settings_screen.dart';
import 'tool_list_screen.dart';
import 'resource_list_screen.dart';

// Global service instance
import '../main.dart' show clientService;

class ClientHome extends StatefulWidget {
  const ClientHome({Key? key}) : super(key: key);

  @override
  State<ClientHome> createState() => _ClientHomeState();
}

class _ClientHomeState extends State<ClientHome> {
  final Logger _logger = Logger('ClientHome');

  // Controllers
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // State
  bool _isConnected = false;
  String _connectionStatus = 'Not connected';
  List<ChatMessage> _messages = [];
  bool _isProcessing = false;

  // Stream subscriptions
  StreamSubscription? _statusSubscription;
  StreamSubscription? _messageSubscription;

  @override
  void initState() {
    super.initState();

    // Initialize state
    _isConnected = clientService.isConnected;
    _connectionStatus = clientService.connectionStatus;
    _messages = clientService.chatHistory;

    // Subscribe to status updates
    _statusSubscription = clientService.statusStream.listen((status) {
      setState(() {
        _isConnected = status['isConnected'] as bool;
        _connectionStatus = status['status'] as String;
      });
    });

    // Subscribe to messages
    _messageSubscription = clientService.messageStream.listen((message) {
      setState(() {
        // Check if the message already exists
        if (!_messages.any((msg) => msg.id == message.id)) {
          _messages.add(message);
        }
      });

      // Adjust scroll
      _scrollToBottom();
    });

    // Adjust scroll if there are initial messages
    if (_messages.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _statusSubscription?.cancel();
    _messageSubscription?.cancel();
    super.dispose();
  }

  // Adjust scroll
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // Server connection dialog
  Future<void> _showConnectDialog() async {
    if (_isConnected) {
      // Show menu if already connected
      showModalBottomSheet<void>(
        context: context,
        builder: (BuildContext context) {
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                ListTile(
                  leading: const Icon(Icons.link_off),
                  title: const Text('Disconnect from server'),
                  onTap: () {
                    Navigator.pop(context);
                    _disconnectFromServer();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.refresh),
                  title: const Text('Reconnect to server'),
                  onTap: () {
                    Navigator.pop(context);
                    _reconnectToServer();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.settings),
                  title: const Text('Server settings'),
                  onTap: () {
                    Navigator.pop(context);
                    _openSettings();
                  },
                ),
              ],
            ),
          );
        },
      );
      return;
    }

    // Server URL and authentication settings
    final serverUrlController = TextEditingController();
    final authTokenController = TextEditingController();
    bool autoConnect = false;

    // Load saved settings
    final prefs = await SharedPreferences.getInstance();
    serverUrlController.text = prefs.getString('server_url') ?? '';
    authTokenController.text = prefs.getString('auth_token') ?? '';
    autoConnect = prefs.getBool('auto_connect') ?? false;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Connect to Server'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: serverUrlController,
                    decoration: const InputDecoration(
                      labelText: 'Server URL',
                      hintText: 'e.g. http://localhost:8999/sse',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: authTokenController,
                    decoration: const InputDecoration(
                      labelText: 'Authentication Token (optional)',
                      border: OutlineInputBorder(),
                    ),
                    obscureText: true,
                  ),
                  const SizedBox(height: 16),
                  CheckboxListTile(
                    title: const Text('Auto-connect on startup'),
                    value: autoConnect,
                    onChanged: (value) {
                      setState(() {
                        autoConnect = value ?? false;
                      });
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Connect'),
              ),
            ],
          );
        },
      ),
    );

    if (result != true) return;

    // Validate URL
    if (serverUrlController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Server URL is required')),
      );
      return;
    }

    // Configure connection
    final config = ClientConfig(
      serverUrl: serverUrlController.text,
      authToken: authTokenController.text.isEmpty ? null : authTokenController.text,
      autoConnect: autoConnect,
    );

    // Attempt connection
    setState(() {
      _isProcessing = true;
    });

    try {
      final success = await clientService.connect(config);

      setState(() {
        _isProcessing = false;
      });

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Connected to server')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to connect: ${clientService.connectionStatus}')),
        );
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error connecting to server: $e')),
      );
    }
  }

  // Disconnect from server
  Future<void> _disconnectFromServer() async {
    setState(() {
      _isProcessing = true;
    });

    try {
      await clientService.disconnect();

      setState(() {
        _isProcessing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Disconnected from server')),
      );
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error disconnecting: $e')),
      );
    }
  }

  // Reconnect to server
  Future<void> _reconnectToServer() async {
    // Disconnect first
    await clientService.disconnect();

    // Load saved settings
    final prefs = await SharedPreferences.getInstance();
    final serverUrl = prefs.getString('server_url');
    final authToken = prefs.getString('auth_token');
    final autoConnect = prefs.getBool('auto_connect') ?? false;

    if (serverUrl == null || serverUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No server URL configured')),
      );
      return;
    }

    // Configure connection
    final config = ClientConfig(
      serverUrl: serverUrl,
      authToken: authToken,
      autoConnect: autoConnect,
    );

    // Attempt connection
    setState(() {
      _isProcessing = true;
    });

    try {
      final success = await clientService.connect(config);

      setState(() {
        _isProcessing = false;
      });

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reconnected to server')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to reconnect: ${clientService.connectionStatus}')),
        );
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error reconnecting: $e')),
      );
    }
  }

  // Open settings screen
  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );
  }

  // Open tools list screen
  void _openToolsList() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ToolListScreen()),
    );
  }

  // Open resources list screen
  void _openResourcesList() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ResourceListScreen()),
    );
  }

  // Send message
  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    // Check connection status
    if (!_isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not connected to server')),
      );
      return;
    }

    // Clear message controller
    _messageController.clear();

    // Set processing state
    setState(() {
      _isProcessing = true;
    });

    try {
      // Send message
      await clientService.sendChatMessage(message);

      setState(() {
        _isProcessing = false;
      });
    } catch (e) {
      _logger.severe('Error sending message: $e');

      setState(() {
        _isProcessing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending message: $e')),
      );
    }
  }

  // Clear chat history
  Future<void> _clearChatHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Chat History'),
        content: const Text('Are you sure you want to clear the chat history?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    ) ?? false;

    if (!confirmed) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      await clientService.clearChatHistory();

      setState(() {
        _messages = clientService.chatHistory;
        _isProcessing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chat history cleared')),
      );
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error clearing chat history: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MCP Document Client'),
        actions: [
          if (_isConnected)
            IconButton(
              icon: const Icon(Icons.list),
              tooltip: 'Tools',
              onPressed: _openToolsList,
            ),
          if (_isConnected)
            IconButton(
              icon: const Icon(Icons.folder),
              tooltip: 'Resources',
              onPressed: _openResourcesList,
            ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: _openSettings,
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'connect':
                  _showConnectDialog();
                  break;
                case 'disconnect':
                  _disconnectFromServer();
                  break;
                case 'reconnect':
                  _reconnectToServer();
                  break;
                case 'clear':
                  _clearChatHistory();
                  break;
              }
            },
            itemBuilder: (context) => [
              if (!_isConnected)
                const PopupMenuItem(
                  value: 'connect',
                  child: Text('Connect to server'),
                ),
              if (_isConnected)
                const PopupMenuItem(
                  value: 'disconnect',
                  child: Text('Disconnect'),
                ),
              if (_isConnected)
                const PopupMenuItem(
                  value: 'reconnect',
                  child: Text('Reconnect'),
                ),
              const PopupMenuItem(
                value: 'clear',
                child: Text('Clear chat history'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Connection status bar
          ConnectionStatusBar(
            isConnected: _isConnected,
            status: _connectionStatus,
            onConnect: _showConnectDialog,
          ),

          // Chat area
          Expanded(
            child: _messages.isEmpty
                ? Center(
              child: Text(
                _isConnected
                    ? 'Connected to server. Start chatting!'
                    : 'Connect to a server to start chatting',
                style: const TextStyle(color: Colors.grey),
              ),
            )
                : ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return ChatMessageWidget(message: message);
              },
            ),
          ),

          // Loading indicator
          if (_isProcessing)
            const LinearProgressIndicator(),

          // Message input area
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: _isConnected ? 'Type a message...' : 'Connect to a server...',
                      border: const OutlineInputBorder(),
                    ),
                    enabled: _isConnected && !_isProcessing,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: (_isConnected && !_isProcessing) ? _sendMessage : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}