import 'package:flutter/material.dart';
import 'package:lustra_ai/models/template.dart';
import 'package:lustra_ai/screens/add_template_screen.dart';
import 'package:lustra_ai/widgets/glassmorphic_container.dart';

class TemplateSearchDelegate extends SearchDelegate<Template?> {
  final List<Template> templates;

  TemplateSearchDelegate(this.templates);

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchResults(context);
  }

  Widget _buildSearchResults(BuildContext context) {
    final filteredTemplates = query.isEmpty
        ? templates
        : templates
            .where((template) =>
                template.title.toLowerCase().contains(query.toLowerCase()))
            .toList();

    if (filteredTemplates.isEmpty) {
      return const Center(
        child: Text('No templates found.'),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.75,
      ),
      itemCount: filteredTemplates.length,
      itemBuilder: (context, index) {
        final template = filteredTemplates[index];
        return GestureDetector(
          onTap: () => _showEditDialog(context, template),
          child: GlassmorphicContainer(
            width: 180,
            height: 220,
            child: Column(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.network(template.imageUrl,
                        fit: BoxFit.cover, width: double.infinity),
                  ),
                ),
                const SizedBox(height: 8),
                Text(template.title,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(color: Colors.white)),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showEditDialog(BuildContext context, Template template) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit Template'),
        content: const Text('What would you like to do?'),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop(); // Close the dialog
              // Navigate to the edit screen
              Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (context) => AddTemplateScreen(
                      template: template, templateType: template.templateType),
                ),
              );
            },
            child: const Text('Edit'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}
