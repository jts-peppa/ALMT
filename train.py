import os
import random
import time
import json
import hashlib
import subprocess
import numpy as np
import torch
import argparse
from core.dataset import MMDataLoader
from core.scheduler import get_scheduler
from core.utils import AverageMeter, setup_seed, results_recorder, dict_to_namespace
from tensorboardX import SummaryWriter
from models.almt import build_model
from core.metric import MetricsTop
import yaml


parser = argparse.ArgumentParser() 
parser.add_argument('--config_file', type=str, default='configs/sims.yaml') 
parser.add_argument('--seed', type=int, default=-1) 
parser.add_argument('--gpu_id', type=int, default=-1) 
parser.add_argument('--evaluate_test', action='store_true',
                    help='Explicitly evaluate Test once after training using the best-Valid checkpoint.')
parser.add_argument('--resume', nargs='?', const='auto', default=None,
                    help='Resume from an epoch-boundary checkpoint; omit the path to use rolling last checkpoint.')
parser.add_argument('--stop_after_epoch', type=int, default=None,
                    help='Operational stop at an epoch boundary (does not alter the configured schedule).')
opt = parser.parse_args()
print(opt)

with open(opt.config_file) as f:
    args = yaml.load(f, Loader=yaml.FullLoader)
args = dict_to_namespace(args)
print(args)

seed = args.base.seed if opt.seed == -1 else opt.seed
gpu_id = args.base.gpu_id if opt.gpu_id == -1 else opt.gpu_id

print('-----------------args-----------------')
print(args)
print('-------------------------------------')

gpu_id = str(gpu_id)
os.environ["CUDA_VISIBLE_DEVICES"] = gpu_id
USE_CUDA = torch.cuda.is_available()
device = torch.device("cuda" if USE_CUDA else "cpu")
print(f"Device: {device} ({gpu_id})")


def _sha256_file(path):
    digest = hashlib.sha256()
    with open(path, 'rb') as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b''):
            digest.update(chunk)
    return digest.hexdigest()


def _source_hash():
    paths = [
        'train.py', 'core/dataset.py', 'core/utils.py',
        'models/almt.py', 'models/almt_layer.py', 'models/bert.py',
    ]
    digest = hashlib.sha256()
    for path in paths:
        digest.update(path.encode('utf-8'))
        digest.update(bytes.fromhex(_sha256_file(path)))
    return digest.hexdigest()


def _git_audit():
    def run(*cmd):
        return subprocess.run(cmd, capture_output=True, text=True, check=True).stdout.strip()
    status = run('git', 'status', '--short')
    return {
        'head': run('git', 'rev-parse', 'HEAD'),
        'branch': run('git', 'branch', '--show-current'),
        'dirty': bool(status),
        'dirty_files': status.splitlines(),
    }


def _rng_state():
    return {
        'python': random.getstate(),
        'numpy': np.random.get_state(),
        'torch_cpu': torch.get_rng_state(),
        'torch_cuda': torch.cuda.get_rng_state_all() if torch.cuda.is_available() else None,
    }


def _restore_rng_state(state):
    random.setstate(state['python'])
    np.random.set_state(state['numpy'])
    # ``torch.load(..., map_location=device)`` also moves serialized RNG
    # tensors to CUDA.  PyTorch RNG restore APIs require CPU ByteTensors.
    torch.set_rng_state(state['torch_cpu'].cpu())
    if state['torch_cuda'] is not None and torch.cuda.is_available():
        torch.cuda.set_rng_state_all([rng.cpu() for rng in state['torch_cuda']])


def _atomic_torch_save(payload, path):
    tmp = path + '.tmp'
    torch.save(payload, tmp)
    os.replace(tmp, path)


def _gradient_accumulation_steps(config):
    steps = getattr(config.base, 'gradient_accumulation_steps', 1)
    if not isinstance(steps, int) or isinstance(steps, bool) or steps < 1:
        raise ValueError('gradient_accumulation_steps must be a positive integer.')
    return steps


