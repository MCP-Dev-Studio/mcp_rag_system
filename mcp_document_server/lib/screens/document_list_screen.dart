import 'package:flutter/material.dart';
import 'package:mcp_llm/mcp_llm.dart';

// Local imports
import '../widgets/document_card.dart';
import 'document_details.dart';

// Global service instance
import '../main.dart' show serverService;

class DocumentListScreen extends StatefulWidget {
  const DocumentListScreen({Key? key}) : super(key: key);

  @override
  State<DocumentListScreen> createState() => _DocumentListScreenState();
}

class _DocumentListScreenState extends State<DocumentListScreen> {
  List<Document> _documents = [];
  List<Document> _filteredDocuments = [];
  bool _isLoading = true;
  List<String> _availableTags = [];
  final Set<String> _selectedTags = {};
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Load documents
  Future<void> _loadDocuments() async {
    if (serverService.documentService == null) {
      setState(() {
        _documents = [];
        _filteredDocuments = [];
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final docs = serverService.documentService!.documents;
      final tags = serverService.documentService!.getAllTags();

      setState(() {
        _documents = docs;
        _filteredDocuments = docs;
        _availableTags = tags;
        _isLoading = false;
      });

      // Apply search and filters
      _applyFilters();
    } catch (e) {
      setState(() {
        _documents = [];
        _filteredDocuments = [];
        _isLoading = false;
      });
    }
  }

  // Apply search and tag filters
  void _applyFilters() {
    final query = _searchController.text.toLowerCase();

    setState(() {
      _filteredDocuments = _documents.where((doc) {
        // Apply tag filter
        if (_selectedTags.isNotEmpty) {
          final docTags = doc.metadata['tags'] as List?;
          if (docTags == null) return false;

          // Check if document has all selected tags
          for (final tag in _selectedTags) {
            if (!docTags.contains(tag)) return false;
          }
        }

        // Apply search filter
        if (query.isNotEmpty) {
          return doc.title.toLowerCase().contains(query) ||
              doc.content.toLowerCase().contains(query);
        }

        return true;
      }).toList();
    });
  }

  // Toggle tag selection
  void _toggleTag(String tag) {
    setState(() {
      if (_selectedTags.contains(tag)) {
        _selectedTags.remove(tag);
      } else {
        _selectedTags.add(tag);
      }
      _applyFilters();
    });
  }

  // Clear all filters
  void _clearFilters() {
    setState(() {
      _selectedTags.clear();
      _searchController.clear();
      _filteredDocuments = _documents;
    });
  }

  // Open document details
  void _openDocumentDetails(Document document) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DocumentDetailsScreen(document: document),
      ),
    ).then((_) {
      // Refresh list when returning from details
      _loadDocuments();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Show placeholder if server is not running
    if (serverService.documentService == null) {
      return const Center(
        child: Text('Server is not running'),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadDocuments,
      child: Column(
        children: [
          // Search and filter bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Search field
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search documents...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _applyFilters();
                      },
                    )
                        : null,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (_) => _applyFilters(),
                ),

                const SizedBox(height: 8.0),

                // Tags filter
                if (_availableTags.isNotEmpty)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        // Clear filters button
                        if (_selectedTags.isNotEmpty || _searchController.text.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: ElevatedButton(
                              onPressed: _clearFilters,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: theme.colorScheme.secondary,
                                foregroundColor: theme.colorScheme.onSecondary,
                              ),
                              child: const Text('Clear Filters'),
                            ),
                          ),

                        // Tags list
                        ..._availableTags.map((tag) {
                          final isSelected = _selectedTags.contains(tag);
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: FilterChip(
                              label: Text(tag),
                              selected: isSelected,
                              onSelected: (_) => _toggleTag(tag),
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // Document list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredDocuments.isEmpty
                ? Center(
              child: Text(
                _documents.isEmpty
                    ? 'No documents available'
                    : 'No documents match the current filters',
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: _filteredDocuments.length,
              itemBuilder: (context, index) {
                final document = _filteredDocuments[index];
                return DocumentCard(
                  document: document,
                  onTap: () => _openDocumentDetails(document),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}