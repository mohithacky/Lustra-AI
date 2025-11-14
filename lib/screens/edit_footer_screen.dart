import 'package:flutter/material.dart';
import 'package:lustra_ai/models/footer_data.dart';

class EditFooterScreen extends StatefulWidget {
  final List<FooterColumnData> footerData;

  const EditFooterScreen({Key? key, required this.footerData}) : super(key: key);

  @override
  _EditFooterScreenState createState() => _EditFooterScreenState();
}

class _EditFooterScreenState extends State<EditFooterScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Footer'),
      ),
      body: ListView.builder(
        itemCount: widget.footerData.length,
        itemBuilder: (context, index) {
          final column = widget.footerData[index];
          return ExpansionTile(
            title: Text(column.title),
            children: column.links.map((link) {
              return ListTile(
                title: Text(link),
                trailing: IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () {
                    // TODO: Implement delete functionality
                  },
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
