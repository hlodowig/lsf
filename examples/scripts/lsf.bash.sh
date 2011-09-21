#!/bin/bash

# load LSF framework
source $LSF_HOME/lsf.sh

# log setup
lib_log --out out
lib_log --disable

# library path setup
lib_path --set $LSF_HOME/lib

# include library
lib_include io

# test
println "Test LSF"

