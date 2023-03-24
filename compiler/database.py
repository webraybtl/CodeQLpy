#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import re
import sys
import shutil
import codeql
import platform
import utils.color_print as color_print

from utils.log              import log
from utils.option           import qlConfig
from utils.check            import checkDB
from utils.functions        import *
from compiler.decompiler    import *
from compiler.ecjcompiler   import *
from compiler.clear         import *
from compiler.maven         import transform


def createJar(source, compiled, version, jars):
    if not compiled:
        log.error("SpringBoot jar project is compiled, using --compiled argument instead.")
        sys.exit()
    source_path = os.path.join(qlConfig("decode_savedir"), os.path.basename(source))
    # 删除历史保存的数据
    delDirFile(source_path)
    # 生成反编译之后的文件
    javaDecompile(source, source_path)

    if os.path.isdir(source_path):
        java_files = list(getFilesFromPath(source_path, "java"))
        class_files = list(getFilesFromPath(source_path, "class"))
        jar_files  = list(getFilesFromPath(source_path, "jar"))

        if len(java_files) <= 0:
            log.error("Auto decompiler error, no java file found.")
        if len(class_files) > 0:
            log.warning("There are {} class files".format(len(list(class_files))))

        # 处理代码中的.java源码文件
        if len(java_files) > 0:
            for java_file in java_files:
                copyJavaFile(java_file, os.path.join(qlConfig("decode_savedir"), "classes"))

        for spring_boot_jar in dirFiles(qlConfig("spring_boot_jar")):
            srcpath = os.path.join(qlConfig("spring_boot_jar"), spring_boot_jar)
            destpath = os.path.join(qlConfig("decode_savedir"), "lib", os.path.basename(srcpath)) 
            copyFile(srcpath, destpath)

        # 处理jar包的问题, 把jar包都拷贝到lib目录集中处理
        if len(jar_files) > 0:
            for jar_file in jar_files:
                srcpath = str(jar_file)
                if not checkJar(srcpath):
                    continue

                flag = True
                for jar in jars:
                    if os.path.basename(jar_file) == jar or re.compile("^{}$".format(jar)).search(os.path.basename(jar_file)):
                        save_dir = os.path.join(qlConfig("decode_savedir"), "classes")
                        javaDecompile(jar_file, save_dir)
                        flag = False
                if flag:
                    destpath = os.path.join(qlConfig("decode_savedir"), "lib", os.path.basename(srcpath))
                    copyFile(srcpath, destpath)

        clearJava(list(getFilesFromPath(qlConfig("decode_savedir"), "java")))

        # 通过ecj对反编译之后的代码进行编译
        compile_cmd = ecjcompileE(qlConfig("decode_savedir"), version)
        db_name = ".".join(os.path.basename(source).split(".")[:-1])
        db_path = os.path.join(qlConfig("general_dbpath"), db_name)
        db_cmd = generate(compile_cmd, qlConfig("decode_savedir"))
        
        ql_cmd = f"codeql database create {db_path} --language=java --command=\"{db_cmd}\" --overwrite"
        if platform.system() == "Darwin":
            ql_cmd = "arch -x86_64 " + ql_cmd
        color_print.debug("Using the following command to create database")
        color_print.info(ql_cmd)
        sys.exit()
        # log.info(f"arch -x86_64 codeql database create {db_path} --language=java --command='{db_cmd}'")
        # 生成数据库，保存在db_path路径
        codeql.Database.create("java", None, compile_cmd, db_path)
        if checkDB(db_path):
            return db_path
        else:
            log.error("Generate database error.")

    else:
        log.error("Decompile error")

