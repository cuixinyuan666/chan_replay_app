class LevelPromoterBspParser {
  const LevelPromoterBspParser._();

  static Map<int, int> countSegNBspLayers(Map<String, dynamic> payload) {
    final result = <int, int>{};
    final grouped = payload['seg_bsp_layers'];
    if (grouped is Map) {
      for (final entry in grouped.entries) {
        final layer = int.tryParse('${entry.key}');
        final rows = entry.value;
        if (layer != null && rows is List) result[layer] = rows.length;
      }
    }
    for (final entry in payload.entries) {
      final key = entry.key;
      if (!key.startsWith('seg') || !key.endsWith('_bsp')) continue;
      final layer = int.tryParse(key.substring(3, key.length - 4));
      final rows = entry.value;
      if (layer != null && rows is List) result[layer] = rows.length;
    }
    return result;
  }
}
