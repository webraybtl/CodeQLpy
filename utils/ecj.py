import pathlib
import os


def compile_cmd_file_create(save_path, ecj_path):
    with open("{}/file.txt".format(save_path), "w+") as f:
        for java_path in pathlib.Path(save_path).glob('**/*.java'):
            f.write(str(java_path) + "\n")
    ecj_absolute_path = pathlib.Path(ecj_path).resolve()
    compile_cmd = "java -jar {} -encoding UTF-8 -8 " \
                  "-warn:none -noExit @{}/file.txt".format(ecj_absolute_path, save_path)

    with open("{}/run.cmd".format(save_path), "w+") as f:
        f.write(compile_cmd)

    with open("{}/run.sh".format(save_path), "w+") as f:
        f.write(compile_cmd)


if __name__ == '__main__':
    self_ecj_path = os.getcwd() + r"/ecj-4.6.1.jar"

    compile_cmd_file_create(os.getcwd() + r"/dubbo", self_ecj_path)