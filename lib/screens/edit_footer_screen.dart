import 'package:flutter/material.dart';
import 'package:lustra_ai/models/footer_data.dart';
import 'package:lustra_ai/services/firestore_service.dart';

class EditFooterScreen extends StatefulWidget {
  final List<FooterColumnData> footerData;
  final String userId;

  const EditFooterScreen({Key? key, required this.footerData, required this.userId})
      : super(key: key);

  @override
  _EditFooterScreenState createState() => _EditFooterScreenState();
}

class _EditFooterScreenState extends State<EditFooterScreen> {
  late Map<String, List<String>> _footerDataMap;
  final FirestoreService _firestoreService = FirestoreService();

  @override
  void initState() {
    super.initState();
    _footerDataMap = {for (var item in widget.footerData) item.title: List<String>.from(item.links)};
  }

  Future<void> _showDeleteConfirmationDialog(String columnTitle, String link) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Link'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('Are you sure you want to delete "$link"?'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Delete'),
              onPressed: () {
                _deleteLink(columnTitle, link);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteLink(String columnTitle, String link) async {
    setState(() {
      _footerDataMap[columnTitle]?.remove(link);
    });
    await _firestoreService.updateFooterData(_footerDataMap, widget.userId);
  }

  @override
  Widget build(BuildContext context) {
    final columns = _footerDataMap.keys.toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Footer'),
      ),
      body: ListView.builder(
        itemCount: columns.length,
        itemBuilder: (context, index) {
          final columnTitle = columns[index];
          final links = _footerDataMap[columnTitle]!;

          return ExpansionTile(
            title: Text(columnTitle),
            children: links.map((link) {
              return ListTile(
                title: Text(link),
                trailing: IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () => _showDeleteConfirmationDialog(columnTitle, link),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
