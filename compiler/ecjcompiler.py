#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import re
import sys
import pathlib
import platform
from copy import deepcopy

from utils.option       import qlConfig
from utils.functions    import *

# 过滤一些开源的框架代码，这些代码对于代码审计是无用的
def filterPackage(java_path):
    black_packages = ["springframework.", "java.lang", "javax."]
    java_path = str(java_path)
    java_classpath = java_path.replace("/", ".")
    for black_package in black_packages:
        if black_package in java_classpath:
            return False
    return True

# 为了提高效率，只对包含白名单的类进行编译，白名单一般是WEB文件
def filterJava(java_path):
    whilte_javas = [b"@Controller", b"@RequestMapping", b"@ResponseBody", b"@WebFilter", b"@RestController", b"@GetMapping", \
    b"@PostMapping", b"HttpServlet", b"ServletRequest",] 
    if not os.path.isfile(java_path):
        return False
    with open(java_path, 'rb') as r:
        content = r.read()
        for whilte_java in whilte_javas:
            if whilte_java in content:
                return True
    return False
# 如果路径中包含特殊字符会导致整个编译失败
def filterJavaPath(java_path):
    black_words = [" "]
    java_path = str(java_path)
    for black_word in black_words:
        if black_word in java_path:
            return False
    return True

# 某些特殊的类文件会导致编译异常
# 1、内部类
# 2、抽象类
def filterClass(java_path):
    if not os.path.isfile(java_path):
        return False
    with open(java_path, 'rb') as r:
        content = r.read()
        if content.count(b" class ") >= 2 or b" abstract class " in content:
            return False
    return True

# 对源码中依赖的jar包进行判断，自动识别可能缺少的包
def autoCheckJar():
    class_path = os.path.join(qlConfig("decode_savedir"), "classes")
    jar_path = os.path.join(qlConfig("decode_savedir"), "lib")
    has_springmvc_flag = False
    has_common_flag = False
    has_jdk_flag = True
    has_tomcat_falg = True
    for java_file in getFilesFromPath(class_path, "java"):
        with open(java_file, 'rb') as r:
            content = r.read()
            if b"org.apache.commons." in content:
                has_common_flag = True
            if b"org.springframework." in content:
                has_springmvc_flag = True
        if has_springmvc_flag and has_common_flag:
            break
    for jar_file in dirFiles(jar_path):
        if jar_file.lower().startswith("spring-"):
            has_springmvc_flag = False
        if jar_file.lower().startswith("commons-"):
            has_common_flag = False
        if "charsets.jar" == jar_file.lower():
            has_jdk_flag = False
        if jar_file.lower().startswith("tomcat-"):
            has_tomcat_falg = False

    return has_springmvc_flag, has_common_flag, has_jdk_flag, has_tomcat_falg


# 生成最终在codeql中使用的编译命令
def generate(command, save_path):
    cmd_path = ""
    save_path = os.path.abspath(save_path)
    if platform.system() == "Darwin" or platform.system() == "Linux":
        cmd_path = "{}/run.sh".format(save_path)
        with open(cmd_path, "w+") as f:
            f.write(command)
        execute("chmod +x {}".format(cmd_path))
        return  "/bin/bash -c " + cmd_path

    if platform.system() == "Windows":
        cmd_path = "{}/run.cmd".format(save_path)
        with open(cmd_path, "w+") as f:
            f.write("@echo off\r\n")
            f.write(command)
        return cmd_path

    log.error("Unknown System.")
    return False

# 从给出的源码中找到源码路径，一般是src/main/java
def getSourcePath(source_path):
    java_files = getFilesFromPath(source_path, "java")
    for java_file in java_files:
        with open(java_file, 'rb') as r:
            content = r.read()
            for packname in re.compile(rb"package\s+([a-zA-Z0-9._\-]+);").findall(content):
                java_file = str(java_file)
                if platform.system() == "Windows":
                    pack_loc = java_file.index(packname.replace(b".", b"\\").decode("utf-8"))
                else:
                    pack_loc = java_file.index(packname.replace(b".", b"/").decode("utf-8"))
                return java_file[:pack_loc]

    return source_path
    

# 对源码进行编译整理，得到源码编译的命令
def ecjcompile(save_path, source_path):
    ecj_path = qlConfig("ecj_tool")
    save_path = os.path.abspath(save_path)
    # 提取代码中所有的.java文件，后续会对.java文件进行编译
    with open("{}/file.txt".format(save_path), "w+") as f:
        for java_path in pathlib.Path(save_path).glob('**/*.java'):
            if filterPackage(java_path):
                f.write(str(java_path) + "\n")

    # 提取所有jar包文件对应的目录
    jar_libs = dirFiles(os.path.join(save_path, "lib"))

    if len(jar_libs) > 0:
        jar_args = " -extdirs " + os.path.join(save_path, "lib")
    else:
        jar_args = ""

    # 从source_path中提取出源码所在路径
    source_java_path = getSourcePath(source_path)

    ecj_absolute_path = pathlib.Path(ecj_path).resolve()
    compile_cmd = qlConfig("jdk8") + " -jar {} {} -encoding UTF-8 -8 " \
                  "-warn:none  -sourcepath {} -proceedOnError -noExit @{}/file.txt".format(ecj_absolute_path, jar_args, source_java_path, save_path)

    return compile_cmd

