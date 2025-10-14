import 'package:flutter/material.dart';
import 'package:lustra_ai/models/template.dart';
import 'package:lustra_ai/screens/ad_shoot_generation_screen.dart';
import 'package:lustra_ai/theme/app_theme.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lustra_ai/services/firestore_service.dart';
import 'dart:developer';
import 'package:lustra_ai/services/template_service.dart';

class AdShootGrid extends StatefulWidget {
  final List<Template> templates;
  final Function(Template)? onTemplateTap;

  const AdShootGrid({Key? key, required this.templates, this.onTemplateTap})
      : super(key: key);

  @override
  _AdShootGridState createState() => _AdShootGridState();
}

class _AdShootGridState extends State<AdShootGrid> {
  final FirestoreService _firestoreService = FirestoreService();
  final TemplateService _templateService = TemplateService();
  late User? _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
  }

  void _handleLike(Template template) {
    setState(() {
      final userEmail = _currentUser?.email;
      if (userEmail != null) {
        if (template.likedBy.contains(userEmail)) {
          template.likedBy.remove(userEmail);
        } else {
          template.likedBy.add(userEmail);
        }
      }
    });

    _templateService.toggleTemplateLike(template).catchError((error) {
      setState(() {
        final userEmail = _currentUser?.email;
        if (userEmail != null) {
          if (template.likedBy.contains(userEmail)) {
            template.likedBy.remove(userEmail);
          } else {
            template.likedBy.add(userEmail);
          }
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update like: $error')),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: widget.templates.map((template) {
            return GestureDetector(
              onTap: () {
                print('--- Template Prompt Start ---');
                const int chunkSize = 800;
                for (int i = 0; i < template.prompt.length; i += chunkSize) {
                  int end = (i + chunkSize < template.prompt.length) ? i + chunkSize : template.prompt.length;
                  print(template.prompt.substring(i, end));
                }
                print('--- Template Prompt End ---');
                if (widget.onTemplateTap != null) {
                  widget.onTemplateTap!(template);
                } else {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => AdShootGenerationScreen(
                      template: template,
                    ),
                  ));
                }
              },
              child: _buildTemplateCard(context, template),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildTemplateCard(BuildContext context, Template template) {
    log('Image URL: ${template.imageUrl}');
    return Card(
      color: AppTheme.secondaryColor,
      margin: const EdgeInsets.only(bottom: 16),
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
                width: double.infinity,
                height: 200,
                placeholder: (context, url) =>
                    const Center(child: CircularProgressIndicator()),
                errorWidget: (context, url, error) => const Icon(Icons.error),
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
                                  try {
                                    await _firestoreService
                                        .deleteTemplate(template);
                                    Navigator.of(dialogContext).pop();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              'Template deleted successfully')),
                                    );
                                  } catch (e) {
                                    Navigator.of(dialogContext).pop();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content: Text(
                                              'Error deleting template: $e')),
                                    );
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: AppTheme.accentColor,
                  child: Text(
                    template.author.substring(0, 1),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    template.author,
                    style: Theme.of(context).textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                GestureDetector(
                  onTap: () => _handleLike(template),
                  child: Icon(
                    template.likedBy.contains(_currentUser?.email)
                        ? Icons.favorite
                        : Icons.favorite_border,
                    size: 16,
                    color: template.likedBy.contains(_currentUser?.email)
                        ? Colors.red
                        : Colors.grey,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  template.likes.toString(),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(width: 8),
                const Icon(Icons.trending_up, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  template.useCount.toString(),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
