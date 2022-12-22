#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import codeql

from utils.option import get
from scan.Scan import Scan

class JavascriptScan(Scan):

	def __init__(self, ):
		self.scan_name = "javascript"
		self.plugin_path = "plugins/" +self.scan_name + "/"

	def run(self, ):
		db = codeql.Database(get('dbpath'))
		for plugin in self.getPluginList(self.plugin_path):
			print("startscan " + plugin)
			print(db.query(self.getQuery(self.plugin_path + plugin)))