# 对反编译的源码进行整理，得到编译的命令
def ecjcompileE(save_path, target_version):
    ecj_path = qlConfig("ecj_tool")
    save_path = os.path.abspath(save_path)
    # 提取代码中所有的.java文件，后续会对.java文件进行编译
    # 优先处理jsp文件反编译的.java文件
    all_java_files = []
    with open("{}/file.txt".format(save_path), "w+") as f:
        for java_path in pathlib.Path(save_path).glob('classes/**/*.java'):
            if filterPackage(java_path) and filterClass(java_path):
                if filterJava(java_path):
                    if java_path not in all_java_files and filterJavaPath(java_path):
                        f.write(str(java_path) + "\n")
                        all_java_files.append(java_path)

        if os.path.isdir(os.path.join(save_path, "org/apache/jsp")):
            for java_path in pathlib.Path(os.path.join(save_path, "org/apache/jsp")).glob('**/*.java'):
                # if filterPackage(java_path) and filterClass(java_path):
                if filterPackage(java_path):
                    if filterJava(java_path) and java_path not in all_java_files and filterJavaPath(java_path):
                        f.write(str(java_path) + "\n")
                        all_java_files.append(java_path)

        for java_path in pathlib.Path(save_path).glob('classes/**/*.java'):
            if filterPackage(java_path) and filterClass(java_path):
                # if filterJava(java_path) and java_path not in all_java_files:
                if java_path not in all_java_files and filterJavaPath(java_path):
                    f.write(str(java_path) + "\n")
                    all_java_files.append(java_path)

    jar_args = " "
    jar_path = []
    if os.path.isdir(os.path.join(save_path, "lib")):
        jar_path.append(os.path.join(save_path, "lib"))

    has_springmvc_flag, has_common_flag,has_jdk_flag, has_tomcat_falg = autoCheckJar()
    if has_springmvc_flag: jar_path.append("lib/spring_mvc_lib")
    if has_common_flag: jar_path.append("lib/common_lib")
    if has_jdk_flag: jar_path.append("lib/java{}_lib".format(target_version))
    if has_tomcat_falg: jar_path.append("lib/tomcat_lib")

    if len(jar_path) > 0:
        if platform.system() == "Windows":
            split_quote = ";"
        else:
            split_quote = ":"
        jar_args += " -extdirs \"{}\"".format(split_quote.join(jar_path))

    if os.path.isdir(os.path.join(save_path, "classes")):
        jar_args += " -sourcepath " + os.path.join(save_path, "classes")

    ecj_absolute_path = pathlib.Path(ecj_path).resolve()
    compile_cmd = qlConfig("jdk8") + " -jar {} {} -encoding UTF-8 -8 " \
                  "-warn:none -proceedOnError -noExit @{}/file.txt".format(ecj_absolute_path, jar_args, save_path)

    return compile_cmd

# 对反编译的源码进行整理，得到编译的命令
def ecjcompileS(save_path):
    ecj_path = qlConfig("ecj_tool")
    save_path = os.path.abspath(save_path)
    # 提取代码中所有的.java文件，后续会对.java文件进行编译
    with open("{}/file.txt".format(save_path), "w+") as f:
        for java_path in pathlib.Path(save_path).glob('**/*.java'):
            if filterPackage(java_path) and filterJava(java_path):
                f.write(str(java_path) + "\n")

    jar_args = " "
    if os.path.isdir(os.path.join(save_path, "lib")):
        jar_args += " -extdirs " + os.path.join(save_path, "lib")

    if os.path.isdir(os.path.join(save_path, "classes")):
        jar_args += " -sourcepath " + os.path.join(save_path, "classes")

    ecj_absolute_path = pathlib.Path(ecj_path).resolve()
    compile_cmd = ""
    compile_list = []
    with open("{}/file.txt".format(save_path), 'r') as r:
        while True:
            line = r.readline().strip()
            if line == "":
                break
            
            if qlConfig("model") == "fast":
                filedir = os.path.dirname(line)
                if filedir not in compile_list:
                    flag = True
                    for compile_dir in deepcopy(compile_list):
                        if compile_dir == filedir:
                            flag = False
                            break
                        if compile_dir in filedir:
                            flag = False
                            break
                        if filedir in compile_dir:
                            flag = True
                            compile_list.remove(compile_dir)
                            break

                    if flag:
                        compile_list.append(filedir)
      
            else:
                if line not in compile_list:
                    compile_list.append(line)

    for compile_file in compile_list:
        compile_cmd += qlConfig("jdk8") + " -jar {} {} -encoding UTF-8 -8 " \
                "-warn:none -proceedOnError -noExit {}\r\n".format(ecj_absolute_path, jar_args, compile_file)

    return compile_cmd



