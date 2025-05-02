import 'dart:convert';
import 'package:logging/logging.dart';
import 'package:mcp_llm/mcp_llm.dart' hide Logger;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Resource provider plugin for MCP
class DocumentResourcePlugin extends BaseToolPlugin {
  // Logger configuration
  final Logger _logger;

  // Resource data
  final Map<String, ResourceData> _resources = {};

  // Constructor
  DocumentResourcePlugin({
    Logger? logger,
  }) : _logger = logger ?? Logger('DocumentResourcePlugin'),
        super(
        name: 'resource',
        version: '1.0.0',
        description: 'Document server resource provider',
        inputSchema: {
          'type': 'object',
          'properties': {
            'operation': {
              'type': 'string',
              'enum': ['getResource', 'listResources', 'addResource', 'updateResource', 'removeResource'],
              'description': 'Resource operation to perform'
            },
            'params': {
              'type': 'object',
              'description': 'Operation parameters',
              'properties': {
                'uri': {
                  'type': 'string',
                  'description': 'Resource URI to access or modify'
                },
                'section': {
                  'type': 'string',
                  'description': 'Section name for documentation resources',
                  'default': 'index'
                },
                'name': {
                  'type': 'string',
                  'description': 'Resource name for adding or updating'
                },
                'description': {
                  'type': 'string',
                  'description': 'Resource description for adding or updating'
                },
                'mimeType': {
                  'type': 'string',
                  'description': 'MIME type for the resource',
                  'default': 'text/markdown'
                },
                'content': {
                  'type': 'string',
                  'description': 'Resource content for adding or updating'
                }
              }
            }
          },
          'required': ['operation', 'params']
        },
      );

  @override
  Future<void> onInitialize(Map<String, dynamic> config) async {
    super.onInitialize(config);
    _initializeResources();
  }

  /// Register initial resources
  void _initializeResources() {
    // User guide resource
    _resources['docs://user-guide'] = ResourceData(
      uri: 'docs://user-guide',
      name: 'Document Server User Guide',
      description: 'Guide on how to use the document server',
      mimeType: 'text/markdown',
      content: _getUserGuide(),
    );

    // Server information resource
    _resources['system://server-info'] = ResourceData(
      uri: 'system://server-info',
      name: 'Server Information',
      description: 'Information about the server version and capabilities',
      mimeType: 'application/json',
      content: _getServerInfo(),
    );

    // API usage examples resource
    _resources['docs://api-examples'] = ResourceData(
      uri: 'docs://api-examples',
      name: 'API Usage Examples',
      description: 'Examples of how to use the document server API',
      mimeType: 'text/markdown',
      content: _getApiExamples(),
    );

    _logger.info('Initialized resources: ${_resources.keys.join(', ')}');
  }

  @override
  Future<LlmCallToolResult> onExecute(Map<String, dynamic> arguments) async {
    _logger.info('Executing resource operation with arguments: $arguments');

    try {
      final operation = arguments['operation'] as String;
      final params = arguments['params'] as Map<String, dynamic>;

      switch (operation) {
        case 'getResource':
          return await _getResource(params);
        case 'listResources':
          return _listResources(params);
        case 'addResource':
          return _addResource(params);
        case 'updateResource':
          return _updateResource(params);
        case 'removeResource':
          return _removeResource(params);
        default:
          throw Exception('Unknown resource operation: $operation');
      }
    } catch (e, stackTrace) {
      _logger.severe('Error executing resource operation: $e\n$stackTrace');
      return LlmCallToolResult(
        [LlmTextContent(text: 'Error executing resource operation: $e')],
        isError: true,
      );
    }
  }

