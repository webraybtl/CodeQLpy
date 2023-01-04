#python3
#aotoman
#20200318
import os
import zipfile

from utils.log       import log
from utils.functions import execJar
from utils.option    import qlConfig

#参数：1、工程目录；2、编译插件路径
def decompile(filepath,toolpath):
    for root,dirs,files in os.walk(filepath):
        print('[+] '+root)
        for filename in files:
            if '.jar' in filename or '.class' in filename:
                if not os.path.exists(root+'_src_'):#自动在jar包同级目录下创建以_src结尾的文件夹，用以存放反编译后的jar包和解压包
                    os.makedirs(root+'_src_')
                try:
                    print(filename)
                    os.system('java -jar {0} {1} {2}'.format(toolpath,root+'/'+filename,root+'_src_'))
                    with zipfile.ZipFile(root+'_src_'+'/'+filename, 'r') as zzz:
                        zzz.extractall(root+'_src_'+'/'+filename[:-4])
                    os.remove(root+'_src_'+'/'+filename)
                except:
                    print('error:'+root+'/'+filename)

def checkTool(toolpath):
    if not os.path.isfile(toolpath) or not toolpath.endswith(".jar"):
        log.error("Tool Error")
        return False
    else:
        return True

def decodeFile(filepath):
    if not checkTool(qlConfig("decode_tool")):
        return False
    # execJar(qlConfig("decode_tool"), filepath, )
    toolpath=qlConfig("decode_tool") #2、编译软件路径
    decompile("/Users/pang0lin/Downloads/test/",toolpath)


if __name__ == '__main__':
    filepath='piao/' #1、需要编译的工程目录
    toolpath='fernflower.jar' #2、编译软件路径
    print(1111)
    decompile(filepath,toolpath)
