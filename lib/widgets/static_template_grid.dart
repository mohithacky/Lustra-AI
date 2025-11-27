import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:lustra_ai/models/template.dart';
import 'package:lustra_ai/theme/app_theme.dart';
import 'package:lustra_ai/upload_screen.dart';
import 'package:lustra_ai/screens/ad_shoot_generation_screen.dart';
import 'package:lustra_ai/screens/ecommerce_studio_generation_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lustra_ai/services/firestore_service.dart';
import 'dart:developer';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:animations/animations.dart';

class StaticTemplateGrid extends StatefulWidget {
  final List<Template> templates;
  final Function(Template)? onTemplateTap;
  final Future<void> Function(Template)? onDelete;
  final List<Map<String, String>>? categories;

  const StaticTemplateGrid(
      {Key? key,
      required this.templates,
      this.onTemplateTap,
      this.onDelete,
      this.categories})
      : super(key: key);

  @override
  _StaticTemplateGridState createState() => _StaticTemplateGridState();
}

class _StaticTemplateGridState extends State<StaticTemplateGrid> {
  final FirestoreService _firestoreService = FirestoreService();

  void _showImagePreview(String imageUrl) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.all(10),
          backgroundColor: Colors.black,
          child: Stack(
            children: [
              InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.contain,
                  placeholder: (context, url) =>
                      const Center(child: CircularProgressIndicator()),
                  errorWidget: (context, url, error) =>
                      const Icon(Icons.error, color: Colors.white),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return MasonryGridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      itemCount: widget.templates.length,
      itemBuilder: (context, index) {
        final template = widget.templates[index];
        return OpenContainer(
          transitionType: ContainerTransitionType.fade,
          closedBuilder: (BuildContext _, VoidCallback openContainer) {
            return GestureDetector(
              onTap: widget.onTemplateTap != null
                  ? () => widget.onTemplateTap!(template)
                  : openContainer,
              child: _buildTemplateCard(context, template),
            );
          },
          openBuilder: (BuildContext _, VoidCallback __) {
            final isAdShoot = template.templateType.toLowerCase() == 'adshoot';
            final isEcommerceStudioAdShoot = isAdShoot &&
                template.collection.any(
                  (c) => c.toLowerCase() == 'ecommerce studio',
                );

            if (isEcommerceStudioAdShoot) {
              return const EcommerceStudioGenerationScreen();
            } else if (isAdShoot) {
              return AdShootGenerationScreen(template: template);
            } else {
              return UploadScreen(
                shootType: template.templateType,
                selectedTemplate: template,
                showTemplateSelection: false,
              );
            }
          },
          closedColor: AppTheme.secondaryColor,
          openColor: AppTheme.backgroundColor,
          closedShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        );
      },
    );
  }

  Widget _buildTemplateCard(BuildContext context, Template template) {
    log('Image URL: ${template.imageUrl}');
    return Card(
      color: AppTheme.secondaryColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              CachedNetworkImage(
                imageUrl: template.imageUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) =>
                    const Center(child: CircularProgressIndicator()),
                errorWidget: (context, url, error) => const Icon(Icons.error),
              ),
              Positioned(
                top: 8,
                left: 8,
                child: GestureDetector(
                  onTap: () => _showImagePreview(template.imageUrl),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.visibility,
                        color: Colors.white, size: 20),
                  ),
                ),
              ),
              if (FirebaseAuth.instance.currentUser?.email ==
                  'mohithacky890@gmail.com')
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (BuildContext dialogContext) {
                          return AlertDialog(
                            title: const Text('Delete Template'),
                            content: const Text(
                                'Are you sure you want to delete this template? This action cannot be undone.'),
                            actions: <Widget>[
                              TextButton(
                                child: const Text('Cancel'),
                                onPressed: () {
                                  Navigator.of(dialogContext).pop();
                                },
                              ),
                              TextButton(
                                child: const Text('Delete'),
                                onPressed: () async {
                                  Navigator.of(dialogContext)
                                      .pop(); // Close the dialog immediately
                                  if (widget.onDelete != null) {
                                    await widget.onDelete!(template);
                                  } else {
                                    // Fallback to old behavior if onDelete is not provided
                                    try {
                                      await _firestoreService
                                          .deleteTemplate(template);
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                            content: Text(
                                                'Template deleted successfully')),
                                      );
                                    } catch (e) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                            content: Text(
                                                'Error deleting template: $e')),
                                      );
                                    }
                                  }
                                },
                              ),
                            ],
                          );
                        },
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.delete,
                          color: Colors.white, size: 20),
                    ),
                  ),
                ),
            ],
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
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.grey),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
