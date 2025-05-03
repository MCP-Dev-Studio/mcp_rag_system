import 'dart:async';
import 'dart:math' as math;
import 'package:mcp_llm/mcp_llm.dart';

import '../services/document_service.dart';

/// Search and RAG functionality plugin for MCP
class SearchPlugin extends BaseToolPlugin {
  // Dependencies
  final DocumentService documentService;
  final Logger _logger;

  // Caching
  final Map<String, dynamic> _queryCache = {};
  final Duration _cacheDuration = Duration(minutes: 30);
  final Map<String, DateTime> _cacheTimestamps = {};
  final int _maxCacheSize = 100;

  // Constructor
  SearchPlugin({
    required this.documentService,
    Logger? logger,
  }) : _logger = logger ?? Logger.getLogger('SearchPlugin'),
        super(
        name: 'search',
        version: '1.0.0',
        description: 'Search and RAG capabilities',
        inputSchema: {
          'type': 'object',
          'properties': {
            'operation': {
              'type': 'string',
              'enum': ['searchDocuments', 'summarizeDocuments', 'questionAnswering', 'findRelatedDocuments'],
              'description': 'Search operation to perform'
            },
            'params': {
              'type': 'object',
              'description': 'Operation parameters',
              'properties': {
                'query': {
                  'type': 'string',
                  'description': 'Search query or question to answer'
                },
                'documentId': {
                  'type': 'string',
                  'description': 'Document ID for finding related documents'
                },
                'topK': {
                  'type': 'integer',
                  'description': 'Number of documents to retrieve',
                  'default': 5
                },
                'summaryLength': {
                  'type': 'string',
                  'enum': ['short', 'medium', 'long'],
                  'description': 'Length of the summary to generate',
                  'default': 'medium'
                },
                'detailedAnswer': {
                  'type': 'boolean',
                  'description': 'Whether to provide a detailed answer with citations',
                  'default': true
                }
              }
            }
          },
          'required': ['operation', 'params']
        },
      );

  @override
  Future<LlmCallToolResult> onExecute(Map<String, dynamic> arguments) async {
    _logger.info('Executing search operation with arguments: $arguments');

    // Clean expired cache entries
    _cleanExpiredCache();

    try {
      final operation = arguments['operation'] as String;
      final params = arguments['params'] as Map<String, dynamic>;

      switch (operation) {
        case 'searchDocuments':
          return await _searchDocuments(params);
        case 'summarizeDocuments':
          return await _summarizeDocuments(params);
        case 'questionAnswering':
          return await _questionAnswering(params);
        case 'findRelatedDocuments':
          return await _findRelatedDocuments(params);
        default:
          throw Exception('Unknown search operation: $operation');
      }
    } catch (e, stackTrace) {
      _logger.error('Error executing search operation: $e\n$stackTrace');
      return LlmCallToolResult(
        [LlmTextContent(text: 'Error executing search operation: $e')],
        isError: true,
      );
    }
  }

  // Document search tool
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

  // Document summarization tool
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
        generationParams: {
          'instructions':  'For the query: "$query", $lengthInstruction Include citations to the source documents when appropriate.',
        },
      );

      // Cache results
      _queryCache[cacheKey] = response;
      _cacheTimestamps[cacheKey] = DateTime.now();

      _logger.info('Generated summary for query: "$query"');
      return LlmCallToolResult([
        LlmTextContent(text: response),
      ]);
    } catch (e) {
      _logger.error('Error generating summary: $e');
      return LlmCallToolResult([
        LlmTextContent(text: 'Error generating summary: $e'),
      ], isError: true);
    }
  }

  // Question answering tool
  Future<LlmCallToolResult> _questionAnswering(Map<String, dynamic> arguments) async {
    final question = arguments['query'] as String;
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
        generationParams: {
          'instructions': additionalInstructions,
        },
      );

      // Cache results
      _queryCache[cacheKey] = answer;
      _cacheTimestamps[cacheKey] = DateTime.now();

      _logger.info('Generated answer for question: "$question"');
      return LlmCallToolResult([
        LlmTextContent(text: answer),
      ]);
    } catch (e) {
      _logger.error('Error answering question: $e');
      return LlmCallToolResult([
        LlmTextContent(text: 'Error answering question: $e'),
      ], isError: true);
    }
  }

  // Find related documents tool
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
        document.title + ' ' + document.content.substring(0, math.min(document.content.length, 200)),
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
      _logger.error('Error finding related documents: $e');
      return LlmCallToolResult([
        LlmTextContent(text: 'Error finding related documents: $e'),
      ], isError: true);
    }
  }

  // Clean expired cache entries
  void _cleanExpiredCache() {
    final now = DateTime.now();

    // Remove expired entries
    final expiredKeys = _cacheTimestamps.entries
        .where((entry) => now.difference(entry.value) > _cacheDuration)
        .map((entry) => entry.key)
        .toList();

    for (final key in expiredKeys) {
      _queryCache.remove(key);
      _cacheTimestamps.remove(key);
    }

    // If cache is still too large, remove oldest entries
    if (_cacheTimestamps.length > _maxCacheSize) {
      final oldestKeys = _cacheTimestamps.entries
          .toList()
        ..sort((a, b) => a.value.compareTo(b.value));

      final keysToRemove = oldestKeys
          .take(_cacheTimestamps.length - _maxCacheSize)
          .map((entry) => entry.key)
          .toList();

      for (final key in keysToRemove) {
        _queryCache.remove(key);
        _cacheTimestamps.remove(key);
      }
    }

    if (expiredKeys.isNotEmpty) {
      _logger.info('Cleaned ${expiredKeys.length} expired cache entries');
    }
  }

  // Methods to invalidate cache
  void invalidateCache() {
    _queryCache.clear();
    _cacheTimestamps.clear();
    _logger.info('Cache invalidated');
  }

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