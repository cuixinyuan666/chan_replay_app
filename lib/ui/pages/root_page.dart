import 'package:flutter/material.dart';

import 'chanpy_compare_page.dart';
import 'replay_page.dart';

class RootPage extends StatelessWidget {
  const RootPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFF0B0D10),
        appBar: AppBar(
          toolbarHeight: 40,
          elevation: 0,
          backgroundColor: const Color(0xFF131722),
          title: const Text('缠论复盘', style: TextStyle(fontSize: 15)),
          bottom: const TabBar(
            tabs: [
              Tab(text: '本地复盘'),
              Tab(text: 'Vespa对齐'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            ReplayPage(),
            ChanpyComparePage(),
          ],
        ),
      ),
    );
  }
}
