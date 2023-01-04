#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import time
import codeql
import utils.color_print as color_print

from scan.Scan       import Scan


class JavaScan(Scan):

    def __init__(self, ):
        Scan.__init__(self, )
        # self.scan_name = ["test", ]
        self.scan_name = ["java", "java_ext"]

    def run(self, database):
        db = codeql.Database(database)
        result_flag = False
        result_file = time.strftime('%Y-%m-%d', time.localtime(time.time())) + "_" + str(int(time.time())) + ".csv"

        for scan_name in self.scan_name:
            plugin_path = os.path.join("plugins", scan_name)
            for plugin in self.getPluginList(plugin_path):
                print("startscan: " + plugin)
                results = db.query(self.getQuery(os.path.join(plugin_path, plugin)))
                if len(results) <= 1:
                    continue
                else:
                    color_print.info("Found {} num vulnerablity with plugin {}".format(len(results) - 1, plugin))
                    if result_flag == False:
                        self.initResult(result_file)
                        result_flag = True

                    self.saveResult(results, result_file, plugin)

        if not result_flag:
            color_print.debug("Not Found any vulnerablity")
        else:
            color_print.debug("Result Save at path {}".format(os.path.join(self.result_path, result_file)))

        print("Scan Over")


