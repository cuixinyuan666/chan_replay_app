import 'package:flutter/material.dart';

/// 研究页面里的筹码分布最小 UI。
///
/// 当前只保留“价格桶数”这个最小颗粒度设置；实际 K 线图筹码分布渲染仍由
/// S13SingleStockReplayPage / S13ChipDistributionPanel 消费当前 K 线图上下文。
class ChipDistributionPage extends StatefulWidget {
  const ChipDistributionPage({super.key});

  @override
  State<ChipDistributionPage> createState() => _ChipDistributionPageState();
}

class _ChipDistributionPageState extends State<ChipDistributionPage> {
  int _binCount = 80;

  static const String _bucketTooltip =
      '价格桶数：把当前价格区间切成多少个价格层来统计筹码。数值越大，价格分层越细；数值越小，分布越平滑。';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0D10),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFF131722),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        const Icon(Icons.stacked_bar_chart,
                            color: Color(0xFF8AB4FF)),
                        const SizedBox(width: 8),
                        Text(
                          '筹码分布/价格桶数',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const Spacer(),
                        const Tooltip(
                          message: _bucketTooltip,
                          waitDuration: Duration(milliseconds: 250),
                          child: Icon(Icons.info_outline, color: Colors.white54),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: <Widget>[
                        const Tooltip(
                          message: _bucketTooltip,
                          waitDuration: Duration(milliseconds: 250),
                          child: Text(
                            '价格桶数',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '$_binCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      value: _binCount.toDouble(),
                      min: 24,
                      max: 160,
                      divisions: 136,
                      label: '$_binCount',
                      onChanged: (value) =>
                          setState(() => _binCount = value.round()),
                    ),
                    const Text(
                      '仅保留价格桶数设置；其它筹码分布加载、目标K、指标和绘图逻辑已从该研究页移除。',
                      style: TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
