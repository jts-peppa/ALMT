'''
* @name: dataset.py
* @description: Dataset loading functions. Note: The code source references MMSA (https://github.com/thuiar/MMSA/tree/master).
'''


import pickle
import numpy as np
import torch
from torch.utils.data import Dataset, DataLoader

class MMDataset(Dataset):
    def __init__(self, args, mode='train'):
        self.mode = mode
        self.args = args.dataset
        DATA_MAP = {
            'mosi': self.__init_mosi,
            'mosei': self.__init_mosei,
            'sims': self.__init_sims
        }
        DATA_MAP[self.args.datasetName]()

    def __init_mosi(self):
        with open(self.args.dataPath, 'rb') as f:
            data = pickle.load(f)

        self.text = data[self.mode]['text_bert'].astype(np.float32)
        self.vision = data[self.mode]['vision'].astype(np.float32)
        self.audio = data[self.mode]['audio'].astype(np.float32)

        print(f'----------------- {self.args.datasetName} {self.mode} -----------------')
        print(f'Language shape: {self.text.shape}')
        print(f'Vision shape: {self.vision.shape}')
        print(f'Audio shape: {self.audio.shape}')
        print('-------------------------------------------------------------------------')

        self.rawText = data[self.mode]['raw_text']
        self.ids = data[self.mode]['id']
        self.labels = {
            'M': data[self.mode][self.args.train_mode+'_labels'].astype(np.float32)
        }
        if self.args.datasetName == 'sims':
            for m in "TAV":
                self.labels[m] = data[self.mode][self.args.train_mode+'_labels_'+m]

        self.audio[self.audio == -np.inf] = 0

    def __init_mosei(self):
        return self.__init_mosi()

    def __init_sims(self):
        return self.__init_mosi()

    def __len__(self):
        return len(self.labels['M'])

    def __getitem__(self, index):
        sample = {
            'raw_text': self.rawText[index],
            'text': torch.Tensor(self.text[index]), 
            'audio': torch.Tensor(self.audio[index]),
            'vision': torch.Tensor(self.vision[index]),
            'index': index,
            'id': self.ids[index],
            'labels': {k: torch.Tensor(v[index].reshape(-1)) for k, v in self.labels.items()}
        } 
        return sample


def MMDataLoader(args, splits=('train', 'valid')):
    """Build only explicitly requested data splits.

    Keeping ``test`` out of the default is intentional: training and model
    selection must not deserialize a test Dataset or expose a test DataLoader.
    """
    valid_splits = {'train', 'valid', 'test'}
    unknown = set(splits) - valid_splits
    if unknown:
        raise ValueError(f'Unknown dataset splits: {sorted(unknown)}')
    datasets = {split: MMDataset(args, mode=split) for split in splits}

    dataLoader = {
        ds: DataLoader(datasets[ds],
                       batch_size=args.base.batch_size,
                       num_workers=args.base.num_workers,
                       shuffle=True if ds == 'train' else False)
        for ds in datasets.keys()
    }
    
    print(f'DataLoader splits created: {list(dataLoader.keys())}')
    return dataLoader
