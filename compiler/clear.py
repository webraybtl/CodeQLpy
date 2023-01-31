#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import re
from utils.functions        import *

# 部分源码在反编译之后会出现package包名不正确的情况进行修复
def clearPackage(target_dir):
    error_packages = {
        b"package BOOT-INF.classes.": b"package ",
        b"package WEB-INF.classes.": b"package ",
        b"package WEB-INF.classes;": b"",
        b"package BOOT-INF.classes;": b"",
        b"package src.main.java.": b"package ",
    }
    for java_file in getFilesFromPath(target_dir, "java"):
        error_flag = False
        content = ""
        with open(java_file, 'rb') as r:
            content = r.read()
            for error_package in error_packages.keys():
                if error_package in content:
                    content = content.replace(error_package, error_packages[error_package])
                    error_flag = True
        if error_flag:
            with open(java_file, 'wb') as w:
                w.write(content)

# 修复部分反编译之后的字段名称无初始化定义，eg:LineInputStream lineInputStream;
def repairNoneDeclare(target_dir):
    for java_file in getFilesFromPath(target_dir, "java"):
        error_flag = False
        content = ""
        with open(java_file, 'rb') as r:
            content = r.read()
            imports = re.compile(rb"import (?:\w+\.)+(\w+)").findall(content)
            for delaration in re.compile(rb'\s*(\w+)\s+\w+\s*;').findall(content):
                black_list = ['return', 'int', 'char', 'boolean', 'String', 'throw', 'float', ]
                if delaration != "" and delaration not in black_list and delaration in imports:
                    content = re.compile(b'(\\s*' + delaration + b'\\s+\\w+\\s*);').sub(rb'\1' + b' = null;', content)
                    error_flag = True
        
        if error_flag:
            with open(java_file, 'wb') as w:
                w.write(content)

# 修复编码问题导致的编译异常
def clearCodingError(target_dir):
    pass

def clearTLD(target_dir):
    # 老版本的代码中出现的tld引用在新版中不支持，需要去除tld引入
    # <%@ taglib uri="/WEB-INF/tags/convert.tld" prefix="f"%>
    for jsp_file in getFilesFromPath(target_dir, "jsp"):
        error_flag = False
        content = ""
        with open(jsp_file, 'rb') as r:
            content = r.read()
            for prefix in re.compile(rb'''<%@\s+taglib.*?uri=\".*?\.tld\".*?prefix=\"(.*?)\".*?%>''').findall(content):
                content = content.replace(prefix + b":", b"")

            if re.compile(rb'''<%@\s+taglib.*?uri=\".*?\.tld\".*?%>''').findall(content):
                content = re.compile(rb'''<%@\s+taglib.*?uri=\".*?\.tld\".*?%>''').sub(b"", content)
                error_flag = True

        if error_flag:
            with open(jsp_file, 'wb') as w:
                w.write(content)

        
def clearJava(target_dir):
    clearPackage(target_dir)
    repairNoneDeclare(target_dir)

def clearSource(target_dir):
    clearTLD(target_dir)
    pass

