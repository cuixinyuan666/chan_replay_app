import 'dart:ui';

import 'tradingview_drawing_tool.dart';

/// Coordinate anchor type for a user-created drawing object.
///
/// Chart anchors bind to the K-line domain through rawIndex and price. Screen
/// anchors bind to the viewport through dx/dy and are reserved for UI notes.
enum DrawingAnchorType { chart, screen }

class DrawingAnchor {
  final DrawingAnchorType type;
  final int? rawIndex;
  final double? price;
  final double? dx;
  final double? dy;

  const DrawingAnchor.chart({
    required this.rawIndex,
    required this.price,
  })  : type = DrawingAnchorType.chart,
        dx = null,
        dy = null;

  const DrawingAnchor.screen({
    required this.dx,
    required this.dy,
  })  : type = DrawingAnchorType.screen,
        rawIndex = null,
        price = null;

  bool get isChart => type == DrawingAnchorType.chart;
  bool get isScreen => type == DrawingAnchorType.screen;

  DrawingAnchor copyWith({
    int? rawIndex,
    double? price,
    double? dx,
    double? dy,
  }) {
    return switch (type) {
      DrawingAnchorType.chart => DrawingAnchor.chart(
          rawIndex: rawIndex ?? this.rawIndex ?? 0,
          price: price ?? this.price ?? 0,
        ),
      DrawingAnchorType.screen => DrawingAnchor.screen(
          dx: dx ?? this.dx ?? 0,
          dy: dy ?? this.dy ?? 0,
        ),
    };
  }

  Map<String, Object?> toJson() {
    return {
      'type': type.name,
      'rawIndex': rawIndex,
      'price': price,
      'dx': dx,
      'dy': dy,
    };
  }

  factory DrawingAnchor.fromJson(Map<String, Object?> json) {
    final type = _anchorTypeFromName(json['type'] as String?);
    return switch (type) {
      DrawingAnchorType.chart => DrawingAnchor.chart(
          rawIndex: (json['rawIndex'] as num?)?.toInt() ?? 0,
          price: (json['price'] as num?)?.toDouble() ?? 0,
        ),
      DrawingAnchorType.screen => DrawingAnchor.screen(
          dx: (json['dx'] as num?)?.toDouble() ?? 0,
          dy: (json['dy'] as num?)?.toDouble() ?? 0,
        ),
    };
  }
}

class DrawingStyle {
  final int colorValue;
  final double strokeWidth;
  final double opacity;
  final bool dashed;
  final bool filled;
  final int fillColorValue;
  final double fillOpacity;
  final double fontSize;

  const DrawingStyle({
    this.colorValue = 0xFFFFFFFF,
    this.strokeWidth = 1.4,
    this.opacity = 1.0,
    this.dashed = false,
    this.filled = false,
    this.fillColorValue = 0x332962FF,
    this.fillOpacity = 0.20,
    this.fontSize = 12,
  });

  Color get color => Color(colorValue).withValues(alpha: opacity.clamp(0.0, 1.0).toDouble());
  Color get fillColor => Color(fillColorValue).withValues(alpha: fillOpacity.clamp(0.0, 1.0).toDouble());

  DrawingStyle copyWith({
    int? colorValue,
    double? strokeWidth,
    double? opacity,
    bool? dashed,
    bool? filled,
    int? fillColorValue,
    double? fillOpacity,
    double? fontSize,
  }) {
    return DrawingStyle(
      colorValue: colorValue ?? this.colorValue,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      opacity: opacity ?? this.opacity,
      dashed: dashed ?? this.dashed,
      filled: filled ?? this.filled,
      fillColorValue: fillColorValue ?? this.fillColorValue,
      fillOpacity: fillOpacity ?? this.fillOpacity,
      fontSize: fontSize ?? this.fontSize,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'colorValue': colorValue,
      'strokeWidth': strokeWidth,
      'opacity': opacity,
      'dashed': dashed,
      'filled': filled,
      'fillColorValue': fillColorValue,
      'fillOpacity': fillOpacity,
      'fontSize': fontSize,
    };
  }

  factory DrawingStyle.fromJson(Map<String, Object?> json) {
    return DrawingStyle(
      colorValue: (json['colorValue'] as num?)?.toInt() ?? 0xFFFFFFFF,
      strokeWidth: (json['strokeWidth'] as num?)?.toDouble() ?? 1.4,
      opacity: (json['opacity'] as num?)?.toDouble() ?? 1.0,
      dashed: json['dashed'] as bool? ?? false,
      filled: json['filled'] as bool? ?? false,
      fillColorValue: (json['fillColorValue'] as num?)?.toInt() ?? 0x332962FF,
      fillOpacity: (json['fillOpacity'] as num?)?.toDouble() ?? 0.20,
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 12,
    );
  }
}

