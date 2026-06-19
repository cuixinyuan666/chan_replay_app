import sys
import unittest
from pathlib import Path


sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'backend'))

from app.a_rhythm_overlay_trainer import (  # noqa: E402
    _Line,
    _build_parent_entries,
    _calc_mode,
    _monotonic_rhythm_triplet,
    with_level_rhythm_overlay,
)


def _line(index, begin_x, end_x, begin_val, end_val, direction):
    return _Line(
        level='fx', index=index, begin_x=begin_x, end_x=end_x,
        begin_val=begin_val, end_val=end_val, direction=direction,
    )


def _entries(direction, a, b, c, d, e, *, mode='transition', parent_index=0):
    opposite = 'DOWN' if direction == 'UP' else 'UP'
    children = [
        _line(0, 0, 1, a, b, direction),
        _line(1, 1, 2, b, c, opposite),
        _line(2, 2, 3, c, d, direction),
        _line(3, 3, 4, d, e, opposite),
    ]
    return _build_parent_entries(
        chart_level='DAILY', child_level='fx', parent_level='bi',
        parent=_line(parent_index, 0, 3, a, d, direction),
        children=children, bars=[], mode=mode,
    )


class RhythmOverlayTrainerTest(unittest.TestCase):
    def test_calc_mode_defaults_and_legacy_normal_map_to_strict1382(self):
        self.assertEqual(_calc_mode(None), 'strict1382')
        self.assertEqual(_calc_mode({'rhythm_calc_mode': 'normal'}), 'strict1382')
        self.assertEqual(_calc_mode({'rhythm_calc_mode': 'invalid'}), 'strict1382')
        self.assertEqual(_calc_mode({'rhythm_calc_mode': 'transition'}), 'transition')

    def test_transition_requires_both_retrace_and_breakout(self):
        self.assertTrue(_monotonic_rhythm_triplet(
            'UP', first_start=10, first_end=20,
            retrace_end=15, current_end=25))
        self.assertFalse(_monotonic_rhythm_triplet(
            'UP', first_start=10, first_end=20,
            retrace_end=8, current_end=25))
        self.assertTrue(_monotonic_rhythm_triplet(
            'DOWN', first_start=30, first_end=20,
            retrace_end=25, current_end=15))
        self.assertFalse(_monotonic_rhythm_triplet(
            'DOWN', first_start=30, first_end=20,
            retrace_end=35, current_end=15))

    def test_strict1382_is_transition_plus_threshold(self):
        passed, _ = _entries('UP', 10, 20, 15, 22, 18, mode='strict1382')
        failed_threshold, _ = _entries(
            'UP', 10, 20, 15, 21, 18, mode='strict1382')
        failed_transition, _ = _entries(
            'UP', 10, 20, 8, 25, 18, mode='strict1382')
        self.assertTrue(passed)
        self.assertFalse(failed_threshold)
        self.assertFalse(failed_transition)

    def test_turning_point_renders_c_to_e_in_both_directions(self):
        for args in [
            ('UP', 10, 20, 15, 25, 22),
            ('DOWN', 30, 20, 25, 15, 18),
        ]:
            lines, _ = _entries(*args)
            self.assertTrue(lines)
            self.assertEqual({line['x1'] for line in lines}, {2})
            self.assertEqual({line['x2'] for line in lines}, {4})

    def test_parent_local_numbering_resets_while_ids_stay_unique(self):
        first, _ = _entries('UP', 10, 20, 15, 25, 22, parent_index=1)
        second, _ = _entries('UP', 10, 20, 15, 25, 22, parent_index=2)
        self.assertEqual(first[0]['round_ref'], 1)
        self.assertEqual(second[0]['round_ref'], 1)
        self.assertEqual(first[0]['label_left'], '1-0')
        self.assertEqual(second[0]['label_left'], '1-0')
        self.assertNotEqual(first[0]['id'], second[0]['id'])

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
            chart_level='DAILY', child_level='fx', parent_level='bi',
            parent=parent, children=children, bars=[], mode='transition')
        group_one = [line for line in lines if line['round_ref'] == 1]
        self.assertEqual({line['x1'] for line in group_one}, {2})
        self.assertEqual({line['x2'] for line in group_one}, {4, 6})

    def test_legacy_normal_is_never_exported(self):
        payload = {'bars': [], 'fx': [], 'bi': [], 'seg': [], 'seg_layers': {}}
        result = with_level_rhythm_overlay(
            'DAILY', payload,
            {'enable_rhythm_1382': True, 'rhythm_calc_mode': 'normal'})
        self.assertEqual(result['meta']['rhythm_calc_mode'], 'strict1382')
        self.assertIn('deprecated', result['meta']['rhythm_calc_mode_compat_note'])


if __name__ == '__main__':
    unittest.main()
