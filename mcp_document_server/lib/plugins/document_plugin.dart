import 'dart:convert';
import 'package:logging/logging.dart';
import 'package:mcp_llm/mcp_llm.dart' hide Logger;

import '../services/document_service.dart';

/// Provides document management functionality as an MCP_LLM plugin.
///
/// This plugin offers features such as adding, retrieving, updating, and deleting documents.
/// It is automatically registered as an MCP tool and accessible from the LLM.
class DocumentPlugin extends BaseToolPlugin {
  // Dependencies
  final DocumentService documentService;
  final Logger _logger;

  DocumentPlugin({
    required this.documentService,
    Logger? logger,
  }) : _logger = logger ?? Logger('DocumentPlugin'),
        super(
        name: 'document',
        version: '1.0.0',
        description: 'Document management plugin',
      );

  @override
  List<LlmTool> getTools() {
    return [
      // Tool for adding a document
      LlmTool(
        name: 'uploadDocument',
        description: 'Upload a new document to the knowledge base',
        inputSchema: {
          'type': 'object',
          'properties': {
            'title': {
              'type': 'string',
              'description': 'Document title',
            },
            'content': {
              'type': 'string',
              'description': 'Document content',
            },
            'tags': {
              'type': 'array',
              'items': {
                'type': 'string',
              },
              'description': 'Tags for the document',
            },
            'author': {
              'type': 'string',
              'description': 'Author of the document',
            },
          },
          'required': ['title', 'content'],
        },
      ),

      // Tool for retrieving a document
      LlmTool(
        name: 'getDocument',
        description: 'Get a document by ID',
        inputSchema: {
          'type': 'object',
          'properties': {
            'documentId': {
              'type': 'string',
              'description': 'ID of the document to retrieve',
            },
          },
          'required': ['documentId'],
        },
      ),

      // Tool for listing documents
      LlmTool(
        name: 'listDocuments',
        description: 'List all documents in the knowledge base',
        inputSchema: {
          'type': 'object',
          'properties': {
            'limit': {
              'type': 'integer',
              'description': 'Maximum number of documents to return',
              'default': 10,
            },
            'tags': {
              'type': 'array',
              'items': {
                'type': 'string',
              },
              'description': 'Filter documents by tags',
            },
          },
        },
      ),

      // Tool for deleting a document
      LlmTool(
        name: 'deleteDocument',
        description: 'Delete a document from the knowledge base',
        inputSchema: {
          'type': 'object',
          'properties': {
            'documentId': {
              'type': 'string',
              'description': 'ID of the document to delete',
            },
          },
          'required': ['documentId'],
        },
      ),

      // Tool for updating a document
      LlmTool(
        name: 'updateDocument',
        description: 'Update an existing document',
        inputSchema: {
          'type': 'object',
          'properties': {
            'documentId': {
              'type': 'string',
              'description': 'ID of the document to update',
            },
            'title': {
              'type': 'string',
              'description': 'New document title',
            },
            'content': {
              'type': 'string',
              'description': 'New document content',
            },
            'tags': {
              'type': 'array',
              'items': {
                'type': 'string',
              },
              'description': 'New tags for the document',
            },
          },
          'required': ['documentId'],
        },
      ),

      // Tool for listing tags
      LlmTool(
        name: 'listDocumentTags',
        description: 'List all tags used in documents',
        inputSchema: {
          'type': 'object',
          'properties': {},
        },
      ),
    ];
  }

