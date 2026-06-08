/// TradingView Charting Library style drawing toolbox registry.
///
/// This file only defines the frontend drawing-tool taxonomy and metadata.
/// It does not implement Chan theory calculations and must not be used as a
/// replacement for the Vespa chan.py-derived engine.

enum TradingViewDrawingGroup {
  cursorAndMeasure,
  lines,
  pitchforks,
  fibonacciAndGann,
  geometricShapes,
  annotation,
  patterns,
  predictionAndMeasurement,
  icons,
  chanOverlay,
}

enum TradingViewDrawingTool {
  // Cursor / measuring helpers.
  cursor,
  crosshair,
  ruler,
  dateRange,
  priceRange,
  dateAndPriceRange,
  longPosition,
  shortPosition,
  forecast,
  barsPattern,
  ghostFeed,

  // Lines.
  trendLine,
  infoLine,
  extendedLine,
  ray,
  horizontalLine,
  horizontalRay,
  verticalLine,
  crossLine,
  parallelChannel,
  regressionTrend,
  flatTopBottom,
  disjointChannel,
  anchoredVwap,
  anchoredText,

  // Pitchforks.
  pitchfork,
  schiffPitchfork,
  modifiedSchiffPitchfork,
  insidePitchfork,

  // Fibonacci / Gann style tools.
  fibRetracement,
  trendBasedFibExtension,
  fibChannel,
  fibTimeZone,
  fibSpeedResistanceFan,
  fibSpeedResistanceArcs,
  fibWedge,
  pitchfan,
  gannBox,
  gannSquareFixed,
  gannSquare,
  gannFan,

  // Geometric shapes.
  brush,
  highlighter,
  arrow,
  arrowMarker,
  rectangle,
  rotatedRectangle,
  ellipse,
  triangle,
  polyline,
  curve,
  path,
  arc,
  circle,

  // Text and labels.
  text,
  anchoredNote,
  note,
  callout,
  balloon,
  priceLabel,
  priceNote,
  signpost,
  flagMark,

  // Patterns.
  abcdPattern,
  xabcdPattern,
  trianglePattern,
  threeDrivesPattern,
  headAndShoulders,
  cypherPattern,
  elliottImpulseWave,
  elliottTriangleWave,
  elliottTripleComboWave,
  elliottCorrectionWave,
  cyclicLines,
  timeCycles,
  sineLine,

  // Icons / markers.
  iconArrowUp,
  iconArrowDown,
  iconCheck,
  iconCross,
  iconCircle,
  iconStar,
  iconFlag,

  // Chan overlay tools. These are display selectors for backend/Vespa outputs,
  // not independent Chan calculators.
  chanFx,
  chanFxLine,
  chanBi,
  chanBiText,
  chanSeg,
  chanSegText,
  chanZs,
  chanBiBsp,
  chanSegBsp,
  chanMergedBars,
}

class TradingViewDrawingToolMeta {
  final TradingViewDrawingTool tool;
  final TradingViewDrawingGroup group;
  final String label;
  final String description;
  final int minPoints;
  final int maxPoints;
  final bool canPersist;
  final bool requiresChanSnapshot;

  const TradingViewDrawingToolMeta({
    required this.tool,
    required this.group,
    required this.label,
    required this.description,
    required this.minPoints,
    required this.maxPoints,
    this.canPersist = true,
    this.requiresChanSnapshot = false,
  });

  bool get isSinglePoint => minPoints == 1 && maxPoints == 1;
  bool get isOpenEnded => maxPoints < 0;
}

class TradingViewDrawingToolRegistry {
  const TradingViewDrawingToolRegistry._();

