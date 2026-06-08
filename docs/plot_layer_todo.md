# Plot layer todo

Goal: improve `origin_vespa_tdx` plot-layer parity with Vespa/chan.py `CPlotDriver`.

Implemented before this note:
- K-line candles
- FX points and FX line
- BI line
- SEG line
- ZS rectangle
- BSP markers
- Step frames from `CChan.step_load()`

Scaffold added:
- `lib/core/models/plot_layer_item.dart`
- `ChanSnapshot.segZss`
- `ChanSnapshot.eigenBoxes`
- `ChanSnapshot.segEigenBoxes`

Remaining integration:
1. `plot_kline_combine`: toolbar switch and `merged_bars` rectangle drawing.
2. `plot_bsp` / `plot_segbsp`: separate BI-BSP and SEG-BSP switches and styles.
3. `plot_segzs`: backend `seg_zs`, parser field, independent rectangle layer.
4. `plot_eigen` / `plot_segeigen`: backend eigen rectangles, parser fields, semi-transparent boxes.
5. Indicators: MACD first, then mean / channel / BOLL / Demark / marker / RSI / KDJ.

Implementation note: apply small patches and run `flutter analyze` after each stage, because the current K-line / FX / BI / SEG / ZS / BSP display is already working.