  @override
  Future<LlmCallToolResult> onExecuteTool(String toolName, Map<String, dynamic> arguments) async {
    _logger.info('Executing tool: $toolName with arguments: $arguments');

    try {
      switch (toolName) {
        case 'uploadDocument':
          return await _uploadDocument(arguments);
        case 'getDocument':
          return await _getDocument(arguments);
        case 'listDocuments':
          return await _listDocuments(arguments);
        case 'deleteDocument':
          return await _deleteDocument(arguments);
        case 'updateDocument':
          return await _updateDocument(arguments);
        case 'listDocumentTags':
          return await _listDocumentTags(arguments);
        default:
          throw ToolExecutionError('Unknown tool: $toolName');
      }
    } catch (e, stackTrace) {
      _logger.severe('Error executing tool $toolName: $e\n$stackTrace');
      return LlmCallToolResult(
        [LlmTextContent(text: 'Error executing tool $toolName: $e')],
        isError: true,
      );
    }
  }

  /// Tool for uploading a document
  Future<LlmCallToolResult> _uploadDocument(Map<String, dynamic> arguments) async {
    final title = arguments['title'] as String;
    final content = arguments['content'] as String;
    final tags = arguments['tags'] as List<dynamic>? ?? [];
    final author = arguments['author'] as String? ?? 'Unknown';

    // Construct metadata
    final metadata = {
      'tags': tags,
      'author': author,
      'created_at': DateTime.now().toIso8601String(),
    };

    // Add document
    final docId = await documentService.addDocument(
      title: title,
      content: content,
      metadata: metadata,
    );

    return LlmCallToolResult([
      LlmTextContent(text: '''
Document added successfully:

Title: $title
ID: $docId
Tags: ${tags.isEmpty ? "none" : tags.join(", ")}
Author: $author
Content Length: ${content.length} characters
'''),
    ]);
  }

  /// Tool for retrieving a document
  Future<LlmCallToolResult> _getDocument(Map<String, dynamic> arguments) async {
    final documentId = arguments['documentId'] as String;

    // Retrieve document
    final document = documentService.getDocument(documentId);

    if (document == null) {
      return LlmCallToolResult([
        LlmTextContent(text: 'Document not found with ID: $documentId'),
      ], isError: true);
    }

    // Format metadata
    final metadata = document.metadata;
    final metadataStr = StringBuffer();

    if (metadata.containsKey('tags') && metadata['tags'] is List) {
      final tags = (metadata['tags'] as List).map((t) => '#$t').join(' ');
      if (tags.isNotEmpty) {
        metadataStr.writeln('Tags: $tags');
      }
    }

    if (metadata.containsKey('author') && metadata['author'] != null) {
      metadataStr.writeln('Author: ${metadata['author']}');
    }

    if (metadata.containsKey('created_at') && metadata['created_at'] != null) {
      try {
        final date = DateTime.parse(metadata['created_at']);
        metadataStr.writeln('Created: ${date.toLocal()}');
      } catch (_) {
        metadataStr.writeln('Created: ${metadata['created_at']}');
      }
    }

    if (metadata.containsKey('updated_at') && metadata['updated_at'] != null) {
      try {
        final date = DateTime.parse(metadata['updated_at']);
        metadataStr.writeln('Updated: ${date.toLocal()}');
      } catch (_) {
        metadataStr.writeln('Updated: ${metadata['updated_at']}');
      }
    }

    return LlmCallToolResult([
      LlmTextContent(text: '''
Document ID: ${document.id}
Title: ${document.title}
${metadataStr.toString()}

Content:
${document.content}
'''),
    ]);
  }

