# Rhythm viewport selector page patch

Run this on branch `jzxfk` after pulling the latest commits:

```bash
python tools/run_rhythm_viewport_patch.py
flutter analyze
flutter test test/s13_rhythm_viewport_selector_test.dart
```

The patch updates `lib/ui/pages/s13_single_stock_replay_page.dart` so rhythm overlays are selected by the current viewport instead of fixed oldest-first `.take(120)` and `.take(80)` calls.

The patch is intentionally exact-match based. If the page shape changes, it exits without editing the file.