  // Get a resource with specified parameters
  Future<LlmCallToolResult> _getResource(Map<String, dynamic> params) async {
    final uri = params['uri'] as String;
    final section = params['section'] as String? ?? 'index';

    _logger.info('Reading resource: $uri, section: $section');

    // Check if the resource exists
    if (!_resources.containsKey(uri)) {
      _logger.warning('Resource not found: $uri');
      return LlmCallToolResult(
        [LlmTextContent(text: 'Resource not found: $uri')],
        isError: true,
      );
    }

    // Retrieve the resource
    final resource = _resources[uri]!;

    // If the resource is a documentation resource with sections
    if (uri.startsWith('docs://') && resource.sections != null) {
      final sectionContent = resource.sections![section];

      if (sectionContent == null) {
        // If requested section doesn't exist, try to use index
        if (section != 'index' && resource.sections!.containsKey('index')) {
          final indexContent = resource.sections!['index']!;
          final content = 'Section "$section" not found. Here\'s the index instead:\n\n$indexContent';
          return LlmCallToolResult([LlmTextContent(text: content)]);
        } else {
          // List available sections
          final availableSections = resource.sections!.keys.toList().join(', ');
          final content = 'Section "$section" not found. Available sections: $availableSections';
          return LlmCallToolResult([LlmTextContent(text: content)]);
        }
      }

      return LlmCallToolResult([LlmTextContent(text: sectionContent)]);
    }

    // If the resource is system info, regenerate it for latest info
    if (uri == 'system://server-info') {
      resource.content = _getServerInfo(); // Update with latest info
    }

    return LlmCallToolResult([
      LlmTextContent(text: resource.content),
    ]);
  }

  // List available resources
  LlmCallToolResult _listResources(Map<String, dynamic> params) {
    final resourceList = _resources.values.map((resource) => {
      'uri': resource.uri,
      'name': resource.name,
      'description': resource.description,
      'mimeType': resource.mimeType,
      'sections': resource.sections?.keys.toList(),
    }).toList();

    final result = StringBuffer('Available Resources:\n\n');

    for (final resource in resourceList) {
      result.writeln('URI: ${resource['uri']}');
      result.writeln('Name: ${resource['name']}');
      result.writeln('Description: ${resource['description']}');
      result.writeln('MIME Type: ${resource['mimeType']}');

      final sections = resource['sections'] as List<String>?;
      if (sections != null && sections.isNotEmpty) {
        result.writeln('Sections: ${sections.join(', ')}');
      }

      result.writeln('---');
    }

    return LlmCallToolResult([
      LlmTextContent(text: result.toString()),
    ]);
  }

  // Add a new resource
  LlmCallToolResult _addResource(Map<String, dynamic> params) {
    final uri = params['uri'] as String;
    final name = params['name'] as String;
    final description = params['description'] as String;
    final mimeType = params['mimeType'] as String? ?? 'text/markdown';
    final content = params['content'] as String;

    // Check if resource already exists
    if (_resources.containsKey(uri)) {
      return LlmCallToolResult([
        LlmTextContent(text: 'Resource with URI "$uri" already exists. Use updateResource to modify it.'),
      ], isError: true);
    }

    // Add the resource
    _resources[uri] = ResourceData(
      uri: uri,
      name: name,
      description: description,
      mimeType: mimeType,
      content: content,
    );

    _logger.info('Added resource: $name (URI: $uri)');

    return LlmCallToolResult([
      LlmTextContent(text: 'Resource added successfully:\nURI: $uri\nName: $name'),
    ]);
  }

  // Update an existing resource
  LlmCallToolResult _updateResource(Map<String, dynamic> params) {
    final uri = params['uri'] as String;
    final name = params['name'] as String?;
    final description = params['description'] as String?;
    final mimeType = params['mimeType'] as String?;
    final content = params['content'] as String?;

    // Check if resource exists
    if (!_resources.containsKey(uri)) {
      return LlmCallToolResult([
        LlmTextContent(text: 'Resource with URI "$uri" does not exist. Use addResource to create it.'),
      ], isError: true);
    }

    // Get existing resource
    final resource = _resources[uri]!;

    // Update the resource with new values or keep existing ones
    _resources[uri] = ResourceData(
      uri: uri,
      name: name ?? resource.name,
      description: description ?? resource.description,
      mimeType: mimeType ?? resource.mimeType,
      content: content ?? resource.content,
      sections: resource.sections,
    );

    _logger.info('Updated resource: ${name ?? resource.name} (URI: $uri)');

    return LlmCallToolResult([
      LlmTextContent(text: 'Resource updated successfully:\nURI: $uri\nName: ${name ?? resource.name}'),
    ]);
  }

  // Remove a resource
  LlmCallToolResult _removeResource(Map<String, dynamic> params) {
    final uri = params['uri'] as String;

    // Check if resource exists
    if (!_resources.containsKey(uri)) {
      return LlmCallToolResult([
        LlmTextContent(text: 'Resource with URI "$uri" does not exist.'),
      ], isError: true);
    }

    // Check if it's a protected system resource
    if (uri.startsWith('system://')) {
      return LlmCallToolResult([
        LlmTextContent(text: 'Cannot remove system resource: $uri'),
      ], isError: true);
    }

    // Get resource name for log message
    final name = _resources[uri]!.name;

    // Remove the resource
    _resources.remove(uri);

    _logger.info('Removed resource: $name (URI: $uri)');

    return LlmCallToolResult([
      LlmTextContent(text: 'Resource removed successfully:\nURI: $uri\nName: $name'),
    ]);
  }

