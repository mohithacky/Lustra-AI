import 'package:flutter/material.dart';
import 'package:lustra_ai/models/template.dart';
import 'package:lustra_ai/services/firestore_service.dart';
import 'package:lustra_ai/screens/add_template_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lustra_ai/widgets/glassmorphic_container.dart';
import 'package:lustra_ai/screens/template_search_delegate.dart';

class MyDesignsScreen extends StatefulWidget {
  const MyDesignsScreen({Key? key}) : super(key: key);

  @override
  _MyDesignsScreenState createState() => _MyDesignsScreenState();
}

class _MyDesignsScreenState extends State<MyDesignsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final FirestoreService _firestoreService = FirestoreService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final bool isAdmin = user?.email == 'mohithacky890@gmail.com';

    return SafeArea(
      child: StreamBuilder<List<Template>>(
        stream: isAdmin
            ? _firestoreService.getAdminTemplatesStream()
            : _firestoreService.getAllUserTemplatesStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.white));
          }
          if (snapshot.hasError) {
            return Center(
                child: Text('Error: ${snapshot.error}',
                    style: Theme.of(context)
                        .textTheme
                        .bodyLarge
                        ?.copyWith(color: Colors.white)));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Text('You haven\'t created any templates yet.',
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(color: Colors.white70)),
            );
          }

          final templates = snapshot.data!;
          final photoShootTemplates = templates
              .where((t) => t.templateType.toLowerCase() == 'photoshoot')
              .toList();
          final adShootTemplates = templates
              .where((t) => t.templateType.toLowerCase() == 'adshoot')
              .toList();
          final productShootTemplates = templates
              .where((t) => t.templateType.toLowerCase() == 'productshoot')
              .toList();

          return Scaffold(
            appBar: AppBar(
              title: const Text('My Designs'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () {
                    showSearch(context: context, delegate: TemplateSearchDelegate(templates));
                  },
                ),
              ],
              backgroundColor: Colors.transparent,
              elevation: 0,
              bottom: TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'ProductShoot'),
                  Tab(text: 'PhotoShoot'),
                  Tab(text: 'AdShoot'),
                ],
              ),
            ),
            body: TabBarView(
              controller: _tabController,
              children: [
                _buildTemplateGrid(productShootTemplates),
                _buildTemplateGrid(photoShootTemplates),
                _buildTemplateGrid(adShootTemplates),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTemplateGrid(List<Template> templates) {
    if (templates.isEmpty) {
      return Center(
        child: Text(
          'No templates in this category yet.',
          style: Theme.of(context)
              .textTheme
              .bodyLarge
              ?.copyWith(color: Colors.white70),
        ),
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
      itemCount: templates.length,
      itemBuilder: (context, index) {
        final template = templates[index];
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
                  builder: (context) => AddTemplateScreen(template: template, templateType: template.templateType),
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
