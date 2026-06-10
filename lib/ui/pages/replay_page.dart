import 'package:flutter/material.dart';

import 'origin_replay_page_v2.dart';

/// Compatibility wrapper for older routes/tests.
///
/// The production replay surface is [OriginReplayPageV2], which consumes Python
/// chan.py JSON. This file intentionally does not import or instantiate any
/// legacy Dart Chan engine so that production code cannot accidentally compute
/// FX/BI/SEG/ZS/BSP in Flutter.
class ReplayPage extends StatelessWidget {
  const ReplayPage({super.key});

  @override
  Widget build(BuildContext context) => const OriginReplayPageV2();
}
