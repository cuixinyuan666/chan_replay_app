import sys
import unittest
from pathlib import Path


sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'backend'))

from app.a_rhythm_overlay_trainer import (  # noqa: E402
    _Line,
    _build_parent_entries,
    _monotonic_rhythm_triplet,
)


def _line(index, begin_x, end_x, begin_val, end_val, direction):
    return _Line(
        level='fx',
        index=index,
        begin_x=begin_x,
        end_x=end_x,
        begin_val=begin_val,
        end_val=end_val,
        direction=direction,
    )


class RhythmOverlayTrainerTest(unittest.TestCase):
    def test_only_accepts_monotonic_three_leg_patterns(self):
        self.assertTrue(_monotonic_rhythm_triplet(
            'UP', first_start=1.0, first_end=2.0,
            retrace_end=1.2, current_end=2.3,
        ))
        self.assertTrue(_monotonic_rhythm_triplet(
            'DOWN', first_start=3.0, first_end=2.0,
            retrace_end=2.8, current_end=1.7,
        ))
        self.assertFalse(_monotonic_rhythm_triplet(
            'UP', first_start=1.0, first_end=2.0,
            retrace_end=0.9, current_end=2.3,
        ))
        self.assertFalse(_monotonic_rhythm_triplet(
            'DOWN', first_start=3.0, first_end=2.0,
            retrace_end=3.1, current_end=1.7,
        ))

    def test_descending_parent_can_emit_rising_fx_rhythm(self):
        parent = _line(1, 0, 6, 3.0, 1.0, 'DOWN')
        children = [
            _line(0, 0, 1, 1.0, 2.0, 'UP'),
            _line(1, 1, 2, 2.0, 1.2, 'DOWN'),
            _line(2, 2, 3, 1.2, 2.4, 'UP'),
            _line(3, 3, 4, 2.4, 1.4, 'DOWN'),
            _line(4, 4, 5, 1.4, 2.8, 'UP'),
            _line(5, 5, 6, 2.8, 1.6, 'DOWN'),
        ]

        lines, _ = _build_parent_entries(
            chart_level='DAILY',
            child_level='fx',
            parent_level='bi',
            parent=parent,
            children=children,
            bars=[],
            mode='normal',
        )

        self.assertTrue(lines)
        self.assertTrue(all(line['dir'] == 'UP' for line in lines))

    def test_same_round_ref_group_uses_one_start_time(self):
        parent = _line(1, 0, 6, 3.0, 1.0, 'DOWN')
        children = [
            _line(0, 0, 1, 1.0, 2.0, 'UP'),
            _line(1, 1, 2, 2.0, 1.2, 'DOWN'),
            _line(2, 2, 3, 1.2, 2.4, 'UP'),
            _line(3, 3, 4, 2.4, 1.4, 'DOWN'),
            _line(4, 4, 5, 1.4, 2.8, 'UP'),
            _line(5, 5, 6, 2.8, 1.6, 'DOWN'),
        ]

        lines, _ = _build_parent_entries(
            chart_level='DAILY',
            child_level='fx',
            parent_level='bi',
            parent=parent,
            children=children,
            bars=[],
            mode='normal',
        )
        group_one = [line for line in lines if line['round_ref'] == 1]

        self.assertEqual({line['x1'] for line in group_one}, {2})
        self.assertEqual({line['x2'] for line in group_one}, {4, 6})


if __name__ == '__main__':
    unittest.main()
