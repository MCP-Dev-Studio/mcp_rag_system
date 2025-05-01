import 'dart:convert';
import 'package:logging/logging.dart';
import 'package:mcp_llm/mcp_llm.dart' hide Logger;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Provides server resources as an MCP_LLM plugin.
///
/// This plugin provides resources such as user guides and server information.
/// It is registered as an MCP resource and can be accessed by clients.
class ResourcePlugin extends BaseResourcePlugin {
  // Logger configuration
  final Logger _logger;

  // Resource data
  final Map<String, ResourceData> _resources = {};

  // Constructor
  ResourcePlugin({
    Logger? logger,
  }) : _logger = logger ?? Logger('ResourcePlugin'),
        super(
        name: 'resources',
        version: '1.0.0',
        description: 'Document server resource provider plugin',
      ) {
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
  }

  @override
  List<McpResource> getResources() {
    final resources = <McpResource>[];

    for (final resource in _resources.values) {
      resources.add(McpResource(
        uri: resource.uri,
        name: resource.name,
        description: resource.description,
        mimeType: resource.mimeType,
      ));
    }

    return resources;
  }

  @override
  Future<McpResourceResult> onReadResource(String uri, [Map<String, dynamic>? params]) async {
    _logger.info('Reading resource: $uri');

    // Check if the resource matches the URI
    if (!_resources.containsKey(uri)) {
      _logger.warning('Resource not found: $uri');
      throw ResourceNotFoundError('Resource not found: $uri');
    }

    // Retrieve the resource
    final resource = _resources[uri]!;

    // If the resource requires dynamic updates
    if (uri == 'system://server-info') {
      resource.content = _getServerInfo(); // Generate the latest server information
    }

    // Create the result
    final content = resource.content;
    final List<McpContent> contents = [];

    // Add content based on MIME type
    if (resource.mimeType.startsWith('text/')) {
      contents.add(McpTextContent(text: content));
    } else if (resource.mimeType == 'application/json') {
      contents.add(McpTextContent(text: content));
    }

    _logger.info('Returning resource: ${resource.name}');

    return McpResourceResult(
      contents: contents,
      mimeType: resource.mimeType,
    );
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
        'resources': '1.0.0',
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
  "tool": "uploadDocument",
  "arguments": {
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
  "tool": "getDocument",
  "arguments": {
    "documentId": "doc_1234567890"
  }
}
```

### Listing Documents
```json
{
  "tool": "listDocuments",
  "arguments": {
    "limit": 10,
    "tags": ["tutorial"]
  }
}
```

### Updating a Document
```json
{
  "tool": "updateDocument",
  "arguments": {
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
  "tool": "searchDocuments",
  "arguments": {
    "query": "What is Model Context Protocol?",
    "topK": 5
  }
}
```

### Generating a Summary
```json
{
  "tool": "summarizeDocuments",
  "arguments": {
    "query": "Model Context Protocol overview",
    "topK": 5,
    "summaryLength": "medium"
  }
}
```

### Answering Questions
```json
{
  "tool": "questionAnswering",
  "arguments": {
    "question": "How does Model Context Protocol work?",
    "topK": 5,
    "detailedAnswer": true
  }
}
```

### Finding Related Documents
```json
{
  "tool": "findRelatedDocuments",
  "arguments": {
    "documentId": "doc_1234567890",
    "topK": 3
  }
}
```
''';
  }

  /// Add a new resource
  void addResource({
    required String uri,
    required String name,
    required String description,
    required String mimeType,
    required String content,
  }) {
    _resources[uri] = ResourceData(
      uri: uri,
      name: name,
      description: description,
      mimeType: mimeType,
      content: content,
    );

    _logger.info('Added resource: $name (URI: $uri)');
  }

  /// Update an existing resource
  void updateResource({
    required String uri,
    String? name,
    String? description,
    String? mimeType,
    String? content,
  }) {
    if (!_resources.containsKey(uri)) {
      _logger.warning('Cannot update resource. Resource not found: $uri');
      return;
    }

    final resource = _resources[uri]!;

    _resources[uri] = ResourceData(
      uri: uri,
      name: name ?? resource.name,
      description: description ?? resource.description,
      mimeType: mimeType ?? resource.mimeType,
      content: content ?? resource.content,
    );

    _logger.info('Updated resource: ${name ?? resource.name} (URI: $uri)');
  }

  /// Remove a resource
  void removeResource(String uri) {
    if (_resources.containsKey(uri)) {
      final name = _resources[uri]!.name;
      _resources.remove(uri);
      _logger.info('Removed resource: $name (URI: $uri)');
    } else {
      _logger.warning('Cannot remove resource. Resource not found: $uri');
    }
  }
}

/// Resource data model
class ResourceData {
  final String uri;
  final String name;
  final String description;
  final String mimeType;
  String content;

  ResourceData({
    required this.uri,
    required this.name,
    required this.description,
    required this.mimeType,
    required this.content,
  });
}