def createDir(source, compiled, version, jars, root_path):
    # 处理未编译的源代码，生成数据库
    if not compiled:
        java_files = list(getFilesFromPath(source, "java"))
        jsp_files  = list(getFilesFromPath(source, "jsp"))
        jar_files  = list(getFilesFromPath(source, "jar"))

        if len(java_files) <= 0:
            log.error("SourceCode has not java file, maybe not an uncompiled SourceCode, using --comopiled argument instead")
            sys.exit()

        if not os.path.isfile(os.path.join(source, "pom.xml")):
            log.error("Only support maven project with pom.xml, check your SourceCode. Or using --compiled argument instead")
            sys.exit()

        # 处理jsp文件，反编译成java文件，并保存在待编译目录
        if len(jsp_files) > 0:
            log.info(f"Found {len(jsp_files)} jsp files to decode")
            # i = 0
            # for jsp_file in jsp_files:
            #     i += 1
            #     log.info(f"Decoded jsp files {i}/{len(jsp_files)}, in processing.")
            #     jspDecompile(jsp_file, source)
            # jspDecompileFiles(jsp_files, source)
            jspDecompileFiles(jsp_files, source)

            convert_jsp_files = []
            for java_file in list(getFilesFromPath(qlConfig("decode_savedir"), "java")):
                java_package = str(java_file).replace("/", ".").replace("\\", ".")
                if "org.apache.jsp." in java_package:
                    convert_jsp_files.append(java_file)

            log.warning(f"Decode jsp file {len(convert_jsp_files)}/{len(jsp_files)} success ")
            if len(convert_jsp_files) <= 0:
                log.error(f"Auto decompiler error, no java file found.")
                sys.exit()
            else:
                # 因为jsp文件编译需要用到tomcat lib目录的jar包，需要把jar包拷贝一份
                for tomcat_jar in dirFiles(qlConfig("tomcat_jar")):
                    srcpath = os.path.join(qlConfig("tomcat_jar"), tomcat_jar)
                    destpath = os.path.join(qlConfig("decode_savedir"), "lib", os.path.basename(srcpath)) 
                    copyFile(srcpath, destpath)

        # 处理本身依赖的jar包
        if len(jar_files) > 0:
            log.info(f"Found {len(jar_files)} jar files to include")
            for jar_file in jar_files:
                srcpath = str(jar_file)
                if not checkJar(srcpath):
                    continue
                destpath = os.path.join(qlConfig("decode_savedir"), "lib", os.path.basename(srcpath))
                copyFile(srcpath, destpath)

        # 通过ecj对jsp文件生成的java文件进行编译
        compile_cmd = ecjcompile(qlConfig("decode_savedir"), source)
        source_split = source.replace("\\", "/").split("/")
        db_name = ""
        for i in range(len(source_split)):
            db_name = source_split[len(source_split) - i -1]
            if db_name != "":
                break
        db_path = os.path.join(qlConfig("general_dbpath"), db_name)

        # 添加maven编译源码的命令
        if platform.system() == "Windows":
            split_quote = "\r\n"
        else:
            split_quote = ";"
        db_cmd = generate("mvn clean package -DskipTests -f {}{} ".format(os.path.join(source, "pom.xml"), split_quote) + compile_cmd, qlConfig("decode_savedir"))

        ql_cmd = f"codeql database create {db_path} --language=java --source-root=\"{source}\" --command=\"{db_cmd}\" --overwrite"
        if platform.system() == "Darwin":
            ql_cmd = "arch -x86_64 " + ql_cmd
        color_print.debug("Using the following command to create database")
        color_print.info(ql_cmd)
        sys.exit()

        # 生成数据库，保存在db_path路径
        codeql.Database.create("java", None, db_cmd, db_path)
        if checkDB(db_path):
            return db_path
        else:
            log.error("Generate database error.")

    # 处理已编译的源码，一般为class和jar
    else:
        # 对源码中不兼容数据进行清洗
        clearSource(source)

        java_files = list(getFilesFromPath(source, "java"))
        jsp_files  = list(getFilesFromPath(root_path, "jsp"))
        jar_files  = list(getFilesFromPath(source, "jar"))

        # WEB-INF目录中的jsp文件不能直接访问，对其进行过滤
        for jsp_file in jsp_files:
            if "WEB-INF" in str(jsp_file):
                jsp_files.remove(jsp_file)
        if len(jsp_files) <= 0:
            log.error("Target SourceCode doesn't found any jsp file,exit")
            sys.exit()
        if not os.path.isfile(os.path.join(root_path, "WEB-INF/web.xml")):
            log.error("Target SourceCode doesn't have WEB-INF/web.xml file,exit")
            sys.exit()

        # 处理jar包的问题, 把jar包都拷贝到lib目录集中处理
        if len(jar_files) > 0:
            for jar_file in jar_files:
                srcpath = str(jar_file)
                if not checkJar(srcpath):
                    continue

                flag = True
                for jar in jars:
                    if os.path.basename(jar_file) == jar or re.compile("^{}$".format(jar)).search(os.path.basename(jar_file)):
                        save_dir = os.path.join(qlConfig("decode_savedir"), "classes")
                        javaDecompile(jar_file, save_dir)
                        flag = False
                if flag:
                    destpath = os.path.join(qlConfig("decode_savedir"), "lib", os.path.basename(srcpath))
                    copyFile(srcpath, destpath)

        # 处理jsp文件，反编译成java文件，并保存在待编译目录
        if len(jsp_files) > 0:
            log.info(f"Found {len(jsp_files)} jsp files to decode")
            jspDecompileFiles(jsp_files, root_path)
            convert_jsp_files = list(getFilesFromPath(os.path.join(qlConfig("decode_savedir"), "org/apache/jsp"), "java"))
            log.warning(f"Decode jsp file {len(convert_jsp_files)}/{len(jsp_files)} success ")
            if len(convert_jsp_files) <= 0:
                log.error(f"Auto decompiler error, no java file found.")
                sys.exit()
            # else:
            #     # 因为jsp文件编译需要用到tomcat lib目录的jar包，需要把jar包拷贝一份
            #     for tomcat_jar in dirFiles(qlConfig("tomcat_jar")):
            #         srcpath = os.path.join(qlConfig("tomcat_jar"), tomcat_jar)
            #         destpath = os.path.join(qlConfig("decode_savedir"), "lib", os.path.basename(srcpath)) 
            #         copyFile(srcpath, destpath)

        # 处理WEB-INF/classes中的源码文件
        if os.path.isdir(os.path.join(root_path, "WEB-INF/classes")):
            save_dir = os.path.join(qlConfig("decode_savedir"), "classes")
            # 对class文件进行反编译
            color_print.info("Start decoding WEB-INF/classes...")
            javaDecompile(os.path.join(root_path, "WEB-INF/classes"), save_dir)

        # 处理代码中的.java源码文件
        if len(java_files) > 0:
            for java_file in java_files:
                java_file = str(java_file)
                relative_path = java_file[len(source):]
                if len(relative_path) <= 1:
                    continue
                if relative_path.startswith("/") or relative_path.startswith("\\"):
                    relative_path = relative_path[1:]
                copyFile(java_file, os.path.join(qlConfig("decode_savedir"), "classes", relative_path))
        
        # 对反编译中异常的java文件进行自动修复
        clearJava(list(getFilesFromPath(qlConfig("decode_savedir"), "java")))

        compile_cmd = ecjcompileE(qlConfig("decode_savedir"), version)
        source_split = source.replace("\\", "/").split("/")
        db_name = ""
        for i in range(len(source_split)):
            source_split_tmp = source_split[len(source_split) - i - 1].strip()
            if source_split_tmp != "":
                db_name = source_split_tmp
                break
        if db_name == "":
            db_name = source

        db_path = os.path.join(qlConfig("general_dbpath"), db_name)
        db_cmd = generate(compile_cmd, qlConfig("decode_savedir"))
        # color_print.debug("About waiting {} hours for compiling files".format(round(len(compile_cmd.split("\n")) * 20 / 3600.0, 2)))
        # 生成数据库，保存在db_path路径

        ql_cmd = f"codeql database create {db_path} --language=java --command=\"{db_cmd}\" --overwrite"
        if platform.system() == "Darwin":
            ql_cmd = "arch -x86_64 " + ql_cmd
        color_print.debug("Using the following command to create database")
        color_print.info(ql_cmd)
        sys.exit()

        codeql.Database.create("java", None, db_cmd, db_path)
        if checkDB(db_path):
            return db_path
        else:
            log.error("Generate database error.")


