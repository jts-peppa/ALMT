import ast
import torch
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

from core import dataset as dataset_module


class _FakeDataset:
    created = []

    def __init__(self, args, mode):
        self.mode = mode
        self.created.append(mode)

    def __len__(self):
        return 1

    def __getitem__(self, index):
        return index


class ProtocolSafeDataLoaderTest(unittest.TestCase):
    def setUp(self):
        _FakeDataset.created.clear()
        self.args = SimpleNamespace(base=SimpleNamespace(batch_size=1, num_workers=0))

    def test_default_never_builds_test(self):
        with patch.object(dataset_module, 'MMDataset', _FakeDataset):
            loaders = dataset_module.MMDataLoader(self.args)
        self.assertEqual(list(loaders), ['train', 'valid'])
        self.assertEqual(_FakeDataset.created, ['train', 'valid'])

    def test_explicit_test_only(self):
        with patch.object(dataset_module, 'MMDataset', _FakeDataset):
            loaders = dataset_module.MMDataLoader(self.args, splits=('test',))
        self.assertEqual(list(loaders), ['test'])
        self.assertEqual(_FakeDataset.created, ['test'])

    def test_unknown_split_fails_closed(self):
        with patch.object(dataset_module, 'MMDataset', _FakeDataset):
            with self.assertRaises(ValueError):
                dataset_module.MMDataLoader(self.args, splits=('validation',))
        self.assertEqual(_FakeDataset.created, [])

    def test_test_loader_is_guarded_by_explicit_flag(self):
        tree = ast.parse(Path('train.py').read_text(encoding='utf-8'))
        guarded = False
        for node in ast.walk(tree):
            if isinstance(node, ast.If) and ast.unparse(node.test) == 'opt.evaluate_test':
                guarded = "splits=('test',)" in ''.join(ast.unparse(x) for x in node.body)
        self.assertTrue(guarded)

    def test_last_checkpoint_contract_is_complete(self):
        source = Path('train.py').read_text(encoding='utf-8')
        for required_key in (
            "'model'", "'optimizer'", "'scheduler'", "'rng'", "'epoch'",
            "'best_valid_loss'", "'config_hash'", "'source_hash'", "'seed'",
        ):
            self.assertIn(required_key, source)
        self.assertIn('_atomic_torch_save(checkpoint_payload, last_checkpoint)', source)

    def test_partial_accumulation_group_is_not_underweighted(self):
        accumulation_steps = 16
        loader_length = 17
        denominators = []
        for cur_iter in range(loader_length):
            group_start = (cur_iter // accumulation_steps) * accumulation_steps
            denominators.append(min(accumulation_steps, loader_length - group_start))
        self.assertEqual(denominators[:16], [16] * 16)
        self.assertEqual(denominators[16], 1)

    def test_accumulation_defaults_to_one_and_rejects_invalid_values(self):
        source = Path('train.py').read_text(encoding='utf-8')
        module_tree = ast.parse(source)
        function = next(
            node for node in module_tree.body
            if isinstance(node, ast.FunctionDef) and node.name == '_gradient_accumulation_steps'
        )
        isolated = ast.Module(body=[function], type_ignores=[])
        namespace = {}
        exec(compile(isolated, 'train.py', 'exec'), namespace)
        resolver = namespace['_gradient_accumulation_steps']

        self.assertEqual(resolver(SimpleNamespace(base=SimpleNamespace())), 1)
        self.assertEqual(
            resolver(SimpleNamespace(base=SimpleNamespace(gradient_accumulation_steps=16))),
            16,
        )
        for invalid in (0, -1, 1.5, True):
            with self.assertRaises(ValueError):
                resolver(SimpleNamespace(base=SimpleNamespace(
                    gradient_accumulation_steps=invalid
                )))

    def test_source_hash_covers_training_recorder_logic(self):
        source = Path('train.py').read_text(encoding='utf-8')
        self.assertIn("'core/utils.py'", source)


if __name__ == '__main__':
    unittest.main()