  /// Generate user guide content
  String _getUserGuide() {
    return '''
# MCP Document Server User Guide

## Overview
This server provides document storage, retrieval, and RAG (Retrieval Augmented Generation) capabilities through the Model Context Protocol (MCP).

## Available Tools

### Document Management (document plugin)
- **uploadDocument**: Upload a new document to the knowledge base
- **getDocument**: Retrieve a specific document by ID
- **listDocuments**: List all available documents
- **deleteDocument**: Delete a document from the server
- **updateDocument**: Update an existing document
- **listDocumentTags**: List all tags used in documents

### Search & RAG (search plugin)
- **searchDocuments**: Search for relevant documents based on a query
- **summarizeDocuments**: Generate summaries from relevant documents
- **questionAnswering**: Answer questions based on retrieved documents
- **findRelatedDocuments**: Find documents related to a specific document

## How to Connect
Connect to this server using an MCP client with the following settings:
- Server URL: ${dotenv.env['MCP_SERVER_URL'] ?? 'http://localhost:8999/sse'}
- Authentication: ${dotenv.env['MCP_AUTH_TOKEN'] != null ? 'Required' : 'None'}

## Examples
- To search: `searchDocuments(query: "What is MCP?")`
- To upload: `uploadDocument(title: "About MCP", content: "MCP stands for...")`
- To get answers: `questionAnswering(question: "How does RAG work?")`
''';
  }

  /// Generate server information content
  String _getServerInfo() {
    final serverInfo = {
      'name': 'MCP Document Server',
      'version': '1.0.0',
      'protocol_version': '2024-11-05',
      'plugins': {
        'document': '1.0.0',
        'search': '1.0.0',
        'resource': '1.0.0',
      },
      'embedding_model': (dotenv.env['OPENAI_API_KEY'] != null)
          ? 'text-embedding-3-large'
          : 'claude-3-sonnet-20240229',
      'server_time': DateTime.now().toIso8601String(),
    };

    return jsonEncode(serverInfo);
  }

  /// Generate API usage examples content
  String _getApiExamples() {
    return '''
# Document Server API Usage Examples

## Document Management

### Uploading a Document
```json
{
  "operation": "uploadDocument",
  "params": {
    "title": "Introduction to MCP",
    "content": "Model Context Protocol (MCP) is a protocol that enables...",
    "tags": ["mcp", "protocol", "tutorial"],
    "author": "John Doe"
  }
}
```

### Getting a Document
```json
{
  "operation": "getDocument",
  "params": {
    "documentId": "doc_1234567890"
  }
}
```

### Listing Documents
```json
{
  "operation": "listDocuments",
  "params": {
    "limit": 10,
    "tags": ["tutorial"]
  }
}
```

### Updating a Document
```json
{
  "operation": "updateDocument",
  "params": {
    "documentId": "doc_1234567890",
    "title": "Updated Introduction to MCP",
    "tags": ["mcp", "tutorial", "updated"]
  }
}
```

## Search & RAG

### Searching Documents
```json
{
  "operation": "searchDocuments",
  "params": {
    "query": "What is Model Context Protocol?",
    "topK": 5
  }
}
```

### Generating a Summary
```json
{
  "operation": "summarizeDocuments",
  "params": {
    "query": "Model Context Protocol overview",
    "topK": 5,
    "summaryLength": "medium"
  }
}
```

### Answering Questions
```json
{
  "operation": "questionAnswering",
  "params": {
    "query": "How does Model Context Protocol work?",
    "topK": 5,
    "detailedAnswer": true
  }
}
```

### Finding Related Documents
```json
{
  "operation": "findRelatedDocuments",
  "params": {
    "documentId": "doc_1234567890",
    "topK": 3
  }
}
```
''';
  }
}

/// Resource data model
class ResourceData {
  final String uri;
  final String name;
  final String description;
  final String mimeType;
  String content;
  final Map<String, String>? sections;

  ResourceData({
    required this.uri,
    required this.name,
    required this.description,
    required this.mimeType,
    required this.content,
    this.sections,
  });
}