import 'package:flutter/material.dart';

class ResearchOptionRegistration {
  final String value;
  final String label;

  const ResearchOptionRegistration({required this.value, required this.label});
}

class ResearchStructureRegistration extends ResearchOptionRegistration {
  final bool recursiveLayer;
  final int fixedLayer;
  final String endpointCandidateSource;
  final String realBspSource;

  const ResearchStructureRegistration({
    required super.value,
    required super.label,
    required this.endpointCandidateSource,
    required this.realBspSource,
    this.recursiveLayer = false,
    this.fixedLayer = 2,
  });

  int effectiveLayer(int layer) => recursiveLayer ? layer : fixedLayer;
}

class ResearchBspTypeRegistration {
  final String value;
  final bool endpointCandidate;
  final String? buyLabel;
  final String? sellLabel;

  const ResearchBspTypeRegistration({
    required this.value,
    this.endpointCandidate = false,
    this.buyLabel,
    this.sellLabel,
  });

  String labelForSide(String side) {
    if (endpointCandidate) {
      return side == 'buy'
          ? (buyLabel ?? '下跌终点候选')
          : (sellLabel ?? '上涨终点候选');
    }
    return '${side == 'buy' ? 'B' : 'S'}$value';
  }
}

enum ResearchActionKind { endpoint, segComposite }

class ResearchActionRegistration {
  final String id;
  final String label;
  final IconData icon;
  final String endpoint;
  final ResearchActionKind kind;

  const ResearchActionRegistration({
    required this.id,
    required this.label,
    required this.icon,
    required this.endpoint,
    this.kind = ResearchActionKind.endpoint,
  });
}

/// Registry for research/backtest page options.
///
/// Keep page widgets declarative: adding a BSP type, source structure, execution
/// mode, K-line period, or action button should register one item here rather
/// than scattering hard-coded dropdown/action lists through the page.
class ResearchBacktestRegistry {
  ResearchBacktestRegistry._();

  static final ResearchBacktestRegistry instance = ResearchBacktestRegistry._();

  final List<ResearchOptionRegistration> _levels = <ResearchOptionRegistration>[
    const ResearchOptionRegistration(value: 'MIN1', label: 'MIN1'),
    const ResearchOptionRegistration(value: 'MIN5', label: 'MIN5'),
    const ResearchOptionRegistration(value: 'MIN15', label: 'MIN15'),
    const ResearchOptionRegistration(value: 'MIN30', label: 'MIN30'),
    const ResearchOptionRegistration(value: 'MIN60', label: 'MIN60'),
    const ResearchOptionRegistration(value: 'DAILY', label: 'DAILY'),
  ];

  final List<ResearchOptionRegistration> _executionModes =
      <ResearchOptionRegistration>[
    const ResearchOptionRegistration(value: 'once', label: 'once'),
    const ResearchOptionRegistration(value: 'step', label: 'step'),
  ];

  final List<ResearchOptionRegistration> _sides = <ResearchOptionRegistration>[
    const ResearchOptionRegistration(value: 'buy', label: '买'),
    const ResearchOptionRegistration(value: 'sell', label: '卖'),
  ];

  final List<ResearchStructureRegistration> _structures =
      <ResearchStructureRegistration>[
    const ResearchStructureRegistration(
      value: 'bi',
      label: '笔',
      endpointCandidateSource: 'bi_endpoint_candidate',
      realBspSource: 'origin_bsp',
    ),
    const ResearchStructureRegistration(
      value: 'seg',
      label: '线段',
      endpointCandidateSource: 'seg_endpoint_candidate',
      realBspSource: 'origin_bsp',
    ),
    const ResearchStructureRegistration(
      value: 'nseg',
      label: 'N段',
      endpointCandidateSource: 'recursive_seg_endpoint_candidate',
      realBspSource: 'recursive_seg_bsp',
      recursiveLayer: true,
    ),
  ];

  final List<ResearchBspTypeRegistration> _bspTypes =
      <ResearchBspTypeRegistration>[
    const ResearchBspTypeRegistration(value: '1'),
    const ResearchBspTypeRegistration(value: '1p'),
    const ResearchBspTypeRegistration(value: '2'),
    const ResearchBspTypeRegistration(value: '2s'),
    const ResearchBspTypeRegistration(value: '3a'),
    const ResearchBspTypeRegistration(value: '3b'),
    const ResearchBspTypeRegistration(
      value: 'endpoint',
      endpointCandidate: true,
      buyLabel: '下跌终点候选',
      sellLabel: '上涨终点候选',
    ),
  ];