  static const List<TradingViewDrawingToolMeta> all = [
    TradingViewDrawingToolMeta(tool: TradingViewDrawingTool.cursor, group: TradingViewDrawingGroup.cursorAndMeasure, label: '光标', description: '选择、移动和编辑已绘制对象', minPoints: 0, maxPoints: 0, canPersist: false),
    TradingViewDrawingToolMeta(tool: TradingViewDrawingTool.crosshair, group: TradingViewDrawingGroup.cursorAndMeasure, label: '十字光标', description: '读取当前K线时间、价格和OHLCV', minPoints: 0, maxPoints: 0, canPersist: false),
    TradingViewDrawingToolMeta(tool: TradingViewDrawingTool.ruler, group: TradingViewDrawingGroup.cursorAndMeasure, label: '测量尺', description: '测量两点之间的涨跌幅、K线数量和价格差', minPoints: 2, maxPoints: 2),
    TradingViewDrawingToolMeta(tool: TradingViewDrawingTool.dateRange, group: TradingViewDrawingGroup.cursorAndMeasure, label: '日期范围', description: '测量横向时间/K线数量', minPoints: 2, maxPoints: 2),
    TradingViewDrawingToolMeta(tool: TradingViewDrawingTool.priceRange, group: TradingViewDrawingGroup.cursorAndMeasure, label: '价格范围', description: '测量纵向价格差和涨跌幅', minPoints: 2, maxPoints: 2),
    TradingViewDrawingToolMeta(tool: TradingViewDrawingTool.dateAndPriceRange, group: TradingViewDrawingGroup.cursorAndMeasure, label: '日期和价格范围', description: '同时测量时间跨度和价格跨度', minPoints: 2, maxPoints: 2),
    TradingViewDrawingToolMeta(tool: TradingViewDrawingTool.longPosition, group: TradingViewDrawingGroup.predictionAndMeasurement, label: '多头头寸', description: '标记入场、止损、止盈和盈亏比', minPoints: 2, maxPoints: 3),
    TradingViewDrawingToolMeta(tool: TradingViewDrawingTool.shortPosition, group: TradingViewDrawingGroup.predictionAndMeasurement, label: '空头头寸', description: '标记做空入场、止损、止盈和盈亏比', minPoints: 2, maxPoints: 3),
    TradingViewDrawingToolMeta(tool: TradingViewDrawingTool.forecast, group: TradingViewDrawingGroup.predictionAndMeasurement, label: '预测', description: '绘制主观路径推演，不参与缠论计算', minPoints: 2, maxPoints: -1),
    TradingViewDrawingToolMeta(tool: TradingViewDrawingTool.barsPattern, group: TradingViewDrawingGroup.predictionAndMeasurement, label: 'K线形态复制', description: '复制历史区间作为对照模板', minPoints: 2, maxPoints: 2),
    TradingViewDrawingToolMeta(tool: TradingViewDrawingTool.ghostFeed, group: TradingViewDrawingGroup.predictionAndMeasurement, label: '幽灵K线', description: '绘制假设性未来K线路径', minPoints: 2, maxPoints: -1),

    TradingViewDrawingToolMeta(tool: TradingViewDrawingTool.trendLine, group: TradingViewDrawingGroup.lines, label: '趋势线', description: '两点直线，最常用画线工具', minPoints: 2, maxPoints: 2),
    TradingViewDrawingToolMeta(tool: TradingViewDrawingTool.infoLine, group: TradingViewDrawingGroup.lines, label: '信息线', description: '带涨跌幅、角度等信息的趋势线', minPoints: 2, maxPoints: 2),
    TradingViewDrawingToolMeta(tool: TradingViewDrawingTool.extendedLine, group: TradingViewDrawingGroup.lines, label: '延长线', description: '两端无限延伸的直线', minPoints: 2, maxPoints: 2),
    TradingViewDrawingToolMeta(tool: TradingViewDrawingTool.ray, group: TradingViewDrawingGroup.lines, label: '射线', description: '从起点向终点方向无限延伸', minPoints: 2, maxPoints: 2),
    TradingViewDrawingToolMeta(tool: TradingViewDrawingTool.horizontalLine, group: TradingViewDrawingGroup.lines, label: '水平线', description: '价格支撑、压力、止损止盈线', minPoints: 1, maxPoints: 1),
    TradingViewDrawingToolMeta(tool: TradingViewDrawingTool.horizontalRay, group: TradingViewDrawingGroup.lines, label: '水平射线', description: '从一点向右延伸的水平价格线', minPoints: 1, maxPoints: 1),
    TradingViewDrawingToolMeta(tool: TradingViewDrawingTool.verticalLine, group: TradingViewDrawingGroup.lines, label: '垂直线', description: '标记事件时间或关键K线', minPoints: 1, maxPoints: 1),
    TradingViewDrawingToolMeta(tool: TradingViewDrawingTool.crossLine, group: TradingViewDrawingGroup.lines, label: '十字线', description: '同时标记价格和时间', minPoints: 1, maxPoints: 1),
    TradingViewDrawingToolMeta(tool: TradingViewDrawingTool.parallelChannel, group: TradingViewDrawingGroup.lines, label: '平行通道', description: '三点确定趋势通道', minPoints: 3, maxPoints: 3),
    TradingViewDrawingToolMeta(tool: TradingViewDrawingTool.regressionTrend, group: TradingViewDrawingGroup.lines, label: '回归趋势', description: '线性回归趋势通道', minPoints: 2, maxPoints: 2),
    TradingViewDrawingToolMeta(tool: TradingViewDrawingTool.flatTopBottom, group: TradingViewDrawingGroup.lines, label: '平顶/平底', description: '标记水平整理边界', minPoints: 2, maxPoints: 2),
    TradingViewDrawingToolMeta(tool: TradingViewDrawingTool.disjointChannel, group: TradingViewDrawingGroup.lines, label: '非连续通道', description: '分离锚点的通道工具', minPoints: 3, maxPoints: 4),
    TradingViewDrawingToolMeta(tool: TradingViewDrawingTool.anchoredVwap, group: TradingViewDrawingGroup.lines, label: '锚定VWAP', description: '从指定K线开始的成交量加权均价', minPoints: 1, maxPoints: 1),
    TradingViewDrawingToolMeta(tool: TradingViewDrawingTool.anchoredText, group: TradingViewDrawingGroup.annotation, label: '锚定文本', description: '固定在图表区域的说明文本', minPoints: 1, maxPoints: 1),

    TradingViewDrawingToolMeta(tool: TradingViewDrawingTool.pitchfork, group: TradingViewDrawingGroup.pitchforks, label: '安德鲁音叉', description: '三点音叉通道', minPoints: 3, maxPoints: 3),
    TradingViewDrawingToolMeta(tool: TradingViewDrawingTool.schiffPitchfork, group: TradingViewDrawingGroup.pitchforks, label: 'Schiff 音叉', description: 'Schiff 变体音叉', minPoints: 3, maxPoints: 3),
    TradingViewDrawingToolMeta(tool: TradingViewDrawingTool.modifiedSchiffPitchfork, group: TradingViewDrawingGroup.pitchforks, label: '修正 Schiff 音叉', description: '修正 Schiff 变体音叉', minPoints: 3, maxPoints: 3),
    TradingViewDrawingToolMeta(tool: TradingViewDrawingTool.insidePitchfork, group: TradingViewDrawingGroup.pitchforks, label: '内部音叉', description: '内部平行通道音叉', minPoints: 3, maxPoints: 3),

    TradingViewDrawingToolMeta(tool: TradingViewDrawingTool.fibRetracement, group: TradingViewDrawingGroup.fibonacciAndGann, label: '斐波那契回撤', description: '回撤比例参考线', minPoints: 2, maxPoints: 2),
    TradingViewDrawingToolMeta(tool: TradingViewDrawingTool.trendBasedFibExtension, group: TradingViewDrawingGroup.fibonacciAndGann, label: '趋势斐波那契扩展', description: '三点趋势扩展目标位', minPoints: 3, maxPoints: 3),
    TradingViewDrawingToolMeta(tool: TradingViewDrawingTool.fibChannel, group: TradingViewDrawingGroup.fibonacciAndGann, label: '斐波那契通道', description: '通道比例扩展', minPoints: 3, maxPoints: 3),
    TradingViewDrawingToolMeta(tool: TradingViewDrawingTool.fibTimeZone, group: TradingViewDrawingGroup.fibonacciAndGann, label: '斐波那契时间周期', description: '按斐波那契数列标记时间间隔', minPoints: 2, maxPoints: 2),
    TradingViewDrawingToolMeta(tool: TradingViewDrawingTool.fibSpeedResistanceFan, group: TradingViewDrawingGroup.fibonacciAndGann, label: '斐波那契速度阻力扇', description: '速度阻力扇形参考', minPoints: 2, maxPoints: 2),
    TradingViewDrawingToolMeta(tool: TradingViewDrawingTool.fibSpeedResistanceArcs, group: TradingViewDrawingGroup.fibonacciAndGann, label: '斐波那契速度阻力弧', description: '弧形速度阻力参考', minPoints: 2, maxPoints: 2),
    TradingViewDrawingToolMeta(tool: TradingViewDrawingTool.fibWedge, group: TradingViewDrawingGroup.fibonacciAndGann, label: '斐波那契楔形', description: '楔形比例参考', minPoints: 3, maxPoints: 3),
    TradingViewDrawingToolMeta(tool: TradingViewDrawingTool.pitchfan, group: TradingViewDrawingGroup.fibonacciAndGann, label: 'Pitchfan', description: '角度扇形参考', minPoints: 3, maxPoints: 3),
    TradingViewDrawingToolMeta(tool: TradingViewDrawingTool.gannBox, group: TradingViewDrawingGroup.fibonacciAndGann, label: '江恩箱', description: '时间价格比例网格', minPoints: 2, maxPoints: 2),
    TradingViewDrawingToolMeta(tool: TradingViewDrawingTool.gannSquareFixed, group: TradingViewDrawingGroup.fibonacciAndGann, label: '固定江恩方形', description: '固定比例江恩方格', minPoints: 1, maxPoints: 1),
    TradingViewDrawingToolMeta(tool: TradingViewDrawingTool.gannSquare, group: TradingViewDrawingGroup.fibonacciAndGann, label: '江恩方形', description: '可调节江恩方格', minPoints: 2, maxPoints: 2),
    TradingViewDrawingToolMeta(tool: TradingViewDrawingTool.gannFan, group: TradingViewDrawingGroup.fibonacciAndGann, label: '江恩扇形', description: '江恩角度扇形线', minPoints: 2, maxPoints: 2),

    TradingViewDrawingToolMeta(tool: TradingViewDrawingTool.brush, group: TradingViewDrawingGroup.geometricShapes, label: '画笔', description: '自由手绘曲线', minPoints: 1, maxPoints: -1),
    TradingViewDrawingToolMeta(tool: TradingViewDrawingTool.highlighter, group: TradingViewDrawingGroup.geometricShapes, label: '高亮笔', description: '自由高亮标注', minPoints: 1, maxPoints: -1),
    TradingViewDrawingToolMeta(tool: TradingViewDrawingTool.arrow, group: TradingViewDrawingGroup.geometricShapes, label: '箭头线', description: '带箭头的线段', minPoints: 2, maxPoints: 2),
    TradingViewDrawingToolMeta(tool: TradingViewDrawingTool.arrowMarker, group: TradingViewDrawingGroup.geometricShapes, label: '箭头标记', description: '单点方向标记', minPoints: 1, maxPoints: 1),
    TradingViewDrawingToolMeta(tool: TradingViewDrawingTool.rectangle, group: TradingViewDrawingGroup.geometricShapes, label: '矩形', description: '区间、箱体、中枢显示的基础形状', minPoints: 2, maxPoints: 2),
    TradingViewDrawingToolMeta(tool: TradingViewDrawingTool.rotatedRectangle, group: TradingViewDrawingGroup.geometricShapes, label: '旋转矩形', description: '斜向箱体或通道区间', minPoints: 3, maxPoints: 3),
    TradingViewDrawingToolMeta(tool: TradingViewDrawingTool.ellipse, group: TradingViewDrawingGroup.geometricShapes, label: '椭圆', description: '圆形或椭圆形区域标记', minPoints: 2, maxPoints: 2),
    TradingViewDrawingToolMeta(tool: TradingViewDrawingTool.triangle, group: TradingViewDrawingGroup.geometricShapes, label: '三角形', description: '三点区域标记', minPoints: 3, maxPoints: 3),
    TradingViewDrawingToolMeta(tool: TradingViewDrawingTool.polyline, group: TradingViewDrawingGroup.geometricShapes, label: '折线', description: '多点折线', minPoints: 2, maxPoints: -1),
    TradingViewDrawingToolMeta(tool: TradingViewDrawingTool.curve, group: TradingViewDrawingGroup.geometricShapes, label: '曲线', description: '平滑曲线', minPoints: 2, maxPoints: -1),
    TradingViewDrawingToolMeta(tool: TradingViewDrawingTool.path, group: TradingViewDrawingGroup.geometricShapes, label: '路径', description: '多段路径', minPoints: 2, maxPoints: -1),
    TradingViewDrawingToolMeta(tool: TradingViewDrawingTool.arc, group: TradingViewDrawingGroup.geometricShapes, label: '圆弧', description: '三点圆弧', minPoints: 3, maxPoints: 3),
    TradingViewDrawingToolMeta(tool: TradingViewDrawingTool.circle, group: TradingViewDrawingGroup.geometricShapes, label: '圆', description: '圆形区域标记', minPoints: 2, maxPoints: 2),

    TradingViewDrawingToolMeta(tool: TradingViewDrawingTool.text, group: TradingViewDrawingGroup.annotation, label: '文本', description: '普通文字标注', minPoints: 1, maxPoints: 1),
    TradingViewDrawingToolMeta(tool: TradingViewDrawingTool.anchoredNote, group: TradingViewDrawingGroup.annotation, label: '锚定备注', description: '图表固定备注', minPoints: 1, maxPoints: 1),
    TradingViewDrawingToolMeta(tool: TradingViewDrawingTool.note, group: TradingViewDrawingGroup.annotation, label: '备注', description: 'K线位置备注', minPoints: 1, maxPoints: 1),
    TradingViewDrawingToolMeta(tool: TradingViewDrawingTool.callout, group: TradingViewDrawingGroup.annotation, label: '标注框', description: '带指向的说明框', minPoints: 2, maxPoints: 2),
    TradingViewDrawingToolMeta(tool: TradingViewDrawingTool.balloon, group: TradingViewDrawingGroup.annotation, label: '气泡', description: '气泡说明标注', minPoints: 1, maxPoints: 1),
    TradingViewDrawingToolMeta(tool: TradingViewDrawingTool.priceLabel, group: TradingViewDrawingGroup.annotation, label: '价格标签', description: '单点价格标签', minPoints: 1, maxPoints: 1),
    TradingViewDrawingToolMeta(tool: TradingViewDrawingTool.priceNote, group: TradingViewDrawingGroup.annotation, label: '价格备注', description: '价格位置备注', minPoints: 1, maxPoints: 1),
    TradingViewDrawingToolMeta(tool: TradingViewDrawingTool.signpost, group: TradingViewDrawingGroup.annotation, label: '路标', description: '事件路标式标注', minPoints: 1, maxPoints: 1),
    TradingViewDrawingToolMeta(tool: TradingViewDrawingTool.flagMark, group: TradingViewDrawingGroup.annotation, label: '旗标', description: '旗帜事件标记', minPoints: 1, maxPoints: 1),

    TradingViewDrawingToolMeta(tool: TradingViewDrawingTool.abcdPattern, group: TradingViewDrawingGroup.patterns, label: 'ABCD 形态', description: '四点谐波/结构形态', minPoints: 4, maxPoints: 4),
    TradingViewDrawingToolMeta(tool: TradingViewDrawingTool.xabcdPattern, group: TradingViewDrawingGroup.patterns, label: 'XABCD 形态', description: '五点谐波形态', minPoints: 5, maxPoints: 5),
    TradingViewDrawingToolMeta(tool: TradingViewDrawingTool.trianglePattern, group: TradingViewDrawingGroup.patterns, label: '三角形形态', description: '三角收敛/扩散形态', minPoints: 5, maxPoints: 5),
    TradingViewDrawingToolMeta(tool: TradingViewDrawingTool.threeDrivesPattern, group: TradingViewDrawingGroup.patterns, label: '三驱动形态', description: '三段驱动结构', minPoints: 6, maxPoints: 6),
    TradingViewDrawingToolMeta(tool: TradingViewDrawingTool.headAndShoulders, group: TradingViewDrawingGroup.patterns, label: '头肩形态', description: '头肩顶/底结构标注', minPoints: 5, maxPoints: 5),
    TradingViewDrawingToolMeta(tool: TradingViewDrawingTool.cypherPattern, group: TradingViewDrawingGroup.patterns, label: 'Cypher 形态', description: 'Cypher 谐波形态', minPoints: 5, maxPoints: 5),
    TradingViewDrawingToolMeta(tool: TradingViewDrawingTool.elliottImpulseWave, group: TradingViewDrawingGroup.patterns, label: '艾略特推动浪', description: '1-5 推动浪标注', minPoints: 6, maxPoints: 6),
    TradingViewDrawingToolMeta(tool: TradingViewDrawingTool.elliottTriangleWave, group: TradingViewDrawingGroup.patterns, label: '艾略特三角浪', description: 'ABCDE 三角调整标注', minPoints: 5, maxPoints: 5),
    TradingViewDrawingToolMeta(tool: TradingViewDrawingTool.elliottTripleComboWave, group: TradingViewDrawingGroup.patterns, label: '艾略特三重组合浪', description: '复杂组合调整标注', minPoints: 7, maxPoints: 7),
    TradingViewDrawingToolMeta(tool: TradingViewDrawingTool.elliottCorrectionWave, group: TradingViewDrawingGroup.patterns, label: '艾略特调整浪', description: 'ABC 调整浪标注', minPoints: 4, maxPoints: 4),
    TradingViewDrawingToolMeta(tool: TradingViewDrawingTool.cyclicLines, group: TradingViewDrawingGroup.patterns, label: '循环线', description: '等间距时间循环线', minPoints: 2, maxPoints: 2),
    TradingViewDrawingToolMeta(tool: TradingViewDrawingTool.timeCycles, group: TradingViewDrawingGroup.patterns, label: '时间循环', description: '周期性时间弧/线', minPoints: 2, maxPoints: 2),
    TradingViewDrawingToolMeta(tool: TradingViewDrawingTool.sineLine, group: TradingViewDrawingGroup.patterns, label: '正弦线', description: '周期波形辅助线', minPoints: 2, maxPoints: 2),

    TradingViewDrawingToolMeta(tool: TradingViewDrawingTool.iconArrowUp, group: TradingViewDrawingGroup.icons, label: '上箭头图标', description: '单点看多/向上标记', minPoints: 1, maxPoints: 1),
    TradingViewDrawingToolMeta(tool: TradingViewDrawingTool.iconArrowDown, group: TradingViewDrawingGroup.icons, label: '下箭头图标', description: '单点看空/向下标记', minPoints: 1, maxPoints: 1),
    TradingViewDrawingToolMeta(tool: TradingViewDrawingTool.iconCheck, group: TradingViewDrawingGroup.icons, label: '对勾图标', description: '确认标记', minPoints: 1, maxPoints: 1),
    TradingViewDrawingToolMeta(tool: TradingViewDrawingTool.iconCross, group: TradingViewDrawingGroup.icons, label: '叉号图标', description: '否定/无效标记', minPoints: 1, maxPoints: 1),
    TradingViewDrawingToolMeta(tool: TradingViewDrawingTool.iconCircle, group: TradingViewDrawingGroup.icons, label: '圆点图标', description: '重点位置标记', minPoints: 1, maxPoints: 1),
    TradingViewDrawingToolMeta(tool: TradingViewDrawingTool.iconStar, group: TradingViewDrawingGroup.icons, label: '星标图标', description: '重点机会标记', minPoints: 1, maxPoints: 1),
    TradingViewDrawingToolMeta(tool: TradingViewDrawingTool.iconFlag, group: TradingViewDrawingGroup.icons, label: '旗帜图标', description: '事件旗帜标记', minPoints: 1, maxPoints: 1),

    TradingViewDrawingToolMeta(tool: TradingViewDrawingTool.chanFx, group: TradingViewDrawingGroup.chanOverlay, label: '缠论分型', description: '显示 Vespa/chan.py 口径分型结果', minPoints: 0, maxPoints: 0, canPersist: false, requiresChanSnapshot: true),
    TradingViewDrawingToolMeta(tool: TradingViewDrawingTool.chanFxLine, group: TradingViewDrawingGroup.chanOverlay, label: '分型连线', description: '显示分型连接辅助线，不参与计算', minPoints: 0, maxPoints: 0, canPersist: false, requiresChanSnapshot: true),
    TradingViewDrawingToolMeta(tool: TradingViewDrawingTool.chanBi, group: TradingViewDrawingGroup.chanOverlay, label: '缠论笔', description: '显示 Vespa/chan.py 口径笔结果', minPoints: 0, maxPoints: 0, canPersist: false, requiresChanSnapshot: true),
    TradingViewDrawingToolMeta(tool: TradingViewDrawingTool.chanBiText, group: TradingViewDrawingGroup.chanOverlay, label: '笔编号', description: '显示笔编号文字', minPoints: 0, maxPoints: 0, canPersist: false, requiresChanSnapshot: true),
    TradingViewDrawingToolMeta(tool: TradingViewDrawingTool.chanSeg, group: TradingViewDrawingGroup.chanOverlay, label: '缠论线段', description: '显示 Vespa/chan.py 口径线段结果', minPoints: 0, maxPoints: 0, canPersist: false, requiresChanSnapshot: true),
    TradingViewDrawingToolMeta(tool: TradingViewDrawingTool.chanSegText, group: TradingViewDrawingGroup.chanOverlay, label: '线段编号', description: '显示线段编号文字', minPoints: 0, maxPoints: 0, canPersist: false, requiresChanSnapshot: true),
    TradingViewDrawingToolMeta(tool: TradingViewDrawingTool.chanZs, group: TradingViewDrawingGroup.chanOverlay, label: '缠论中枢', description: '显示 Vespa/chan.py 口径中枢结果', minPoints: 0, maxPoints: 0, canPersist: false, requiresChanSnapshot: true),
    TradingViewDrawingToolMeta(tool: TradingViewDrawingTool.chanBiBsp, group: TradingViewDrawingGroup.chanOverlay, label: '笔买卖点', description: '显示后端返回的 level=bi BSP，不在前端重算', minPoints: 0, maxPoints: 0, canPersist: false, requiresChanSnapshot: true),
    TradingViewDrawingToolMeta(tool: TradingViewDrawingTool.chanSegBsp, group: TradingViewDrawingGroup.chanOverlay, label: '线段买卖点', description: '显示后端返回的 level=seg BSP，不在前端重算', minPoints: 0, maxPoints: 0, canPersist: false, requiresChanSnapshot: true),
    TradingViewDrawingToolMeta(tool: TradingViewDrawingTool.chanMergedBars, group: TradingViewDrawingGroup.chanOverlay, label: '合并K线', description: '显示包含关系处理后的合并K线外框', minPoints: 0, maxPoints: 0, canPersist: false, requiresChanSnapshot: true),
  ];

  static Map<TradingViewDrawingGroup, List<TradingViewDrawingToolMeta>> byGroup() {
    final result = <TradingViewDrawingGroup, List<TradingViewDrawingToolMeta>>{};
    for (final meta in all) {
      result.putIfAbsent(meta.group, () => <TradingViewDrawingToolMeta>[]).add(meta);
    }
    return result;
  }

  static TradingViewDrawingToolMeta metaOf(TradingViewDrawingTool tool) {
    return all.firstWhere((meta) => meta.tool == tool);
  }
}
