#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
CodeQL for Python.
"""

import io
import os
import platform
import subprocess
import tempfile
import uuid

from utils.option import qlConfig
from utils.log    import log

# Configuration
codeql_path = 'codeql'
search_path = None
library_path = None

# Temporaries
temp_path = tempfile.TemporaryDirectory(dir=qlConfig("qlpath"))

def temporary_root():
    global temp_path
    if temp_path is None:
        temp_path = tempfile.TemporaryDirectory(prefix="codeql-python_")
    return temp_path.name

def temporary_path(prefix, suffix):
    name = ''
    if prefix:
        name += prefix
    name += uuid.uuid4().hex
    if suffix:
        name += suffix
    return os.path.join(temporary_root(), name)

def temporary_dir(create=True, prefix=None, suffix=None):
    path = temporary_path(prefix, suffix)
    if create:
        os.makedirs(str(path))

    return path

def temporary_file(create=True, prefix=None, suffix=None):
    path = temporary_path(prefix, suffix)
    if create:
        open(path, 'a').close()
    return path

# Environment
def set_search_path(path):
    global search_path
    if type(path) == list:
        separator = ';' if os.name == 'nt' else ':'
        path = separator.join(path)
    search_path = path

def run(args):
    command = [codeql_path] + list(map(str, args))
    encoding = "utf-8"
    if platform.system() == "Darwin":
        command = ["arch -x86_64"] + command
    if platform.system() == "Windows":
        encoding = "gbk"
    # log.info(" ".join(command))
    proc = subprocess.Popen(" ".join(command), shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, bufsize=-1)
    proc.wait()
    stream_stdout = io.TextIOWrapper(proc.stdout, encoding=encoding)
    stream_stderr = io.TextIOWrapper(proc.stderr, encoding=encoding)
    str_stdout = stream_stdout.read()

    if qlConfig("debug").lower() == "on":
        str_stderr = stream_stderr.read()
        log.warning(str_stderr)
    
    return str_stdout

    # return subprocess.run(command, stdout=subprocess.DEVNULL)
