import 'package:flutter/foundation.dart';

class ChipDistributionSettings {
  final int priceBucketCount;

  const ChipDistributionSettings({
    this.priceBucketCount = 80,
  });

  ChipDistributionSettings copyWith({int? priceBucketCount}) {
    return ChipDistributionSettings(
      priceBucketCount:
          (priceBucketCount ?? this.priceBucketCount).clamp(24, 160).toInt(),
    );
  }

  String toEvidenceText() =>
      'chip_bin_count=$priceBucketCount chip_bin_count_source=global_chip_distribution_settings '
      'chip_minimal_ui=price_bucket_count_only';
}

class ChipDistributionSettingsController {
  static final ValueNotifier<ChipDistributionSettings> selected =
      ValueNotifier<ChipDistributionSettings>(const ChipDistributionSettings());

  static ChipDistributionSettings get current => selected.value;

  static void setPriceBucketCount(int value) {
    selected.value = selected.value.copyWith(priceBucketCount: value);
  }

  static void reset() {
    selected.value = const ChipDistributionSettings();
  }
}
