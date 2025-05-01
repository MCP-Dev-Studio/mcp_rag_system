import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mcp_llm/mcp_llm.dart';

class DocumentService {
  // Logger configuration
  final Logger _logger = Logger('DocumentService');

  // Data storage-related objects
  final String _basePath;
  late final PersistentStorage _storage;
  late final DocumentStore _documentStore;
  RetrievalManager? _retrievalManager;

  // Stream controller
  final _documentsStreamController = StreamController<List<Document>>.broadcast();

  // Internal state
  List<Document> _documents = [];
  bool _isInitialized = false;

  // Getters
  bool get isInitialized => _isInitialized;
  List<Document> get documents => _documents;
  Stream<List<Document>> get documentsStream => _documentsStreamController.stream;
  DocumentStore get documentStore => _documentStore;
  RetrievalManager? get retrievalManager => _retrievalManager;

  // Constructor
  DocumentService(this._basePath);

  // Initialization
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _logger.info('Initializing DocumentService at path: $_basePath');

      // Initialize storage
      _storage = PersistentStorage(_basePath);

      // Initialize DocumentStore
      _documentStore = DocumentStore(_storage);
      await _documentStore.initialize();

      // Check API keys for embedding model configuration
      final openAiApiKey = dotenv.env['OPENAI_API_KEY'];
      final claudeApiKey = dotenv.env['CLAUDE_API_KEY'];

      if (openAiApiKey != null && openAiApiKey.isNotEmpty) {
        // OpenAI embedding setup
        _setupOpenAiEmbeddings(openAiApiKey);
      } else if (claudeApiKey != null && claudeApiKey.isNotEmpty) {
        // Claude embedding setup
        _setupClaudeEmbeddings(claudeApiKey);
      } else {
        _logger.warning('No API keys found for embeddings. RetrievalManager will not be initialized.');
      }

      // Load documents
      await _loadDocuments();