def createWar(source, compiled, version, jars):
    if not compiled:
        log.error("SpringMVC war project is compiled, using --compiled argument instead.")
        sys.exit()
    source_path = os.path.join(qlConfig("decode_savedir"), "website")
    javaDecompile(source, source_path)

    # 对源码中不兼容数据进行清洗
    clearSource(source_path)

    java_files = list(getFilesFromPath(qlConfig("decode_savedir"), "java"))
    jsp_files  = list(getFilesFromPath(qlConfig("decode_savedir"), "jsp"))
    jar_files  = list(getFilesFromPath(qlConfig("decode_savedir"), "jar"))

    # WEB-INF目录中的jsp文件不能直接访问，对其进行过滤
    for jsp_file in jsp_files:
        if "WEB-INF" in str(jsp_file):
            jsp_files.remove(jsp_file)
    if len(jsp_files) <= 0:
        log.error("Target SourceCode doesn't found any jsp file,exit")
        sys.exit()
    if not os.path.isfile(os.path.join(source_path, "WEB-INF/web.xml")):
        log.error("Target SourceCode doesn't have WEB-INF/web.xml file,exit")
        sys.exit()

    # 处理jar包的问题, 把jar包都拷贝到lib目录集中处理
    if len(jar_files) > 0:
        for jar_file in jar_files:
            srcpath = str(jar_file)
            if not checkJar(srcpath):
                continue
            flag = True
            for jar in jars:
                if os.path.basename(jar_file) == jar or re.compile("^{}$".format(jar)).search(os.path.basename(jar_file)):
                    save_dir = os.path.join(qlConfig("decode_savedir"), "classes")
                    javaDecompile(jar_file, save_dir)
                    flag = False
            if flag:
                destpath = os.path.join(qlConfig("decode_savedir"), "lib", os.path.basename(srcpath))
                copyFile(srcpath, destpath)

    # 处理jsp文件，反编译成java文件，并保存在待编译目录
    if len(jsp_files) > 0:
        log.info(f"Found {len(jsp_files)} jsp files to decode")
        # i = 0
        # for jsp_file in jsp_files:
        #     i += 1
        #     log.info(f"Decoded jsp files {i}/{len(jsp_files)}, in processing.")
        #     jspDecompile(jsp_file, source)
        jspDecompileFiles(jsp_files, source_path)
        convert_jsp_files = list(getFilesFromPath(os.path.join(qlConfig("decode_savedir"), "org/apache/jsp"), "java"))
        log.warning(f"Decode jsp file {len(convert_jsp_files)}/{len(jsp_files)} success ")
        if len(convert_jsp_files) <= 0:
            log.error(f"Auto decompiler error, no java file found.")
            sys.exit()
        # else:
        #     # 因为jsp文件编译需要用到tomcat lib目录的jar包，需要把jar包拷贝一份
        #     for tomcat_jar in dirFiles(qlConfig("tomcat_jar")):
        #         srcpath = os.path.join(qlConfig("tomcat_jar"), tomcat_jar)
        #         destpath = os.path.join(qlConfig("decode_savedir"), "lib", os.path.basename(srcpath)) 
        #         copyFile(srcpath, destpath)

    # 处理WEB-INF/classes中的源码文件
    if os.path.isdir(os.path.join(source_path, "WEB-INF/classes")):
        save_dir = os.path.join(qlConfig("decode_savedir"), "classes")
        # 对class文件进行反编译
        color_print.info("Start decoding WEB-INF/classes...")
        javaDecompile(os.path.join(source_path, "WEB-INF/classes"), save_dir)

    # 处理代码中的.java源码文件
    if len(java_files) > 0:
        for java_file in java_files:
            java_file = str(java_file)
            relative_path = java_file[len(qlConfig("decode_savedir")):]
            if len(relative_path) <= 1:
                continue
            if "WEB-INF" in java_file:
                continue
            if relative_path.startswith("/") or relative_path.startswith("\\"):
                relative_path = relative_path[1:]
            copyFile(java_file, os.path.join(qlConfig("decode_savedir"), 'classes', relative_path))

    # 对反编译中异常的java文件进行自动修复
    clearJava(list(getFilesFromPath(qlConfig("decode_savedir"), "java")))

    compile_cmd = ecjcompileE(qlConfig("decode_savedir"), version)
    source_split = source.replace("\\", "/").split("/")
    db_name = ""
    for i in range(len(source_split)):
        source_split_tmp = source_split[len(source_split) - i - 1].strip()
        if source_split_tmp != "":
            db_name = source_split_tmp
            break
    if db_name == "":
        db_name = source

    db_path = os.path.join(qlConfig("general_dbpath"), db_name)
    db_cmd = generate(compile_cmd, qlConfig("decode_savedir"))
    # color_print.debug("About waiting {} hours for compiling files".format(round(len(compile_cmd.split("\n")) * 20 / 3600.0, 2)))
    # 生成数据库，保存在db_path路径
    ql_cmd = f"codeql database create {db_path} --language=java --command=\"{db_cmd}\" --overwrite"
    if platform.system() == "Darwin":
        ql_cmd = "arch -x86_64 " + ql_cmd
    color_print.debug("Using the following command to create database")
    color_print.info(ql_cmd)
    sys.exit()

    # 由于自动生成数据库时间太长，看不到中间输出结果，不再提供自动生成数据库的功能
    codeql.Database.create("java", None, db_cmd, db_path)
    if checkDB(db_path):
        return db_path
    else:
        log.error("Generate database error.")


# 根据不同类型的源码进行处理
def createDB(source, compiled, version, jar_list, root_path):
    # 清除历史保存的源码数据
    for path in os.listdir(qlConfig("decode_savedir")):
        c_path = os.path.join(qlConfig("decode_savedir"), path)
        if os.path.isfile(c_path):
            os.remove(c_path)
        elif os.path.isdir(c_path):
            shutil.rmtree(c_path)
    # 处理附属jar包        
    jars = []
    for jar in jar_list.split(","):
        jar = jar.strip()
        if jar != "" and jar not in jars:
            jars.append(jar)

    # 开始创建数据库
    if os.path.isfile(source):
        if source.endswith(".jar"):
            return createJar(source, compiled, version, jars)
        elif source.endswith(".war"):
            return createWar(source, compiled, version, jars)
        else:
            log.error("Unsupport source code")
            sys.exit()
    elif os.path.isdir(source):
        return createDir(source, compiled, version, jars, root_path)
    else:
        log.error("SourceCode is not exists")
        sys.exit()
