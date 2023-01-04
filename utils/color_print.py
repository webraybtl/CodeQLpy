#!/usr/bin/env python3
# -*- coding: utf-8 -*-

from colorama import init,Back

init()

def color_print(color, val):
    print(color, val, Back.RESET)

def debug(val):
    color_print(Back.CYAN, val)

def error(val):
    color_print(Back.RED, val)

def warning(val):
    color_print(Back.MAGENTA, val)
    
def info(val):
    color_print(Back.GREEN, val)

