#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import re

from utils.log              import log
from utils.option           import qlConfig
from utils.functions        import *

# 远程下载依赖，并保存在指定目录，返回依赖列表
def downloadDependency(pom_file):
    dependencies = []
    command = "mvn dependency:list -DremoteRepositories=http://repo1.maven.org/maven2/ "\
    f"  -Dmaven.repo.local={qlConfig('maven_savedir')} -f {pom_file}"
    cmd_result = execute(command)
    for t0 in re.compile(r"\[INFO\] The following files have been resolved:(.*?)\[INFO\] BUILD SUCCESS", re.S).findall(cmd_result):
        for t1 in t0.split("\n"):
            if t1.startswith("[INFO]"):
                t2 = t1.split("    ")
                if len(t2) == 2:
                    dependencies.append(t2[1].strip())
    return dependencies


# 处理maven对应pom.xml的依赖问题
def transform(pom_file):
    if not os.path.isfile(pom_file) or not pom_file.endswith(".xml"):
        log.error("Maven pom.xml error")
        return False

    dependencies = downloadDependency(pom_file)
    if len(dependencies) <= 0:
        log.error("Maven download error.")
        return False
    for dependency in dependencies:
        print(dependency)
        dependency_split = dependency.split(":")
        if len(dependency_split) < 4:
            log.error(f"pom.xml dependency:{dependency} error")
            continue
        if dependency_split[2] != "jar":
            log.error(f"pom.xml dependency:{dependency} not a jar dependency")
            continue
        dependency_groupid = dependency_split[0]
        dependency_artifactid = dependency_split[1]
        dependency_version = dependency_split[3]
        dependency_path = os.path.join(qlConfig("maven_savedir"), dependency_groupid.replace(".", "/"), dependency_artifactid.replace(".", "/"))
        if not os.path.isdir(dependency_path):
            log.error(f"pom.xml dependency:{dependency} download error")
            continue
        jar_file = list(getFilesFromPath(dependency_path, "jar"))
        if len(jar_file) <= 0:
            log.error(f"pom.xml dependency:{dependency_path} has no jar package")
            continue
        for jar in jar_file:
            srcpath = str(jar)
            destpath = os.path.join(qlConfig("decode_savedir"), "lib", os.path.basename(srcpath))
            copyFile(srcpath, destpath)
        return True


