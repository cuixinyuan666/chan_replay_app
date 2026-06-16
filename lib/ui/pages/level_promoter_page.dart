import 'package:flutter/material.dart';

class LevelPromoterPage extends StatelessWidget {
  const LevelPromoterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF0D1117),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(52, 10, 10, 10),
          child: Center(
            child: Text('级别推进器', style: TextStyle(color: Colors.white)),
          ),
        ),
      ),
    );
  }
}