  /// Tool for listing documents
  Future<LlmCallToolResult> _listDocuments(Map<String, dynamic> arguments) async {
    final limit = arguments['limit'] as int? ?? 10;
    final tags = arguments['tags'] as List<dynamic>? ?? [];

    // Retrieve documents
    List<Document> documents = documentService.documents;

    // Filter by tags
    if (tags.isNotEmpty) {
      documents = documentService.getDocumentsByTags(
        tags.map((t) => t.toString()).toList(),
      );
    }

    // Limit results
    if (documents.length > limit) {
      documents = documents.sublist(0, limit);
    }

    if (documents.isEmpty) {
      return LlmCallToolResult([
        LlmTextContent(text: 'No documents found.'),
      ]);
    }

    // Format results
    final result = StringBuffer('Found ${documents.length} documents:\n\n');

    for (final doc in documents) {
      result.writeln('ID: ${doc.id}');
      result.writeln('Title: ${doc.title}');

      if (doc.metadata.containsKey('tags') && doc.metadata['tags'] is List) {
        final tags = (doc.metadata['tags'] as List).map((t) => '#$t').join(' ');
        if (tags.isNotEmpty) {
          result.writeln('Tags: $tags');
        }
      }

      if (doc.metadata.containsKey('author') && doc.metadata['author'] != null) {
        result.writeln('Author: ${doc.metadata['author']}');
      }

      final contentPreview = doc.content.length > 100
          ? '${doc.content.substring(0, 100)}...'
          : doc.content;

      result.writeln('Content Preview: $contentPreview');
      result.writeln('---');
    }

    return LlmCallToolResult([
      LlmTextContent(text: result.toString()),
    ]);
  }

  /// Tool for deleting a document
  Future<LlmCallToolResult> _deleteDocument(Map<String, dynamic> arguments) async {
    final documentId = arguments['documentId'] as String;

    // Delete document
    final deleted = await documentService.deleteDocument(documentId);

    if (deleted) {
      return LlmCallToolResult([
        LlmTextContent(text: 'Document with ID $documentId was successfully deleted.'),
      ]);
    } else {
      return LlmCallToolResult([
        LlmTextContent(text: 'Failed to delete document with ID $documentId. Document may not exist.'),
      ], isError: true);
    }
  }

  /// Tool for updating a document
  Future<LlmCallToolResult> _updateDocument(Map<String, dynamic> arguments) async {
    final documentId = arguments['documentId'] as String;
    final title = arguments['title'] as String?;
    final content = arguments['content'] as String?;
    final tags = arguments['tags'] as List<dynamic>?;

    // Construct metadata
    Map<String, dynamic>? metadata;
    if (tags != null) {
      metadata = {'tags': tags};
    }

    // Update document
    final updatedId = await documentService.updateDocument(
      id: documentId,
      title: title,
      content: content,
      metadata: metadata,
    );

    if (updatedId != null) {
      return LlmCallToolResult([
        LlmTextContent(text: '''
Document has been updated successfully:
ID: $updatedId
${title != null ? 'Title: $title' : ''}
${content != null ? 'Content Length: ${content.length} characters' : ''}
${tags != null ? 'Tags: ${tags.join(', ')}' : ''}
'''),
      ]);
    } else {
      return LlmCallToolResult([
        LlmTextContent(text: 'Failed to update document with ID $documentId. Document may not exist.'),
      ], isError: true);
    }
  }

  /// Tool for listing tags
  Future<LlmCallToolResult> _listDocumentTags(Map<String, dynamic> arguments) async {
    // Retrieve all tags
    final tags = documentService.getAllTags();

    if (tags.isEmpty) {
      return LlmCallToolResult([
        LlmTextContent(text: 'No tags found in the document collection.'),
      ]);
    }

    // Retrieve tag list
    final documents = documentService.documents;
    final Map<String, int> tagCounts = {};

    for (final doc in documents) {
      if (doc.metadata.containsKey('tags') && doc.metadata['tags'] is List) {
        final docTags = doc.metadata['tags'] as List;
        for (final tag in docTags) {
          final tagStr = tag.toString();
          tagCounts[tagStr] = (tagCounts[tagStr] ?? 0) + 1;
        }
      }
    }

    // Sort tags by usage frequency in descending order
    final sortedTags = tagCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Format results
    final result = StringBuffer('Found ${tagCounts.length} unique tags:\n\n');

    for (final entry in sortedTags) {
      result.writeln('${entry.key}: ${entry.value} document${entry.value > 1 ? 's' : ''}');
    }

    return LlmCallToolResult([
      LlmTextContent(text: result.toString()),
    ]);
  }
}
