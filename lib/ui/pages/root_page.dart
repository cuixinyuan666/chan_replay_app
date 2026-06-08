import 'package:flutter/material.dart';

import '../drawing/tradingview_toolbox_host.dart';
import 'origin_replay_page_v2.dart';

class RootPage extends StatelessWidget {
  const RootPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const TradingViewToolboxHost(
      // 当前小任务先把 TradingView 工具箱入口接入根页面。
      // 画线落点与 ChanSnapshot 动态可用状态将在下一小任务移入图表状态层绑定。
      hasBars: true,
      hasChanSnapshot: false,
      child: OriginReplayPageV2(),
    );
  }
}
