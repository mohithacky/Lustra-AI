import 'package:flutter/material.dart';
import 'package:lustra_ai/theme/app_theme.dart';
import 'package:lustra_ai/widgets/template_grid.dart';

class JewelleryTemplateScreen extends StatefulWidget {
  final String initialJewelleryType;
  final String shootType;

  const JewelleryTemplateScreen(
      {Key? key, required this.initialJewelleryType, required this.shootType})
      : super(key: key);

  @override
  _JewelleryTemplateScreenState createState() =>
      _JewelleryTemplateScreenState();
}

class _JewelleryTemplateScreenState extends State<JewelleryTemplateScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<String> _jewelleryTypes = [
    'Necklace',
    'Earrings',
    'Bangles',
    'Bali',
    'Jhumka',
    'Ring'
  ];

  @override
  void initState() {
    super.initState();
    int initialIndex = _jewelleryTypes.indexOf(widget.initialJewelleryType);
    if (initialIndex == -1) {
      initialIndex = 0;
    }
    _tabController = TabController(
        length: _jewelleryTypes.length, vsync: this, initialIndex: initialIndex);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select a Template'),
        backgroundColor: AppTheme.primaryColor,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: _jewelleryTypes.map((String type) => Tab(text: type)).toList(),
          indicatorColor: AppTheme.accentColor,
          labelColor: AppTheme.accentColor,
          unselectedLabelColor: Colors.grey,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _jewelleryTypes.map((String type) {
          return TemplateGrid(
            jewelleryType: type,
            shootType: widget.shootType,
            onTemplateSelected: (template) {
              Navigator.of(context).pop(template);
            },
          );
        }).toList(),
      ),
    );
  }
}
