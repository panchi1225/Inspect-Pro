import copy
import unittest
from add_rough_terrain_crane import build_plan, TYPE_PATH


class MasterTests(unittest.TestCase):
    def setUp(self):
        self.existing = {'machines/old-id': {'type': '油圧ショベル', 'sortOrder': 91},
                         'machine_types/excavator': {'name': '油圧ショベル'}}

    def test_append_repeat_preserve(self):
        before = copy.deepcopy(self.existing)
        first = build_plan(self.existing)
        self.assertEqual(len(first), 45)
        self.assertEqual(self.existing, before)
        self.existing.update(first)
        self.assertEqual(build_plan(self.existing), {})
        for model in ('25t', '50t'):
            machines = [v for p, v in first.items() if p.startswith(f'machines/rtc_{model}_')]
            self.assertEqual([m['unitNumber'] for m in machines], [f'{i}号機' for i in range(1, 16)])
            self.assertTrue(all(m['sortOrder'] > 91 for m in machines))
        items = [v for p, v in first.items() if '/items/' in p]
        self.assertEqual(len(items), 14)
        self.assertEqual(sum(i['isRequired'] for i in items), 5)

    def test_conflicts_never_overwrite(self):
        for path, value in [
            ('machines/rtc_25t_01', {'type': '別機械'}),
            ('machines/other-id', {'type': 'ラフタークレーン'}),
            (TYPE_PATH, {'name': '別機械'}),
            (TYPE_PATH + '/items/custom', {'name': '追加項目'}),
            ('machine_types/another', {'name': 'ラフタークレーン'}),
        ]:
            with self.subTest(path=path):
                state = {**self.existing, path: value}
                before = copy.deepcopy(state)
                with self.assertRaises(ValueError):
                    build_plan(state)
                self.assertEqual(state, before)

    def test_changed_item_and_partial_resume(self):
        first = build_plan(self.existing)
        self.existing.update(first)
        del self.existing['machines/rtc_50t_15']
        self.assertEqual(list(build_plan(self.existing)), ['machines/rtc_50t_15'])
        self.existing[TYPE_PATH + '/items/rtc_06']['checkpoint'] = '変更済み'
        with self.assertRaises(ValueError):
            build_plan(self.existing)


if __name__ == '__main__':
    unittest.main()
