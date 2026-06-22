import 'package:chan_replay_app/data/chan_snapshot_json_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('keeps endpoint candidates separate from calculated recursive BSP', () {
    final snapshot = ChanSnapshotJsonParser.parse(<String, dynamic>{
      'raw_bars': <dynamic>[],
      'seg_bsp_layers': <String, dynamic>{'2': <dynamic>[]},
      'seg_endpoint_bsp_layers': <String, dynamic>{
        '2': <dynamic>[
          <String, dynamic>{
            'raw_index': 42,
            'price': 12.34,
            'type': 'SEG2_B',
            'level': 'seg2',
            'is_buy': true,
            'derived': true,
          },
        ],
      },
    });

    expect(snapshot.recursiveSegBsps[2], isEmpty);
    expect(snapshot.recursiveSegBspCandidates[2], hasLength(1));
    expect(snapshot.recursiveSegBspCandidates[2]!.single.rawIndex, 42);
    expect(snapshot.recursiveSegBspCandidates[2]!.single.isBuy, isTrue);
    expect(snapshot.recursiveSegBspCandidates[2]!.single.derived, isTrue);
  });

  test('prefers calculated recursive segment BSP over endpoint fallback', () {
    final snapshot = ChanSnapshotJsonParser.parse(<String, dynamic>{
      'raw_bars': <dynamic>[],
      'seg_bsp_layers': <String, dynamic>{
        '2': <dynamic>[
          <String, dynamic>{
            'raw_index': 10,
            'price': 10.0,
            'type': 'B1',
            'level': 'seg2',
          },
        ],
      },
      'seg_endpoint_bsp_layers': <String, dynamic>{
        '2': <dynamic>[
          <String, dynamic>{
            'raw_index': 42,
            'price': 12.34,
            'type': 'SEG2_B',
            'level': 'seg2',
          },
        ],
      },
    });

    expect(snapshot.recursiveSegBsps[2], hasLength(1));
    expect(snapshot.recursiveSegBsps[2]!.single.rawIndex, 10);
    expect(snapshot.recursiveSegBsps[2]!.single.type, 'B1');
    expect(snapshot.recursiveSegBspCandidates[2], hasLength(1));
  });

  test('parses recursive segment ZS independently by layer', () {
    final snapshot = ChanSnapshotJsonParser.parse(<String, dynamic>{
      'seg_zs_layers': <String, dynamic>{
        '3': <dynamic>[
          <String, dynamic>{
            'index': 1,
            'start_parent_index': 2,
            'end_parent_index': 4,
            'start_raw_index': 20,
            'end_raw_index': 40,
            'zg': 12.0,
            'zd': 10.0,
            'gg': 13.0,
            'dd': 9.0,
            'is_sure': false,
          },
        ],
      },
    });

    expect(snapshot.recursiveSegZss[3], hasLength(1));
    expect(snapshot.recursiveSegZss[3]!.single.startRawIndex, 20);
    expect(snapshot.recursiveSegZss[3]!.single.confirmed, isFalse);
  });

  test('prefers step recognition history and retains structural anchor', () {
    final snapshot = ChanSnapshotJsonParser.parse(<String, dynamic>{
      'seg_bsp_layers': <String, dynamic>{
        '2': <dynamic>[
          <String, dynamic>{
            'raw_index': 10,
            'price': 9.8,
            'type': 'B1p',
          },
        ],
      },
      'seg_bsp_history_layers': <String, dynamic>{
        '2': <dynamic>[
          <String, dynamic>{
            'raw_index': 12,
            'anchor_raw_index': 10,
            'recognized_raw_index': 12,
            'price': 9.8,
            'type': 'B1',
            'is_buy': true,
          },
        ],
      },
    });

    final bsp = snapshot.recursiveSegBsps[2]!.single;
    expect(bsp.rawIndex, 12);
    expect(bsp.anchorRawIndex, 10);
    expect(bsp.recognizedRawIndex, 12);
    expect(bsp.type, 'B1');
  });
}
