#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import time
import os,re,random
from utils.functions        import *

# 部分源码在反编译之后会出现package包名不正确的情况进行修复
def clearPackage(java_files):
    error_packages = {
        b"package BOOT-INF.classes.": b"package ",
        b"package WEB-INF.classes.": b"package ",
        b"package WEB-INF.classes;": b"",
        b"package BOOT-INF.classes;": b"",
        b"package src.main.java.": b"package ",
    }
    for java_file in java_files:
        if not os.path.isfile(java_file):
            continue
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
def repairNoneDeclare(java_files):
    for java_file in java_files:
        # java_file = java_files
        if not os.path.isfile(java_file):
            continue
        error_flag = False
        content = ""
        with open(java_file, 'rb') as r:
            content = r.read()
            imports = re.compile(rb"import (?:\w+\.)+(\w+)").findall(content)
            for delaration in re.compile(rb'\s*(\w+)\s+\w+\s*;').findall(content):
                black_list = ['return', 'int', 'char', 'boolean', 'String', 'throw', 'float', 'byte', ]
                if delaration != "" and delaration not in black_list and delaration in imports:
                    content = re.compile(b'(\\s*' + delaration + b'\\s+\\w+\\s*);').sub(rb'\1' + b' = null;', content)
                    error_flag = True
            for delaration in re.compile(rb'\s*(\w+)\[\]\s+\w+\s*;').findall(content):
                black_list = ['return', 'int', 'char', 'boolean', 'String', 'throw', 'float', 'byte', ]
                if delaration != "" and delaration not in black_list and delaration in imports:
                    content = re.compile(b'(\\s*' + delaration + b'\\[\\]\\s+\\w+\\s*);').sub(rb'\1' + b' = null;', content)
                    error_flag = True
        
        if error_flag:
            with open(java_file, 'wb') as w:
                w.write(content)