def main():
    setup_seed(seed)
    log_path = os.path.join(".", "log", args.base.project_name)
    if not os.path.exists(log_path):
        os.makedirs(log_path)

    save_path = os.path.join(args.base.ckpt_root, args.base.project_name)
    if not os.path.exists(save_path):
        os.makedirs(save_path)

    model = build_model(args).to(device)

    dataLoader = MMDataLoader(args, splits=('train', 'valid'))

    optimizer = torch.optim.AdamW(model.parameters(),
                                 lr=args.base.lr,
                                 weight_decay=args.base.weight_decay)

    scheduler_warmup = get_scheduler(optimizer, args)

    loss_fn = torch.nn.MSELoss()

    metrics_fn = MetricsTop().getMetics(args.dataset.datasetName)

    training_results_recorder = results_recorder()
    validation_results_recorder = results_recorder()
    best_valid_loss = float('inf')
    best_checkpoint = os.path.join(save_path, f'best_valid_seed{seed}.pth')
    last_checkpoint = os.path.join(save_path, f'last_seed{seed}.pth')
    config_hash = _sha256_file(opt.config_file)
    source_hash = _source_hash()
    git_audit = _git_audit()
    start_epoch = 1
    resumed_from = None

    if opt.resume is not None:
        resumed_from = last_checkpoint if opt.resume == 'auto' else opt.resume
        checkpoint = torch.load(resumed_from, map_location=device, weights_only=False)
        if checkpoint['config_hash'] != config_hash:
            raise RuntimeError('Resume refused: configuration hash mismatch.')
        if checkpoint['source_hash'] != source_hash:
            raise RuntimeError('Resume refused: protocol source hash mismatch.')
        if checkpoint['seed'] != seed:
            raise RuntimeError('Resume refused: seed mismatch.')
        model.load_state_dict(checkpoint['model'])
        optimizer.load_state_dict(checkpoint['optimizer'])
        scheduler_warmup.load_state_dict(checkpoint['scheduler'])
        best_valid_loss = checkpoint['best_valid_loss']
        training_results_recorder.best_results_one_epoch = checkpoint.get('training_best_one', {})
        training_results_recorder.best_results_all_epochs = checkpoint.get('training_best_all', {})
        validation_results_recorder.best_results_one_epoch = checkpoint.get('validation_best_one', {})
        validation_results_recorder.best_results_all_epochs = checkpoint.get('validation_best_all', {})
        start_epoch = checkpoint['epoch'] + 1
        _restore_rng_state(checkpoint['rng'])
        print(f'Resumed epoch-boundary checkpoint: {resumed_from}; next epoch={start_epoch}')

    accumulation_steps = _gradient_accumulation_steps(args)
    audit = {
        'config_file': os.path.abspath(opt.config_file),
        'config_hash': config_hash,
        'source_hash': source_hash,
        'git': git_audit,
        'seed': seed,
        'physical_batch_size': args.base.batch_size,
        'gradient_accumulation_steps': accumulation_steps,
        'effective_batch_size': args.base.batch_size * accumulation_steps,
        'num_workers': args.base.num_workers,
        'test_evaluation_requested': opt.evaluate_test,
        'resumed_from': resumed_from,
        'operational_stop_after_epoch': opt.stop_after_epoch,
    }
    with open(os.path.join(save_path, f'audit_seed{seed}.json'), 'w', encoding='utf-8') as handle:
        json.dump(audit, handle, indent=2)

    writer = SummaryWriter(logdir=log_path)


    run_start = time.perf_counter()
    if torch.cuda.is_available():
        torch.cuda.reset_peak_memory_stats()

    final_epoch_this_run = args.base.n_epochs
    if opt.stop_after_epoch is not None:
        if opt.stop_after_epoch < start_epoch:
            raise ValueError('stop_after_epoch is earlier than the next epoch to run.')
        final_epoch_this_run = min(final_epoch_this_run, opt.stop_after_epoch)

    for epoch in range(start_epoch, final_epoch_this_run + 1):
        epoch_start = time.perf_counter()
        training_ret = train(model, dataLoader['train'], optimizer, loss_fn, metrics_fn)
        validation_ret = evaluate(model, dataLoader['valid'], loss_fn, metrics_fn)
        training_results_recorder.update(training_ret['results'], epoch)
        validation_results_recorder.update(validation_ret['results'], epoch)
        best_validation_results = validation_results_recorder.get_best_results()

        if validation_ret['loss_recorder'].value_avg < best_valid_loss:
            best_valid_loss = validation_ret['loss_recorder'].value_avg
            _atomic_torch_save({
                'epoch': epoch,
                'seed': seed,
                'valid_loss': best_valid_loss,
                'model': model.state_dict(),
            }, best_checkpoint)

        print(f'\n----------------- Results Epoch {epoch} -----------------')
        print(f'Learning Rate: {optimizer.state_dict()["param_groups"][0]["lr"]}')
        print(f'Training Results: {training_ret["results"]}')
        print(f'Validation Results: {validation_ret["results"]}')
        print(f'Best Validation Results across All Epochs: {best_validation_results["best_results_all_epochs"]}')
        print(f'Best Validation Results of One Epochs: {best_validation_results["best_results_one_epoch"]}\n')
        print(f'Best Valid Loss: {best_valid_loss:.8f}; checkpoint: {best_checkpoint}')
        print('----------------------------------------------------------\n')

        writer.add_scalar('train/MAE', training_ret['loss_recorder'].value_avg, epoch)
        writer.add_scalar('valid/MAE', validation_ret['loss_recorder'].value_avg, epoch)
        scheduler_warmup.step()

        checkpoint_payload = {
            'epoch': epoch,
            'seed': seed,
            'best_valid_loss': best_valid_loss,
            'model': model.state_dict(),
            'optimizer': optimizer.state_dict(),
            'scheduler': scheduler_warmup.state_dict(),
            'rng': _rng_state(),
            'training_best_one': training_results_recorder.best_results_one_epoch,
            'training_best_all': training_results_recorder.best_results_all_epochs,
            'validation_best_one': validation_results_recorder.best_results_one_epoch,
            'validation_best_all': validation_results_recorder.best_results_all_epochs,
            'config_hash': config_hash,
            'source_hash': source_hash,
            'git': git_audit,
        }
        _atomic_torch_save(checkpoint_payload, last_checkpoint)
        epoch_seconds = time.perf_counter() - epoch_start
        peak_mib = torch.cuda.max_memory_allocated() / 2**20 if torch.cuda.is_available() else 0.0
        print(f'Epoch audit: seconds={epoch_seconds:.2f}, peak_cuda_allocated_mib={peak_mib:.2f}, '
              f'last_checkpoint={last_checkpoint}')

    if opt.evaluate_test:
        checkpoint = torch.load(best_checkpoint, map_location=device, weights_only=False)
        model.load_state_dict(checkpoint['model'])
        test_loader = MMDataLoader(args, splits=('test',))['test']
        test_ret = evaluate(model, test_loader, loss_fn, metrics_fn)
        print(f'Final Test Results (explicit request, best Valid epoch {checkpoint["epoch"]}): '
              f'{test_ret["results"]}')

    # with open(f'./{args.dataset.datasetName}_results_all_epoch.txt', 'a+') as f:
    #     f.write(f'{seed}: {best_test_results["best_results_all_epochs"]}\n')
    
    # with open(f'./{args.dataset.datasetName}_results_one_epoch.txt', 'a+') as f:
    #     f.write(f'{seed}: {best_test_results["best_results_one_epoch"]}\n')

    writer.close()
    print(f'Total run seconds: {time.perf_counter() - run_start:.2f}')


