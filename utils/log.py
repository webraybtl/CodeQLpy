#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import logging
import os
import time

from utils.option import logConfig

log_dir = logConfig("path")

if not os.path.exists(log_dir):
    os.mkdir(log_dir)

class Logger():
    def log(self):
        logger = logging.getLogger("logger")
        logger.setLevel(logging.INFO)
        sh = logging.StreamHandler()

        log_file = os.path.join(log_dir, time.strftime('%Y-%m-%d', time.localtime(time.time())) + ".log")
        fh = logging.FileHandler(log_file,encoding="UTF-8")

        # 创建格式器,并将sh，fh设置对应的格式
        formator = logging.Formatter(fmt = "%(asctime)s %(filename)s %(levelname)s %(message)s",
                                     datefmt="%Y/%m/%d %X")
        sh.setFormatter(formator)
        fh.setFormatter(formator)

        # 将处理器，添加至日志器中
        logger.addHandler(sh)
        logger.addHandler(fh)

        return logger

log = Logger().log()
