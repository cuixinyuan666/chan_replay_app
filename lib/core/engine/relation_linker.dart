import '../models/bi.dart';
import '../models/seg.dart';

class LinkedChanStruct {
  final List<BI> bis;
  final List<SEG> segs;

  const LinkedChanStruct({required this.bis, required this.segs});
}

class ChanRelationLinker {
  LinkedChanStruct link(List<BI> sourceBis, List<SEG> sourceSegs) {
    if (sourceBis.isEmpty) {
      return const LinkedChanStruct(bis: [], segs: []);
    }

    var bis = _linkBiPrevNext(sourceBis);
    final parentMap = _buildParentSegMap(bis, sourceSegs);
    bis = _applyParentSeg(bis, parentMap);
    final segs = _linkSegs(sourceSegs, bis);

    return LinkedChanStruct(
      bis: List<BI>.unmodifiable(bis),
      segs: List<SEG>.unmodifiable(segs),
    );
  }

  List<BI> _linkBiPrevNext(List<BI> source) {
    return [
      for (var i = 0; i < source.length; i++)
        source[i].copyWith(
          prevIndex: i > 0 ? source[i - 1].index : null,
          clearPrevIndex: i == 0,
          nextIndex: i + 1 < source.length ? source[i + 1].index : null,
          clearNextIndex: i + 1 >= source.length,
          clearParentSegIndex: true,
          clearParentSegDirection: true,
          clearParentSegIsSure: true,
          clearParentSegStartBiIndex: true,
          clearParentSegEndBiIndex: true,
          isSure: true,
        ),
    ];
  }

  Map<int, _ParentSegInfo> _buildParentSegMap(List<BI> bis, List<SEG> segs) {
    final map = <int, _ParentSegInfo>{};
    for (final seg in segs) {
      for (final bi in bis) {
        if (bi.index < seg.startBiIndex || bi.index > seg.endBiIndex) continue;
        map[bi.index] = _ParentSegInfo(
          segIndex: seg.index,
          direction: seg.direction == SegDirection.up ? BiDirection.up : BiDirection.down,
          isSure: seg.isSure,
          startBiIndex: seg.startBiIndex,
          endBiIndex: seg.endBiIndex,
        );
      }
    }
    return map;
  }

  List<BI> _applyParentSeg(List<BI> source, Map<int, _ParentSegInfo> parentMap) {
    return [
      for (final bi in source)
        if (parentMap.containsKey(bi.index))
          bi.copyWith(
            parentSegIndex: parentMap[bi.index]!.segIndex,
            parentSegDirection: parentMap[bi.index]!.direction,
            parentSegIsSure: parentMap[bi.index]!.isSure,
            parentSegStartBiIndex: parentMap[bi.index]!.startBiIndex,
            parentSegEndBiIndex: parentMap[bi.index]!.endBiIndex,
          )
        else
          bi.copyWith(
            clearParentSegIndex: true,
            clearParentSegDirection: true,
            clearParentSegIsSure: true,
            clearParentSegStartBiIndex: true,
            clearParentSegEndBiIndex: true,
          ),
    ];
  }

  List<SEG> _linkSegs(List<SEG> sourceSegs, List<BI> linkedBis) {
    final biByIndex = {for (final bi in linkedBis) bi.index: bi};
    return [
      for (var i = 0; i < sourceSegs.length; i++)
        _rebuildSeg(
          sourceSegs[i],
          biByIndex,
          prevIndex: i > 0 ? sourceSegs[i - 1].index : null,
          nextIndex: i + 1 < sourceSegs.length ? sourceSegs[i + 1].index : null,
        ),
    ];
  }

  SEG _rebuildSeg(
    SEG seg,
    Map<int, BI> biByIndex, {
    required int? prevIndex,
    required int? nextIndex,
  }) {
    final list = <BI>[];
    for (var i = seg.startBiIndex; i <= seg.endBiIndex; i++) {
      final bi = biByIndex[i];
      if (bi != null) list.add(bi);
    }

    final start = biByIndex[seg.startBiIndex] ?? seg.startBi;
    final end = biByIndex[seg.endBiIndex] ?? seg.endBi;
    return seg.copyWith(
      startBi: start,
      endBi: end,
      biList: List<BI>.unmodifiable(list),
      prevIndex: prevIndex,
      clearPrevIndex: prevIndex == null,
      nextIndex: nextIndex,
      clearNextIndex: nextIndex == null,
    );
  }
}

class _ParentSegInfo {
  final int segIndex;
  final BiDirection direction;
  final bool isSure;
  final int startBiIndex;
  final int endBiIndex;

  const _ParentSegInfo({
    required this.segIndex,
    required this.direction,
    required this.isSure,
    required this.startBiIndex,
    required this.endBiIndex,
  });
}
