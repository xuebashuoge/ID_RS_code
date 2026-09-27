import json
import tempfile
import unittest
from pathlib import Path

from noiseless_rank_aligned import EXPECTED_NT, generate


class NoiselessRankAlignedTest(unittest.TestCase):
    def test_only_rank_function_changes(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            base, extension, out = root / 'base', root / 'extension', root / 'out'
            base.mkdir(); extension.mkdir()
            originals = []
            for index, nt in enumerate(EXPECTED_NT):
                task = dict(
                    kind='noiseless', family='rank', nt=nt, messages=2000,
                    first_message=1, seed_group=2, first_position=1,
                    positions=2 ** (nt // 2), chunk_size=64,
                    runtime_limit=18000 if nt <= 40 else 3000,
                    output=f'noiseless/rank_{nt}.mat')
                originals.append(task)
                destination = base if nt <= 40 else extension
                path = destination / 'noiseless.json'
                current = json.loads(path.read_text()) if path.exists() else []
                path.write_text(json.dumps(current + [task]))

            generate(base, extension, out)
            tasks = json.loads((out / 'noiseless.json').read_text())
            self.assertEqual(len(tasks), len(EXPECTED_NT))
            for original, aligned in zip(originals, tasks):
                self.assertEqual(
                    {key: value for key, value in aligned.items()
                     if key not in ('m', 'rank_threshold')}, original)
                self.assertEqual((aligned['m'], aligned['rank_threshold']),
                                 (150, 2000))
            self.assertEqual(len(json.loads(
                (out / 'probe_rank.json').read_text())), 1)
            self.assertEqual(len(json.loads(
                (out / 'noiseless_rank.json').read_text())),
                len(EXPECTED_NT) - 1)


if __name__ == '__main__':
    unittest.main()
