#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
CodeQL for Python.
"""

import csv
import io
import os
import shutil
import tempfile

from .common import *

class BQRS(object):
    def __init__(self, path):
        """
        Arguments:
        path -- Location of the query results file
        """
        # Temporaries will be cleaned up on destructor
        self.path = path

    # Helpers
    def run_command(self, command, options=[], post=[]):
        return run(['bqrs', command] + options + [self.path])

    def parse(self):
        path = temporary_file(suffix='.csv')
        self.decode(format='csv', output=path)
        with open(path, 'r') as f:
            return list(csv.reader(f, delimiter=','))

    # Interface
    def info(self, format):
        """
        Display metadata for a BQRS file.
        This command displays an overview of the data contained in the compact binary BQRS file that is the result of executing a
        query. It shows the names and sizes of each result set (table) in the BQRS file, and the column types of each result set.
        It can also optionally precompute offsets for using the pagination options of codeql bqrs decode. This is mainly useful
        for IDE plugins.
        """
        options = ['-v']
        self.run_command('info', options)

    def decode(self, format=None, output=None):
        """
        Convert result data from BQRS into other forms.
        The decoded output will be written to standard output, unless the --output option is specified.
        """
        options = []
        if format:
            options += [f'--format={format:s}']
        if output:
            options += ['-o', output]
        self.run_command('decode', options)

    def diff(self, other):
        """
        Compute the difference between two result sets.
        """
        if type(other) == BQRS:
            other = other.path
        self.run_command('diff', post=[other])