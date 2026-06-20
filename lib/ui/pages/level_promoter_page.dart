import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/settings/level_promoter_settings.dart';

class LevelPromoterPage extends StatefulWidget {
  const LevelPromoterPage({super.key});

  @override
  State<LevelPromoterPage> createState() => _LevelPromoterPageState();
}

class _LevelPromoterPageState extends State<LevelPromoterPage> {
  late final TextEditingController _maxLayerController;
  String _status = '默认全局 N=2；保存后所有后续 chan.py 请求统一使用该值。';

  @override
  void initState() {
    super.initState();
    _maxLayerController = TextEditingController(
      text: '${LevelPromoterSettings.currentMaxLayer}',
    );
    LevelPromoterSettings.maxLayer.addListener(_syncControllerFromGlobal);
  }

  @override
  void dispose() {
    LevelPromoterSettings.maxLayer.removeListener(_syncControllerFromGlobal);
    _maxLayerController.dispose();
    super.dispose();
  }

  void _syncControllerFromGlobal() {
    final text = '${LevelPromoterSettings.currentMaxLayer}';
    if (_maxLayerController.text != text) _maxLayerController.text = text;
    if (mounted) setState(() {});
  }

  void _save() {
    final parsed = int.tryParse(_maxLayerController.text.trim());
    if (parsed == null) {
      _show('请输入整数，最小值为 2');
      return;
    }
    LevelPromoterSettings.setMaxLayer(parsed);
    setState(() {
      _status =
          '已保存：全局级别推进器 N=${LevelPromoterSettings.currentMaxLayer}。后续单股多级别复盘、扫描器、S8 等请求会自动携带该值。';
    });
    _show('级别推进器全局 N=${LevelPromoterSettings.currentMaxLayer}');
  }

  Future<void> _copyConfig() async {
    final text = [
      'manual level promoter global setting evidence',
      'entry_name: 级别推进器',
      'global_max_layer: ${LevelPromoterSettings.currentMaxLayer}',
      'default_max_layer: ${LevelPromoterSettings.defaultMaxLayer}',
      'scope: global frontend config injection',
      'applies_to: analyze_multi, single analyze, scanner payload where frontend builds config',
      'config_fields: ${LevelPromoterSettings.configFields}',
      'source_policy: setting only; backend a_* adapter still owns recursive export; no chan.py source pollution',
    ].join('\n');
    await Clipboard.setData(ClipboardData(text: text));
    _show('全局设置证据已复制');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 460,
              child: _panel(
                title: '级别推进器',
                child: ValueListenableBuilder<int>(
                  valueListenable: LevelPromoterSettings.maxLayer,
                  builder: (context, value, _) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Text(
                        '这里只设置全局 N 段数量；不再单独输入股票代码、市场、K线级别或显示图表。',
                        style: TextStyle(
                            color: Colors.white70, fontSize: 12, height: 1.35),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: 180,
                        child: TextField(
                          controller: _maxLayerController,
                          keyboardType: TextInputType.number,
                          inputFormatters: <TextInputFormatter>[
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          style: const TextStyle(
                              color: Colors.white, fontSize: 14),
                          decoration: const InputDecoration(
                            labelText: 'N段数量',
                            helperText: '默认 2；最小 2',
                            isDense: true,
                            filled: true,
                            fillColor: Color(0xFF1C2330),
                            border: OutlineInputBorder(),
                          ),
                          onSubmitted: (_) => _save(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: <Widget>[
                          FilledButton.icon(
                            onPressed: _save,
                            icon: const Icon(Icons.save, size: 16),
                            label: const Text('保存全局设置'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _copyConfig,
                            icon: const Icon(Icons.copy, size: 16),
                            label: const Text('复制设置证据'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _chip('当前全局 N', '$value'),
                      const SizedBox(height: 10),
                      Text(
                        _status,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12, height: 1.35),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _panel({required String title, required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF131722),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(title,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            child,
          ],
        ),
      );

  Widget _chip(String label, String value) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFF2962FF).withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
              color: const Color(0xFF8AB4FF).withValues(alpha: 0.50)),
        ),
        child: Text(
          '$label: $value',
          style: const TextStyle(
              color: Color(0xFF8AB4FF),
              fontSize: 12,
              fontWeight: FontWeight.w700),
        ),
      );

  void _show(String message) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(message)));
}
