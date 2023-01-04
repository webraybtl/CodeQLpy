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

# Constants
CODEQL_QLPACK = '''
name: codeql/java-tests
groups: [java, test]
dependencies:
    codeql/java-all: "*"
    codeql/java-queries: "*"
extractor: java
tests: .
'''

class Database(object):
    def __init__(self, path, temp=False):
        """
        Arguments:
        path -- Path of the database
        temp -- Remove database path in destructor
        """
        self.path = path
        self.temp = temp

    def __del__(self):
        if self.temp:
            shutil.rmtree(self.path)

    # Helpers
    def run_command(self, command, options=[], post=[]):
        run(['database', command] + options + [self.path] + post)

    @staticmethod
    def from_cpp(code, command=None):
        # Get default compiler
        compilers = ['cxx', 'clang++', 'g++', 'cc', 'clang', 'gcc']
        if command is None:
            for compiler in compilers:
                if shutil.which(compiler) is not None:
                    command = [compiler, '-c']
                    break
        # Create database
        directory = temporary_dir()
        fpath = os.path.join(directory, 'source.cpp')
        with open(fpath, 'w') as f:
            f.write(code)
        command.append(fpath)
        return Database.create('cpp', directory, command)

    def query(self, ql):
        """
        Syntactic sugar to execute a CodeQL snippet and parse the results.
        """
        # Prepare query directory
        if not hasattr(self, 'qldir'):
            # self.qldir = qlConfig("qlpath")
            self.qldir = tempfile.TemporaryDirectory(dir=qlConfig("qlpath"))
            # qlpack_path = os.path.join(self.qldir, 'qlpack.yml')
            # with open(qlpack_path, mode='w') as f:
            #     qlpack_text = CODEQL_QLPACK
            #     f.write(qlpack_text)
        # Perform query
            # print(qlpack_path, os.path.exists(qlpack_path))
        query_path = os.path.join(self.qldir.name, uuid.uuid4().hex + ".ql")
        # reply_path = os.path.join(self.qldir, 'reply.csv')
        with open(query_path, mode='w') as f:
            f.write(ql)
        query = codeql.Query(query_path)
        bqrs = query.run(database=self)
        return bqrs.parse()

    # Interface
    @staticmethod
    def create(language, source=None, command=None, location=None):
        """
        Create a CodeQL database instance for a source tree that can be analyzed
        using one of the CodeQL products.
        Arguments:
        language -- The language that the new database will be used to analyze.
        source -- The root source code directory.
            In many cases, this will be the checkout root. Files within it are
            considered to be the primary source files for this database.
            In some output formats, files will be referred to by their relative path
            from this directory.
        command -- For compiled languages, build commands that will cause the
            compiler to be invoked on the source code to analyze. These commands
            will be executed under an instrumentation environment that allows
            analysis of generated code and (in some cases) standard libraries.
        database -- Path to generated database
        """
        # Syntactic sugar: Default location to temporary directory
        if location is None:
            location = temporary_dir()

        # Create and submit command
        if source is not None:
            args = ['database', 'create', '-l', language, '-s', source]
        else:
            args = ['database', 'create', '-l', language]
        if command is not None:
            if type(command) == list:
                command = ' '.join(map(lambda x: f'"{x}"' if ' ' in x else x, command))
            args += ['-c', '"' + command + '"']
        args.append(location)

        if os.path.exists(location):
            args.append("--overwrite")

        run(args)

        # Return database instance
        return Database(location)


    def analyze(self, queries, format, output):
        """
        Analyze a database, producing meaningful results in the context of the
        source code.
        Run a query suite (or some individual queries) against a CodeQL
        database, producing results, styled as alerts or paths, in SARIF or
        another interpreted format.
        This command combines the effect of the codeql database run-queries
        and codeql database interpret-results commands. If you want to run
        queries whose results don't meet the requirements for being interpreted
        as source-code alerts, use codeql database run-queries or codeql query
        run instead, and then codeql bqrs decode to convert the raw results to a
        readable notation.
        """
        # Support single query or list of queries
        if type(queries) is not list:
            queries = [queries]
        # Prepare options
        options = [f'--format={format}', '-o', output]
        if search_path is not None:
            options += ['--search-path', search_path]
        # Dispatch command
        self.run_command('analyze', options, post=queries)
    
    def upgrade(self):
        """
        Upgrade a database so it is usable by the current tools.
        This rewrites a CodeQL database to be compatible with the QL libraries
        that are found on the QL pack search path, if necessary.
        If an upgrade is necessary, it is irreversible. The database will
        subsequently be unusable with the libraries that were current when it
        was created.
        """
        self.run_command('upgrade')

    def cleanup(self):
        """
        Compact a CodeQL database on disk.
        Delete temporary data, and generally make a database as small as
        possible on disk without degrading its future usefulness.
        """
        self.run_command('cleanup')

    def bundle(self, output):
        """
        Create a relocatable archive of a CodeQL database.
        A command that zips up the useful parts of the database. This will only
        include the mandatory components, unless the user specifically requests
        that results, logs, TRAP, or similar should be included.
        """
        options = ['-o', output]
        self.run_command('bundle', options)