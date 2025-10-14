import 'package:flutter/material.dart';
import 'package:lustra_ai/models/template.dart';
import 'package:lustra_ai/screens/jewellery_template_screen.dart';
import 'package:lustra_ai/widgets/glassmorphic_container.dart';

class JewelleryCategorySelectionScreen extends StatelessWidget {
  final String shootType;

  const JewelleryCategorySelectionScreen({Key? key, required this.shootType})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final jewelleryTypes = [
      {'name': 'Necklace', 'image': 'assets/images/logo.png'},
      {'name': 'Earrings', 'image': 'assets/images/earrings.jpg'},
      {'name': 'Bangles', 'image': 'assets/images/logo.png'},
      {'name': 'Baali', 'image': 'assets/images/logo.png'},
      {'name': 'Belt Necklace', 'image': 'assets/images/logo.png'},
      {'name': 'Long Necklace', 'image': 'assets/images/logo.png'},
      {'name': 'Chain', 'image': 'assets/images/logo.png'},
      {'name': 'Nathia', 'image': 'assets/images/logo.png'},
      {'name': 'Choker', 'image': 'assets/images/logo.png'},
      {'name': 'Ring', 'image': 'assets/images/logo.png'},
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text('Select Jewellery Type for $shootType'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.0,
          ),
          itemCount: jewelleryTypes.length,
          itemBuilder: (context, index) {
            final type = jewelleryTypes[index];
            return _buildJewelleryTypeCard(
                context, type['name']!, type['image']!);
          },
        ),
      ),
    );
  }

  Widget _buildJewelleryTypeCard(
      BuildContext context, String type, String imagePath) {
    return GestureDetector(
      onTap: () async {
        final selectedTemplate = await Navigator.of(context).push<Template>(
          MaterialPageRoute(
            builder: (context) => JewelleryTemplateScreen(
              initialJewelleryType: type,
              shootType: shootType, // Pass the shootType to the template screen
            ),
          ),
        );
        if (selectedTemplate != null) {
          // If a template is selected, pop back to the UploadScreen with it
          Navigator.of(context).pop(selectedTemplate);
        }
      },
      child: GlassmorphicContainer(
        width: 150,
        height: 150,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              backgroundImage: AssetImage(imagePath),
              radius: 30,
            ),
            const SizedBox(height: 12),
            Text(
              type,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: Colors.white, fontSize: 10.0),
            ),
          ],
        ),
      ),
    );
  }
}
