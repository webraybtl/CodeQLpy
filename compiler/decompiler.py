#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import sys,time,re
from concurrent.futures import ThreadPoolExecutor as Pool

from utils.option       import qlConfig
from utils.log          import log
from utils.functions    import execJar

def checkTool(toolpath):
    if not os.path.isfile(toolpath) or not toolpath.endswith(".jar"):
        log.error("Tool Error")
        return False
    else:
        return True

# 对class源码进行反编译
def javaDecompile(filepath, save_dir):
    # 使用idea的java-decompiler.jar对代码进行反编译
    if qlConfig("decompile_type") == "idea":
        toolpath=qlConfig("idea_decode_tool")
        if not checkTool(toolpath):
            return False

        if not os.path.isdir(save_dir):
            os.makedirs(save_dir)
        # decompile_dir = qlConfig("decode_savedir")
        args = f" -cp {toolpath} org.jetbrains.java.decompiler.main.decompiler.ConsoleDecompiler -dgs=true {filepath} {save_dir}"
        execJar(args, 11)

    # 使用jd-cli.jar对代码进行反编译（默认）
    else:
        toolpath=qlConfig("jd_decode_tool")
        if not checkTool(toolpath):
            return False

        if not os.path.isdir(save_dir):
            os.makedirs(save_dir)
        print("decoding {}...".format(filepath))
        args = f" -jar {toolpath} --outputDir {save_dir} {filepath}"
        execJar(args, 11)


# 对jsp文件进行反编译
def jspDecompile(filepath, webroot, number):
    toolpath=qlConfig("jsp_decode_tool")
    if not checkTool(toolpath):
        return False

    decompile_dir = qlConfig("decode_savedir")
    filepath = str(filepath)
    filename = filepath[len(webroot):]
    print("processing {}".format(number))
    webroot = webroot.replace("\\", "\\\\")
    args = f" -jar {toolpath} \"{webroot}\" \"{filename}\" {decompile_dir}"
    execJar(args, 11)


def jspDecompileFiles(files, webroot):
    pool = Pool(max_workers=int(qlConfig("thread_num")))
    number = 1
    futures = []
    for filepath in files:
        percent = "{}/{}".format(number, len(files))
        future = pool.submit(jspDecompile, filepath, webroot, percent, )
        
        futures.append(future)
        number += 1
    pool.shutdown(wait=True)
    