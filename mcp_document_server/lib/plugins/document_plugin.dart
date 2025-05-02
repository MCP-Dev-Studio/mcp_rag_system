import 'dart:async';
import 'package:logging/logging.dart';
import 'package:mcp_llm/mcp_llm.dart' hide Logger;

import '../services/document_service.dart';

/// Document management plugin for MCP
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
        inputSchema: {
          'type': 'object',
          'properties': {
            'operation': {
              'type': 'string',
              'enum': ['uploadDocument', 'getDocument', 'listDocuments', 'deleteDocument', 'updateDocument', 'listDocumentTags'],
              'description': 'Operation to perform on documents'
            },
            'params': {
              'type': 'object',
              'description': 'Operation parameters',
              'properties': {
                'title': {
                  'type': 'string',
                  'description': 'Document title (for upload/update operations)'
                },
                'content': {
                  'type': 'string',
                  'description': 'Document content (for upload/update operations)'
                },
                'documentId': {
                  'type': 'string',
                  'description': 'Document ID (for get/delete/update operations)'
                },
                'tags': {
                  'type': 'array',
                  'items': {
                    'type': 'string'
                  },
                  'description': 'Tags for the document (for upload/update operations)'
                },
                'author': {
                  'type': 'string',
                  'description': 'Author of the document (for upload/update operations)'
                },
                'limit': {
                  'type': 'integer',
                  'description': 'Maximum number of documents to return (for list operation)',
                  'default': 10
                }
              }
            }
          },
          'required': ['operation', 'params']
        },
      );

  @override
  Future<LlmCallToolResult> onExecute(Map<String, dynamic> arguments) async {
    _logger.info('Executing document operation with arguments: $arguments');

    try {
      final operation = arguments['operation'] as String;
      final params = arguments['params'] as Map<String, dynamic>;

      switch (operation) {
        case 'uploadDocument':
          return await _uploadDocument(params);
        case 'getDocument':
          return await _getDocument(params);
        case 'listDocuments':
          return await _listDocuments(params);
        case 'deleteDocument':
          return await _deleteDocument(params);
        case 'updateDocument':
          return await _updateDocument(params);
        case 'listDocumentTags':
          return await _listDocumentTags(params);
        default:
          throw Exception('Unknown operation: $operation');
      }
    } catch (e, stackTrace) {
      _logger.severe('Error executing document operation: $e\n$stackTrace');
      return LlmCallToolResult(
        [LlmTextContent(text: 'Error executing document operation: $e')],
        isError: true,
      );
    }
  }

  // Tool for uploading a document
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

  // Tool for retrieving a document
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

  // Tool for listing documents
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

  // Tool for deleting a document
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

  // Tool for updating a document
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

  // Tool for listing tags
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