class DrawingObject {
  final String id;
  final TradingViewDrawingTool tool;
  final List<DrawingAnchor> anchors;
  final DrawingStyle style;
  final String text;
  final bool locked;
  final bool hidden;
  final bool selected;
  final DateTime createdAt;
  final DateTime updatedAt;

  const DrawingObject({
    required this.id,
    required this.tool,
    required this.anchors,
    this.style = const DrawingStyle(),
    this.text = '',
    this.locked = false,
    this.hidden = false,
    this.selected = false,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isChanOverlay => TradingViewDrawingToolRegistry.metaOf(tool).requiresChanSnapshot;
  bool get canPersist => TradingViewDrawingToolRegistry.metaOf(tool).canPersist;
  int get anchorCount => anchors.length;

  DrawingObject copyWith({
    String? id,
    TradingViewDrawingTool? tool,
    List<DrawingAnchor>? anchors,
    DrawingStyle? style,
    String? text,
    bool? locked,
    bool? hidden,
    bool? selected,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DrawingObject(
      id: id ?? this.id,
      tool: tool ?? this.tool,
      anchors: anchors ?? this.anchors,
      style: style ?? this.style,
      text: text ?? this.text,
      locked: locked ?? this.locked,
      hidden: hidden ?? this.hidden,
      selected: selected ?? this.selected,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  DrawingObject touch() => copyWith(updatedAt: DateTime.now());
  DrawingObject selectOnly(bool value) => copyWith(selected: value, updatedAt: DateTime.now());
  DrawingObject lock(bool value) => copyWith(locked: value, updatedAt: DateTime.now());
  DrawingObject hide(bool value) => copyWith(hidden: value, updatedAt: DateTime.now());

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'tool': tool.name,
      'anchors': anchors.map((e) => e.toJson()).toList(growable: false),
      'style': style.toJson(),
      'text': text,
      'locked': locked,
      'hidden': hidden,
      'selected': selected,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory DrawingObject.fromJson(Map<String, Object?> json) {
    final anchorsJson = json['anchors'];
    final styleJson = json['style'];
    return DrawingObject(
      id: json['id'] as String? ?? '',
      tool: _drawingToolFromName(json['tool'] as String?),
      anchors: anchorsJson is List
          ? anchorsJson
              .whereType<Map>()
              .map((e) => DrawingAnchor.fromJson(Map<String, Object?>.from(e)))
              .toList(growable: false)
          : const [],
      style: styleJson is Map ? DrawingStyle.fromJson(Map<String, Object?>.from(styleJson)) : const DrawingStyle(),
      text: json['text'] as String? ?? '',
      locked: json['locked'] as bool? ?? false,
      hidden: json['hidden'] as bool? ?? false,
      selected: json['selected'] as bool? ?? false,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class DrawingObjectCollection {
  final List<DrawingObject> objects;

  const DrawingObjectCollection({this.objects = const []});

  DrawingObjectCollection upsert(DrawingObject object) {
    final index = objects.indexWhere((e) => e.id == object.id);
    if (index < 0) return DrawingObjectCollection(objects: [...objects, object]);
    return DrawingObjectCollection(
      objects: [
        for (var i = 0; i < objects.length; i++)
          if (i == index) object else objects[i],
      ],
    );
  }

  DrawingObjectCollection remove(String id) {
    return DrawingObjectCollection(objects: objects.where((e) => e.id != id).toList(growable: false));
  }

  DrawingObjectCollection clearSelection() {
    return DrawingObjectCollection(
      objects: [for (final object in objects) if (object.selected) object.selectOnly(false) else object],
    );
  }

  DrawingObjectCollection select(String id) {
    return DrawingObjectCollection(
      objects: [for (final object in objects) object.selectOnly(object.id == id)],
    );
  }

  List<Map<String, Object?>> toJson() => objects.map((e) => e.toJson()).toList(growable: false);

  factory DrawingObjectCollection.fromJson(List<Object?> json) {
    return DrawingObjectCollection(
      objects: json
          .whereType<Map>()
          .map((e) => DrawingObject.fromJson(Map<String, Object?>.from(e)))
          .toList(growable: false),
    );
  }
}

DrawingAnchorType _anchorTypeFromName(String? name) {
  return DrawingAnchorType.values.firstWhere(
    (e) => e.name == name,
    orElse: () => DrawingAnchorType.chart,
  );
}

TradingViewDrawingTool _drawingToolFromName(String? name) {
  return TradingViewDrawingTool.values.firstWhere(
    (e) => e.name == name,
    orElse: () => TradingViewDrawingTool.cursor,
  );
}
