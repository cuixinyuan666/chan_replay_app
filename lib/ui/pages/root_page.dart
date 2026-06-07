import 'package:flutter/material.dart';

import 'czsc_easy_tdx_page.dart';
import 'replay_page.dart';

class RootPage extends StatefulWidget {
  const RootPage({super.key});

  @override
  State<RootPage> createState() => _RootPageState();
}

class _RootPageState extends State<RootPage> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          ReplayPage(),
          CzscEasyTdxPage(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.timeline),
            label: '本地复盘',
          ),
          NavigationDestination(
            icon: Icon(Icons.hub),
            label: 'CZSC后端',
          ),
        ],
      ),
    );
  }
}