# 修复混淆代码中方法和属性为关键字的情况
def repairKeyPrivateFunction(java_files):
    java_keys = b"abstract,assert,boolean,break,byte,case,catch,char,class,const,continue,\
    default,do,double,else,enum,extends,final,finally,float,for,goto,if,implements,import,\
    instanceof,int,interface,long,native,new,package,private,protected,public,return,strictfp,\
    short,static,super,switch,synchronized,this,throw,throws,transient,try,void,volatile,while"
    for java_file in java_files:
        if not os.path.isfile(java_file):
            continue
        error_flag = False
        content = ""
        with open(java_file, 'rb') as r:
            content = r.read()
            # 替换方法名
            for private_function_name in re.compile(rb"(?:public|private|protected) (?:static )?\w+ (\w+)\(").findall(content):
                if private_function_name in java_keys.split(b","):
                    ori_str = private_function_name + b"("
                    rep_str = private_function_name + str(random.randint(1000,9999)).encode() + b"("
                    content = content.replace(ori_str, rep_str)
                    error_flag = True
            # 替换属性名
            for private_attribute_name in re.compile(rb"(?:public|private|protected) (?:static )?(?:final )?\w+(?:\[\])* (\w+) = ").findall(content):
                if private_attribute_name in java_keys.split(b","):
                    rand_num = str(random.randint(1000,9999)).encode()
                    if b" " + private_attribute_name + b" = " in content:
                        ori_str = b" " + private_attribute_name + b" = "
                        rep_str = b" " + private_attribute_name + rand_num + b" = "
                        content = content.replace(ori_str, rep_str)
                        error_flag = True

                    if  b"this." + private_attribute_name in content:
                        content = re.compile(rb"this\." + private_attribute_name + rb"(\W)").sub(rb'this.' + private_attribute_name + rand_num + rb'\1', content)
                        error_flag = True

                    if not private_attribute_name in b"byte,int,long,short,float".split(b","):
                        if re.compile(rb"\W" + private_attribute_name + rb'(?:\.|\(|\[\w|;|\+|\-| )').findall(content):
                            content = re.compile(rb"(\W)" + private_attribute_name + rb'(\.|\(|\[\w|;|\+|\-| )').sub(rb'\1' + private_attribute_name + rand_num + rb'\2', content)
                            error_flag = True
                    else:
                        if re.compile(rb"\W" + private_attribute_name + rb'(?:\.|\(|;|\+|\-)').findall(content):
                            content = re.compile(rb"(\W)" + private_attribute_name + rb'(\.|\(|;|\+|\-)').sub(rb'\1' + private_attribute_name + rand_num + rb'\2', content)
                            error_flag = True

                    if re.compile(rb"\w+\." + private_attribute_name + rb"\W+").search(content):
                        content = re.compile(rb"(\w+\.)" + private_attribute_name + rb'(\W+)').sub(rb'\1' + private_attribute_name + rand_num + rb'\2', content)
                        error_flag = True

            # 替换变量名
            for variable_name in re.compile(rb" [a-zA-Z0-9]+ (\w+) = ").findall(content):
                if variable_name in java_keys.split(b","):
                    rand_num = str(random.randint(1000,9999)).encode()
                    if b" " + variable_name + b" = " in content:
                        ori_str = b" " + variable_name + b" = "
                        rep_str = b" " + variable_name + rand_num + b" = " 
                        content = content.replace(ori_str, rep_str)
                        error_flag = True
                    
                    if  b"this." + variable_name in content:
                        content = re.compile(rb"this\." + variable_name + rb"(\W)").sub(rb'this.' + variable_name + rand_num + rb'\1', content)
                        error_flag = True

                    if not variable_name in b"byte,int,long,short,float".split(b","):
                        if re.compile(rb"\W" + variable_name + rb'(?:\.|\(|\[\w|;|\+|\-| )').findall(content):
                            content = re.compile(rb"(\W)" + variable_name + rb'(\.|\(|\[\w|;|\+|\-| )').sub(rb'\1' + variable_name + rand_num + rb'\2', content)
                            error_flag = True
                    else:
                        if re.compile(rb"\W" + variable_name + rb'(?:\.|\(|;|\+|\-)').findall(content):
                            content = re.compile(rb"(\W)" + variable_name + rb'(\.|\(|;|\+|\-)').sub(rb'\1' + variable_name + rand_num + rb'\2', content)
                            error_flag = True

                    if re.compile(rb"\w+\." + variable_name + rb"\W+").search(content):
                        content = re.compile(rb"(\w+\.)" + variable_name + rb'(\W+)').sub(rb'\1' + variable_name + rand_num + rb'\2', content)
                        error_flag = True
        
        if error_flag:
            with open(java_file, 'wb') as w:
                w.write(content)

# 部分代码在反编译之后会出现相同类名的情况
def clearDuplicateClass(java_files):
    for java_file in java_files:
        if not os.path.isfile(java_file):
            continue
        error_flag = False
        content = ""
        with open(java_file, 'rb') as r:
            content = r.read()
            while True:
                classes = []
                flag = False
                for child_class in re.compile(rb"((?: +)(?:public|private|protected) (?:static )?class (\w+) )").findall(content):
                    if child_class[0] not in classes:
                        classes.append(child_class[0])
                    else:
                        rand_num = str(random.randint(1000,9999)).encode()
                        new_child_class = child_class[0].replace(child_class[1], child_class[1] + rand_num)
                        content = content.replace(child_class[0], new_child_class, 1)
                        flag = True
                        error_flag = True
                        break

                if not flag:
                    break
        if error_flag:
            with open(java_file, 'wb') as w:
                w.write(content)

# 修复重复定义字段
def clearDuplicateDeclare(java_files):
    for java_file in java_files:
        if not os.path.isfile(java_file):
            continue
        error_flag = False
        content = ""
        with open(java_file, 'rb') as r:
            content = r.read()
            if re.compile(rb" (\w+) = \1;").search(content):
                error_flag = True
                content = re.compile(rb"(, (\w+) = \2;)").sub(rb' ;',content)
        if error_flag:
            with open(java_file, 'wb') as w:
                w.write(content)

