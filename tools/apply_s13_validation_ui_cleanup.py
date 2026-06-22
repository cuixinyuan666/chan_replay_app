from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
S13 = ROOT / 'lib' / 'ui' / 'pages' / 's13_single_stock_replay_page.dart'


def _replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'[abort] {label}: expected 1 match, got {count}')
    return text.replace(old, new, 1)


def _remove_once(text: str, old: str, label: str) -> str:
    return _replace_once(text, old, '', label)


def main() -> None:
    text = S13.read_text(encoding='utf-8')
    original = text

    # 股票区：删除验证/诊断型 backend、窗口、复制当前状态按钮；保留 symbol/market/date/runtime 等实际运行输入。
    text = _remove_once(
        text,
        """                _input(_backendUrlController, 'backend',\n                    width: 210, enabled: false),\n""",
        'remove disabled backend input in _s13ToolbarSections',
    )
    text = _remove_once(
        text,
        """                _infoButton('窗口', _effectiveWindowText),\n                _currentSettingsCopyButton(),\n""",
        'remove window/status buttons in _s13ToolbarSections',
    )
    text = _remove_once(
        text,
        """                _input(_backendUrlController, 'backend',\n                    width: 210, enabled: false),\n""",
        'remove disabled backend input in _unifiedToolPanel',
    )
    text = _remove_once(
        text,
        """                _infoButton('窗口', _effectiveWindowText),\n                _currentSettingsCopyButton(),\n""",
        'remove window/status buttons in _unifiedToolPanel',
    )

    # 级别区：删除“校验/当前”提示按钮，只保留可操作级别 chips。
    text = _remove_once(
        text,
        """            const SizedBox(height: 8),\n            Wrap(spacing: 8, runSpacing: 8, children: <Widget>[\n              _infoButton('校验', _lastLevelValidation),\n              _infoButton('当前', _loadedLevels.join(',')),\n            ]),\n""",
        'remove validation/current info buttons in _s13ToolbarSections',
    )
    text = _remove_once(
        text,
        """            const SizedBox(height: 8),\n            Wrap(spacing: 8, runSpacing: 8, children: <Widget>[\n              _infoButton('校验', _lastLevelValidation),\n              _infoButton('当前', _loadedLevels.join(',')),\n            ]),\n""",
        'remove validation/current info buttons in _unifiedToolPanel',
    )

    # 复盘 / marker 区：删除复制 marker 证据、step、marker、1.382 诊断按钮；保留 once/step 模式和载入复盘。
    marker_toolbar_block = """              OutlinedButton.icon(\n                onPressed: _copyS13IntervalNestMarkerEvidence,\n                icon: const Icon(Icons.copy, size: 16),\n                label: const Text('复制 marker 证据'),\n              ),\n              _infoButton('step', _stepFrameLabel),\n              _infoButton('marker', '${_nestedBspMarkers.length}'),\n              _infoButton(\n                  '1.382', _rhythmSummaryFor(_activeSnapshot).shortText),\n"""
    text = _remove_once(text, marker_toolbar_block, 'remove marker diagnostic buttons in _s13ToolbarSections')
    text = _remove_once(text, marker_toolbar_block, 'remove marker diagnostic buttons in _unifiedToolPanel')

    # 删除 segN 真实买卖点验证展示区。该区域属于验收/诊断，不是日常设置；后续 BSP 底部文字验证独立实现。
    seg_section = """        SideToolbarSection(\n          title: 'segN 真实买卖点',\n          children: <Widget>[\n            Wrap(\n              spacing: 8,\n              runSpacing: 8,\n              children: <Widget>[\n                OutlinedButton.icon(\n                  onPressed:\n                      _activeSnapshot == null ? null : _resetChartToLatest,\n                  icon: const Icon(Icons.last_page, size: 16),\n                  label: const Text('回到最新'),\n                ),\n                for (final result in _recursiveRealBspResults.take(24))\n                  FilledButton.tonal(\n                    onPressed: () =>\n                        _jumpToRecursiveBsp(result.layer, result.bsp),\n                    child: Text(\n                        '${result.layer}段 ${result.bsp.type} @${result.bsp.rawIndex}'),\n                  ),\n              ],\n            ),\n            if (_recursiveRealBspResults.isEmpty)\n              const Text(\n                '当前快照没有 CBSPointList 真实买卖点；橙色候选端点不参与策略组合。',\n                style: TextStyle(color: Colors.white54, fontSize: 11),\n              ),\n          ],\n        ),\n"""
    text = _remove_once(text, seg_section, 'remove segN real BSP diagnostic section')

    unified_seg_block = """            _sectionGap(),\n            _sectionTitle('segN 真实买卖点'),\n            Wrap(\n              spacing: 8,\n              runSpacing: 8,\n              children: <Widget>[\n                OutlinedButton.icon(\n                  onPressed:\n                      _activeSnapshot == null ? null : _resetChartToLatest,\n                  icon: const Icon(Icons.last_page, size: 16),\n                  label: const Text('回到最新'),\n                ),\n                for (final result in _recursiveRealBspResults.take(24))\n                  FilledButton.tonal(\n                    onPressed: () =>\n                        _jumpToRecursiveBsp(result.layer, result.bsp),\n                    child: Text(\n                        '${result.layer}段 ${result.bsp.type} @${result.bsp.rawIndex}'),\n                  ),\n              ],\n            ),\n            if (_recursiveRealBspResults.isEmpty)\n              const Text(\n                '当前快照没有 CBSPointList 真实买卖点；橙色候选端点不参与策略组合。',\n                style: TextStyle(color: Colors.white54, fontSize: 11),\n              ),\n"""
    text = _remove_once(text, unified_seg_block, 'remove segN real BSP diagnostic section in _unifiedToolPanel')

    if text == original:
        raise SystemExit('[abort] no changes produced')
    S13.write_text(text, encoding='utf-8')
    print('S13 validation UI cleanup applied.')
    print('Next: flutter analyze')


if __name__ == '__main__':
    main()
