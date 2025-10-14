import 'package:flutter/material.dart';
import 'package:lustra_ai/models/template.dart';
import 'package:lustra_ai/services/used_template_service.dart';
import 'package:lustra_ai/widgets/static_template_grid.dart';

class UsedTemplatesScreen extends StatefulWidget {
  const UsedTemplatesScreen({Key? key}) : super(key: key);

  @override
  _UsedTemplatesScreenState createState() => _UsedTemplatesScreenState();
}

class _UsedTemplatesScreenState extends State<UsedTemplatesScreen> {
  late Stream<List<Template>> _usedTemplatesStream;
  final UsedTemplateService _usedTemplateService = UsedTemplateService();

  @override
  void initState() {
    super.initState();
    _usedTemplatesStream = _usedTemplateService.getUsedTemplatesStream();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Used Templates'),
      ),
      body: StreamBuilder<List<Template>>(
        stream: _usedTemplatesStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No used templates found.'));
          }

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: StaticTemplateGrid(templates: snapshot.data!),
          );
        },
      ),
    );
  }
}
