import 'package:flutter/material.dart';

class ChanpyComparePage extends StatelessWidget {
  const ChanpyComparePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0D10),
      appBar: AppBar(
        toolbarHeight: 40,
        elevation: 0,
        backgroundColor: const Color(0xFF131722),
        title: const Text('Vespa 对齐测试基准', style: TextStyle(fontSize: 14)),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: const [
            _SectionCard(
              title: '用途',
              body:
                  '该选项卡只作为测试基准入口说明，不参与实时行情和前端绘图。后续修缠论算法前，先跑 tools/chanpy_compare，把 Dart 引擎与 Vespa/chan.py 的 FX、BI、SEG、ZS 输出做结构化 diff。',
            ),
            SizedBox(height: 12),
            _SectionCard(
              title: '运行步骤',
              body:
                  '1. git clone https://github.com/Vespa314/chan.py.git ../chan.py\n'
                  '2. python tools/chanpy_compare/run_compare.py --csv assets/sample_data/000001_daily.csv --chanpy-path ../chan.py --out build/chanpy_compare\n'
                  '3. 查看 build/chanpy_compare/diff_report.md\n'
                  '4. 按差异最大模块修复：先 BI，再 SEG，再 ZS。',
            ),
            SizedBox(height: 12),
            _SectionCard(
              title: '输出文件',
              body:
                  'build/chanpy_compare/chanpy.json：Vespa/chan.py 输出\n'
                  'build/chanpy_compare/chanpy_raw.json：chan.py 原始 toJson 输出，首次运行后用于收紧字段映射\n'
                  'build/chanpy_compare/dart.json：当前 Dart ChanReplayEngine 输出\n'
                  'build/chanpy_compare/diff_report.json：机器可读差异\n'
                  'build/chanpy_compare/diff_report.md：人工阅读差异报告',
            ),
            SizedBox(height: 12),
            _SectionCard(
              title: '硬性约束',
              body:
                  '前端错位、提示重叠、按钮重复等问题只修前端。\n'
                  '算法问题必须先用 Vespa 对齐基准定位差异。\n'
                  '禁止为了让图形看起来合理而自造 FX/BI/SEG/ZS 规则。',
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String body;

  const _SectionCard({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF131722),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
            const SizedBox(height: 8),
            SelectableText(body, style: const TextStyle(color: Colors.white70, height: 1.45)),
          ],
        ),
      ),
    );
  }
}
