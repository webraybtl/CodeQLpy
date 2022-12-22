#!/usr/bin/env python3
# -*- coding: utf-8 -*-

from utils.functions        import *


def clearPackage(target_dir):
    # 部分源码在反编译之后会出现package包名不正确的情况进行修复
    error_packages = {
        "package BOOT-INF.classes.": "package ",
        "package WEB-INF.classes.": "package ",
        "package WEB-INF.classes;": "",
        "package BOOT-INF.classes;": "",
        "package src.main.java.": "package ",
    }
    for java_file in getFilesFromPath(target_dir, "java"):
        error_flag = False
        content = ""
        with open(java_file, 'r') as r:
            content = r.read()
            for error_package in error_packages.keys():
                if error_package in content:
                    content = content.replace(error_package, error_packages[error_package])
                    error_flag = True
        if error_flag:
            with open(java_file, 'w') as w:
                w.write(content)

        
def clearJava(target_dir):
    clearPackage(target_dir)

