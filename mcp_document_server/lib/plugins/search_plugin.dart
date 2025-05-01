import 'dart:async';
import 'dart:convert';
import 'package:logging/logging.dart';
import 'package:mcp_llm/mcp_llm.dart';

import '../services/document_service.dart';

/// Provides search and RAG functionality as an MCP_LLM plugin.
///
/// This plugin offers features such as document search, summarization, and Q&A.
/// It is automatically registered as an MCP tool and accessible from the LLM.
class SearchPlugin extends BaseToolPlugin {
  // Dependencies
  final DocumentService documentService;
  final Logger _logger;

  // Caching
  final Map<String, dynamic> _queryCache = {};
  final Duration _cacheDuration = Duration(minutes: 30);
  final Map<String, DateTime> _cacheTimestamps = {};

  // Constructor
  SearchPlugin({
    required this.documentService,
    Logger? logger,
  }) : _logger = logger ?? Logger('SearchPlugin'),
        super(
        name: 'search',
        version: '1.0.0',
        description: 'Search and RAG capabilities plugin',
      );

  @override
  List<LlmTool> getTools() {
    return [
      // Document search tool
      LlmTool(
        name: 'searchDocuments',
        description: 'Search for documents relevant to a query using vector search',
        inputSchema: {
          'type': 'object',
          'properties': {
            'query': {
              'type': 'string',
              'description': 'The search query',
            },
            'topK': {
              'type': 'integer',
              'description': 'Number of documents to retrieve',
              'default': 5,
            },
          },
          'required': ['query'],
        },
      ),

      // Document summarization tool
      LlmTool(
        name: 'summarizeDocuments',
        description: 'Generate a summary based on documents relevant to a query',
        inputSchema: {
          'type': 'object',
          'properties': {
            'query': {
              'type': 'string',
              'description': 'The search query',
            },
            'topK': {
              'type': 'integer',
              'description': 'Number of documents to retrieve',
              'default': 5,
            },
            'summaryLength': {
              'type': 'string',
              'enum': ['short', 'medium', 'long'],
              'description': 'Length of the summary',
              'default': 'medium',
            },
          },
          'required': ['query'],
        },
      ),

      // Question answering tool
      LlmTool(
        name: 'questionAnswering',
        description: 'Answer a question based on the knowledge base documents',
        inputSchema: {
          'type': 'object',
          'properties': {
            'question': {
              'type': 'string',
              'description': 'The question to answer',
            },
            'topK': {
              'type': 'integer',
              'description': 'Number of documents to retrieve',
              'default': 5,
            },
            'detailedAnswer': {
              'type': 'boolean',
              'description': 'Whether to provide a detailed answer with citations',
              'default': true,
            },
          },
          'required': ['question'],
        },
      ),

      // Find related documents tool
      LlmTool(
        name: 'findRelatedDocuments',
        description: 'Find documents related to a specific document by ID',
        inputSchema: {
          'type': 'object',
          'properties': {
            'documentId': {
              'type': 'string',
              'description': 'ID of the reference document',
            },
            'topK': {
              'type': 'integer',
              'description': 'Number of related documents to retrieve',
              'default': 3,
            },
          },
          'required': ['documentId'],
        },
      ),
    ];
  }

