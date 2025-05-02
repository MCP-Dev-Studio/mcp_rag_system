import 'package:flutter/material.dart';
import 'package:mcp_llm/mcp_llm.dart' hide Logger;
import 'package:logging/logging.dart';

// Global service instance
import '../main.dart' show serverService;

class DocumentDetailsScreen extends StatefulWidget {
  final Document document;

  const DocumentDetailsScreen({
    Key? key,
    required this.document,
  }) : super(key: key);

  @override
  State<DocumentDetailsScreen> createState() => _DocumentDetailsScreenState();
}

class _DocumentDetailsScreenState extends State<DocumentDetailsScreen> {
  final Logger _logger = Logger('DocumentDetailsScreen');

  late Document _document;
  bool _isEditing = false;
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  late TextEditingController _tagsController;
  late TextEditingController _authorController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _document = widget.document;
    _titleController = TextEditingController(text: _document.title);
    _contentController = TextEditingController(text: _document.content);

    // Initialize tags
    final tags = _document.metadata['tags'] as List?;
    _tagsController = TextEditingController(
      text: tags != null ? tags.join(', ') : '',
    );

    // Initialize author
    final author = _document.metadata['author'] as String?;
    _authorController = TextEditingController(
      text: author ?? '',
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _tagsController.dispose();
    _authorController.dispose();
    super.dispose();
  }

