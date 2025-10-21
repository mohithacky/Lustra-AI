import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:lustra_ai/services/firestore_service.dart';
import 'package:lustra_ai/models/template.dart';
import 'package:lustra_ai/theme/app_theme.dart';

class TemplateGrid extends StatefulWidget {
  final String jewelleryType;
  final String shootType;
  final Function(Template) onTemplateSelected;

  const TemplateGrid({
    Key? key,
    required this.jewelleryType,
    required this.shootType,
    required this.onTemplateSelected,
  }) : super(key: key);

  @override
  _TemplateGridState createState() => _TemplateGridState();
}

class _TemplateGridState extends State<TemplateGrid> {
  final FirestoreService _firestoreService = FirestoreService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Template>>(
      stream: _firestoreService.getTemplatesForType(widget.jewelleryType, shootType: widget.shootType),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error: ${snapshot.error}',
              style: const TextStyle(color: Colors.red),
            ),
          );
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Text(
              'No templates for ${widget.jewelleryType}',
              style: const TextStyle(color: Colors.white70),
            ),
          );
        }

        final templates = snapshot.data!;

        return MasonryGridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          itemCount: templates.length,
          itemBuilder: (context, index) {
            final template = templates[index];
            return GestureDetector(
              onTap: () => widget.onTemplateSelected(template),
              child: _buildTemplateCard(context, template),
            );
          },
        );
      },
    );
  }

  Widget _buildTemplateCard(BuildContext context, Template template) {
    return Card(
      color: AppTheme.secondaryColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Image.network(
            template.imageUrl,
            fit: BoxFit.cover,
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              template.title,
              style: Theme.of(context).textTheme.titleSmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Text(
              template.jewelleryType,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
