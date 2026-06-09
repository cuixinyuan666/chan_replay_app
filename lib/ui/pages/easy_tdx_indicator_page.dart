import 'package:flutter/material.dart';

class EasyTdxIndicatorPage extends StatelessWidget {
  const EasyTdxIndicatorPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: const Color(0xFF0B0F16),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.insights, color: Color(0xFF8AB4FF), size: 28),
                  const SizedBox(width: 10),
                  Text(
                    'easy-tdx 指标',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                '本页用于确认 easy-tdx 指标分支已经进入 App。指标只做展示，不参与 chan.py 的 FX / BI / SEG / ZS / BSP 计算。',
                style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70, height: 1.5),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: const [
                  _IndicatorCard(title: 'VOL', desc: '成交量副图，raw_index 与 K线对齐'),
                  _IndicatorCard(title: 'amount', desc: '成交额，缺失时显示 --，不伪造 0'),
                  _IndicatorCard(title: 'turnover', desc: '换手率，easy-tdx 缺失时保持 null'),
                  _IndicatorCard(title: 'MA', desc: 'MA5 / MA10 / MA20 / MA60 展示线'),
                  _IndicatorCard(title: 'BOLL', desc: 'upper / mid / lower 展示线'),
                  _IndicatorCard(title: 'MACD', desc: 'DIF / DEA / HIST 展示副图'),
                ],
              ),
              const SizedBox(height: 24),
              const _StatusPanel(),
            ],
          ),
        ),
      ),
    );
  }
}

class _IndicatorCard extends StatelessWidget {
  final String title;
  final String desc;

  const _IndicatorCard({required this.title, required this.desc});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF151B26),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            desc,
            style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.35),
          ),
        ],
      ),
    );
  }
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF101722),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2962FF).withValues(alpha: 0.35)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '当前接入状态',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 10),
          _StatusRow(text: '后端已新增 backend/app/a_easy_tdx_indicators.py'),
          _StatusRow(text: 'easy_tdx_provider 已透传 raw_index / volume / amount / turnover'),
          _StatusRow(text: 'Flutter 已新增 EasyTdxIndicators 数据模型'),
          _StatusRow(text: 'ChanSnapshot 已具备 indicators 字段'),
          _StatusRow(text: '下一步：把 indicators 接入 OriginKlineChart 的主图/副图绘制'),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final String text;

  const _StatusRow({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
