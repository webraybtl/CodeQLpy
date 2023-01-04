#!/usr/bin/env python3
# -*- coding: utf-8 -*-

from configparser import ConfigParser

def get(option, key):
	conn = ConfigParser()
	conn.read("config/config.ini")
	return conn.get(option, key)

def qlConfig(key):
	return get("codeql", key)

def logConfig(key):
	return get("log", key)
