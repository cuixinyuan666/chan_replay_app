import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import 'ui/pages/root_page.dart';
import 'ui/widgets/windows_hover_title_bar.dart';

class ChanReplayApp extends StatelessWidget {
  const ChanReplayApp({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF2962FF),
      brightness: Brightness.dark,
    ).copyWith(surface: const Color(0xFF131722));

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '缠论K线复盘',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: scheme,
        scaffoldBackgroundColor: const Color(0xFF0B0D10),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF131722),
          foregroundColor: Colors.white,
        ),
        sliderTheme: const SliderThemeData(
          activeTrackColor: Color(0xFF2962FF),
          thumbColor: Color(0xFF2962FF),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF0B0D10),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      builder: (context, child) {
        final content = child ?? const SizedBox.shrink();
        if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
          return WindowsHoverTitleBar(child: ExcludeSemantics(child: content));
        }
        return content;
      },
      home: const RootPage(),
    );
  }
}