# 修复final字段重复定义
def repairFinalField(java_files):
    for java_file in java_files:
        if not os.path.isfile(java_file):
            continue
        error_flag = False
        content = ""

        with open(java_file, 'rb') as r:
            content = r.read()
            for t in re.compile(rb"(?:private|public|protected) final \w+ (\w+) = ").findall(content):
                if b"this." + t + b" = " in content:
                    content = re.compile(rb"(private|public|protected) final (\w+) (\w+) = ").sub(rb"\1 \2 \3 = ",content)
                    error_flag = True

        if error_flag:
            with open(java_file, 'wb') as w:
                w.write(content)

# 修复变量名是null的错误
def repairNoneVariable(java_files):
    for java_file in java_files:
        if not os.path.isfile(java_file):
            continue
        error_flag = False
        content = ""

        with open(java_file, 'rb') as r:
            content = r.read()
            if re.compile(rb"\s+\w+ null = ").search(content):
                rand_num = str(random.randint(1000,9999)).encode()
                content = re.compile(rb"(\s+\w+ )null = ").sub(rb"\1" + b"null" + rand_num + b" = ", content)
                error_flag = True

        if error_flag:
            with open(java_file, 'wb') as w:
                w.write(content)

# 修复引入相同类名的bug
def clearDuplicateImport(java_files):
    for java_file in java_files:
        if not os.path.isfile(java_file):
            continue
        error_flag = False
        content = ""

        with open(java_file, 'rb') as r:
            content = r.read()
            import_names = []
            import_packages = []
            for imp in re.compile(rb"(\bimport (?:\w+\.)+([\w\*]+);)").findall(content):
                if imp[1] == b"*" and imp[0] not in import_packages:
                    import_packages.append(imp[0])
                elif imp[1] != b"*" and imp[1] not in import_names and imp[0] not in import_packages:
                    import_names.append(imp[1])
                    import_packages.append(imp[0])
                else:
                    error_flag = True
            if error_flag and len(import_packages) > 0:
                imports = b"\n".join(import_packages)
                content = re.compile(rb"(\bimport (?:\w+\.)+([\w\*]+);\s+)+").sub(imports + b"\n\n", content)
                with open(java_file, 'wb') as w:
                    w.write(content)

# 修复编码问题导致的编译异常
def clearCodingError(target_dir):
    pass

def clearTLD(target_dir):
    # 老版本的代码中出现的tld引用在新版中不支持，需要去除tld引入
    # <%@ taglib uri="/WEB-INF/tags/convert.tld" prefix="f"%>
    for jsp_file in getFilesFromPath(target_dir, "jsp"):
        if not os.path.isfile(jsp_file):
            continue
        error_flag = False
        content = ""
        with open(jsp_file, 'rb') as r:
            content = r.read()
            for prefix in re.compile(rb'''(?:<%@\s*taglib.*?(?:uri|tagdir)=\".*?\".*?prefix=\"(.*?)\".*?%>|<%@\s*taglib.*?prefix=\"(.*?)\".*?(?:uri|tagdir)=\".*?\".*?%>)''').findall(content):
                prefix = prefix[1] if prefix[0] == b"" else prefix[0]
                content = content.replace(prefix + b":", b"")

            if re.compile(rb'''<%@\s*taglib.*?(?:uri|tagdir)=\".*?\".*?%>''').search(content):
                content = re.compile(rb'''<%@\s*taglib.*?(?:uri|tagdir)=\".*?\".*?%>''').sub(b"", content)
                error_flag = True

        if error_flag:
            with open(jsp_file, 'wb') as w:
                w.write(content)

        
def clearJava(target_files):
    clearPackage(target_files)
    clearDuplicateClass(target_files)
    clearDuplicateDeclare(target_files)
    clearDuplicateImport(target_files)
    # repairNoneDeclare(target_files)
    repairKeyPrivateFunction(target_files)
    repairFinalField(target_files)
    repairNoneVariable(target_files)


def clearSource(target_dir):
    clearTLD(target_dir)
    pass

