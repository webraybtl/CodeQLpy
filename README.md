# CodeQLpy

## 项目简介

CodeQLpy是一款基于CodeQL实现的自动化代码审计工具，目前仅支持java语言，后期会增加对其他语言的支持。

支持对多种不同类型的java代码进行代码审计，包括jsp文件、SpringMVC的war包、SpringBoot的jar包、maven源代码。

## 安装准备

1、首先安装CodeQL，具体安装方法可以参考https://www.freebuf.com/articles/web/283795.html。注意一定要使用新版本，老版本中有不支持的语法

2、python环境依赖，本项目依赖python3.7及以上版本，具体依赖见requirements.txt

```
pip3 install -r requirements.txt
```

3、java环境依赖，本项目运行需要安装下面的java组件：JDK8、JDK11、maven。

4、修改config/config.ini文件，需要修改的配置项是qlpath和jdk8和jdk11，其他项目可保持默认。注意jdk的路径中有空格的话需要用双引号包裹。

```
[codeql]
qlpath = D:\CodeQL\ql\java\ql\test\
jdk8 = "C:\Program Files\Java\jre1.8.0_131\bin\java.exe"
jdk11 = "C:\Program Files\Java\jdk-11\bin\java.exe"
idea_decode_tool = lib/java-decompiler.jar
jd_decode_tool  = lib/jd-cli.jar
jsp_decode_tool = lib/jsp2class.jar
ecj_tool = lib/ecj-4.6.1.jar
tomcat_jar = lib/tomcat_lib
decode_savedir = out/decode/
general_dbpath = out/database/
maven_savedir  = out/mvn/
decompile_type = jd
debug = on
model = fast
thread_num = 10

[log]
path = out/log/
```

## 项目使用

本项目的使用主要分成三个步骤，

**Step1, 生成数据库初始化**

```
python3 main.py -t /Users/xxx/Downloads/OAapp/ -c
```

参数解释，

-t参数表示目标源码的路径，支持的源码类型是文件夹，jar包和war包。注意如果是文件夹类型的源码，-t指定的路径必须是网站跟目录，不然会因为源码中相对路径错误导致编译异常。

-c表示源码是属于编译后的源码，即class文件。如果不指定，则表示源码为编译前源码，即java文件。

**Step2，生成数据库**

这一步直接使用上一步命令最终返回的生成数据库的命令在cmd/bash环境中运行即可

mac命令如下

```
arch -x86_64 codeql database create out/database/OAapp --language=java --command='/bin/bash -c /Users/xxx/CodeQLpy/out/decode/run.sh' --overwrite
```

windows命令如下

```
codeql database create out/database/OAapp --language=java --command='run.cmd' --overwrite
```

**Step3，代码审计**

这一步需要使用上一步命令最终相应的生成数据库的路径

```
python3 main.py -d /Users/xxx/CodeQLpy/out/database/OAapp/
```

-d 参数表示待扫描的数据库路径

运行完成之后最终会返回结果文件，结果文件是csv文件，保存目录在out/result/目录之下。

## CodeQLpy应用

CodeQLpy用于自动化分析常见WEB应用漏洞，包括但不限于SQL注入、XSS、命令执行、任意文件操作、XXE、SSRF、反序列化等。CodeQLpy不能用于挖掘反序列化利用链。

为什么不直接在lgtm网站上分析？

lgtm要求分析的源码一定是编译前的源码，而且其包含的插件有限，扩展性不够。
