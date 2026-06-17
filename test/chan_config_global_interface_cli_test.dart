import 'package:flutter_test/flutter_test.dart';
import 'package:chan_replay_app/core/settings/chan_config_store.dart';
import 'package:chan_replay_app/core/settings/level_promoter_settings.dart';

void main() {
  tearDown(() {
    ChanConfigStore.reset();
    LevelPromoterSettings.setMaxLayer(LevelPromoterSettings.defaultMaxLayer);
  });

  test('chan settings are global and override single-stock multi-level replay base config', () {
    ChanConfigStore.reset();

    ChanConfigStore.setValue('bi_algo', 'fx');
    ChanConfigStore.setValue('seg_algo', 'break');
    ChanConfigStore.setValue('zs_algo', 'auto');
    ChanConfigStore.setValue('bs_type', '1,2,3a');

    LevelPromoterSettings.setMaxLayer(5);

    final baseConfig = <String, dynamic>{
      'bi_algo': 'normal',
      'seg_algo': 'chan',
      'zs_algo': 'normal',
      'recursive_seg_max_level': 4,
      'enable_rhythm_1382': true,
      'rhythm_calc_mode': 'normal',
      'rhythm_max_lines': 160,
      'rhythm_max_hits_per_line': 3,
    };

    final effectiveConfig = ChanConfigStore.backendConfig(base: baseConfig);

    expect(effectiveConfig['bi_algo'], 'fx');
    expect(effectiveConfig['seg_algo'], 'break');
    expect(effectiveConfig['zs_algo'], 'auto');
    expect(effectiveConfig['bs_type'], '1,2,3a');

    expect(effectiveConfig['level_promoter_max_level'], 5);
    expect(effectiveConfig['recursive_seg_max_level'], 5);
    expect(effectiveConfig['seg_recursive_max_level'], 5);

    expect(effectiveConfig['enable_rhythm_1382'], true);
    expect(effectiveConfig['rhythm_calc_mode'], 'normal');
    expect(effectiveConfig['rhythm_max_lines'], 160);
    expect(effectiveConfig['rhythm_max_hits_per_line'], 3);

    expect(effectiveConfig.containsKey('bsp_advanced'), false);
    expect(ChanConfigStore.changedCount, greaterThanOrEqualTo(4));
  });

  test('bsp_advanced is expanded to backend override fields', () {
    ChanConfigStore.reset();

    ChanConfigStore.setValue(
      'bsp_advanced',
      [
        'macd_algo-buy=area',
        'bs_type-sell=1,2s',
        'strict_bsp3-seg=true',
      ].join('\n'),
    );

    final effectiveConfig = ChanConfigStore.backendConfig();

    expect(effectiveConfig.containsKey('bsp_advanced'), false);
    expect(effectiveConfig['macd_algo-buy'], 'area');
    expect(effectiveConfig['bs_type-sell'], '1,2s');
    expect(effectiveConfig['strict_bsp3-seg'], 'true');
  });
}
