#!/usr/bin/env python

import pandas as pd

class HEMGroups:
    '''
    Read the HEM groups file
    This file is used to x-ref the SCCs into source groups for area sources
    '''
    def __init__(self, group_file):
        '''
        self.run_groups = {'np10m': 'NPTEN', 'nplow': 'NPLOW', 'nonroad': 'NONRD', 'rwc': 'RWC',
            'or_ld': 'LD', 'or_hd': 'HD', 'cmv_p': 'PORT', 'cmv_uw': 'UNDWY'}
        '''
        self.xref = self._read_groups(group_file)
        self.scc_list = list(self.xref['scc'].drop_duplicates())

    def _read_groups(self, group_file):
        df = pd.read_csv(group_file, dtype={'scc': '|S10', 'run_group': '|S16'}, 
          usecols=['scc','run_group','source_group'])
        return df

