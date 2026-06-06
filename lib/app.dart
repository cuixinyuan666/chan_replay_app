import 'package:flutter/material.dart';
import 'ui/pages/replay_page.dart';

class ChanReplayApp extends StatelessWidget {
  const ChanReplayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '缠论K线复盘',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3367D6), brightness: Brightness.dark),
        scaffoldBackgroundColor: const Color(0xFF101216),
      ),
      home: const ReplayPage(),
    );
  }
}
