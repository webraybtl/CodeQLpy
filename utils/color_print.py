#!/usr/bin/env python3
# -*- coding: utf-8 -*-

def color_print(val,style=0,font=0,back=0):
    print(str("\033[{0};{1};{2}m" + val + '\033[0m').format(style, font, back))

def debug(val):
    color_print(val, 0, 35, 47)

def error(var):
    color_print(var, 0, 31, 47)

def warning(var):
    color_print(var, 0, 33, 47)
    
def info(var):
    color_print(var, 0, 32, 47)

