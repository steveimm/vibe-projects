import 'package:flutter/material.dart';

import '../../shared/widgets.dart';
import 'body_tab.dart';
import 'analysis_tab.dart';

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});
  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Progress'),
        bottom: TabBar(
          isScrollable: MediaQuery.textScalerOf(context).scale(1) > 1.4,
          tabAlignment: MediaQuery.textScalerOf(context).scale(1) > 1.4 ? TabAlignment.start : TabAlignment.fill,
          tabs: const [
            Tab(text: 'Analysis'),
            Tab(text: 'Measurements'),
          ],
        ),
      ),
      body: const ContentWidth(child: TabBarView(children: [AnalysisTab(), BodyTab()])),
    ),
  );
}
