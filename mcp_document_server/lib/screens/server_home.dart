import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:logging/logging.dart';
import 'package:mcp_llm/mcp_llm.dart' hide Logger;

// Local imports
import 'document_list_screen.dart';
import 'settings_screen.dart';
import 'document_details.dart';
import '../widgets/server_status_bar.dart';
import '../widgets/log_console.dart';
import '../widgets/document_card.dart';

// Global service instance
import '../main.dart' show serverService;

class ServerHome extends StatefulWidget {
  const ServerHome({Key? key}) : super(key: key);

  @override
  State<ServerHome> createState() => _ServerHomeState();
}

class _ServerHomeState extends State<ServerHome> with SingleTickerProviderStateMixin {
  final Logger _logger = Logger('ServerHome');

  // Tab controller
  late TabController _tabController;

  // Server status
  bool _isServerRunning = false;
  String _serverStatus = 'Server not running';
  int _connectedClients = 0;

  // Document-related
  List<Document> _recentDocuments = [];
  bool _isLoadingDocuments = false;

  // Stream subscriptions
  StreamSubscription? _serverStatusSubscription;
  StreamSubscription? _documentsSubscription;

  // Log controller
  final ScrollController _logScrollController = ScrollController();
  List<String> _logMessages = [];

  @override
  void initState() {
    super.initState();

    // Initialize tab controller
    _tabController = TabController(length: 3, vsync: this);

    // Subscribe to server status
    _serverStatusSubscription = serverService.statusStream.listen((status) {
      setState(() {
        _isServerRunning = status['isRunning'] as bool;
        _serverStatus = status['statusMessage'] as String;
        _connectedClients = status['connectedClients'] as int;
      });
    });

    // Subscribe to log stream
    serverService.logStream.listen((log) {
      setState(() {
        _logMessages.add(log);
        if (_logMessages.length > 1000) {
          _logMessages.removeRange(0, _logMessages.length - 1000);
        }
      });

      // Adjust log scroll
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_logScrollController.hasClients) {
          _logScrollController.animateTo(
            _logScrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    });

    // Load documents
    _loadDocuments();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _serverStatusSubscription?.cancel();
    _documentsSubscription?.cancel();
    _logScrollController.dispose();
    super.dispose();
  }

  // Load documents
  Future<void> _loadDocuments() async {
    if (!_isServerRunning || serverService.documentService == null) {
      setState(() {
        _recentDocuments = [];
      });
      return;
    }

    setState(() {
      _isLoadingDocuments = true;
    });

    try {
      // Subscribe to document service stream
      _documentsSubscription?.cancel();
      _documentsSubscription = serverService.documentService!.documentsStream.listen((documents) {
        setState(() {
          // Sort documents by latest
          final sortedDocs = List<Document>.from(documents);
          sortedDocs.sort((a, b) {
            final aTime = _getDocumentTimestamp(a);
            final bTime = _getDocumentTimestamp(b);
            return bTime.compareTo(aTime); // Descending order (latest first)
          });

          // Get recent documents
          _recentDocuments = sortedDocs.take(5).toList();
          _isLoadingDocuments = false;
        });
      });

      // Initial document load
      final documents = serverService.documentService!.documents;
      final sortedDocs = List<Document>.from(documents);
      sortedDocs.sort((a, b) {
        final aTime = _getDocumentTimestamp(a);
        final bTime = _getDocumentTimestamp(b);
        return bTime.compareTo(aTime); // Descending order (latest first)
      });

      setState(() {
        _recentDocuments = sortedDocs.take(5).toList();
        _isLoadingDocuments = false;
      });
    } catch (e) {
      _logger.severe('Error loading documents: $e');
      setState(() {
        _isLoadingDocuments = false;
      });
    }
  }

  // Get document timestamp
  DateTime _getDocumentTimestamp(Document document) {
    try {
      if (document.metadata.containsKey('updated_at')) {
        return DateTime.parse(document.metadata['updated_at'] as String);
      } else if (document.metadata.containsKey('created_at')) {
        return DateTime.parse(document.metadata['created_at'] as String);
      }
    } catch (e) {
      // Ignore date parsing errors
    }
    return DateTime(1970); // Default value
  }

  // Start/stop server
  Future<void> _toggleServer() async {
    if (_isServerRunning) {
      await serverService.stopServer();
    } else {
      await serverService.startServer();
      _loadDocuments();
    }
  }

  // Open document details page
  void _openDocumentDetails(Document document) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DocumentDetailsScreen(document: document),
      ),
    );
  }

  // Show document upload dialog
  Future<void> _showUploadDocumentDialog() async {
    if (!_isServerRunning || serverService.documentService == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Server is not running')),
      );
      return;
    }

    final titleController = TextEditingController();
    final authorController = TextEditingController();
    final tagsController = TextEditingController();

    // File selection
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['txt', 'md', 'json', 'html', 'csv'],
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    String content;

    // Read file content
    if (file.bytes != null) {
      // From web as bytes
      content = utf8.decode(file.bytes!);
    } else if (file.path != null) {
      // From native platform as file path
      content = await File(file.path!).readAsString();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot read file')),
      );
      return;
    }

    // Metadata input dialog
    bool? result2 = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Document Details'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('File: ${file.name}', style: const TextStyle(fontStyle: FontStyle.italic)),
              const SizedBox(height: 16),
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: authorController,
                decoration: const InputDecoration(
                  labelText: 'Author',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: tagsController,
                decoration: const InputDecoration(
                  labelText: 'Tags (comma separated)',
                  hintText: 'e.g. tutorial, reference, important',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Content Preview:'),
              Container(
                height: 100,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    content.length > 500 ? content.substring(0, 500) + '...' : content,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                ),
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
            child: const Text('Upload'),
          ),
        ],
      ),
    );

    if (result2 != true) return;

    // Ensure title is provided
    if (titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title is required')),
      );
      return;
    }

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      // Process tags
      final tags = tagsController.text.isEmpty
          ? <String>[]
          : tagsController.text.split(',').map((t) => t.trim()).toList();

      // Construct metadata
      final metadata = {
        'tags': tags,
        'author': authorController.text,
        'filename': file.name,
        'filesize': file.size,
      };

      // Add document
      final docId = await serverService.documentService!.addDocument(
        title: titleController.text,
        content: content,
        metadata: metadata,
      );

      // Dismiss loading indicator
      Navigator.of(context).pop();

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Document uploaded successfully (ID: $docId)')),
      );

      // Refresh document list
      _loadDocuments();
    } catch (e) {
      // Dismiss loading indicator
      Navigator.of(context).pop();

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading document: $e')),
      );
    }
  }

  // Create sample documents
  Future<void> _createSampleDocuments() async {
    if (!_isServerRunning || serverService.documentService == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Server is not running')),
      );
      return;
    }

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final documentService = serverService.documentService!;

      // Sample document 1
      await documentService.addDocument(
        title: 'Introduction to MCP',
        content: '''
Model Context Protocol (MCP) is a communication protocol that enables interaction between AI models and external tools, resources, and capabilities. It provides a standardized way for AI models to access information, perform actions, and utilize various functionalities beyond their training data.

Key features of MCP include:
1. Tool invocation: Models can call external tools to perform specific tasks
2. Resource access: Models can read from and interact with external resources
3. Prompt templates: Standardized prompt formats for consistent model behavior
4. Sampling control: Fine-grained control over model generation parameters

MCP bridges the gap between AI models and the external world, allowing for more powerful and extensible AI applications.
''',
        metadata: {
          'tags': ['MCP', 'protocol', 'AI', 'overview'],
          'author': 'System',
        },
      );

      // Sample document 2
      await documentService.addDocument(
        title: 'Retrieval Augmented Generation (RAG)',
        content: '''
Retrieval Augmented Generation (RAG) is a technique that enhances language models by retrieving relevant information from external sources before generating responses. This approach combines the strengths of retrieval-based and generation-based methods for natural language processing.

Key components of RAG systems:
1. Document store: Collection of documents, articles, or knowledge sources
2. Embedding model: Creates vector representations of documents and queries
3. Retriever: Finds relevant documents based on semantic similarity
4. Generator: Language model that creates responses based on retrieved context

Benefits of RAG:
- Reduces hallucinations by grounding responses in factual information
- Provides up-to-date knowledge beyond the model's training cutoff
- Enables domain-specific applications without extensive fine-tuning
- Creates transparent, attributable responses with citations

RAG is particularly useful in question answering, customer support, documentation search, and knowledge-intensive applications where accuracy is critical.
''',
        metadata: {
          'tags': ['RAG', 'retrieval', 'AI', 'technique'],
          'author': 'System',
        },
      );

      // Sample document 3
      await documentService.addDocument(
        title: 'MCP Client Implementation Guide',
        content: '''
# MCP Client Implementation Guide

Implementing an MCP client involves the following steps:

## 1. Create an MCP client instance
```dart
final client = McpClient.createClient(
  name: 'MyClient',
  version: '1.0.0',
);
```

## 2. Create a transport layer
```dart
final transport = await McpClient.createSseTransport(
  serverUrl: 'http://localhost:8080/sse',
);
```

## 3. Connect the client to the transport
```dart
await client.connect(transport);
```

## 4. Initialize the connection
```dart
await client.initialize();
```

## 5. Interact with the server
```dart
// List available tools
final tools = await client.listTools();

// Call a tool
final result = await client.callTool('calculator', {
  'operation': 'add',
  'a': 5,
  'b': 3,
});

// Read a resource
final resourceResult = await client.readResource('docs://guide');
```

## 6. Handle notifications and events
```dart
client.onResourceUpdated((uri) {
  print('Resource updated: \$uri');
});

client.onToolsListChanged(() {
  print('Tools list has changed');
});
```

## 7. Disconnect when done
```dart
client.disconnect();
```
''',
        metadata: {
          'tags': ['MCP', 'client', 'implementation', 'guide'],
          'author': 'System',
        },
      );

      // Dismiss loading indicator
      Navigator.of(context).pop();

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sample documents created successfully')),
      );

      // Refresh document list
      _loadDocuments();
    } catch (e) {
      // Dismiss loading indicator
      Navigator.of(context).pop();

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating sample documents: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MCP Document Server'),
        actions: [
          IconButton(
            icon: Icon(_isServerRunning ? Icons.stop : Icons.play_arrow),
            tooltip: _isServerRunning ? 'Stop Server' : 'Start Server',
            onPressed: _toggleServer,
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Dashboard'),
            Tab(text: 'Documents'),
            Tab(text: 'Logs'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Server status bar
          ServerStatusBar(
            isRunning: _isServerRunning,
            statusMessage: _serverStatus,
            connectedClients: _connectedClients,
          ),

          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Dashboard tab
                _buildDashboardTab(),

                // Documents tab
                const DocumentListScreen(),

                // Logs tab
                LogConsole(
                  logMessages: _logMessages,
                  scrollController: _logScrollController,
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _isServerRunning && _tabController.index == 1
          ? FloatingActionButton(
        onPressed: _showUploadDocumentDialog,
        tooltip: 'Upload Document',
        child: const Icon(Icons.upload_file),
      )
          : null,
    );
  }

  // Build dashboard tab
  Widget _buildDashboardTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Server information card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Server Information', style: Theme.of(context).textTheme.titleMedium),
                  const Divider(),
                  Text('Status: ${_isServerRunning ? 'Running' : 'Stopped'}'),
                  Text('Connected Clients: $_connectedClients'),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      FilledButton.icon(
                        onPressed: _toggleServer,
                        icon: Icon(_isServerRunning ? Icons.stop : Icons.play_arrow),
                        label: Text(_isServerRunning ? 'Stop Server' : 'Start Server'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Document statistics card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Document Statistics', style: Theme.of(context).textTheme.titleMedium),
                  const Divider(),
                  if (_isServerRunning && serverService.documentService != null)
                    Text('Total Documents: ${serverService.documentService!.documents.length}')
                  else
                    const Text('Total Documents: N/A'),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: _isServerRunning
                            ? () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const DocumentListScreen(),
                          ),
                        )
                            : null,
                        icon: const Icon(Icons.list),
                        label: const Text('View All'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: _isServerRunning ? _createSampleDocuments : null,
                        icon: const Icon(Icons.add),
                        label: const Text('Create Samples'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Recent documents section
          Text('Recent Documents', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),

          if (_isLoadingDocuments)
            const Center(child: CircularProgressIndicator())
          else if (_recentDocuments.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: Text(
                    _isServerRunning
                        ? 'No documents available. Upload a document or create samples.'
                        : 'Start the server to manage documents.',
                  ),
                ),
              ),
            )
          else
            Column(
              children: _recentDocuments.map((doc) => DocumentCard(
                document: doc,
                onTap: () => _openDocumentDetails(doc),
              )).toList(),
            ),
        ],
      ),
    );
  }
}