      _isInitialized = true;
      _logger.info('DocumentService initialized with ${_documents.length} documents');
    } catch (e, stackTrace) {
      _logger.severe('Error initializing DocumentService: $e');
      _logger.severe('Stack trace: $stackTrace');
      rethrow;
    }
  }

  // OpenAI embedding setup
  void _setupOpenAiEmbeddings(String apiKey) {
    _logger.info('Setting up OpenAI embeddings');

    // Create McpLlm instance
    final mcpLlm = McpLlm();

    // Register OpenAI provider
    mcpLlm.registerProvider('openai', OpenAiProviderFactory());

    // Create RetrievalManager
    _retrievalManager = mcpLlm.createRetrievalManager(
      providerName: 'openai',
      documentStore: _documentStore,
      config: LlmConfiguration(
        apiKey: apiKey,
        model: 'text-embedding-3-large',
      ),
    );

    _logger.info('OpenAI RetrievalManager created');
  }

  // Claude embedding setup
  void _setupClaudeEmbeddings(String apiKey) {
    _logger.info('Setting up Claude embeddings');

    // Create McpLlm instance
    final mcpLlm = McpLlm();

    // Register Claude provider
    mcpLlm.registerProvider('claude', ClaudeProviderFactory());

    // Create RetrievalManager
    _retrievalManager = mcpLlm.createRetrievalManager(
      providerName: 'claude',
      documentStore: _documentStore,
      config: LlmConfiguration(
        apiKey: apiKey,
        model: 'claude-3-sonnet-20240229',
      ),
    );

    _logger.info('Claude RetrievalManager created');
  }

  // Load documents
  Future<void> _loadDocuments() async {
    try {
      _logger.info('Loading documents from store');
      final documents = await _documentStore.getAllDocuments();

      _documents = documents;
      _documentsStreamController.add(_documents);

      _logger.info('Loaded ${documents.length} documents');
    } catch (e) {
      _logger.severe('Error loading documents: $e');
    }
  }

  // Add document
  Future<String> addDocument({
    required String title,
    required String content,
    Map<String, dynamic>? metadata,
  }) async {
    if (!_isInitialized) {
      throw Exception('DocumentService not initialized');
    }

    if (_retrievalManager == null) {
      throw Exception('RetrievalManager not initialized');
    }

    try {
      _logger.info('Adding document: $title');

      // Prepare metadata
      final docMetadata = metadata ?? {};
      if (!docMetadata.containsKey('created_at')) {
        docMetadata['created_at'] = DateTime.now().toIso8601String();
      }

      // Create document
      final document = Document(
        id: 'doc_${DateTime.now().millisecondsSinceEpoch}',
        title: title,
        content: content,
        metadata: docMetadata,
      );

      // Add document and generate embeddings
      final docId = await _retrievalManager!.addDocument(document);

      // Update document list
      await _loadDocuments();

      _logger.info('Document added with ID: $docId');
      return docId;
    } catch (e, stackTrace) {
      _logger.severe('Error adding document: $e');
      _logger.severe('Stack trace: $stackTrace');
      rethrow;
    }
  }

  // Get document
  Document? getDocument(String id) {
    try {
      return _documentStore.getDocument(id);
    } catch (e) {
      _logger.warning('Error getting document $id: $e');
      return null;
    }
  }

  // Delete document
  Future<bool> deleteDocument(String id) async {
    if (!_isInitialized) {
      throw Exception('DocumentService not initialized');
    }

    try {
      _logger.info('Deleting document: $id');
      final result = await _documentStore.deleteDocument(id);

      if (result) {
        // Update document list
        await _loadDocuments();
        _logger.info('Document deleted: $id');
      } else {
        _logger.warning('Document not found or deletion failed: $id');
      }

      return result;
    } catch (e) {
      _logger.severe('Error deleting document: $e');
      return false;
    }
  }

  // Update document
  Future<String?> updateDocument({
    required String id,
    String? title,
    String? content,
    Map<String, dynamic>? metadata,
  }) async {
    if (!_isInitialized) {
      throw Exception('DocumentService not initialized');
    }

    if (_retrievalManager == null) {
      throw Exception('RetrievalManager not initialized');
    }

    try {
      _logger.info('Updating document: $id');

      // Retrieve existing document
      final document = _documentStore.getDocument(id);
      if (document == null) {
        _logger.warning('Document not found: $id');
        return null;
      }

      // Prepare metadata
      final updatedMetadata = Map<String, dynamic>.from(document.metadata);
      if (metadata != null) {
        updatedMetadata.addAll(metadata);
      }
      updatedMetadata['updated_at'] = DateTime.now().toIso8601String();

      // Create updated document
      final updatedDocument = Document(
        id: document.id,
        title: title ?? document.title,
        content: content ?? document.content,
        metadata: updatedMetadata,
      );

      // Delete and re-add document
      await _documentStore.deleteDocument(id);
      final docId = await _retrievalManager!.addDocument(updatedDocument);

      // Update document list
      await _loadDocuments();

      _logger.info('Document updated: $id');
      return docId;
    } catch (e) {
      _logger.severe('Error updating document: $e');
      return null;
    }
  }

  // Search documents
  Future<List<Document>> searchDocuments(String query, {int topK = 5}) async {
    if (!_isInitialized) {
      throw Exception('DocumentService not initialized');
    }

    if (_retrievalManager == null) {
      throw Exception('RetrievalManager not initialized');
    }

    try {
      _logger.info('Searching documents: "$query" (topK: $topK)');

      final results = await _retrievalManager!.retrieveRelevant(
        query,
        topK: topK,
        minimumScore: 0.6,
      );

      _logger.info('Found ${results.length} documents for query: "$query"');
      return results;
    } catch (e) {
      _logger.severe('Error searching documents: $e');
      return [];
    }
  }

  // Filter documents by tags
  List<Document> getDocumentsByTags(List<String> tags) {
    if (tags.isEmpty) return _documents;

    return _documents.where((doc) {
      if (!doc.metadata.containsKey('tags') || !(doc.metadata['tags'] is List)) {
        return false;
      }

      final docTags = doc.metadata['tags'] as List;
      return tags.every((tag) => docTags.contains(tag));
    }).toList();
  }

  // Get all tags
  List<String> getAllTags() {
    final Set<String> allTags = {};

    for (final doc in _documents) {
      if (doc.metadata.containsKey('tags') && doc.metadata['tags'] is List) {
        final tags = doc.metadata['tags'] as List;
        for (final tag in tags) {
          allTags.add(tag.toString());
        }
      }
    }

    return allTags.toList()..sort();
  }

  // Create backup
  Future<String> createBackup(String backupPath) async {
    try {
      _logger.info('Creating backup to $backupPath');

      // Check backup directory
      final backupDir = Directory(backupPath);
      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }

      // Generate timestamp
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').replaceAll('.', '-');
      final backupFilePath = path.join(backupPath, 'documents_$timestamp.json');
      final backupFile = File(backupFilePath);

      // Get all current documents
      final documents = await _documentStore.getAllDocuments();

      // Construct backup data
      final backupData = {
        'timestamp': timestamp,
        'document_count': documents.length,
        'documents': documents.map((doc) => doc.toJson()).toList(),
      };

      // Save to file
      await backupFile.writeAsString(jsonEncode(backupData));

      _logger.info('Backup created at $backupFilePath with ${documents.length} documents');
      return backupFilePath;
    } catch (e) {
      _logger.severe('Error creating backup: $e');
      rethrow;
    }
  }

  // Restore from backup
  Future<int> restoreFromBackup(String backupFilePath) async {
    try {
      _logger.info('Restoring from backup: $backupFilePath');

      // Read backup file
      final backupFile = File(backupFilePath);
      if (!await backupFile.exists()) {
        throw Exception('Backup file not found: $backupFilePath');
      }

      final jsonString = await backupFile.readAsString();
      final backupData = jsonDecode(jsonString) as Map<String, dynamic>;

      // Extract documents
      final List<dynamic> docData = backupData['documents'];

      // Delete existing documents (optional)
      int restoredCount = 0;

      // Add new documents
      if (_retrievalManager != null) {
        for (final data in docData) {
          try {
            // Create Document object
            final doc = Document.fromJson(data);

            // Add document
            await _retrievalManager!.addDocument(doc);
            restoredCount++;
          } catch (e) {
            _logger.warning('Error restoring document: $e');
          }
        }
      }

      // Update document list
      await _loadDocuments();

      _logger.info('Restored $restoredCount documents from backup');
      return restoredCount;
    } catch (e, stackTrace) {
      _logger.severe('Error restoring from backup: $e');
      _logger.severe('Stack trace: $stackTrace');
      rethrow;
    }
  }

  // Resource cleanup
  void dispose() {
    _documentsStreamController.close();
  }
}
