# Rhythm viewport page patch notes

Use this command sequence on branch `jzxfk`:

```bash
python tools/run_rhythm_viewport_patch.py
flutter analyze
flutter test test/s13_rhythm_viewport_selector_test.dart
```

The patch switches page rendering to the viewport selector helper. It is exact-match based and exits if the page shape has changed.
