#!/bin/bash

# load LSF framework
source $LSF_HOME/lsf.sh

# log setup
lsf_log --out out
lsf_log --enable

# library path setup
lib_path --set $LSF_HOME/lib

# include library
lib_include io

# test
println "Test LSF"

