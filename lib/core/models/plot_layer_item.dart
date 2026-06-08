class PlotLayerItem {
  final int index;
  final int startRawIndex;
  final int endRawIndex;
  final double top;
  final double bottom;
  final String type;
  final String label;
  final bool confirmed;

  const PlotLayerItem({
    required this.index,
    required this.startRawIndex,
    required this.endRawIndex,
    required this.top,
    required this.bottom,
    this.type = '',
    this.label = '',
    this.confirmed = true,
  });
}
