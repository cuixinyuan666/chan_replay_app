import 'package:flutter/foundation.dart';

/// App-wide level promoter setting.
///
/// This is a lightweight in-session global setting. All frontend calls that
/// build chan.py config should pass [configFields] so the backend recursive
/// segment exporter receives one consistent N value.
class LevelPromoterSettings {
  static const int defaultMaxLayer = 2;

  static final ValueNotifier<int> maxLayer = ValueNotifier<int>(defaultMaxLayer);

  static int get currentMaxLayer => _normalize(maxLayer.value);

  static Map<String, dynamic> get configFields => <String, dynamic>{
        'level_promoter_max_level': currentMaxLayer,
        'recursive_seg_max_level': currentMaxLayer,
        'seg_recursive_max_level': currentMaxLayer,
      };

  static Map<String, dynamic> applyToConfig(Map<String, dynamic> base) => <String, dynamic>{
        ...base,
        ...configFields,
      };

  static void setMaxLayer(int value) {
    final normalized = _normalize(value);
    if (maxLayer.value != normalized) maxLayer.value = normalized;
  }

  static int _normalize(int value) => value < 2 ? 2 : value;
}
