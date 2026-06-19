import 'package:chan_replay_app/data/chan_snapshot_json_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('snapshot parser passively preserves backend rhythm identity and span',
      () {
    final payload = <String, dynamic>{
      'bars': <dynamic>[],
      'rhythm_lines': <dynamic>[
        <String, dynamic>{
          'id': 'rhythm|bi-parent-7|fx|UP|1|1|0',
          'level': 'MIN15',
          'source_kind': 'fx',
          'source_label': '分型',
          'parent_level': 'bi',
          'parent_key': 'bi-parent-7',
          'calc_mode': 'strict1382',
          'dir': 'UP',
          'display_label': '节奏线1-0',
          'label_left': '1-0',
          'label_right': '0.5',
          'x1': 12,
          'y1': 20.5,
          'x2': 18,
          'y2': 20.5,
          'threshold': 21.91,
          'ratio': 0.5,
          'threshold_ratio': 1.382,
          'round_current': 1,
          'round_ref': 1,
          'layer': 0,
        },
      ],
      'rhythm_hits': <dynamic>[],
    };

    final snapshot = ChanSnapshotJsonParser.parse(payload);
    expect(snapshot.rhythmLines, hasLength(1));
    final line = snapshot.rhythmLines.single;
    expect(line.parentKey, 'bi-parent-7');
    expect(line.calcMode, 'strict1382');
    expect(line.labelLeft, '1-0');
    expect(line.x1, 12);
    expect(line.x2, 18);
  });
}
