import 'package:flutter/material.dart';

import 'ui/pages/root_page_four_way.dart';

class ChanReplayApp extends StatelessWidget {
  const ChanReplayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '缠论K线复盘',
      home: RootPage(),
    );
  }
}