def train(model, data_loader, optimizer, loss_fn, metrics_fn):
    loss_recorder = AverageMeter()

    y_pred, y_true = [], []

    model.train()
    accumulation_steps = _gradient_accumulation_steps(args)
    optimizer.zero_grad(set_to_none=True)
    for cur_iter, data in enumerate(data_loader):
        img, audio, text = data['vision'].to(device), data['audio'].to(device), data['text'].to(device)
        label = data['labels']['M'].to(device)
        label = label.view(-1, 1)
        batchsize = img.shape[0]

        output = model(img, audio, text)

        loss = loss_fn(output, label)

        loss_recorder.update(loss.item(), batchsize)

        group_start = (cur_iter // accumulation_steps) * accumulation_steps
        group_size = min(accumulation_steps, len(data_loader) - group_start)
        (loss / group_size).backward()
        if (cur_iter + 1) % accumulation_steps == 0 or (cur_iter + 1) == len(data_loader):
            optimizer.step()
            optimizer.zero_grad(set_to_none=True)

        y_pred.append(output.cpu())
        y_true.append(label.cpu())

    pred, true = torch.cat(y_pred), torch.cat(y_true)
    results = metrics_fn(pred, true)

    return {'results': results, 'loss_recorder': loss_recorder} 


def evaluate(model, data_loader, loss_fn, metrics_fn):
    loss_recorder = AverageMeter()
    y_pred, y_true = [], []

    model.eval()
    
    for cur_iter, data in enumerate(data_loader):
        img, audio, text = data['vision'].to(device), data['audio'].to(device), data['text'].to(device)
        label = data['labels']['M'].to(device)
        label = label.view(-1, 1)
        batchsize = img.shape[0]

        with torch.no_grad():
            output = model(img, audio, text)

        loss = loss_fn(output, label)

        y_pred.append(output.cpu())
        y_true.append(label.cpu())

        loss_recorder.update(loss.item(), batchsize)

    pred, true = torch.cat(y_pred), torch.cat(y_true)
    results = metrics_fn(pred, true)

    return {'results': results, 'loss_recorder': loss_recorder} 

if __name__ == '__main__':
    main()
