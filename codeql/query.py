#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
CodeQL for Python.
"""

import os
import shutil
import tempfile

import codeql
from .common import *
from utils.option import qlConfig

class Query(object):
    def __init__(self, path):
        """
        Arguments:
        path -- Location of the query file
        """
        # Temporaries will be cleaned up on destructor
        self.path = path

    # Helpers
    def run_command(self, command, options=[], post=[]):
        run(['query', command] + options + [self.path] + post)

    @staticmethod
    def from_source(code):
        path = temporary_file(suffix='.ql')
        with open(path, mode='w') as f:
            f.write(code)
        return Query(path)

    @staticmethod
    def from_file(path):
        return Query(path)

    # Interface
    def compile(self):
        """
        Compile or check QL code.
        Compile one or more queries. Usually the main outcome of this command is that the compiled version of the query is written
        to a compilation cache where it will be found when the query is later executed. Other output options are mostly for
        debugging.
        """
        self.run('compile')

    def run(self, database, output=None):
        """
        Run a single query.
        This command runs single query against a CodeQL database or raw QL dataset.
        By default the result of the query will be displayed on the terminal in a human-friendly rendering. If you want to do
        further processing of the results, we strongly recommend using the --output option to write the results to a file in an
        intermediate binary format, which can then be unpacked into various more machine-friendly representations by codeql
        bqrs decode.
        If your query produces results in a form that can be interpreted as source-code alerts, you may find codeql database
        analyze a more convenient way to run it. In particular, codeql database analyze can produce output in the SARIF format,
        which can be used with an variety of alert viewers.
        """
        # Return temporary results if no output is specified
        # qldir = tempfile.TemporaryDirectory(dir=qlConfig("qlpath"))
        # output = os.path.join(qldir.name, uuid.uuid4().hex + ".bqrs")
        # if not os.path.exists(output):
        #     with open(output, 'w') as w:
        #         w.write("");
        output = os.path.join(qlConfig('qlpath'), "query.bqrs")
        # Obtain actual path to database
        if type(database) == codeql.Database:
            database = database.path
        # Perform query and return results
        options = ['-o', output, '-d', database]
        self.run_command('run', options)
        return codeql.BQRS(output)