  @override
  Future<LlmCallToolResult> onExecuteTool(String toolName, Map<String, dynamic> arguments) async {
    _logger.info('Executing tool: $toolName with arguments: $arguments');

    // Clean expired cache entries
    _cleanExpiredCache();

    try {
      switch (toolName) {
        case 'searchDocuments':
          return await _searchDocuments(arguments);
        case 'summarizeDocuments':
          return await _summarizeDocuments(arguments);
        case 'questionAnswering':
          return await _questionAnswering(arguments);
        case 'findRelatedDocuments':
          return await _findRelatedDocuments(arguments);
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

  /// Document search tool
  Future<LlmCallToolResult> _searchDocuments(Map<String, dynamic> arguments) async {
    final query = arguments['query'] as String;
    final topK = arguments['topK'] as int? ?? 5;

    // Check cache
    final cacheKey = 'search_${query}_${topK}';
    if (_queryCache.containsKey(cacheKey)) {
      _logger.info('Using cached result for query: "$query"');
      return LlmCallToolResult([
        LlmTextContent(text: _queryCache[cacheKey] as String),
      ]);
    }

    // Perform search
    final retrievalManager = documentService.retrievalManager;
    if (retrievalManager == null) {
      return LlmCallToolResult([
        LlmTextContent(text: 'Search functionality is not available because the retrieval manager is not initialized.'),
      ], isError: true);
    }

    _logger.info('Searching documents for query: "$query" (topK: $topK)');
    final results = await retrievalManager.retrieveRelevant(
      query,
      topK: topK,
      minimumScore: 0.6,
    );

    if (results.isEmpty) {
      _logger.info('No documents found for query: "$query"');
      return LlmCallToolResult([
        LlmTextContent(text: 'No relevant documents found for the query: "$query"'),
      ]);
    }

    // Format results
    final result = StringBuffer('Found ${results.length} relevant documents for query: "$query"\n\n');

    for (int i = 0; i < results.length; i++) {
      final doc = results[i];
      final metadata = doc.metadata;

      result.writeln('${i + 1}. ${doc.title} (ID: ${doc.id})');

      if (metadata.containsKey('tags') && metadata['tags'] is List) {
        final tags = (metadata['tags'] as List).map((t) => '#$t').join(' ');
        if (tags.isNotEmpty) {
          result.writeln('   Tags: $tags');
        }
      }

      if (metadata.containsKey('author') && metadata['author'] != null) {
        result.writeln('   Author: ${metadata['author']}');
      }

      result.writeln('\n   Content:\n   ${doc.content}\n');
      result.writeln('---');
    }

    // Cache results
    final resultStr = result.toString();
    _queryCache[cacheKey] = resultStr;
    _cacheTimestamps[cacheKey] = DateTime.now();

    _logger.info('Returning ${results.length} search results for query: "$query"');
    return LlmCallToolResult([
      LlmTextContent(text: resultStr),
    ]);
  }

  /// Document summarization tool
  Future<LlmCallToolResult> _summarizeDocuments(Map<String, dynamic> arguments) async {
    final query = arguments['query'] as String;
    final topK = arguments['topK'] as int? ?? 5;
    final summaryLength = arguments['summaryLength'] as String? ?? 'medium';

    // Check cache
    final cacheKey = 'summary_${query}_${topK}_${summaryLength}';
    if (_queryCache.containsKey(cacheKey)) {
      _logger.info('Using cached result for summary: "$query"');
      return LlmCallToolResult([
        LlmTextContent(text: _queryCache[cacheKey] as String),
      ]);
    }

    // Perform search
    final retrievalManager = documentService.retrievalManager;
    if (retrievalManager == null) {
      return LlmCallToolResult([
        LlmTextContent(text: 'Summary functionality is not available because the retrieval manager is not initialized.'),
      ], isError: true);
    }

    // Adjust instructions based on summary length
    String lengthInstruction;
    switch (summaryLength) {
      case 'short':
        lengthInstruction = 'Provide a brief summary in 1-2 paragraphs.';
        break;
      case 'long':
        lengthInstruction = 'Provide a comprehensive summary with detailed information from all relevant documents.';
        break;
      case 'medium':
      default:
        lengthInstruction = 'Provide a balanced summary covering the main points from the documents.';
        break;
    }

    _logger.info('Generating summary for query: "$query" (topK: $topK, length: $summaryLength)');

    try {
      // Perform search and generate summary
      final response = await retrievalManager.retrieveAndGenerate(
        query,
        topK: topK,
        useHybridSearch: true,
        additionalInstructions: 'For the query: "$query", $lengthInstruction Include citations to the source documents when appropriate.',
      );

      // Cache results
      _queryCache[cacheKey] = response;
      _cacheTimestamps[cacheKey] = DateTime.now();

      _logger.info('Generated summary for query: "$query"');
      return LlmCallToolResult([
        LlmTextContent(text: response),
      ]);
    } catch (e) {
      _logger.severe('Error generating summary: $e');
      return LlmCallToolResult([
        LlmTextContent(text: 'Error generating summary: $e'),
      ], isError: true);
    }
  }

  /// Question answering tool
  Future<LlmCallToolResult> _questionAnswering(Map<String, dynamic> arguments) async {
    final question = arguments['question'] as String;
    final topK = arguments['topK'] as int? ?? 5;
    final detailedAnswer = arguments['detailedAnswer'] as bool? ?? true;

    // Check cache
    final cacheKey = 'qa_${question}_${topK}_${detailedAnswer}';
    if (_queryCache.containsKey(cacheKey)) {
      _logger.info('Using cached result for question: "$question"');
      return LlmCallToolResult([
        LlmTextContent(text: _queryCache[cacheKey] as String),
      ]);
    }

    // Perform search
    final retrievalManager = documentService.retrievalManager;
    if (retrievalManager == null) {
      return LlmCallToolResult([
        LlmTextContent(text: 'Question answering functionality is not available because the retrieval manager is not initialized.'),
      ], isError: true);
    }

    // Adjust instructions based on detailed answer preference
    String additionalInstructions = detailedAnswer
        ? 'Provide a detailed answer with citations to the source documents. Include document titles in citations.'
        : 'Provide a concise answer based on the documents without citations.';

    _logger.info('Answering question: "$question" (topK: $topK, detailed: $detailedAnswer)');

    try {
      // Perform search and generate answer
      final answer = await retrievalManager.retrieveAndGenerate(
        question,
        topK: topK,
        useHybridSearch: true,
        additionalInstructions: additionalInstructions,
      );

      // Cache results
      _queryCache[cacheKey] = answer;
      _cacheTimestamps[cacheKey] = DateTime.now();

      _logger.info('Generated answer for question: "$question"');
      return LlmCallToolResult([
        LlmTextContent(text: answer),
      ]);
    } catch (e) {
      _logger.severe('Error answering question: $e');
      return LlmCallToolResult([
        LlmTextContent(text: 'Error answering question: $e'),
      ], isError: true);
    }
  }

  /// Find related documents tool
  Future<LlmCallToolResult> _findRelatedDocuments(Map<String, dynamic> arguments) async {
    final documentId = arguments['documentId'] as String;
    final topK = arguments['topK'] as int? ?? 3;

    // Check cache
    final cacheKey = 'related_${documentId}_${topK}';
    if (_queryCache.containsKey(cacheKey)) {
      _logger.info('Using cached result for related documents to: "$documentId"');
      return LlmCallToolResult([
        LlmTextContent(text: _queryCache[cacheKey] as String),
      ]);
    }

    // Retrieve reference document
    final document = documentService.getDocument(documentId);
    if (document == null) {
      return LlmCallToolResult([
        LlmTextContent(text: 'Document not found with ID: $documentId'),
      ], isError: true);
    }

    // Perform search
    final retrievalManager = documentService.retrievalManager;
    if (retrievalManager == null) {
      return LlmCallToolResult([
        LlmTextContent(text: 'Related document search is not available because the retrieval manager is not initialized.'),
      ], isError: true);
    }

    _logger.info('Finding documents related to: "${document.title}" (ID: $documentId)');

    try {
      // Use the content of the document as the query
      final results = await retrievalManager.retrieveRelevant(
        document.title + ' ' + document.content.substring(0, Math.min(document.content.length, 200)),
        topK: topK + 1, // Retrieve one extra to exclude itself
        minimumScore: 0.6,
      );

      // Exclude the reference document itself
      final filteredResults = results.where((doc) => doc.id != documentId).take(topK).toList();

      if (filteredResults.isEmpty) {
        _logger.info('No related documents found for document: "${document.title}"');
        return LlmCallToolResult([
          LlmTextContent(text: 'No related documents found for: "${document.title}" (ID: $documentId)'),
        ]);
      }

      // Format results
      final result = StringBuffer('Documents related to "${document.title}" (ID: $documentId):\n\n');

      for (int i = 0; i < filteredResults.length; i++) {
        final doc = filteredResults[i];
        final metadata = doc.metadata;

        result.writeln('${i + 1}. ${doc.title} (ID: ${doc.id})');

        if (metadata.containsKey('tags') && metadata['tags'] is List) {
          final tags = (metadata['tags'] as List).map((t) => '#$t').join(' ');
          if (tags.isNotEmpty) {
            result.writeln('   Tags: $tags');
          }
        }

        final contentPreview = doc.content.length > 150
            ? '${doc.content.substring(0, 150)}...'
            : doc.content;

        result.writeln('   Content Preview: $contentPreview');
        result.writeln('---');
      }

      // Cache results
      final resultStr = result.toString();
      _queryCache[cacheKey] = resultStr;
      _cacheTimestamps[cacheKey] = DateTime.now();

      _logger.info('Found ${filteredResults.length} documents related to: "${document.title}"');
      return LlmCallToolResult([
        LlmTextContent(text: resultStr),
      ]);
    } catch (e) {
      _logger.severe('Error finding related documents: $e');
      return LlmCallToolResult([
        LlmTextContent(text: 'Error finding related documents: $e'),
      ], isError: true);
    }
  }

  /// Clean expired cache entries
  void _cleanExpiredCache() {
    final now = DateTime.now();
    final expiredKeys = _cacheTimestamps.entries
        .where((entry) => now.difference(entry.value) > _cacheDuration)
        .map((entry) => entry.key)
        .toList();

    for (final key in expiredKeys) {
      _queryCache.remove(key);
      _cacheTimestamps.remove(key);
    }

    if (expiredKeys.isNotEmpty) {
      _logger.info('Cleaned ${expiredKeys.length} expired cache entries');
    }
  }

  /// Invalidate all cache
  void invalidateCache() {
    _queryCache.clear();
    _cacheTimestamps.clear();
    _logger.info('Cache invalidated');
  }

  /// Invalidate cache for a specific query
  void invalidateCacheForQuery(String query) {
    final keysToRemove = _queryCache.keys
        .where((key) => key.contains(query))
        .toList();

    for (final key in keysToRemove) {
      _queryCache.remove(key);
      _cacheTimestamps.remove(key);
    }

    _logger.info('Invalidated ${keysToRemove.length} cache entries for query: "$query"');
  }
}
