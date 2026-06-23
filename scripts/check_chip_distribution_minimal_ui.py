from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CHIP_PAGE = ROOT / 'lib' / 'ui' / 'pages' / 'chip_distribution_page.dart'
SIDEBAR = ROOT / 'lib' / 'ui' / 'widgets' / 'four_way_granular_sidebar_shell.dart'
SETTINGS = ROOT / 'lib' / 'core' / 'settings' / 'chip_distribution_settings.dart'
S13_PANEL = ROOT / 'lib' / 'ui' / 'widgets' / 's13_chip_distribution_panel.dart'
S13_PAGE = ROOT / 'lib' / 'ui' / 'pages' / 's13_single_stock_replay_page.dart'


def read(path: Path) -> str:
    return path.read_text(encoding='utf-8')


def assert_contains(text: str, needle: str, where: str) -> None:
    if needle not in text:
        raise AssertionError(f'{where} missing expected text: {needle}')


def assert_not_contains(text: str, needle: str, where: str) -> None:
    if needle in text:
        raise AssertionError(f'{where} still contains removed text: {needle}')


def main() -> None:
    chip_page = read(CHIP_PAGE)
    sidebar = read(SIDEBAR)
    settings = read(SETTINGS)
    s13_panel = read(S13_PANEL)
    s13_page = read(S13_PAGE)

    assert_contains(sidebar, "label: '价格桶数'", 'sidebar registration')
    assert_not_contains(sidebar, "label: '筹码分布/价格桶数'", 'sidebar registration')
    assert_contains(chip_page, "'价格桶数'", 'minimal chip page')
    assert_not_contains(chip_page, "'筹码分布/价格桶数'", 'minimal chip page')
    assert_contains(chip_page, "Tooltip(", 'minimal chip page')
    assert_contains(chip_page, "ChipDistributionSettingsController.selected", 'minimal chip page')
    assert_contains(chip_page, "setPriceBucketCount", 'minimal chip page')
    assert_not_contains(chip_page, "int _binCount", 'minimal chip page')

    assert_contains(settings, "class ChipDistributionSettings", 'global settings')
    assert_contains(settings, "priceBucketCount", 'global settings')
    assert_contains(settings, "ChipDistributionSettingsController", 'global settings')
    assert_contains(settings, "chip_bin_count_source=global_chip_distribution_settings", 'global settings evidence')
    assert_contains(settings, "chip_minimal_ui=price_bucket_count_only", 'global settings evidence')

    assert_contains(s13_panel, "ValueListenableBuilder<ChipDistributionSettings>", 'S13 embedded chip panel')
    assert_contains(s13_panel, "ChipDistributionSettingsController.selected", 'S13 embedded chip panel')
    assert_contains(s13_panel, "settings.priceBucketCount", 'S13 embedded chip panel')
    assert_contains(s13_panel, "effectiveBinCount", 'S13 embedded chip panel')
    assert_contains(s13_panel, "_PriceBucketCountOverlay", 'S13 embedded bucket overlay')
    assert_contains(s13_panel, "仅此控件响应操作", 'S13 embedded bucket overlay')
    assert_contains(s13_panel, "HitTestBehavior.opaque", 'S13 embedded bucket overlay')
    assert_contains(s13_panel, "Slider(", 'S13 embedded bucket overlay')
    assert_contains(s13_page, "chip_distribution_settings.dart", 'S13 evidence import')
    assert_contains(s13_page, "ChipDistributionSettingsController.current", 'S13 evidence global settings')
    assert_contains(s13_page, "chip_bin_count_source", 'S13 evidence output')
    assert_contains(s13_page, "chip_minimal_ui", 'S13 evidence output')

    for removed in [
        'PythonMultiLevelChanAnalysis',
        'PythonMultiLevelChanAnalysisSource',
        'ChipDistributionEngine',
        'ChipOnlineReplayAdapter',
        'MultiLevelChanSnapshot',
        'ChanSnapshot',
        '_loadOnlineReplay',
        '_symbolController',
        '_marketController',
        '_levelsController',
        '_startController',
        '_endController',
        '_modeChip',
        '_levelChip',
        '载入在线数据',
        '目标来源',
        '平均成本',
        '获利筹码',
    ]:
        assert_not_contains(chip_page, removed, 'minimal chip page')

    print('PASS chip_distribution_page bucket count UI and kline overlay contract')


if __name__ == '__main__':
    main()