  // Delete document
  Future<void> _deleteDocument() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Document'),
        content: const Text('Are you sure you want to delete this document? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    ) ?? false;

    if (!confirmed) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Delete document
      final success = await serverService.documentService!.deleteDocument(_document.id);

      setState(() {
        _isLoading = false;
      });

      if (success) {
        // Show success message and navigate back
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Document deleted successfully')),
          );
        }
      } else {
        // Show error message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to delete document')),
          );
        }
      }
    } catch (e) {
      _logger.severe('Error deleting document: $e');

      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting document: $e')),
        );
      }
    }
  }

  // Save document changes
  Future<void> _saveChanges() async {
    // Validate fields
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title cannot be empty')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Process tags
      final tags = _tagsController.text.isEmpty
          ? <String>[]
          : _tagsController.text.split(',').map((t) => t.trim()).toList();

      // Prepare metadata
      final metadata = Map<String, dynamic>.from(_document.metadata);
      metadata['tags'] = tags;
      metadata['author'] = _authorController.text;
      metadata['updated_at'] = DateTime.now().toIso8601String();

      // Update document
      final updatedDocId = await serverService.documentService!.updateDocument(
        id: _document.id,
        title: _titleController.text,
        content: _contentController.text,
        metadata: metadata,
      );

      if (updatedDocId != null) {
        // Fetch updated document
        final updatedDoc = serverService.documentService!.getDocument(updatedDocId);

        setState(() {
          _isLoading = false;
          _isEditing = false;
          if (updatedDoc != null) {
            _document = updatedDoc;
          }
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Document updated successfully')),
          );
        }
      } else {
        setState(() {
          _isLoading = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to update document')),
          );
        }
      }
    } catch (e) {
      _logger.severe('Error updating document: $e');

      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating document: $e')),
        );
      }
    }
  }

  // Toggle edit mode
  void _toggleEditMode() {
    setState(() {
      _isEditing = !_isEditing;

      if (!_isEditing) {
        // Reset controllers when canceling edit
        _titleController.text = _document.title;
        _contentController.text = _document.content;

        final tags = _document.metadata['tags'] as List?;
        _tagsController.text = tags != null ? tags.join(', ') : '';

        final author = _document.metadata['author'] as String?;
        _authorController.text = author ?? '';
      }
    });
  }

  // View document embeddings
  Future<void> _viewEmbeddings() async {
    if (serverService.documentService!.retrievalManager == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Retrieval manager is not initialized. Embeddings are not available.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final retrievalManager = serverService.documentService!.retrievalManager!;

      // Find most similar documents to demonstrate embeddings are working
      final relatedDocs = await retrievalManager.retrieveRelevant(
        _document.title + ' ' + _document.content.substring(0, 100),
        topK: 5,
        minimumScore: 0.5,
      );

      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        // Show related documents dialog
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Vector Embeddings'),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Document ID: ${_document.id}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'This document has been processed with vector embeddings.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Related Documents',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    ...relatedDocs.map((doc) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(doc.title),
                        subtitle: Text(
                          doc.id == _document.id
                              ? 'Current document'
                              : 'ID: ${doc.id}',
                        ),
                        dense: true,
                      ),
                    )),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      _logger.severe('Error retrieving embeddings: $e');

      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error retrieving embeddings: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Extract metadata
    String? createdAt;
    String? updatedAt;
    String? author;
    List<String> tags = [];

    if (_document.metadata.containsKey('created_at')) {
      final timestamp = _document.metadata['created_at'] as String;
      try {
        final date = DateTime.parse(timestamp);
        createdAt = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
      } catch (_) {
        createdAt = timestamp;
      }
    }

    if (_document.metadata.containsKey('updated_at')) {
      final timestamp = _document.metadata['updated_at'] as String;
      try {
        final date = DateTime.parse(timestamp);
        updatedAt = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
      } catch (_) {
        updatedAt = timestamp;
      }
    }

    if (_document.metadata.containsKey('author')) {
      author = _document.metadata['author'] as String?;
    }

    if (_document.metadata.containsKey('tags') && _document.metadata['tags'] is List) {
      tags = (_document.metadata['tags'] as List).map((tag) => tag.toString()).toList();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Document Details'),
        actions: [
          // Vector embeddings button
          IconButton(
            icon: const Icon(Icons.auto_graph),
            tooltip: 'View Embeddings',
            onPressed: _isLoading ? null : _viewEmbeddings,
          ),

          // Edit/Save button
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.save),
              tooltip: 'Save Changes',
              onPressed: _isLoading ? null : _saveChanges,
            )
          else
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'Edit Document',
              onPressed: _isLoading ? null : _toggleEditMode,
            ),

          // Cancel/Delete button
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.cancel),
              tooltip: 'Cancel Editing',
              onPressed: _isLoading ? null : _toggleEditMode,
            )
          else
            IconButton(
              icon: const Icon(Icons.delete),
              tooltip: 'Delete Document',
              onPressed: _isLoading ? null : _deleteDocument,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Document ID
            Text(
              'ID: ${_document.id}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 16.0),

            // Title
            if (_isEditing)
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
                style: theme.textTheme.titleLarge,
              )
            else
              Text(
                _document.title,
                style: theme.textTheme.titleLarge,
              ),
            const SizedBox(height: 16.0),

            // Metadata
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Metadata', style: theme.textTheme.titleMedium),
                    const Divider(),

                    // Author
                    if (_isEditing)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: TextField(
                          controller: _authorController,
                          decoration: const InputDecoration(
                            labelText: 'Author',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      )
                    else if (author != null)
                      ListTile(
                        leading: const Icon(Icons.person),
                        title: const Text('Author'),
                        subtitle: Text(author),
                        dense: true,
                      ),

                    // Created date
                    if (createdAt != null)
                      ListTile(
                        leading: const Icon(Icons.calendar_today),
                        title: const Text('Created'),
                        subtitle: Text(createdAt),
                        dense: true,
                      ),

                    // Updated date
                    if (updatedAt != null)
                      ListTile(
                        leading: const Icon(Icons.update),
                        title: const Text('Updated'),
                        subtitle: Text(updatedAt),
                        dense: true,
                      ),

                    // Tags
                    if (_isEditing)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: TextField(
                          controller: _tagsController,
                          decoration: const InputDecoration(
                            labelText: 'Tags (comma separated)',
                            hintText: 'e.g. tutorial, reference, important',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      )
                    else if (tags.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Tags:'),
                            const SizedBox(height: 8.0),
                            Wrap(
                              spacing: 8.0,
                              runSpacing: 4.0,
                              children: tags.map((tag) => Chip(
                                label: Text(tag),
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              )).toList(),
                            ),
                          ],
                        ),
                      ),

                    // File info if available
                    if (_document.metadata.containsKey('filename'))
                      ListTile(
                        leading: const Icon(Icons.file_present),
                        title: const Text('Original File'),
                        subtitle: Text(_document.metadata['filename'] as String),
                        dense: true,
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16.0),

            // Content
            Text('Content', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8.0),

            if (_isEditing)
              TextField(
                controller: _contentController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                ),
                maxLines: null,
                minLines: 10,
              )
            else
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  border: Border.all(color: theme.dividerColor),
                  borderRadius: BorderRadius.circular(4.0),
                ),
                child: SelectableText(_document.content),
              ),
          ],
        ),
      ),
    );
  }
}