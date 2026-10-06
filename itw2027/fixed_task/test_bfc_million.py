import json
import tempfile
import unittest
from collections import defaultdict
from pathlib import Path

from bfc_million import FRAMES_PER_POINT, SHARD_FRAMES, SNR_DB, generate


class BfcMillionManifestTest(unittest.TestCase):
    def test_exact_coverage_and_separate_arrays(self):
        with tempfile.TemporaryDirectory() as directory:
            out = Path(directory) / 'campaign'
            generate(out)
            tasks = json.loads((out / 'tasks.json').read_text())
            self.assertEqual(len(tasks), 12_600)
            self.assertEqual(sum(t['frames'] for t in tasks), 18_000_000)
            self.assertEqual(len({t['output'] for t in tasks}), len(tasks))
            for family in SHARD_FRAMES:
                selected = json.loads((out / f'{family}_tasks.json').read_text())
                self.assertEqual(selected, [t for t in tasks if t['family'] == family])
                self.assertLess(len(selected), 10_000)
            grouped = defaultdict(list)
            for task in tasks:
                self.assertEqual(task['scheme'], 'bfc')
                self.assertEqual(task['ldpc_rate'], 1 / 3)
                self.assertEqual(task['frames_per_point'], FRAMES_PER_POINT)
                self.assertEqual(task['frames'], SHARD_FRAMES[task['family']])
                grouped[task['family'], task['snr_db']].append(task)
            self.assertEqual(set(grouped), {(family, snr)
                                             for family in SHARD_FRAMES for snr in SNR_DB})
            for group in grouped.values():
                group.sort(key=lambda task: task['first_frame'])
                self.assertEqual([task['first_frame'] for task in group],
                                 list(range(1, FRAMES_PER_POINT + 1,
                                            group[0]['frames'])))


if __name__ == '__main__':
    unittest.main()
