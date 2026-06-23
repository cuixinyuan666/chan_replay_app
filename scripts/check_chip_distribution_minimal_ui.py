from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CHIP_PAGE = ROOT / 'lib' / 'ui' / 'pages' / 'chip_distribution_page.dart'
SIDEBAR = ROOT / 'lib' / 'ui' / 'widgets' / 'four_way_granular_sidebar_shell.dart'


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

    assert_contains(sidebar, "label: '筹码分布/价格桶数'", 'sidebar registration')
    assert_contains(chip_page, "筹码分布/价格桶数", 'minimal chip page')
    assert_contains(chip_page, "价格桶数", 'minimal chip page')
    assert_contains(chip_page, "Tooltip(", 'minimal chip page')
    assert_contains(chip_page, "_binCount", 'minimal chip page')

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

    print('PASS chip_distribution_page minimal UI contract')


if __name__ == '__main__':
    main()
