#!/bin/bash

# Prefisso per i nomi dei comandi LSF
LSF_CMD_PREFIX="lsf_"

# Lista dei comandi LSF attivi.
LSF_CMD=( log parse keywords main version exit )

# Prefisso per i nomi delle funzioni di libreria
LSF_LIB_CMD_PREFIX="lib_"

# Lista delle funzioni di libreria attive
LSF_LIB_CMD=( apply archive depend detect_collision disable enable find import include update list list_apply name path test )

# Prefisso per le variabili d'ambiente di LSF
LSF_VAR_PREFIX="$(echo $LSF_CMD_PREFIX     | tr '[:lower:]' '[:upper:]')"

# Prefisso per le variabili d'ambiente di libreria
LSF_LIB_VAR_PREFIX="$(echo $LSF_LIB_CMD_PREFIX | tr '[:lower:]' '[:upper:]')"

# Estensione dei file di libreria
LSF_LIB_EXT="lsf"

# Estensione degli archivi di libreria
LSF_ARC_EXT="lsa"


### UTILITY FUNCTIONS ##########################################################

# Restituisce il path assoluto.
__lib_get_absolute_path()
{
	readlink -m $*
}

# Stampa il contento di una directory
__lib_list_dir()
{
	[ $# -eq 0 -a ! -d "$1" ] && return 1
	local dir="${1%/}"
	local file=
	
	
	if [ "$dir" != "." ]; then
		echo "$dir" #| awk -v PWD="$PWD/" '{gsub(PWD,""); print}'
		dir="$dir/*"
	else
		dir="*"
	fi
	
	for file in $dir; do
		[ -f "$file" ] && echo "$file" #| awk -v PWD="$PWD/" '{gsub(PWD,""); print}'
		
		[ -d "$file" ] && $FUNCNAME "$file"
	done
}