  final List<ResearchActionRegistration> _actions =
      <ResearchActionRegistration>[
    const ResearchActionRegistration(
      id: 'bsp-features',
      label: 'BSP 特征',
      icon: Icons.table_chart,
      endpoint: '/api/research/bsp/features',
    ),
    const ResearchActionRegistration(
      id: 'ml-score',
      label: 'ML 打分',
      icon: Icons.psychology,
      endpoint: '/api/research/ml/score',
    ),
    const ResearchActionRegistration(
      id: 'backtest',
      label: '回测',
      icon: Icons.show_chart,
      endpoint: '/api/research/backtest',
    ),
    const ResearchActionRegistration(
      id: 'pipeline',
      label: '一键 Pipeline',
      icon: Icons.account_tree,
      endpoint: '/api/research/pipeline',
    ),
    const ResearchActionRegistration(
      id: 'seg-composite',
      label: '组合回测',
      icon: Icons.layers,
      endpoint: '/api/research/seg-composite/backtest',
      kind: ResearchActionKind.segComposite,
    ),
  ];

  List<ResearchOptionRegistration> get levels => List.unmodifiable(_levels);
  List<ResearchOptionRegistration> get executionModes =>
      List.unmodifiable(_executionModes);
  List<ResearchOptionRegistration> get sides => List.unmodifiable(_sides);
  List<ResearchStructureRegistration> get structures =>
      List.unmodifiable(_structures);
  List<ResearchBspTypeRegistration> get bspTypes =>
      List.unmodifiable(_bspTypes);
  List<ResearchActionRegistration> get actions => List.unmodifiable(_actions);

  ResearchStructureRegistration get defaultStructure => _structures.last;
  ResearchBspTypeRegistration get defaultBspType => _bspTypes.last;

  void registerLevel(ResearchOptionRegistration registration) =>
      _upsertOption(_levels, registration);

  void registerExecutionMode(ResearchOptionRegistration registration) =>
      _upsertOption(_executionModes, registration);

  void registerSide(ResearchOptionRegistration registration) =>
      _upsertOption(_sides, registration);

  void registerStructure(ResearchStructureRegistration registration) =>
      _upsertStructure(_structures, registration);

  void registerBspType(ResearchBspTypeRegistration registration) =>
      _upsertBspType(_bspTypes, registration);

  void registerAction(ResearchActionRegistration registration) =>
      _upsertAction(_actions, registration);

  ResearchStructureRegistration structureOf(String value) =>
      _structures.firstWhere(
        (item) => item.value == value,
        orElse: () => defaultStructure,
      );

  ResearchBspTypeRegistration bspTypeOf(String value) => _bspTypes.firstWhere(
        (item) => item.value == value,
        orElse: () => defaultBspType,
      );

  bool hasBspType(String value) => _bspTypes.any((item) => item.value == value);

  Map<String, dynamic> buildConditionPayload({
    required String structure,
    required int layer,
    required String side,
    required String type,
  }) {
    final structureRegistration = structureOf(structure);
    final typeRegistration = bspTypeOf(type);
    final isEndpoint = typeRegistration.endpointCandidate;
    return {
      'source': isEndpoint
          ? structureRegistration.endpointCandidateSource
          : structureRegistration.realBspSource,
      'structure': structureRegistration.value,
      'layer': structureRegistration.effectiveLayer(layer),
      'side': side,
      'types': isEndpoint ? <String>[] : <String>[typeRegistration.value],
    };
  }

  static void _upsertOption(
    List<ResearchOptionRegistration> target,
    ResearchOptionRegistration registration,
  ) {
    final index = target.indexWhere((item) => item.value == registration.value);
    if (index >= 0) {
      target[index] = registration;
    } else {
      target.add(registration);
    }
  }

  static void _upsertStructure(
    List<ResearchStructureRegistration> target,
    ResearchStructureRegistration registration,
  ) {
    final index = target.indexWhere((item) => item.value == registration.value);
    if (index >= 0) {
      target[index] = registration;
    } else {
      target.add(registration);
    }
  }

  static void _upsertBspType(
    List<ResearchBspTypeRegistration> target,
    ResearchBspTypeRegistration registration,
  ) {
    final index = target.indexWhere((item) => item.value == registration.value);
    if (index >= 0) {
      target[index] = registration;
    } else {
      target.add(registration);
    }
  }

  static void _upsertAction(
    List<ResearchActionRegistration> target,
    ResearchActionRegistration registration,
  ) {
    final index = target.indexWhere((item) => item.id == registration.id);
    if (index >= 0) {
      target[index] = registration;
    } else {
      target.add(registration);
    }
  }
}
