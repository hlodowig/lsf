#!/bin/bash

# Copyright (C) 2010 - Luigi Capraro (luigi.capraro@gmail.com)
#
# Import Utilities is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# Import Utilities is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
# See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Import Utilities; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, 
# Boston, MA  02110-1301  USA
#

# LSF Version info
export LSF_VERSINFO=([0]="0" [1]="9" [2]="1" [3]="9" [4]="alpha" [5]="all")

# Attiva l'espansione degli alias
shopt -s expand_aliases

# Variabile d'ambiente contenente la lista delle directory contenenti librerie.
export LIB_PATH="${LIB_PATH:-"lib"}"

# Estensione dei file di libreria
export LIB_EXT="lsf"

# Estensione degli archivi di libreria
export ARC_EXT="lsa"

# Lista dei file di libreria importati.
LIB_FILE_LIST="${LIB_FILE_LIST:-""}"

# Mappa che associa ad un archivio una directory temporanea
declare -gxA LIB_ARC_MAP


### UTILITY FUNCTIONS ##########################################################

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

# Restituisce il path assoluto.
__lib_get_absolute_path()
{
	local FILEPATH=$(
		if [ $# -eq 0 ]; then
			cat
		else
			echo $1
		fi
	)
	
	echo "$STRING" | grep -E -q -e "$REGEXP" >/dev/null
	
	if ! echo "$FILEPATH" | grep -E -q -e "^/" >/dev/null; then
		
		FILEPATH="${PWD}/$FILEPATH"
	fi
	
	FILEPATH=$(echo "$FILEPATH" |
	awk '{
		 gsub("\\.(/|$)","#/");
		 gsub("/\\.#","/##");
		 gsub("/\\.$","/");
		 gsub("/#/","/");
		 while ($0~"//+|/#|/[^/]+/##") {
		     gsub("//+|/[^/]+/##(/|$)?","/");
		 }
		 gsub("/$","")
		 print
		}')
	if [ -z "$FILEPATH" ]; then
		FILEPATH="/"
	fi
	
	echo $FILEPATH
}


### LIB_LIST FILES SECTION #####################################################

# Restituisce la lista dei file delle librerie importate nell'ambiente corrente.
__lib_list_files()
{
	[ -z "$LIB_FILE_LIST" ] && return
	
	local libfile=""
	
	for libfile in $LIB_FILE_LIST; do
		echo $libfile | awk '{gsub("^[0-9]+/","/"); print}'
	done
}

# Restituisce la lista dei nomi delle librerie importate nell'ambiente corrente.
__lib_list_names()
{
	[ -z "$LIB_FILE_LIST" ] && return
	
	local libfile=""
	
	for libfile in $LIB_FILE_LIST; do
		libfile=$(echo $libfile | awk '{gsub("^[0-9]+/","/"); print}')
		lib_name $libfile
	done
}

# Svuota la lista dei file delle librerie importate nell'ambiente corrente.
__lib_list_files_clear()
{
	LIB_FILE_LIST=""
}

# Rimuove il path di un file dalla lista dei file delle librerie importate
# nell'ambiente corrente.
__lib_list_files_remove()
{
	local lib=
	
	for lib in $@; do

		lib="$(__lib_get_absolute_path "$lib")"
	
		LIB_FILE_LIST=$( echo -e "$LIB_FILE_LIST" |
						 awk -vLIB="[0-9]+$lib" '{gsub(LIB,""); print}' |
						 grep -v -E -e '^$')
	done
	
}

# Aggiunge il path di un file alla lista dei file delle librerie importate
# nell'ambiente corrente.
__lib_list_files_add()
{	
	[ $# -eq 0 ] && return 1
	
	local lib=
	
	for lib in $@; do
		__lib_list_files_remove "$lib"

		lib="$(__lib_get_absolute_path "$lib")"
	
		LIB_FILE_LIST=$(echo -e "${LIB_FILE_LIST}\n$(stat -c %Y $lib)$lib" | 
			            grep -v -E -e '^$')
	done
}

# Restituisce la data di ultima modifica relativa al path della libreria 
# importata nell'ambiente corrente.
__lib_list_files_get_mod_time()
{
	local lib="$(__lib_get_absolute_path "$1")"
	
	echo -e "$LIB_FILE_LIST" | grep -E -e "$lib" | awk '{gsub("[^0-9]+",""); print}'
}


### LOG SECTION ################################################################

# Variabile booleana d'ambiente che indica se il log è attivo 
export LIB_LOG_ENABLE=${LIB_LOG_ENABLE:-0}
# Variabile d'ambiente contenente il path del dispositivo e file di output.
export LIB_LOG_OUT=${LIB_LOG_OUT:-"/dev/stderr"}

# Log Manager
#
# Stampa messaggi di log.
lsf_log()
{
	__lsf_log_usage()
	{
		local CMD="$1"
		
		
		(cat << END
NAME
	${CMD:=lsf_log} - Log Manager di LSF.

SYNOPSIS
	Enable/Disable command:
	    $CMD [OPTIONS] -e|--enable
	    $CMD [OPTIONS] -s|--disable
	    $CMD [OPTIONS] -E|--is-enabled
	
	Print command:
	    $CMD [OPTIONS] [-e|--enable] <message>
	
	Outout command:
	    $CMD [OPTIONS] -o|--output
	    $CMD [OPTIONS] -o|--output <file>|<device>
	
	View command:
	    $CMD [OPTIONS] -l|--view
	
	Reset command:
	    $CMD [OPTIONS] -R|--reset
	
	
DESCRIPTION
	Il comando $CMD gestisce le operazioni di log del framework LSF.
	
	
GENERIC OPTIONS
	-e, --enable
	    Abilita il sistema di logging.
	
	-d, --disable
	    Disabilita il sistema di logging.
	
	-E, --is-enabled
	    Verifica che il sistama di logging sia abilitato o meno.
	    Ritorna 0 se abilitato, 1 altrimenti.
	
	-o|--output
	    Se non vengono forniti paramentri, stampa a video il file o il device di log.
	    Se viene passato un paramentro, imposta il nuovo output per il log.
	
	-l|--view
	    Se l'output è un file, stampa il contenuto del file di log.
	
	-R|--reset
	    Se l'output è un file, cancella il contentuo del file di log.
	
	-h, --help
	    Stampa questa messaggio e esce.
	
	-v, --verbose
	    Stampa informazioni dettagliate.
	
	-V, --no-verbose
	    Non stampa informazioni dettagliate.
	
END
) | less
		
		return 0
	}
	
	
	local ARGS=$(getopt -o hoEedlRvV -l help,output,is-enabled,enable,disable,view,reset,verbose,no-verbose -- "$@")
	eval set -- $ARGS
	
	local CMD="PRINT"
	local VERBOSE=0
	
	while true ; do
		case "$1" in
		-o|--output)         CMD="OUTPUT"                          ; shift    ;;
		-R|--reset)          CMD="RESET"                           ; shift    ;;
		-l|--view)           CMD="VIEW"                            ; shift    ;;
		-e|--enable)         CMD="ON"                              ; shift    ;;
		-d|--disable)        CMD="OFF"                             ; shift    ;;
		-E|--is-enabled)     test $LIB_LOG_ENABLE -eq 1 && return 0; return  1;;
		-v|--verbose)        VERBOSE=1                             ; shift    ;;
		-V|--no-verbose)     VERBOSE=0                             ; shift    ;;
		-h|--help)           __lsf_log_usage $FUNCNAME             ; return  0;;
		--) shift; break;;
		esac
	done
	
	__lsf_log_out()
	{
		if [ -n "$1" ]; then
			case $1 in
			1|out|stdout) LIB_LOG_OUT="/dev/stdout";;
			2|err|stderr) LIB_LOG_OUT="/dev/stderr";;
			*) LIB_LOG_OUT=$(__lib_get_absolute_path "$1");;
			esac
			
			
			if [ -w "$LIB_LOG_OUT" ]; then
				export LIB_LOG_OUT
				return 0
			fi
			
			return 1
		fi
		
		echo "$LIB_LOG_OUT"
		
		return 0
	}
	
	__lsf_log_enable()
	{
		[ $VERBOSE -eq 1 ] && echo "Log abilitato."
		export LIB_LOG_ENABLE=1
	}
	
	__lsf_log_disable()
	{
		[ $VERBOSE -eq 1 ] && echo "Log disabilitato."
		export LIB_LOG_ENABLE=0
	}
	
	__lsf_log_print()
	{
		[ $# -eq 0 ] && return
		
		if [ ! -f "$LIB_LOG_OUT" ]; then
			local LIB_LOG_DIR=$(dirname "$LIB_LOG_OUT")
			
			if [ ! -d "$LIB_LOG_DIR" ]; then
				[ $VERBOSE -eq 1 ] &&
				echo "La directory '$LIB_LOG_DIR' non esiste."
				
				mkdir -p "$LIB_LOG_DIR"
				
				if [ $? -eq 0 ]; then
					[ $VERBOSE -eq 1 ] &&
					echo "La directory '$LIB_LOG_DIR' e stata creata."
					
					! test -e "$LIB_LOG_OUT" && touch "$LIB_LOG_OUT" || return 2
					
					return 0
				fi
				
				return 1
			fi
		fi
		
		
		if [ $LIB_LOG_ENABLE -eq 1 ]; then
			echo -e $(date +"%Y-%m-%d %H:%M:%S") $(id -nu) $* >> ${LIB_LOG_OUT}
		fi
	}
	
	__lsf_log_view()
	{
		[ $VERBOSE -eq 1 ] &&
		echo "Contenuto del file di log: '$LIB_LOG_OUT'."
			
		[ -f "$LIB_LOG_OUT" ] && 
		less "$LIB_LOG_OUT"
		
		return $?
	}
	
	__lsf_log_reset()
	{
		if [ -f "$LIB_LOG_OUT" ]; then
			[ $VERBOSE -eq 1 ] &&
			echo "Reset del file di log: '$LIB_LOG_OUT'."
			echo "" > "$LIB_LOG_OUT"
			
			return $?
		fi
		
		return 0
	}
	
	__lsf_log_exit()
	{
		unset __lsf_log_enable
		unset __lsf_log_disable
		unset __lsf_log_out
		unset __lsf_log_print
		unset __lsf_log_view
		unset __lsf_log_reset
		unset __lsf_log_exit
		
		return $1
	}
	
	case "$CMD" in
	ON)       __lsf_log_enable    ;;
	OFF)      __lsf_log_disable   ;;
	RESET)    __lsf_log_reset     ;;
	VIEW)     __lsf_log_view      ;;
	OUTPUT)   __lsf_log_out   "$1";;
	PRINT|*)  __lsf_log_print "$@";;
	esac
	
	__lsf_log_exit $?
}



### PATH SECTION ###############################################################

# Toolkit per la variabile LIB_PATH
lib_path()
{
	__lib_path_usage()
	{
		local CMD="$1"
		
		(cat << END
NAME
	${CMD:=lib_path} - Toolkit per la variabile LIB_PATH.

SYNOPSIS
	$CMD [OPTIONS] [-g|--get] [i1:i2:i3]   con 1 < in < D+1, D=# path
	
	$CMD [OPTIONS] -s|--set <path>[:<path>...]
	
	$CMD [OPTIONS] -a|--add <path> [<path>...]
	
	$CMD [OPTIONS] -r|--remove <path> [<path>...]
	
	$CMD [OPTIONS] -l|--list
	
	$CMD [OPTIONS] -R|--reset
	
	$CMD -h|--help
	
DESCRIPTION
	Il comando $CMD gestisce e manipola la variabile d'ambiente LIB_PATH del framework LSF.
	
	
GENERIC OPTIONS
	
	-v, --verbose
	    Stampa informazioni dettagliate.
	
	-V, --no-verbose
	    Non stampa informazioni dettagliate.
	
	-A, --absolute-path
	    Converte i path relativi in assoluti.
	
	-w, --real-path
	    Converte i path relativi agli archivi nelle relative directory temporanee.
	
	-W, --no-real-path
	    Non converte i path relativi agli archivi. (default)
	
COMMAND OPTIONS
	-g, --get
	    Restituisce il valore della variabile d'ambiente LIB_PATH.
	
	-s, --set
	    Imposta il valore della variabile d'ambiente LIB_PATH.
	
	-f, --find
	    Verifica se un path appartiena alla lista della variabile d'ambiente LIB_PATH.
	
	-a, --add
	    Aggiunge un path o una lista di path alla variabile d'ambiente LIB_PATH.
	
	-r, --remove
	    Rimuove un path o una lista di path dalla variabile d'ambiente LIB_PATH.
	
	-R, --reset
	    Rimuove tutti i path dalla variabile d'ambiente LIB_PATH.
	
	-l, --list
	    Stampa la lista di path della variabile d'ambiente LIB_PATH.
	
	-h, --help
	    Stampa questa messaggio e esce.
	
END
		) | less
		
		return 0
	}
	
	
	local ARGS=$(getopt -o hgsfarRlvVAwW -l help,get,set,find,add,remove,reset,list,verbose,no-verbose,absolute-path,real-path,no-real-path -- "$@")
	eval set -- $ARGS
	
	local CMD="GET"
	local VERBOSE=0
	local ABS_PATH=0
	local REAL_PATH=0
	
	while true ; do
		case "$1" in
		-g|--get)           CMD="GET"                              ; shift    ;;
		-s|--set)           CMD="SET"                              ; shift    ;;
		-f|--find)          CMD="FIND"                             ; shift    ;;
		-a|--add)           CMD="ADD"                              ; shift    ;;
		-r|--remove)        CMD="REMOVE"                           ; shift    ;;
		-R|--reset)         CMD="RESET"                            ; shift    ;;
		-l|--list)          CMD="LIST"                             ; shift    ;;
		-A|--absolute-path) ABS_PATH=1                             ; shift    ;;
		-w|--real-path)     REAL_PATH=1                            ; shift    ;;
		-W|--no-real-path)  REAL_PATH=0                            ; shift    ;;
		-v|--verbose)       VERBOSE=1                              ; shift    ;;
		-V|--no-verbose)    VERBOSE=0                              ; shift    ;;
		-h|--help)          __lib_path_usage "$FUNCNAME"           ; return  0;;
		--) shift; break;;
		esac
	done
	
	# Restituisce il valore della variabile LIB_PATH, se non viene passato alcun
	# parametro.
	# Se come parametro viene passata una sequenza numerica separata da ':',vengono
	# retituiti i path relativi alle posizioni.
	#
	# ES.
	# > lib_path_get
	#   .:lib:/home/user/lsf/lib
	# > lib_path_get 2:3
	#   lib:/home/user/lsf/lib
	#
	__lib_path_get()
	{
		[ $VERBOSE -eq 1 ] &&
		echo "LIB_PATH: Get $*"
		
		[ -z "$LIB_PATH" ] && return
		
		local LP=""
		local lib=
		
		if [ $# -eq 0 ]; then
			for lib in $(echo -e ${LIB_PATH//:/\\n}); do
				if [ $ABS_PATH -eq 1 ]; then
					lib="$(__lib_get_absolute_path "$lib")"
				fi
				
				if [ $REAL_PATH -eq 1 ] && lib_test --is-archive "$lib"; then
					lib="$(lib_archive --track --search $lib)"
				fi
				
				LP="${LP}:${lib}"
			done
		else
			
			for path_num in $(echo $* | tr : ' '); do
				
				lib=$(echo $LIB_PATH | awk -F: -v PN=$path_num '{print $PN}')
				
				[ $ABS_PATH -eq 1 ] && lib=$(__lib_get_absolute_path "$lib")
				
				if [ $REAL_PATH -eq 1 ] && lib_test --is-archive "$lib"; then
					lib="$(lib_archive --track --search $lib)"
				fi
				
				LP=${LP}:${lib}
			done
		fi
		
		LP=${LP#:}
		LP=${LP%:}
		
		echo $LP 
	}
	
	# Stampa la lista dei path della variabile LIB_PATH, separati dal carattere di
	# newline.
	__lib_path_list()
	{
		[ $VERBOSE -eq 1 ] && echo "LIB_PATH: List"
		
		local path_list="$(__lib_path_get)"
		echo -e ${path_list//:/\\n}
	}
	
	# Imposta la variabile LIB_PATH.
	__lib_path_set()
	{
		
		local libs="$(echo "$1" | awk -F: '{for (i=NF; i>0; i--) { if (i>1) printf "%s:", $i; else print $i; }; }')"
		local lib=""
		
		[ -z "$libs" -a $ABS_PATH -eq 1 ] && libs="$LIB_PATH"
		
		[ -z "$libs" ] && return 1
		
		[ $VERBOSE -eq 1 ] &&
		echo "LIB_PATH: Set path list"
		
		LIB_PATH=""
		
		for lib in $(echo "$libs" | tr : ' '); do
			
			__lib_path_add "$lib"
		done
		
		export LIB_PATH
	}
	
	# Verifica se un path appartiene alla lista contenuta nella variabile LIB_PATH
	__lib_path_find()
	{
		local verbose=$VERBOSE
		
		if [ "$1" == "-v" ]; then
			verbose=2
			shift
		fi
		
		local path=""
		
		path=$(echo $LIB_PATH | grep -o -E -e "(^|:)$1/?(:|$)")
		# test 1
		if [ -n "$path" ]; then
			path=${path#:}; path=${path%:}
			[ $verbose -eq 1 ] && echo "lib_path: found '$path'"
			[ $verbose -eq 2 ] && echo "$path"
			return 0
		fi
		
		local abs_path=$(__lib_get_absolute_path "$1")
		path=$(echo $LIB_PATH | grep -E -e "(^|:)$abs_path/?(:|$)")
		
		# test 2
		if [ -n "$path" ]; then
			[ $verbose -eq 1 ] && echo "lib_path: found '$abs_path'"
			[ $verbose -eq 2 ] && echo "$abs_path"
			return 0
		fi
		
		local path2=$(echo $LIB_PATH | grep -E -e "(^|:).*$(basename "$1")/?(:|$)")
		
		# test 3
		if [ -n "$path2" ]; then
			path2=${path2#:}; path2=${path2%:}
			local abs_path2=$(__lib_get_absolute_path "$path2")
			
			if [ "$abs_path" == "$abs_path2" ]; then
				[ $verbose -eq 1 ] && echo "lib_path: found '$path2'"
				[ $verbose -eq 2 ] && echo "$path2"
				return 0
			fi
		fi
		
		[ $verbose -eq 1 ] && echo "lib_path: '$1' not found"
		
		return 1
	}
	
	# Aggiunge un path alla lista contenuta nella variabile LIB_PATH.
	__lib_path_add()
	{
		
		for lib in $*; do
			
			__lib_path_find "$lib" && continue
			
			[ $ABS_PATH -eq 1 ] && lib=$(__lib_get_absolute_path "$lib")
			
			if   lib_test --is-file "$lib"; then
				[ $VERBOSE -eq 1 ] &&
				echo "LIB_PATH: Add file library path: $lib"
			elif lib_test --is-dir  "$lib"; then
				[ $VERBOSE -eq 1 ] &&
				echo "LIB_PATH: Add dir library path: $lib"
			elif lib_test --is-archive  "$lib"; then
				local larc_opts="--quiet"
				[ $VERBOSE -eq 1 ] && larc_opts="--verbose"
				
				lib_archive $larc_opts --temp-dir --track --clean-dir --extract "$lib"
				
				if [ $REAL_PATH -eq 1 ]; then
					lib="$(lib_archive --track --search $lib)"
				fi
				
				[ $VERBOSE -eq 1 ] &&
				echo "LIB_PATH: Add archive library path: $lib"
			else
				[ $VERBOSE -eq 1 ] &&
				echo "LIB_PATH: Add path: '$lib' failed! No type found."
				
				continue
			fi
			if [ -n "$LIB_PATH" ]; then
				LIB_PATH="${lib%\/}:$LIB_PATH"
			else
				LIB_PATH="${lib%\/}"
			fi
		done
		
		export LIB_PATH
	}

	# Rimuove un path dalla lista contenuta nella variabile LIB_PATH.
	__lib_path_remove()
	{
		for lib in $*; do
			
			local path=$(__lib_path_find -v "$lib")
			
			[ -z "$path" ] && continue
			
			if [ $VERBOSE -eq 1 ]; then
				echo -n "LIB_PATH: Remove path '$lib'"
				
				[ "$lib" != "$path" ] && echo -n " ($path)"
				echo
			fi
			
			LIB_PATH=$(echo $LIB_PATH |
					   awk -v LIB="$path" '{gsub(LIB, ""); print}' |
					   awk '{gsub(":+",":"); print}' |
					   awk '{gsub("^:|:$",""); print}')
			
			if lib_test --is-archive "$lib"; then
				local opts="--quiet"
				[ $VERBOSE -eq 1 ] && opts="--verbose"
				lib_archive $opts --clean "$lib"
			fi
		done
	
		export LIB_PATH
	}
	
	__lib_path_reset()
	{
		[ $VERBOSE -eq 1 ] &&
			echo "LIB_PATH: Reset"
			
		export LIB_PATH=""
	}
	
	
	__lib_path_exit()
	{
		unset __lib_path_get
		unset __lib_path_set
		unset __lib_path_find
		unset __lib_path_add
		unset __lib_path_list
		unset __lib_path_remove
		unset __lib_path_reset
		unset __lib_path_exit
		
		return $1
	}
	
	case "$CMD" in
	RESET)  __lib_path_reset      ;;
	LIST)   __lib_path_list       ;;
	FIND)   __lib_path_find   "$1";;
	ADD)    __lib_path_add    "$@";;
	REMOVE) __lib_path_remove "$@";;
	SET)    __lib_path_set    "$@";;
	GET|*)  __lib_path_get    "$@";;
	esac
	
	__lib_path_exit $?
}



### LIBRARY NAMING SECTION #####################################################

# Restituisce il nome di una libreria o di un modulo a partire dal file o dalla
# cartella.
#
# Se l'argomento è nullo o il file o cartella non esiste
lib_name()
{
	__lib_name_usage()
	{
		local CMD="$1"

		(cat <<END
NAME
	${CMD:=lib_name} - Restituisce il nome della libreria.

SYNOPSIS
	$CMD  <lib_path>|<dir_path|<archive_path>
	
	
DESCRIPTION
	Il comando $CMD converte il path delle libreria (file, directory, archivio),
	nel nome associato secondo le regole di naming. 
	
	
OPTIONS
	-p, --add-libpath
	    Aggiuge temporaneamente una nuova lista di path di libreria a quelli presenti
	    nella variabile d'ambiente LIB_PATH.
	
	-P, --libpath
	    Imposta temporaneamente una nuova lista di path di libreria, invece di quelli 
	    presenti nella variabile d'ambiente LIB_PATH.
	
	-h| --help
	    Stampa questo messaggio ed esce.
	
NAMING
	_____________________________________________________
	
	Conversion Sintax:
	
	- Library File:
	    <lib_file_name>.$LIB_EXT  ==>  <lib_file_name>
	    
	- Library Directory:
	    <lib_dir_name>  ==>  <lib_dir_name>[:|/]
	
	- Library Archive:
	    <lib_arc_name>.$ARC_EXT  ==>  <lib_arc_name>@
	_____________________________________________________
	
	EXAMPLE:
	
	> LIB_PATH=lib
	
	> ls lib
	  core/ 
	  core.lsa 
	  core.lsf
	> lib_name lib/core.lsf
	  core
	> lib_name lib/core.lsa
	  core@
	> lib_name lib/core
	  core:
	  
	  # Per riferirsi al contenuto di un archivio
	> lib_name lib/core/archive.lsa:/cui/term.lsf
	  core:archive@:cui:term
	  
END
		
		) | less
		
		return 0
	}
	
	[ $# -eq 0 -o -z "$*" ] && return 1
	
	local ARGS=$(getopt -o hp:P:vV -l help,add-libpath:,libpath:,verbose,no-verbose -- "$@")
	eval set -- $ARGS
	
	#echo "NAME ARGS=$ARGS" > /dev/stderr
	
	local libpath=""
	local add_libpath=1
	local VERBOSE=0
	
	while true ; do
		case "$1" in
		-p|--add-libpath)  libpath="${2} ${libpath}"  ; shift  2;;
		-P|--libpath)      libpath="$2"; add_libpath=0; shift  2;;
		-v|--verbose)      VERBOSE=1                  ; shift   ;;
		-V|--no-verbose)   VERBOSE=0                  ; shift   ;;
		-h|--help)         __lib_name_usage $FUNCNAME ; return 0;;
		--) shift;;
		*) break;;
		esac
	done
	
	local LIB_NAME=""
	local lib="$1"
	local sublib=""
	
	if [ $add_libpath -eq 1 ]; then
		libpath="${libpath} $(lib_path --list --absolute-path --real-path)"
	fi
	
	if echo "$lib" | grep -q -E -e"[.]$ARC_EXT"; then
		
		local regex="^.*.$ARC_EXT"
		
		sublib="$(echo "$lib" | awk -v S="$regex" '{gsub(S,""); print}')"
		lib="$(echo "$lib" | grep -o -E -e "$regex")"
	fi
	
	
	lib=$(__lib_get_absolute_path "$lib")
	
	local dirs=""
	
	for libdir in ${libpath}; do
		
		[ "$lib" == $libdir ] && return 3
		
		dirs="$dirs|$libdir"
	done
	
	dirs=${dirs#|}
	
	CMD="echo \"${lib}${sublib}\" |
	       awk '{ gsub(\"^($dirs)/\",\"\");    print }' | 
	       awk '{ gsub(\"(:|/)+\",\"/\");      print }' | 
	       awk '{ gsub(\"[.]$ARC_EXT\",\"@\"); print }' |
	       awk '! /[.]$LIB_EXT\$/ { printf \"%s/\n\", \$0 }
	              /[.]$LIB_EXT\$/ { gsub(\"[.]$LIB_EXT\$\",\"\"); print}' |
	       tr / :"
	
	LIB_NAME=$(eval "$CMD")
	
	if [ $VERBOSE -eq 1 ]; then
		echo "Il nome associato al file di libreria '$1' è il seguente:"
	fi
	
	echo $LIB_NAME
}



### LIBRARY ARCHIVE SECTION ####################################################

# Costruisce un archivio o ne visualizza il contenuto.
lib_archive()
{
	
	__lib_archive_usage()
	{
		local CMD="$1"
		
		(cat << END
NAME
	${CMD:=lib_archive} - Crea e gestice gli archivi di libreria.

SYNOPSIS
	Create command:
	    $CMD [OPTIONS] -c|--create|--build [-d|--dir .]             [lib.$ARC_EXT]
	    $CMD [OPTIONS] -c|--create|--build [-d|--dir .]              <archive_name>.$ARC_EXT
	    $CMD [OPTIONS] -c|--create|--build [-d|--dir <archive_name>] <archive_name>
	    $CMD [OPTIONS] -c|--create|--build  -d|--dir <dir>           <archive_name>[.$ARC_EXT]
	    $CMD [OPTIONS] -c|--create|--build  -d|--dir <dir>          [<dir>.$ARC_EXT]
	    
	    $CMD [OPTIONS] -c|--create|--build <archive_name>[.$ARC_EXT]:<dir>
	    $CMD [OPTIONS] -c|--create|--build <archive_name>.$ARC_EXT(:|/):<dir>
	
	
	Check command:
	    $CMD [OPTIONS] [NAMING_OPTIONS] -C|--check   <archive_file>[.$ARC_EXT]
	    
	    $CMD [OPTIONS] [NAMING_OPTIONS] -y|--verify  <archive_name>@
	
	
	List command:
	    $CMD [OPTIONS] [NAMING_OPTIONS] -l|--list  <archive_file>[.$ARC_EXT]
	    $CMD [OPTIONS] [NAMING_OPTIONS] -L|--ls    <archive_name>@
	
	
	Search command:
	    $CMD [OPTIONS] [NAMING_OPTIONS] -s|--search -m|--library <lib_file>  <archive_file>
	    $CMD [OPTIONS] [NAMING_OPTIONS] -s|--search  <archive_file>[:|/]<lib_file>
	    
	    $CMD [OPTIONS] [NAMING_OPTIONS] -f|--find    <archive_name>@[:]<lib_name>
	
	Extract command:
	    $CMD [OPTIONS] [NAMING_OPTIONS] [EXTRACT OPTIONS] [-d|--dir <dir>] -x|--extract [-m|--library <lib_file>]  <archive_file>
	    $CMD [OPTIONS] [NAMING_OPTIONS] [EXTRACT OPTIONS] [-d|--dir <dir>] -x|--extract  <archive_file>[[:|/]<lib_file>]
	    
	    $CMD [OPTIONS] [NAMING_OPTIONS] [EXTRACT OPTIONS] [-d|--dir DIR] -u|--unpack  <archive_name>@
	
	Clear command:
	    $CMD [OPTIONS] [NAMING_OPTIONS] --clean       [<archive_file>]
	    $CMD [OPTIONS] [NAMING_OPTIONS] --clean-temp  [<archive_file>]
	    $CMD [OPTIONS] [NAMING_OPTIONS] --clean-track [<archive_file>]
	
	    $CMD [OPTIONS] [NAMING_OPTIONS] --clean       [<archive_name>@]
	    $CMD [OPTIONS] [NAMING_OPTIONS] --clean-temp  [<archive_name>@]
	    $CMD [OPTIONS] [NAMING_OPTIONS] --clean-track [<archive_name>@]


DESCRIPTION
	Il comando $CMD crea e gestisce un archivio di libreria.


GENERIC OPTIONS
	-h, --help
	    Stampa questa messaggio e esce.
	
	-p, --add-libpath
	    Aggiuge temporaneamente una nuova lista di path di libreria a quelli presenti
	    nella variabile d'ambiente LIB_PATH.
	
	-P, --libpath
	    Imposta temporaneamente una nuova lista di path di libreria, invece di quelli 
	    presenti nella variabile d'ambiente LIB_PATH.
	
	-q, --quiet
	    Non stampa nulla sullo standard output.
	
	-Q, --no-quiet
	    Stampa infomazioni essenziali.
	
	-v, --verbose
	    Stampa informazioni dettagliate.
	
	-V, --no-verbose
	    Non stampa informazioni dettagliate.

COMMAND OPTIONS
	-c, --create, --build
	    Crea un nuovo archivio di libreria
	
	-C, --check
	    Controlla se il file passato come parametro è un archivio di librerie
	
	-y, --verify
	    Equivale a: --naming --check o in breve -nC
	
	-l, --list
	    Stampa la lista dei file e delle directory contenute nell'archivio di librerie
	
	-L, --ls
	    Equivale a: --naming --list  o in breve -nl
	
	-s, --search
	    Verifica se il file o la directory specificata come parametro è contenuto
	    all'interno dell'archivio di libreria.
	
	-f, --find
	    Equivale a: --naming --search o in breve -ns
	
	-x, --extract
	    Estrae il contenuto dell'archivio di librerie nella directory specificata.
	
	-u, --unpack
	    Equivale a: --naming --extract o in brave -nx
	
	--clear-temp
	    Senza parametri, cancella tutte le cartelle temporanee in /tmp/lst-*
	    Se viene passato l'indentificativo di un archivio, cancella solamente
	    la cartella temporanea associata a quest'ultimo, se esiste.
	
	--clear-track
	    Senza parametri, svuota la mappa per il tracking degli archivi estratti.
	    Se viene passato l'indentificativo di un archivio, cancella solamente
	    l'entri della mappa associata a quest'ultimo, se esiste.
	
	--clear
	    Equivale a: --clear-temp --clear-track

CREATE OPTIONS
	-d, --dir DIR
	    Imposta la directory ch

SEARCH OPTIONS
	-m, --library LIB_PATH
	    Imposta la libreria da ricercare all'interno dell'archivio.

EXTRACT OPTIONS
	-d, --dir DIR
	    Imposta la directory di estrazione per l'archivio.
	
	-m, --library LIB_PATH
	    Imposta la libreria da estrarre dall'archivio.
	
	-t, --temp-dir
	    Abilita la creazione automatica di una directory temporanea di estrazione.
	    Le directory temporanee seguono il seguente pattern: /tmp/lsf-[PID]-XXXXXXXX.
	
	--no-temp-dir (default)
	    Disabilita la creazione automatica di una directory temporanea di estrazione.
	
	-T, --track
	    Abilita la modalità di tracciamento.
	    Il comando salva nella variabile d'ambieante LIB_ARC_MAP la coppia 
	    archivio e directory di estrazione, considerando i path assoluti.
	
	--no-track  (default)
	    Disabilità la modalità di tracciamento.
	
	-r, --clean-dir
	    Rimuove il contenuto della cartella, prima di effettuare l'estrazione.
	
	-R, --no-clean-dir (default)
	    Non rimuove il contenuto della cartella, prima di effettuare l'estrazione.
	
	-F, --force
	    Anche se la modalità di tracking è attiva, forza l'estrazione dell'archivio.
	
	--no-force (default)
	    Non forza l'estrazione quando l'archivio è già stato tracciato come estratto.

NAMING OPTIONS
	-n, --naming
	    Abilita la modalità di naming.
	    Converte il nome di una libreria nei corrispondente path.
	    @see lib_name --help: NAMING SECTION
	
	-N, --no-naming   (default)
	    Disabilita la modalità di naming.
	
	-a, --auto-naming (default)
	    Abilita automaticamente la modalità naming se nel parametro di input compare '@'.
	
	-A, --no-auto-naming
	    Disabilita la modalità automatica di naming.

END
		) | less
		return 0
	}
	
	local ARGS=$(getopt -o CyclLhsfxud:nNvVqQrRtTFp:P:m:aAD -l check,verify,create,build,list,ls,search,find,extract,unpack,dir:,help,naming,no-naming,temp-dir,no-temp-dir,track,no-track,clean-dir,no-clean-dir,quiet,no-quiet,verbose,no-verbose,force,no-force,clean,clean-temp,clean-track,libpath:,add-libpath:,library:,auto-naming,no-auto-naming,diff -- "$@")
	eval set -- $ARGS
	
	#echo "ARCHIVE ARGS=$ARGS" > /dev/stderr
	
	local LIB_FILE=""
	local DIR=""
	local TMP=0
	local TRACK=0
	local REALPATH=0
	local FORCE=0
	local QUIET=0
	local VERBOSE=0
	local CMD=""
	local SEARCH=0
	local CLEAN_DIR=0
	local CLEAN_TEMP=0
	local CLEAN_TRACK=0
	local libpath=
	local tar_verbose=
	local libpath=
	local FIND_OPTS=
	local NAMING=0
	local AUTO_NAMING=1
	
	while true ; do
		case "$1" in
		-c|--create|--build) CMD="CREATE"                          ; shift    ;;
		-C|--check)          CMD="CHECK"                           ; shift    ;;
		-y|--verify)         CMD="CHECK"; NAMING=1                 ; shift    ;;
		-l|--list)           CMD="LIST"                            ; shift    ;;
		-L|--ls)             CMD="LIST"; NAMING=1                  ; shift    ;;
		-x|--extract)        CMD="EXTRACT"                         ; shift    ;;
		-u|--unpack)         CMD="EXTRACT"; NAMING=1               ; shift    ;;
		-s|--search)         CMD="SEARCH"                          ; shift    ;;
		-f|--find)           CMD="SEARCH"; NAMING=1                ; shift    ;;
		-D|--diff)           CMD="DIFF"                            ; shift    ;;
		-m|--library)        LIB_FILE="$2"                         ; shift   2;;
		-n|--naming)         NAMING=1                              ; shift    ;;
		-N|--no-naming)      NAMING=0                              ; shift    ;;
		-a|--auto-naming)    AUTO_NAMING=1                         ; shift    ;;
		-A|--no-auto-naming) AUTO_NAMING=0                         ; shift    ;;
		-p|--add-libpath)    libpath="${2}:${LIB_PATH}"            ; shift   2;;
		-P|--libpath)        libpath="$2"                          ; shift   2;;
		--clean-temp)        CMD="CLEAN";
		                     CLEAN_TEMP=1                          ; shift    ;;
		--clean-track)       CMD="CLEAN";
		                     CLEAN_TRACK=1                         ; shift    ;;
		--clean)             CMD="CLEAN";
		                     CLEAN_TEMP=1;
		                     CLEAN_TRACK=1                         ; shift    ;;
		-d|--dir)            DIR="$2"                              ; shift   2;;
		-t|--temp-dir)       TMP=1                                 ; shift    ;;
		--no-temp-dir)       TMP=0                                 ; shift    ;;
		-T|--track)          TRACK=1                               ; shift    ;;
		--no-track)          TRACK=0                               ; shift    ;;
		-r|--clean-dir)      CLEAN_DIR=1                           ; shift    ;;
		-R|--no-clean-dir)   CLEAN_DIR=0                           ; shift    ;;
		-F|--force)          FORCE=1                               ; shift    ;;
		--no-force)          FORCE=0                               ; shift    ;;
		-q|--quiet)          QUIET=1   ;FIND_OPTS="$FIND_OPTS $1"  ; shift    ;;
		-Q|--no-quiet)       QUIET=0   ;FIND_OPTS="$FIND_OPTS $1"  ; shift    ;;
		-v|--verbose)        VERBOSE=1 ;FIND_OPTS="$FIND_OPTS $1"  ; shift    ;;
		-V|--no-verbose)     VERBOSE=0 ;FIND_OPTS="$FIND_OPTS $1"  ; shift    ;;
		-h|--help) __lib_archive_usage "$FUNCNAME"                 ; return  0;;
		--) shift; break;;
		esac
	done
	
	if [ -z "$CMD" ]; then
		echo "$FUNCNAME: nessun comando specificato."
		echo
		echo "La lista dei comandi è la seguente:"
		echo "-c --create --build"
		echo "-C --check"
		echo "-y --verify"
		echo "-l --list"
		echo "-D --diff"
		echo "-L --ls"
		echo "-s --search"
		echo "-f --find"
		echo "-x --extract"
		echo "-u --unpack"
		echo "--clean"
		echo "--clean-temp"
		echo "--clean-track"
		echo
		echo "Usa $FUNCNAME -h o $FUNCNAME --help per ulteriori informazioni."
		return 1
	fi
	
	
	__lib_archive_create()
	{
		[ $# -eq 0 ] && return 1
		
		local DIR="$1"
		local ARCHIVE_FILE="$2"
		
		
		[ $QUIET -eq 0 -o $VERBOSE -eq 1 ] && 
		(echo "Creazione archivio di librerie: $ARCHIVE_FILE"
		 echo "Library directory: $DIR")
		
		ARCHIVE_FILE="$(__lib_get_absolute_path "$ARCHIVE_FILE")"
		
		if [ ! -d "$DIR" ]; then
			if [ $QUIET -eq 0 -o $VERBOSE -eq 1 ]; then
				echo "La directory '$DIR' non esiste."
				echo "Creazione archivio fallita!"
			fi
			return 2
		fi
		
		local tar_opts=
		[ $VERBOSE -eq 1 ] && tar_opts="-v"
		(cd "$DIR" && tar $tar_opts -czf "$ARCHIVE_FILE" * 2> /dev/null);
		
		local exit_code=$?
		
		if [ $QUIET -eq 0 -o $VERBOSE -eq 1 ]; then
			if [ $exit_code -eq 0 ]; then
				echo "Creazione archivio completata con successo!"
			else
				echo "Creazione archivio fallita!"
			fi
		fi
		
		return $exit_code
	}
	
	__lib_is_archive()
	{
		[ $# -eq 0 ] && return 1
		
		local verbose=0
		
		[ $QUIET -eq 0 -o $VERBOSE -eq 1 ] && verbose=1
		[ $QUIET -eq 1 ]                   && verbose=0
		
		if [ "$1" == "-q" ]; then
			verbose=0
			shift
		fi
		
		[ -f "$1" ] && 
		echo "$1" | grep -q ".$ARC_EXT" && 
		file --mime-type "$1" | grep -q "gzip"
		
		local exit_code=$?
		
		if [ $verbose -eq 1 ]; then
			if [ $exit_code -eq 0 ]; then
				echo "Il file '$1' è un archivio di libreria"
			else
				echo "Il file '$1' non è un archivio di libreria"
			fi
		fi
		
		return $exit_code
	}
	
	__lib_archive_list()
	{
		[ $# -gt 0 ] && __lib_is_archive -q "$1"  || return 1 
		
		local ARCHIVE_NAME=$(__lib_get_absolute_path "$1")
		
		if [ $VERBOSE -eq 1 ]; then
			echo "Librerie dell'archivio '$1':"
		fi
		
		tar -tzf "$ARCHIVE_NAME" | awk '{gsub("^[.]?/?",""); print}'
	}
	
	__lib_archive_diff_list()
	{
		[ $# -gt 1 ] || return 1
		
		(cd "$2" && tar -dzf "$1" "$3" 2>&1 | awk '{gsub ("tar: ",""); print}' | awk -F: '{print $1}' | sort | uniq)
	}
	
	__lib_archive_diff()
	{
		[ $# -gt 1 ] && __lib_is_archive -q "$1"  || return 1
		
		local ARCHIVE_NAME=$(__lib_get_absolute_path "$1")
		
		(cd "$2" && tar -dzf "$ARCHIVE_NAME" "$3" > /dev/null 2>&1)
		local exit_code=$?
		
		
		if [ $exit_code -eq 0 ]; then
			[ $QUIET -eq 0 -a $VERBOSE -eq 1 ] &&
			echo "Librerie contenute nella directory '$2' non differisco da quelle dell'archivio '$1'."
		else
			if [ $QUIET -eq 0 ]; then
				[ $VERBOSE -eq 1 ] &&
				echo "Librerie contenute nella directory '$2' che differisco da quelle dell'archivio '$1':"
				__lib_archive_diff_list "$ARCHIVE_NAME" "$2" "$3"
			fi
		fi
		
		return $exit_code
	}
	
	__lib_archive_search()
	{
		[ $# -gt 0 ] && __lib_is_archive -q "$1"  || return 1 
		
		local ARCHIVE_NAME=$(__lib_get_absolute_path "$1")
		local LIB="$2"
		
		if [ $TRACK -eq 1 ]; then
			local arc_dir="${LIB_ARC_MAP[$ARCHIVE_NAME]}"
			
			[ -n "$arc_dir" ] && echo "$arc_dir"
			
			return 0
		fi
		
		if [ -z "$LIB" ]; then
			
			[ $QUIET -eq 1 ] || echo "$ARCHIVE_NAME"
			return 0
		fi
		
		
		[ $VERBOSE -eq 1 ] &&
		echo -n "Ricerca della libreria '$LIB' nell'archivio '$1': "
		
		local libfile=""
		for libfile in $(__lib_archive_list "$ARCHIVE_NAME"); do
			if [ "$2" == "$libfile" ]; then
				[ $VERBOSE -eq 1 ] && echo "trovato!"
				if [ $QUIET -eq 0 ]; then
					if [ $REALPATH -eq 1 -a -n "${LIB_ARC_MAP[$ARCHIVE_NAME]}" ]; then
						echo "${LIB_ARC_MAP[$ARCHIVE_NAME]}:$LIB"
					else
						echo "$ARCHIVE_NAME:$LIB"
					fi
				fi
				return 0
			elif [ "$2.$LIB_EXT" == "$libfile" ]; then
				[ $VERBOSE -eq 1 ] && echo "trovato!"
				if [ $QUIET -eq 0 ]; then
					if [ $REALPATH -eq 1 -a -n "${LIB_ARC_MAP[$ARCHIVE_NAME]}" ]; then
						echo "${LIB_ARC_MAP[$ARCHIVE_NAME]}:$LIB.$LIB_EXT"
					else
						echo "$ARCHIVE_NAME:$LIB.$LIB_EXT"
					fi
				fi
				return 0
			elif [ "$2.$ARC_EXT" == "$libfile" ]; then
				[ $VERBOSE -eq 1 ] && echo "trovato!"
				if [ $QUIET -eq 0 ]; then
					if [ $REALPATH -eq 1 -a -n "${LIB_ARC_MAP[$ARCHIVE_NAME]}" ]; then
						echo "${LIB_ARC_MAP[$ARCHIVE_NAME]}:$LIB.$ARC_EXT"
					else
						echo "$ARCHIVE_NAME:$LIB.$ARC_EXT"
					fi
				fi
				return 0
			fi
		done
		
		[ $VERBOSE -eq 1 ] && echo "non trovato!"
		
		return 1
	}
	
	
	__lib_archive_extract()
	{
		[ $# -gt 1 ] && __lib_is_archive -q "$2"  || return 1
		
		local DIR="$1"
		local ARCHIVE_NAME=$(__lib_get_absolute_path "$2")
		local LIB="$3"
		
		[ "$DIR" == "--" ] && DIR=
		#echo "Extract:"           > /dev/stderr
		#echo "DIR=$DIR"           > /dev/stderr
		#echo "ARC_NAME=$ARC_NAME" > /dev/stderr
		#echo "LIB=$lIB"           > /dev/stderr
		
		local diff_list=
		#local old_mod_time=0
		#local new_mod_time=$(stat -c %Y $ARCHIVE_NAME)
		local exit_code=1
		
		if [ $TRACK -eq 1 -a -z "$DIR" ]; then
			
			[ $VERBOSE -eq 1 ] &&
			echo "Verifica se l'archivio '$2' è già stato estratto..."
			
			DIR="${LIB_ARC_MAP[$ARCHIVE_NAME]}"
			
			if [ -n "$DIR" ]; then 
				
				if [ ! -d "$DIR" ]; then
					
					[ $VERBOSE -eq 1 ] &&
					echo "La directory '$DIR' è stata rimossa o il file non è una directory."
					
					unset LIB_ARC_MAP[$ARCHIVE_NAME]
				else
					[ $VERBOSE -eq 1 ] &&
					echo "Directory trovata: $DIR"
					
					diff_list=$(__lib_archive_diff_list "$ARCHIVE_NAME" "$DIR" "$LIB")
					
					#old_mod_time=$(stat -c %Y "$DIR")
					
					#if [ ${new_mod_time} -gt ${old_mod_time:=0} ]; then
					if [ -n "$diff_list" ]; then
						
						[ $VERBOSE -eq 1 ] &&
						echo "L'archivio è stato modificato, la directory non è valida!"
						
						#[ $? -eq 0 -a $VERBOSE -eq 1 ] &&
						#echo "Rimozione del contenuto della cartella associata all'archivio."
						#rm -r "$DIR/*"
					elif [ $FORCE -eq 0 ]; then
						
						[ $VERBOSE -eq 1 ] &&
						echo "Estrazione di file dall'archivio non necessaria."
						
						if [ $QUIET -eq 0 ]; then
							__lib_list_dir "$DIR" #| awk -v DIR="$DIR" '{printf "%s/%s\n", DIR, $0}'
						fi
						
						return 0
					fi
				fi
			else
				[ $VERBOSE -eq 1 ] &&
				echo "Directory non trovata"
			fi
		fi
		
		if [ $TMP -eq 1 ] && [ -z "$DIR" -o ! -d "$DIR" ]; then
			
			DIR=$(mktemp --tmpdir -d lsf-$$-XXXXXXXX)
			
			[ $VERBOSE -eq 1 ] &&
			echo "Creata nuova cartella temporanea per l'archivio': '$DIR'"
		fi
		
		if [ -z "$DIR" ]; then
			DIR=$(basename "$ARCHIVE_NAME" | awk -v S=".$ARC_EXT" '{gsub(S,""); print}')
		fi
		
		if [ ! -d "$DIR" ]; then
			
			[ $VERBOSE -eq 1 ] &&
			echo "La directory '$DIR' non esiste e verrà creata."
			
			mkdir -p "$DIR"
			
			if [ $? -ne 0 ]; then
				[ $VERBOSE -eq 1 ] &&
				echo "Impossibile creare la directory '$DIR' per l'estrazione."
			
				return
			fi
			
		elif [ $CLEAN_DIR -eq 1 ]; then
			
			[ $? -eq 0 -a $VERBOSE -eq 1 ] &&
			echo "Rimozione del contenuto della cartella associata all'archivio."
			
			rm -r $DIR/* 2> /dev/null
		fi
		
		if [ $VERBOSE -eq 1 ]; then
			if [ -z "$LIB" ]; then
				echo -en "Estrazione dell'"
			else
				echo -en "Estrazione della libreria '$LIB' dall'"
			fi
			echo -e "archivio '$2' nella directory: $DIR\n"
		fi
		
		
		# Estazione dell'archivio
		tar -xzvf "$ARCHIVE_NAME" -C "$DIR" "$LIB" 2> /dev/null | 
		if [ $QUIET -eq 0 ]; then
			awk -v DIR="$DIR" 'BEGIN {print DIR } {printf "%s/%s\n", DIR, $0}'
		else
			cat > /dev/null
		fi
		
		local exit_code=$?
		
		if [ $VERBOSE -eq 1 ]; then
			if [ $exit_code -eq 0 ]; then
				echo -e "\nCompletata con successo!"
			else
				echo -e "\nEstrazione fallita!"
			fi
		fi
		
		if [ $TRACK -eq 1 ]; then
			LIB_ARC_MAP[$ARCHIVE_NAME]="$(__lib_get_absolute_path "$DIR")"
			if [ $VERBOSE -eq 1 ]; then
				echo "Salvataggio della directory corrente di estarzione nella mappa degli archivi."
				echo "LIB_ARC_MAP[$ARCHIVE_NAME]=${LIB_ARC_MAP[$ARCHIVE_NAME]}"
			fi
		fi
		
		return $exit_code
	}
	
	__lib_archive_clean()
	{
		local ARCHIVE_NAME=""
		
		[ -n "$1" ] && ARCHIVE_NAME=$(__lib_get_absolute_path "$1")
		
		if [ $CLEAN_TEMP -eq 1 ]; then
			
			if [ -z "$ARCHIVE_NAME" ]; then
				
				[ $QUIET -eq 0 ] &&
				lsf_log "Rimozione delle directory temporanee."
				
				local tmp_dir=
				
				for tmp_dir in $(ls -1d /tmp/lsf-* 2> /dev/null); do
					
					rm -r "$tmp_dir" 2> /dev/null
					[ $VERBOSE -eq 1 ] && (
					[ $? -eq 0 ] && echo -n "[OK] " || echo -n "[KO] "
					echo "Remove directory: $tmp_dir")
				done
			else
				local tmp_dir="${LIB_ARC_MAP[$ARCHIVE_NAME]}"
				
				if [ -n "$tmp_dir" -a -d "$tmp_dir" ]; then
					[ $QUIET -eq 0 ] &&
					lsf_log "Rimozione delle directory temporanea dell'archivio '$ARCHIVE_NAME'."
					rm -r "$tmp_dir" 2> /dev/null
				else
					[ $VERBOSE -eq 1 ] &&
					echo "Rimozione delle directory temporanea dell'archivio '$ARCHIVE_NAME' fallita."
				fi
			fi
		fi
		
		if [ $CLEAN_TRACK -eq 1 ]; then
			if [ -z "$ARCHIVE_NAME" ]; then
				[ $QUIET -eq 0 ] &&
				lsf_log "Pulizia della mappa degli archivi."
				
				LIB_ARC_MAP=()
			else
				[ $QUIET -eq 0 ] &&
				lsf_log "Rimozione dalla mappa degli archivi, del track di '$ARCHIVE_NAME'."
				
				unset LIB_ARC_MAP[$ARCHIVE_NAME]
			fi
		fi
	}
	
	__lib_archive_exit()
	{
		unset __lib_is_archive
		unset __lib_archive_list
		unset __lib_archive_create
		unset __lib_archive_diff
		unset __lib_archive_diff_list
		unset __lib_archive_search
		unset __lib_archive_extract
		unset __lib_archive_clean
		unset __lib_archive_exit
		
		return $1
	}
	
	
	#echo -e "Input: $1\n" > /dev/stderr
	
	if [ $NAMING -eq 0 -a $AUTO_NAMING -eq 1 ]; then
		echo $1 | grep -q "@" && NAMING=1
	fi
	
	
	local ARC_FILE="$1"
	
	if [ $NAMING -eq 1 ]; then
		
		#echo "Naming: enabled"
		
		local ARC_NAME=$(echo ${ARC_FILE} | awk '{gsub(":","/"); gsub("@.*$",""); printf "%s@\n", $0}')
		local LIB_NAME=$(echo ${ARC_FILE} | awk -v A="^$ARC_NAME" '{  gsub(A,""); print }')
		
		#echo "- ARC_NAME=$ARC_NAME" > /dev/stderr
		#echo "- LIB_NAME=$LIB_NAME" > /dev/stderr
		
		[ -n "$ARC_NAME" ] && ARC_FILE="${ARC_NAME/@/.$ARC_EXT}"
		
		if [ -n "$LIB_NAME" ]; then
			LIB_FILE=$(echo ${LIB_NAME//://} | awk -v E=".$ARC_EXT/" '
		               {  gsub("@", E); 
		                  gsub("//","/");
		                  gsub("^/",""); 
		                  print
		               }' | awk -v AE="[.]$ARC_EXT[/]$" -v AES=".$ARC_EXT" -v LE="$LIB_EXT" '
		               ! /[/]$/ { printf "%s.%s\n", $0, LE } 
		                 /[/]$/ { gsub(AE,AES); print      }')
		fi 
		
		for libdir in ${libpath//:/ }; do
		
			if [ -f "${libdir}/$ARC_FILE" ]; then
				ARC_FILE="${libdir}/$ARC_FILE"
				break
			fi
		done
	else
		
		#echo "Naming: disabled"
		
		local regex="^[^:]+(.$ARC_EXT|:)"
		local lib_file=
		
		lib_file="$(echo "$ARC_FILE" | awk -v S="${regex}/?" '{gsub(S,""); print}')"
		lib_file="${lib_file#/}"
		[ -z "$LIB_FILE" ] && LIB_FILE="$lib_file"
		
		ARC_FILE="$(echo "$ARC_FILE" | grep -o -E -e "$regex")"
		ARC_FILE=${ARC_FILE%:}
	fi
	
	#echo "- ARC_FILE=$ARC_FILE" > /dev/stderr
	#echo "- LIB_FILE=$LIB_FILE" > /dev/stderr
	#echo "- DIR=$DIR" > /dev/stderr
	#echo
	
	if echo $LIB_FILE | grep -q -E -e ".+[.]$ARC_EXT.+$"; then
		
		[ $QUIET -eq 0 -o $VERBOSE -eq 1 ] && (
 		echo "WARNING: LIB_FILE=$LIB_FILE"
 		echo "         Scanning of archive content in archive not yet implemented!")
		return 3
	fi
	
	if [ "$CMD" == "CREATE" ]; then
		
		[ -z "$DIR" -a -n "$LIB_FILE" -a -e "$LIB_FILE" ] &&
		DIR="$LIB_FILE"
		
		[ -z "$ARC_FILE" -a -n "$DIR" ] && 
		ARC_FILE="$(basename "$DIR").$ARC_EXT"
	fi
	
	if [ -z "$ARC_FILE" -a "$CMD" != "SEARCH" ]; then
		[ -z "$DIR" -a -n "$LIB_FILE" ] &&
		ARC_FILE="$LIB_FILE.$ARC_EXT"
		LIB_FILE=""
	fi
	
	if [ "$CMD" == "CREATE" ]; then
		ARC_FILE="${ARC_FILE:=lib.$ARC_EXT}"
		DIR="${DIR:=.}"
	fi
	
	if [ -n "$ARC_FILE" ]; then
		if ! echo $ARC_FILE | grep -q ".$ARC_EXT$"; then
			ARC_FILE="$ARC_FILE.$ARC_EXT"
		fi
	else
		ARC_FILE="lib.$ARC_EXT"
	fi
	
	#echo "Output:"
	#echo "- ARC_FILE=$ARC_FILE" > /dev/stderr
	#echo "- LIB_FILE=$LIB_FILE" > /dev/stderr
	#echo "- DIR=$DIR" > /dev/stderr
	#return
	
	case "$CMD" in
	CHECK)   __lib_is_archive      "$ARC_FILE";;
	LIST)    __lib_archive_list    "$ARC_FILE";;
	DIFF)    __lib_archive_diff "$ARC_FILE" "${DIR:=.}" "$LIB_FILE";;
	CREATE)  __lib_archive_create  "${DIR:=.}" "$ARC_FILE";;
	SEARCH)  __lib_archive_search  "$ARC_FILE" "$LIB_FILE";;
	EXTRACT) __lib_archive_extract "${DIR:=--}" "$ARC_FILE" "$LIB_FILE";;
	CLEAN)   __lib_archive_clean "$1";;
	esac
	
	__lib_archive_exit $?
}


# Trova il file associato ad una libreria o ad una cartella
# lib_find
lib_find()
{
	__lib_find_usage()
{
	local CMD="$1"

	(cat <<END
NAME
	${CMD:=lib_find} - Restituisce il path della libreria passato come parametro.

SYNOPSIS
	$CMD [OPTIONS] [dir:...][archive@:][dir:...]<lib_name>
	
	$CMD [OPTIONS] -f|--file <lib_file>
	
	$CMD [OPTIONS] -d|--dir <lib_dir>
	
DESCRIPTION
	Il comando $CMD trova il path associato ad una libreria, sia essa file o cartella.
	
	
OPTIONS
	
	-f, --file
	    Verifica se il file di libreria esiste, senza eseguire operazioni di naming.
	    Se il file non esiste, ritorna un exit code pari a 1, altrimenti ritorna 0
	    e ne stampa il path sullo standard output (se l'optione quiet non è specificata).
	
	-d, --dir
	    Verifica se la directory specificata dal path esiste, senza eseguire
	    operazioni di naming.
	    Se la directory non esiste, ritorna un exit code pari a 1, altrimenti ritorna 0
	    e ne stampa il path sullo standard output (se l'optione quiet non è specificata).
	
	-a, --archive  ARCHIVE_PATH[:LIB_PATH]
	    Verifica se l'archivio specificato, o il file contenuto in esso, esiste, senza eseguire
	    operazioni di naming.
	    Se l'archivio, o il file in esso specificato, non esiste, ritorna un exit code pari a 1, 
	    altrimenti ritorna 0 e ne stampa il path sullo standard output 
	    (se l'optione quiet non è specificata).
	
	-p, --add-libpath
	    Aggiuge temporaneamente una nuova lista di path di libreria a quelli presenti
	    nella variabile d'ambiente LIB_PATH.
	
	-P, --libpath
	    Imposta temporaneamente una nuova lista di path di libreria, invece di quelli 
	    presenti nella variabile d'ambiente LIB_PATH.
	
	-F, --first
	    Ritorna il primo path di libreria che corrisponde al nome di libreria cercato.
	
	-A, --all
	    Ritorna tutti i path di libreria che corrispondono al nome di libreria cercato.
	
	-q, --quiet
	    Non stampa il path sullo standard output.
	
	-Q, --no-quiet
	    Se trova il file, lo stampa sullo standard output.
	
	
LIBRARY NAMING
	
	Il comando $CMD di default associa ad ogni file di libreria un nome.
	Una libreria potrebbe essere o un file o una cartella contenente altri file
	di libreria.
	
	Il nome di una libreria è così costruito:
	- se il file o la cartella di libreria ha una directory genitrice che si trova 
	  nella variabile LIB_PATH, questa è eliminata dal path.
	- se la libreria è un file l'estensione '.$LIB_EXT' viene omessa.
	- Optionalmente il carattere '/' può essere sostituito dal carattere ':'
	
	
EXAMPLES
	
	Se la libreria cercata è, ad esempio, 'math:sin', il comanando cerchera
	all'interno di ogni cartella della variabile LIB_PATH, o il file 'math/sin.$LIB_EXT'
	oppure la cartella math/sin.
	
	
	~ > LIB_PATH=$HOME/lib1:$HOME/lib2       oppure  
	~ > lib_path_set $HOME/lib1:$HOME/lib2   oppure
	~ > lib_path_add $HOME/lib1
	~ > lib_path_add $HOME/lib2
	
	~ > ls -R lib1
	    lib1/:
	    a.lib b.lib dir1
	    lib1/dir1:
	    c.lib dir2
	    lib1/dir1/dir2
	    d.lib f.lib 
	    ls -R lib2
	    lib2/:
	    g.lib
	
	~ > $CMD a
	    $HOME/lib1/a.lib (return 0)
	
	~ > $CMD b
	    $HOME/lib1/b.lib (return 0)
	
	~ > $CMD g
	    $HOME/lib2/g.lib (return 0)
	
	~ > $CMD dir1
	    $HOME/lib1/dir1 (return 0)
	
	~ > $CMD dir1:c          oppure     $CMD dir1/c
	    $HOME/lib1/dir1/c.lib (return 0)
	
	~ > $CMD dir1:dir2       oppure     $CMD dir1/dir2
	    $HOME/lib1/dir1/dir2 (return 0)
	
	~ > $CMD dir1:dir2:d     oppure     $CMD dir1/dir2/d
	    $HOME/lib1/dir1/dir2/d.lib (return 0)
	
	~ > $CMD dir1:dir2:f     oppure     $CMD dir1/dir2/f
	    $HOME/lib1/dir1/dir2/f.lib (return 0)
	
	~ > $CMD --file lib2/g.lib
	    $HOME/lib2/g.lib (return 0)
	
	~ > $CMD --file lib1/g.lib
	    (return 1)

	~ > $CMD --dir lib1/dir1
	    $HOME/lib1/dir1 (return 0)
	
	~ > $CMD --dir lib2/dir1
	    (return 1)
	
END
		) | less
		return 0
}

	[ $# -eq 0 -o -z "$*" ] && return 1
	
	local ARGS=$(getopt -o hf:d:a:p:P:FAqQvV -l help,file:,dir:,archive:,add-libpath:,libpath:,first,all,quiet,no-quiet,verbose,no-verbose -- "$@")
	eval set -- $ARGS
	
	#echo "FIND ARGS=$ARGS" > /dev/stderr
	
	local QUIET=0
	local libpath=""
	local ARCHIVE_MODE=0
	local VERBOSE=0
	local opts=
	local add_path=1
	local FIND_ALL=0
	
	while true ; do
		case "$1" in
		-q|--quiet)        QUIET=1; opts="$opts $1"   ; shift   ;;
		-Q|--no-quiet)     QUIET=0                    ; shift   ;;
		-p|--add-libpath)  libpath="$2"; add_path=1   ; shift  2;;
		-P|--libpath)      libpath="$2"; add_path=0   ; shift  2;;
		-f|--file) 
			[ -f "$2" ] && echo $2 | grep -q -E -e "[.]$LIB_EXT$" || return 1
			[ $QUIET -eq 1 ] || echo "$2" #__lib_get_absolute_path "$2"
			return 0;;
		-d|--dir)
			[ -d "$2" ] || return 1
			[ $QUIET -eq 1 ] || echo "$2" #__lib_get_absolute_path "$2"
			return 0;;
		-a|--archive)      ARCHIVE_MODE=1             ; shift   ;;
		-F|--first)        FIND_ALL=0                 ; shift   ;;
		-A|--all)          FIND_ALL=1                 ; shift   ;;
		-v|--verbose)      VERBOSE=1; opts="$opts $1" ; shift   ;;
		-V|--no-verbose)   VERBOSE=0                  ; shift   ;;
		-h|--help)         __lib_find_usage $FUNCNAME ; return 0;;
		--) shift;;
		*) break;;
		esac
	done
	
	#return 1
	
	local LIB="${1//://}"
	
	if [ $ARCHIVE_MODE -eq 1 ]; then
		lib_archive --no-quiet $opts --search $LIB
		
		return $?
	fi
	
	if [ $add_path -eq 1 ]; then
		#libpath="$libpath:$LIB_PATH"
		#libpath="$libpath:$(lib_path --list)"
		#libpath="$libpath:$(lib_path --list --absolute-path)"
		#libpath="$libpath:$(lib_path --list --real-path)"
		
		libpath="$libpath:$(lib_path --list --absolute-path --real-path)"
	fi
	
	
	local libdir=
	local exit_code=1
	
	for libdir in ${libpath//:/ }; do
		
		if [ -d "${libdir}/$LIB" ]; then
			
			[ $QUIET -eq 1 ] || echo ${libdir}/$LIB
			
			[ $FIND_ALL -eq 0 ] && return 0
			
			exit_code=0
			
		elif [ -f "${libdir}/$LIB.$LIB_EXT" ]; then
			
			[ $QUIET -eq 1 ] || echo  ${libdir}/$LIB.$LIB_EXT
			
			[ $FIND_ALL -eq 0 ] && return 0
			
			exit_code=0
			
		elif echo "$LIB" | grep -q "@"; then
			
			local lib="$LIB"
			local regex="^.*@"
			
			LIB="$(echo "$lib" | grep -o -E -e "$regex" | awk '{gsub("@",""); print}').$ARC_EXT"
			SUB_LIB="$(echo "$lib" | awk -v S="$regex" '{gsub(S,""); print}')"
			SUB_LIB="${SUB_LIB#/}"
			
			lib_archive --no-quiet $opts --search "${libdir}/$LIB:$SUB_LIB"
			
			[ $FIND_ALL -eq 0 ] && return 0
			
			exit_code=$?
		fi
	done
	
	return $exit_code
}


# Applica alla lista di librerie passate come parametri la funzione specificata,
# restituendo l'exit code relativo all'esecuzione di quest'ultima.
#
# library function definition:
#
# function_name() { ... }
#
# ES.
# > lib_set lib
#
# > function fun() { echo "$1 -> $2"; } # function definition
# >
# > lib_apply [-F|--lib-function] fun a mod mod:c
#   a -> lib/a.lib
#   mod -> lib/mod
#   mod:c -> lib/mod/c.lib
#
# > cd lib
# > lib_apply [-F|--lib-function] fun [-f|--file] a.lib mod/c.lib
#   a.lib -> lib/a.lib
#   mod/c.lib -> lib/mod/c.lib
#
# > cd lib
# > lib_apply [-F|--lib-function] fun [-d|--dir] mod
#   mod -> lib/mod
#
lib_apply()
{
	[ $# -eq 0 ] && return 1
	
	__lib_apply_usage()
	{
		local CMD="$1"
		
		(cat <<END
NAME
	${CMD:=lib_apply} - Trova la libreria e applica una funzione specifica su di essa.
	
SYNOPSIS
	$CMD [OPTIONS] [dir:...][archive_name@[:]][dir:...]<lib_name>
	
	$CMD [OPTIONS] -f|--file    <lib_file_path>
	
	$CMD [OPTIONS] -d|--dir     <lib_dir_path>
	
	$CMD [OPTIONS] -a|--archive <lib_arc_path>
	
	
DESCRIPTION
	Il comando $CMD trova il path associato ad una libreria, sia essa file o cartella o archivio,
	e applica ai suddetti file una funzione definita dall'utente e passata come parametro.
	
	
OPTIONS
	-F, --lib-function
	    Funzione applicata alla libreria se viene trovata.
	    Sono disponibili due variabili: LIB_NAME e LIB_FILE (quest'ultimo passato come parametro).
	
	-E, --lib-error-function
	    Funzione applicata alla libreria se non viene trovata.
	    Sono disponibili due variabili: LIB_FILE e LIB_NAME (quest'ultimo passato come parametro)
	
	-f, --file
	    Verifica se il file di libreria esiste, senza eseguire operazioni di naming.
	    Se il file esiste, viene applicata la funzione specificata, altrimenti la funzione di error.
	
	-d, --dir
	    Verifica se la directory specificata dal path esiste, senza eseguire
	    operazioni di naming.
	    Se la directory esiste, viene applicata la funzione specificata, altrimenti la funzione di error.
	
	-a, --archive  
	    Verifica se l'archivio specificato dal path esiste, senza eseguire
	    operazioni di naming.
	    Se l'archivio esiste, viene applicata la funzione specificata, altrimenti la funzione di error.
	
	-h| --help
	    Stampa questo messaggio ed esce.
	
END
		) | less
		
		return 0
	}
	
	local ARGS=$(getopt -o h,F:E:fdaqQ -l help,lib-function:,lib-error-function:,file,dir,archive,quiet,no-quiet -- "$@")
	eval set -- $ARGS
	
	local LIB_FILE=
	local LIB_NAME=
	local SUB_LIB=
	local FIND_OPT=""
	local exit_code=
	local QUIET=0
	
	local IS_ARC=0
	local LIB_FUN="__lib_apply_default_lib_function"
	local ERR_FUN="__lib_apply_default_lib_error_function"
	
	
	while true ; do
		case "$1" in
		-F|--lib-function)       LIB_FUN="$2"   ; shift  2;;
		-E|--lib-error-function) ERR_FUN="$2"   ; shift  2;;
		-f|--file)               FIND_OPT="$1"  ; shift   ;;
		-d|--dir)                FIND_OPT="$1"  ; shift   ;;
		-a|--archive) IS_ARC=1;  FIND_OPT="$1"  ; shift   ;;
		-q|--quiet)              QUIET=1        ; shift   ;;
		-Q|--no-quiet)           QUIET=0        ; shift   ;;
		-h|--help) __lib_apply_usage $FUNCNAME  ; return 0;;
		--) shift;;
		*) break;;
		esac
	done
	
	__lib_apply_default_lib_function()
	{
		if [ $QUIET -eq 0 ]; then
			echo "$LIB_NAME=$LIB_FILE"
		fi
		
		test -n "$1"
	
	}
	
	__lib_apply_default_lib_error_function()
	{
		[ $# -eq 0 ] && return 0
		
		if [ $QUIET -eq 0 ]; then
			echo "Library '$1' not found!"
		fi
		
		return 1
	}
	
	[ -z "LIB_FUN" ] && return
	
	exit_code=0
	
	for LIB_NAME in "$@"; do
		LIB_FILE=$(lib_find $FIND_OPT $LIB_NAME)
		
		if [ -n "$LIB_FILE" ]; then
			
			if [ $IS_ARC -eq 1 ]; then
				LIB_FILE=$(lib_archive --no-verbose --no-quiet --clean-dir --track --temp-dir --extract "$LIB_FILE" | 
				           awk 'NR==1 {print}') 
				
				# WARNING: Il comando lib_archive viene eseguito un una subshell
				# per cui modifiche alla variabile LIB_ARC_MAP non verranno salvate.
			fi
		
			# esecuzione della user function
			$LIB_FUN "$LIB_FILE"
			
			exit_code=$((exit_code+$?))
			
			if [ $IS_ARC -eq 1 ]; then
				# rimozione dei file temporanei creati, se non erano stati
				# precedentemente mappati
				local path=
				local found=0
				for path in ${LIB_ARC_MAP[@]}; do
					if [ "$LIB_FILE" == "$path" ]; then
						found=1
						break
					fi
				done
			
				[ $found -eq 0 ] && rm -rf $LIB_FILE 2> /dev/null 
			fi
		else
			[ -n "$ERR_FUN" ] && $ERR_FUN "$LIB_NAME"
			
			exit_code=$((exit_code+1))
		fi
	done
	
	unset __lib_apply_default_lib_function
	unset __lib_apply_default_lib_error_function
	
	return $exit_code
}

# Implementa una serie di operatori booleani.
lib_test()
{
	__lib_test_usage()
	{
		local CMD="$1"
		
		(cat << END
NAME
	${CMD:=lib_test} - Esegue test sulla libreria.

SYNOPSIS
	$CMD [OPTIONS] -e|--is-enabled               <lib_name>
	
	$CMD [OPTIONS] -e|--is-enabled -f|--file     <lib_file_path>
	
	$CMD [OPTIONS] -e|--is-enabled -d|--dir      <lib_dir_path>
	
	$CMD [OPTIONS] -e|--is-enabled -a|--archive  <lib_arc_path>
	
	
	$CMD [OPTIONS] -i|--is-installed               <lib_name>
	
	$CMD [OPTIONS] -i|--is-installed -f|--file     <lib_file_path>
	
	$CMD [OPTIONS] -i|--is-installed -d|--dir      <lib_dir_path>
	
	$CMD [OPTIONS] -i|--is-installed -a|--archive  <lib_arc_path>
	
	
	$CMD [OPTIONS] -l|--is-loaded               <lib_name>
	
	$CMD [OPTIONS] -l|--is-loaded -f|--file     <lib_file_path>
	
	$CMD [OPTIONS] -l|--is-loaded -d|--dir      <lib_dir_path>
	
	$CMD [OPTIONS] -l|--is-loaded -a|--archive  <lib_arc_path>
	
	
	
	$CMD [OPTIONS] -f|--file|--is-file        <lib_file_path>
	
	$CMD [OPTIONS] -d|--dir|--is-dir          <lib_dir_path>
	
	$CMD [OPTIONS] -a|--archive|--is-archive  <lib_arc_path>
	
	
	$CMD -h|--help
	
	
DESCRIPTION
	Il comando $CMD gestisce e manipola la variabile d'ambiente LIB_PATH del framework LSF.
	
	
GENERIC OPTIONS
	
	-e, --is-enabled
	    Verifica se una libreria è abilitata.
	
	-i, --is-installed
	    Verifica se una libreria è installata in una delle directory di LIB_PATH.
	
	-l, --is-loaded
	    Verifica se una libreria è stata importata nell'ambiente corrente.
	
	-f, --is-file
	    Verifica se la libreria è un file.
	
	-d, --is-dir
	    Verifica se la libreria è una directory.
	
	-a, --is-archive
	    Verifica se la libreria è un archivio.
	
	-v, --verbose
	    Stampa informazioni dettagliate.
	
	-V, --no-verbose
	    Non stampa informazioni dettagliate.
	
	-A, --absolute-path
	    Converte i path relativi in assoluti.
	
	-h, --help
	    Stampa questa messaggio e esce.
	
END
		) | less
		
		return 0
	}
	
	[ $# -eq 0 ] && return 1
	
	
	local FIND_OPT=""
	local QUIET="--quiet"
	local VERBOSE=0
	
	__lib_is_enabled()
	{
		[ -z "$1" ] && return 2
		test -x "$1"
	}
	
	# Restituisce un exit code pari a 0 se la libreria passata come parametro è
	# presente nel path, altrimenti 1.
	__lib_is_installed()
	{
		[ -z "$1" ] && return 1
		#test -e "$1"
		return 0
	}
	
	# Restituisce un exit code pari a 0 se la libreria passata come parametro è
	# stata importata, altrimenti 1.
	__lib_is_loaded()
	{
		[ -z "$1" ] && return 2
		echo "$(__lib_list_files)" | grep -E -q -e "$1"
	}
	
	__lib_test_exit()
	{
		unset __lib_is_enabled
		unset __lib_is_installed
		unset __lib_is_loaded
		unset __lib_test_exit
		
		return $1
	}
	
	local ARGS=$(getopt -o heilfdaqQvV -l help,is-enabled,is-installed,is-loaded,file,dir,archive,is-file,is-dir,is-archive,quiet,no-quiet,verbose,no-verbose -- "$@")
	eval set -- $ARGS
	
	local TEST="EXIST"
	
	while true ; do
		case "$1" in
		-e|--is-enabled)    TEST="ENABLED"             ; shift;;
		-i|--is-installed)  TEST="INSTALLED"           ; shift;;
		-l|--is-loaded)     TEST="LOADED"              ; shift;;
		-f|--file)          FIND_OPT="$1"              ; shift;;
		-d|--dir)           FIND_OPT="$1"              ; shift;;
		-a|--archive)       FIND_OPT="$1"              ; shift;;
		--is-file)          TEST="EXIST";FIND_OPT="-f" ; shift;;
		--is-dir)           TEST="EXIST";FIND_OPT="-d" ; shift;;
		--is-archive)       TEST="EXIST";FIND_OPT="-a" ; shift;;
		-q|--quiet)         QUIET="$1"                 ; shift;;
		-Q|--no-quiet)      QUIET="$1"                 ; shift;;
		-v|--verbose)       VERBOSE=1; QUIET="-Q"      ; shift;;
		-V|--no-verbose)    VERBOSE=0; QUIET="-q"      ; shift;;
		-h|--help)          __lib_test_usage $FUNCNAME ;
		                    __lib_test_exit  $?        ; return  0;;
		--) shift;;
		*) break;;
		esac
	done
	
	local FUN=
	local LIB="$1"
	
	case "$TEST" in
	ENABLED)           FUN="__lib_is_enabled";;
	LOADED)            FUN="__lib_is_loaded";;
	EXIST|INSTALLED)   FUN="__lib_is_installed";;
	esac
	
	lib_apply $QUIET --lib-function $FUN $FIND_OPT "$LIB"
	
	__lib_test_exit $?
}


# Abilita una libreria per l'import.
lib_enable()
{
	__lib_enable_usage()
	{
		local CMD="$1"
		
		(cat <<END
NAME
	${CMD:=lib_enable} - Abilita una libreria per l'importazione.
	
SYNOPSIS
	$CMD [OPTIONS] <lib_name>
	
	$CMD [OPTIONS] -f|--file    <lib_file_path>
	
	$CMD [OPTIONS] -d|--dir     <lib_dir_path>
	
	$CMD [OPTIONS] -a|--archive <lib_arc_path>
	
	
DESCRIPTION
	Il comando $CMD abilita una libreria (file, directory o archivio) per l'importazione.
	
	
OPTIONS
	-f, --file
	    Il parametro è il path di un file di libreria.
	
	-d, --dir
	    Il parametro è il path di una directory di libreria.
	
	-a, --archive  
	    Il parametro è il path di un archivio di libreria.
	
	-q, --quiet
	    Disabilita la stampa di messaggi nel log.
	
	-Q, --no-quiet
	    Abilita la stampa di messaggi nel log.
	
	-h| --help
	    Stampa questo messaggio ed esce.
END
		) | less
	}
	
	local ARGS=$(getopt -o hqQ -l help,quiet,no-quiet -- "$@")
	eval set -- $ARGS
	
	local QUIET=0
	
	while true ; do
		case "$1" in
		-q|--quiet)     QUIET=1                      ; shift   ;;
		-Q|--no-quiet)  QUIET=0                      ; shift   ;;
		-h|--help)    __lib_enable_usage $FUNCNAME   ; return 0;;
		--) shift;;
		*) break;;
		esac
	done
	
	__lib_enable()
	{
		[ -n "$1" ] || return 1
		
		chmod a+x $1
		
		[ $QUIET -eq 0 ] &&
		lsf_log "Enable library: $LIB_NAME"
		
	}
	
	__lib_not_found() { [ $QUIET -eq 0 ] && lsf_log "Library '$1' not found!"; }
	
	lib_apply --lib-function __lib_enable --lib-error-function __lib_not_found $*
	
	local exit_code=$?
	
	unset __lib_enable
	unset __lib_not_found
	
	return $exit_code
}



# Disabilita una libreria per l'import.
lib_disable()
{
	__lib_disable_usage()
	{
		local CMD="$1"
		
		(cat <<END
NAME
	${CMD:=lib_disable} - Disabilita una libreria per l'importazione.
	
SYNOPSIS
	$CMD [OPTIONS] <lib_name>
	
	$CMD [OPTIONS] -f|--file     <lib_file_path>
	
	$CMD [OPTIONS] -d|--dir      <lib_dir_path>
	
	$CMD [OPTIONS] -a|--archive  <lib_arc_path>
	
	
DESCRIPTION
	Il comando $CMD disabilita una libreria (file, directory o archivio) per l'importazione.
	
	
OPTIONS
	-f, --file
	    Il parametro è il path di un file di libreria.
	
	-d, --dir
	    Il parametro è il path di una directory di libreria.
	
	-a, --archive  
	    Il parametro è il path di un archivio di libreria.
	
	-q, --quiet
	    Disabilita la stampa di messaggi nel log.
	
	-Q, --no-quiet
	    Abilita la stampa di messaggi nel log.
	
	-h| --help
	    Stampa questo messaggio ed esce.
END
		) | less
	}
	
	local ARGS=$(getopt -o hqQ -l help,quiet,no-quiet -- "$@")
	eval set -- $ARGS
	
	while true ; do
		case "$1" in
		-q|--quiet)     QUIET=1                      ; shift   ;;
		-Q|--no-quiet)  QUIET=0                      ; shift   ;;
		-h|--help)    __lib_disable_usage $FUNCNAME  ; return 0;;
		--) shift;;
		*) break;;
		esac
	done
	
	__lib_disable()
	{
		[ -n "$1" ] || return 1
		
		chmod a-x $1
		
		[ $QUIET -eq 0 ] &&
		lsf_log "Disable library: $LIB_NAME"
	}
	
	__lib_not_found() { [ $QUIET -eq 0 ] && lsf_log "Library '$1' not found!"; }
	
	lib_apply --lib-function __lib_disable --lib-error-function __lib_not_found $*
	
	local exit_code=$?
	
	unset __lib_disable
	unset __lib_not_found
	
	return $exit_code
}



# Importa una libreria nell'ambiente corrente.

LIB_IMPORT=1
LIB_IMPORT_ALL=0

lib_import()
{
	[ $LIB_IMPORT -eq 1 ] || return 0
	
	__lib_import_usage()
	{
		local CMD=$1
		(cat << END
NAME
	${CMD:=lib_import} - Importa librerie nell'ambiente corrente.

SYNOPSIS
	$CMD
	
	$CMD [OPTIONS] <lib_name>
	
	$CMD [OPTIONS] -f|--file <lib_file>
	
	$CMD [OPTIONS] [-r|--recursive] -d|--dir <lib_dir>
	
	
	$CMD -i|--include    ( alias lib_include )
	
	$CMD -u|--update     ( alias lib_update  )
	
	$CMD -l|--list
	$CMD -L|--list-files
	$CMD -R|--list-clear
	
DESCRIPTION
	Il comando $CMD... 
	
OPTIONS
	
	-f, --file
	    Importa il file di libreria, specificandone il path, senza eseguire operazioni di naming.
	    Se il file non esiste, ritorna un codice di errore.
	
	-d, --dir
	    Importa gli script contenuti nella cartella specificata dal path,
	    senza eseguire operazioni di naming.
	    Se l'optione 'include' non è specificata, importa solo gli script abilitati,
	    altrimenti importa tutti gli script con estensione '.$LIB_EXT'.
	    (see: LIBRARY NAMING section of lib_find)
	
	-a, --archive
	    Importa gli script contenuti nella cartella specificata dal path,
	    senza eseguire operazioni di naming.
	    Se l'optione 'include' non è specificata, importa solo gli script abilitati,
	    altrimenti importa tutti gli script con estensione '.$LIB_EXT'.
	    (see: LIBRARY NAMING section of lib_find)
	
	-r, --recursive
	    Se la libreria è una cartella, importa ricorsivamente gli script nella cartella
	    e nelle sue sottocartelle.
	
	-i, --include
	    Importa una libreria senza controllare se è abilitata o meno.
	    (see: LIBRARY ACTIVATION section)
	
	-c, --check
	    Evita di importare la libreria se questa è gia stata precedentemente importata
	    nell'ambiente corrente. Qualora il sorgente della libreria è stato modificato
	    dopo l'import, questa viene importata nuovamente sovrascrivento la precedente
	    definizione.
	
	-C, --no-check
	    Importa la libreria anche se questa è già stata importata precedentemente.
	
	-F, --force
	    Forza l'import della libreria, non effettuando alcun controllo.
	    Equivale a: --include --no-check
	
	-q, --quiet
	    Disabilita la stampa dei messaggi nel log. (see: lsf_log funtions)
	
	-Q, --no-quiet
	    Abilita la stampa dei messaggi nel log. (see: lsf_log funtions)
	
	-p, --add-libpath
	    Aggiuge temporaneamente una nuova lista di path di libreria a quelli presenti
	    nella variabile d'ambiente LIB_PATH.
	
	-P, --libpath
	    Imposta temporaneamente una nuova lista di path di libreria, invece di quelli 
	    presenti nella variabile d'ambiente LIB_PATH.
	
	-s, --fast
	    Attiva la modalità fast quando è attiva l'opzione --all.
	    Disabilita i comandi di import o include per i sorgenti caricati nell'ambiente.
	    Non sicura se ci sono librerie dipendenti da librerie non attivate.
	    @see lib_enable, lib_disable
	
	-S, --no-fast
	    Disattiva la modalità fast quando è attiva l'opzione --all. (default)
	
	-D, --dummy
	    Esegue tutte le operazioni di checking, ma non importa la libreria.
	
	-h, --help
	    Stampa questo messaggio ed esce.
	
	
	Command list:
	
	-A, --all
	    Importa tutte le librerie abilitate presenti nei path della variabile
	    d'ambiente LIB_PATH.
	
	-u, --update
	    Se necessario, ricarica tutte le librerie importate se sono stati modificati
	    i sorgenti.
	
	-l, --list
	    Stampa l'elenco dei nomi di libreria importati nell'ambiente corrente.
	
	-L, --list-files
	    Stampa l'elenco dei nomi dei file di libreria importati nell'ambiente corrente.
	
	-R, --list-clear
	    Svuota la lista delle librerie attuamelmente importate.
	
	
LIBRARY ACTIVATION

	see: lib_enable, lib_disable, lib_test --is-enabled
	

EXAMPLES
	
	~ > LIB_PATH=$HOME/lib1:$HOME/lib2       oppure  
	~ > lib_path_set $HOME/lib1:$HOME/lib2   oppure
	~ > lib_path_add $HOME/lib1
	~ > lib_path_add $HOME/lib2
	
	~ > ls -R lib1
	    lib1/:
	    a.lib b.lib dir1
	    lib1/dir1:
	    c.lib dir2
	    lib1/dir1/dir2
	    d.lib f.lib 
	    ls -R lib2
	    lib2/:
	    g.lib
	
	~ > $CMD a
	    importa il file: lib1/a.lib
	
	~ > $CMD b
	    importa il file: lib1/b.lib
	
	~ > $CMD g
	    importa il file: lib2/g.lib
	
	~ > $CMD dir1
	    importa il file: lib1/dir1/c.lib
	
	~ > $CMD -r dir1
	    importa i files: lib1/dir1/c.lib, lib1/dir1/dir2/d.lib, lib1/dir1/dir2/f.lib
	
	~ > $CMD dir1:c          oppure     $CMD dir1/c
	    importa il file: lib1/dir1/c.lib
	
	~ > $CMD dir1:dir2       oppure     $CMD dir1/dir2
	    importa i files: lib1/dir1/dir2/d.lib, lib1/dir1/dir2/f.lib
	
	~ > $CMD dir1:dir2:d     oppure     $CMD dir1/dir2/d
	    importa il file: lib1/dir1/dir2/d.lib
	
	~ > $CMD dir1:dir2:f     oppure     $CMD dir1/dir2/f
	    importa il file: lib1/dir1/dir2/f.lib
	
	
END
) | less
	}
	
	local ARGS=$(getopt -o hfdircCuDqQlLRFaAp:P:sSvV -l help,file,dir,archive,include,recursive,check,no-check,update,dummy,quiet,no-quiet,list,list-files,list-clear,force,all,libpath:,add-libpath:,fast,no-fast,verbose,no-verbose -- "$@")
	eval set -- $ARGS
	
	#echo "___________________________________________________"
	#echo $ARGS
	
	local ALL=0
	local LIB=""
	local LIB_FILE=""
	local LIB_PATH_OPT=""
	local FIND_OPT=""
	local OPTIONS=""
	local INCLUDE=0
	local RECURSIVE=0
	local CHECK=1
	local UPDATE=0
	local DUMMY=0
	local QUIET=0
	local VERBOSE=0
	local FAST=0
	
	while true ; do
		
		case "$1" in
		-A|--all)        ALL=1                                        ; shift  ;;
		-f|--file)       FIND_OPT="$1"                                ; shift  ;;
		-d|--dir)        FIND_OPT="$1"                                ; shift  ;;
		-a|--archive)    FIND_OPT="$1"                                ; shift  ;;
		-r|--recursive)  RECURSIVE=1;        OPTIONS="$OPTIONS $1"    ; shift  ;;
		-c|--check)      CHECK=1;            OPTIONS="$OPTIONS $1"    ; shift  ;;
		-C|--no-check)   CHECK=0;            OPTIONS="$OPTIONS $1"    ; shift  ;;
		-i|--include)    INCLUDE=1;          OPTIONS="$OPTIONS $1"    ; shift  ;;
		-q|--quiet)      QUIET=1             OPTIONS="$OPTIONS $1"    ; shift  ;;
		-Q|--no-quiet)   QUIET=0             OPTIONS="$OPTIONS $1"    ; shift  ;;
		-v|--verbose)    VERBOSE=1           OPTIONS="$OPTIONS $1"    ; shift  ;;
		-V|--no-verbose) VERBOSE=0           OPTIONS="$OPTIONS $1"    ; shift  ;;
		-D|--dummy)      DUMMY=1;            OPTIONS="$OPTIONS $1"    ; shift  ;;
		-F|--force)      CHECK=0; INCLUDE=1; OPTIONS="$OPTIONS -C -i" ; shift  ;;
		-s|--fast)       FAST=1                                       ; shift  ;;
		-S|--no-fast)    FAST=0                                       ; shift  ;;
		-p|--add-libpath)  LIB_PATH_OPT="$1 $2"                       ; shift 2;;
		-P|--libpath)      LIB_PATH_OPT="$1 $2"                       ; shift 2;;
		-l|--list)       __lib_list_names      ; return ;; 
		-L|--list-files) __lib_list_files      ; return ;;
		-R|--list-clear)
			lib_archive --clean
			__lib_list_files_clear;
			return 0;;
		-h|--help)     __lib_import_usage $FUNCNAME;  return 0;; 
		-u|--update)     UPDATE=1                                     ; break  ;;
		--) shift;;
		-*) echo "Usa $FUNCNAME -h oppure $FUNCNAME --help per ulteriori informazioni";
		    return 1;;
		*) break;;
		esac
	done
	
	
	# lib_import --all invocation
	if [ $ALL -eq 1 ]; then
		
		[ $FAST -eq 1 ] && LIB_IMPORT_ALL=1
		
		for dir in $(lib_path --list --absolute-path --real-path)
		do
			$FUNCNAME $OPTIONS $LIB_PATH_OPT --recursive --dir $dir
		done
		
		LIB_IMPORT_ALL=0
		
		return 0
	fi
	
	# lib_import --update invocation
	if [ $UPDATE -eq 1 ]; then
		
		for lib_loaded in $(__lib_list_files); do
			$FUNCNAME $LIB_PATH_OPT --include --check --file "$lib_loaded"
		done
		
		return 0
	fi
	
	if [ $# -eq 0 ]; then
		FIND_OPT="--dir"
		LIB="."
	else
		LIB="$1"
	fi
	
	# verifica se la pathname expansion di bash è fallita
	echo "$LIB" | grep -q -E -e "[*][.]($LIB_EXT|$ARC_EXT)$" && return 3
	
	LIB_FILE=$(lib_find $LIB_PATH_OPT $FIND_OPT $LIB)
	
	if [ -z "$LIB_FILE" ]; then
		[ $QUIET -eq 1 ] || lsf_log "Library '$LIB' not found!"	
		return 1
	fi
	
	if echo "$LIB_FILE" | grep ":"; then
		SUB_LIB="$(echo "$LIB_FILE" | awk -F : '{ print $2 }')"
		LIB_FILE="$(echo "$LIB_FILE" | awk -F : '{ print $1 }')"
		#echo "LIB_FILE=$LIB_FILE, SUB_LIB=$SUB_LIB"
	fi
	
	if [ $INCLUDE -eq 0 -a ! -x "$LIB_FILE" ]; then
		[ $QUIET -eq 1 ] || lsf_log "Library '$LIB' disable!"
		return 2
	fi
	
	if [ -f "$LIB_FILE" ]; then  # se la libreria è un file o un'archivio
		
		if [ $CHECK -eq 0 ] ||
		   ! $(lib_test --is-loaded --file "$LIB_FILE") ||
		   [ $(stat -c %Y "$LIB_FILE") -gt $(__lib_list_files_get_mod_time "$LIB_FILE") ]; 
		then
			if [ $DUMMY -eq 1 ]; then
				# Stampa semplicemente il path della libreria.
				echo "$LIB_FILE"
				
			else # importa un file
			
				if ! file --mime-type "$LIB_FILE" | grep -q "gzip"; then
					
					[ $LIB_IMPORT_ALL -eq 1 ] && LIB_IMPORT=0
					source "$LIB_FILE"
					[ $LIB_IMPORT_ALL -eq 1 ] && LIB_IMPORT=1
					
					__lib_list_files_add "$LIB_FILE"
					
					[ $QUIET -eq 1 ] || lsf_log "Import library module:\t $LIB"
				
				else # importa un'archivio
					
					# Scompatta l'archivio in una directory temporanea, se non 
					# già stata associata all'archivio ne crea una nuova e ne 
					# tiene traccia.
					
					local opts="--quiet"
					
					#[ $QUIET   -eq 1 ] && opts="--quiet"
					[ $VERBOSE -eq 1 ] && opts="$opts --verbose"
					
					local lib_opts=
					
					[ -n "$SUB_LIB" ] && lib_opts="--library "$SUB_LIB""
					
					lib_archive $opts --clean-dir --track --temp-dir --extract "$LIB_FILE" $lib_opts
					
					local tmp_dir="${LIB_ARC_MAP[$LIB_FILE]}"
					
					lib_path --add "$tmp_dir"
					
					if [ -n "$SUB_LIB" ]; then
						local type_opt=
						
						if   echo "$SUB_LIB" | grep -q ".$LIB_EXT$"; then
							type_opt="--file"
						elif echo "$SUB_LIB" | grep -q ".$ARC_EXT$"; then
							type_opt="--archive"
						else
							type_opt="--dir"
						fi
						
						# importa un file dell'archivio
						$FUNCNAME $LIB_PATH_OPT $OPTIONS $type_opt  "${tmp_dir}/${SUB_LIB}"
					else
						# importa tutto l'archivio
						$FUNCNAME --recursive $LIB_PATH_OPT $OPTIONS --dir  "$tmp_dir"
					fi
					
					lib_path --remove "$tmp_dir"
				fi
			fi
		fi
		
		return 0
		
	elif [ -d "$LIB_FILE" ]; then # importa una directory
		
		local DIR="$LIB_FILE"
		
		[ $QUIET -eq 1 ] || lsf_log "Import library directory:\t $LIB_FILE"
		
		if [ $(ls -A1 "$DIR" | wc -l) -gt 0 ]; then
			
			# importa tutti i file di libreria
			for library in $DIR/*.$LIB_EXT; do
				if [ $INCLUDE -eq 1 -o -x $library ]; then
					$FUNCNAME $LIB_PATH_OPT $OPTIONS --file $library
				fi
			done
			
			# se in modalità ricorsiva
			if [ $RECURSIVE -eq 1 ]; then
			
				# importa tutte le directory
				for libdir in $DIR/*; do
					
					test -d $libdir || continue
					
					if [ $INCLUDE -eq 1 -o  -x "$libdir" ]; then
						$FUNCNAME $LIB_PATH_OPT $OPTIONS --dir $libdir
					else
						[ $QUIET -eq 1 ] || lsf_log "Library directory '$libdir' disable!"
					fi
				done
				
				# importa tutti gli archivi
				for library in $DIR/*.$ARC_EXT; do
					if [ $INCLUDE -eq 1 -o -x $library ]; then
						$FUNCNAME $LIB_PATH_OPT $OPTIONS --archive $library
					fi
				done
			fi
		fi
		
		return 0
	fi
}

#alias lib_include="lib_import --include"
#alias lib_update="lib_import --update"

lib_include() { lib_import -i $@; }

lib_update()  { lib_import -u $@; }


### List functions #############################################################

lib_list_apply()
{
	__lib_list_apply_usage()
	{
		local CMD="$1"
		
		(cat << END
NAME
	${CMD:=lib_test} - Applica una funzione definita dall'utente per file, directory, e archivi, navigando le cartelle specificate.
	
SYNOPSIS
	$CMD [-r|--recursive] -f|--function         <fun>     [DIR ...]
	
	$CMD [-r|--recursive] -l|--lib-function     <lib_fun> [DIR ...]
	
	$CMD [-r|--recursive] -d|--dir-function     <dir_fun> [DIR ...]
	
	$CMD [-r|--recursive] -a|--archive-function <arc_fun> [DIR ...]
	
	
	$CMD [-r|--recursive] [-f <arc_fun>] [-l <lib_fun>] [-d <dir_fun>] [-a <arc_fun>] [DIR ...]
	
	
	$CMD -h|--help
	
	
DESCRIPTION
	Il comando $CMD applica una funzione definita dall'utente per file, directory, e archivi,
	navigando le cartelle specificate.
	
OPTIONS
	-f, --function <fun_name>
	    Imposta una generica user function per file di libreria, directory e archivi.
	
	-l, --lib-function <lib_name>
	    Imposta una generica user function per file di libreria.
	
	-d, --dir-function <dir_name>
	    Imposta una generica user function per directory di libreria.
	
	-a, --archive-function <archive_name>
	    Imposta una generica user function per archivi di libreria.
	
	-r, --recursive
	    Naviga ricorsivamente le directory.
	
END
		) | less
		
		return 0
	}
	
	
	local ARGS=$(getopt -o rhf:d:l:a: -l recursive,help,function:,dir-function:,lib-function:,archive-function -- "$@")
	eval set -- $ARGS
	
	#echo "ARGS=$ARGS"
	
	local DIR_FUN=""
	local LIB_FUN=""
	local ARC_FUN=""
	local RECURSIVE=0
	local libset=""
	
	while true ; do
		case "$1" in
		-f|--function) LIB_FUN="$2";DIR_FUN="$2";ARC_FUN="$2 "; shift  2;;
		-d|--dir-function)     DIR_FUN="$2"                   ; shift  2;;
		-l|--lib-function)     LIB_FUN="$2"                   ; shift  2;;
		-a|--archive-function) ARC_FUN="$2"                   ; shift  2;;
		-r|--recursive)        RECURSIVE=1                    ; shift   ;;
		-h|--help)       __lib_list_apply_usage "$FUNCNAME"   ; return 0;;
		--) shift;;
		*) break;;
		esac
	done
	
	[ -z "$LIB_FUN" ] && [ -z "$DIR_FUN" ] && [ -z "$ARC_FUN" ] && retunr 2
	 
	__already_visited()
	{
		[ -n "$libset" ] || return 2
		
		for lib in ${libset//;/ }; do
			if [ "$1" = "$lib" ]; then
				return 0
			fi
		done
		
		return 1
	}
	__list_lib()
	{
		local DIR="$(__lib_get_absolute_path "$1")"
		local libdir=""
		local libname=""
		
		! lib_test -d "$DIR" || __already_visited "$DIR" && return 1
		
		[ -z "$DIR_FUN" ] || $DIR_FUN "$DIR"
		libset="$libset;$DIR"
		
		if [ $(ls -A1 "$DIR" | wc -l) -gt 0 ]; then
		
			if [ -n "$LIB_FUN" ]; then
				for library in $DIR/*.$LIB_EXT; do
					! lib_test --file "$library"  || 
					__already_visited $library && 
					continue
					
					$LIB_FUN "$library"
					libset="$libset;$library"
				done
			fi
			
			if [ -n "$ARC_FUN" ]; then
				for library in $DIR/*.$ARC_EXT; do
					 ! lib_test --archive "$library"  || 
					 __already_visited $library && 
					 continue
					
					$ARC_FUN "$library"
					libset="$libset;$library"
				done
			fi
			
			if [ $RECURSIVE -eq 1 ]; then
				for libdir in $DIR/*; do
					test -d $libdir || continue
					
					if [ -x "$libdir" ]; then
						$FUNCNAME "$libdir"
					fi
				done
			fi
		
		fi
	}
	
	local paths="$*"
	
	if [ $# -eq 0 ]; then
		
		paths="$(lib_path --list --absolute-path --real-path)"
		RECURSIVE=1
	fi
	
	for DIR in $paths; do
		
		test -d "$DIR" || continue
		
		__list_lib $DIR
	done
	
	unset __list_lib
}



# Mostra la lista delle librerie
#
# @see lib_name
# @see lib_list_apply
lib_list()
{
	__lib_list_usage()
	{
		local CMD="$1"
		
		(cat << END
NAME
	${CMD:=lib_test} - Stampa la lista delle librerie in una directory.
	
SYNOPSIS
	$CMD [OPTIONS]
	
	$CMD [OPTIONS] <dir...>
	
	
	$CMD -h|--help
	
	
DESCRIPTION
	Il comando $CMD stampa la lista delle librerie abilitate e importate in una directory,
	se non viene passato alcun paramentro, usa le directory della variabile LIB_PATH.
	
OPTIONS
	-n, --libname
	    Stampa i nomi delle librerie
	
	-f, --filename
	    Stampa i path dei file di libreria
	
	-l, --format-list
	    Stampa la lista formattata
	
	-L, --no-format-list
	    Stampa la lista non formattata
	
	-r, --recursive
	    Naviga la ricorsivamente le cartelle
	
	-m, --list-dir
	    Stampa anche informazioni sulle directory di libreria
	
	-M, --no-list-dir
	    Non stampa informazioni sulle directory di libreria
	
	-e, --only-enabled
	    Stampa solamente le librerie abilitate
	
	-d, --only-disabled
	    Stampa solamente le librerie disabilitate
	
	-h, --help
	    Stampa questo messaggio ed esce
	
	
END
		) | less
		
		return 0
	}
	
	local ARGS=$(getopt -o rednfhlLmM -l recursive,help,only-enabled,only-disable,filename,libname,format-list,no-format-list,list-dir,no-list-dir -- "$@")
	eval set -- $ARGS
	
	
	local OPTIONS=""
	local ONLY_ENABLED=0
	local ONLY_DISABLED=0
	local NAME=1
	local FORMAT=1
	local LIST_DIR=""
	local libset=""
	
	while true ; do
		case "$1" in
		-n|--libname)        NAME=1                              ; shift   ;;
		-f|--filename)       NAME=0                              ; shift   ;;
		-l|--format-list)    FORMAT=1                            ; shift   ;;
		-L|--no-format-list) FORMAT=0                            ; shift   ;;
		-r|--recursive)      OPTIONS="--recursive"               ; shift   ;;
		-m|--list-dir)       LIST_DIR="--dir-function __lib_fun" ; shift   ;;
		-M|--no-list-dir)    LIST_DIR=""                         ; shift   ;;
		-e|--only-enabled)   ONLY_ENABLED=1                      ; shift   ;;
		-d|--only-disabled)  ONLY_DISABLED=1                     ; shift   ;;
		-h|--help) __lib_list_usage $FUNCNAME                    ; return 0;;
		--) shift;;
		*) break;;
		esac
	done
	
	__lib_fun()
	{
		local library="$1"
		
		if [ $NAME -eq 1 ]; then
			libname=$(lib_name $library)
		else
			libname=$library
		fi
		
		[ -n "$libname" ] || return
		
		if [ -x $library ]; then
			if [ $ONLY_ENABLED -eq 1 -o $FORMAT -eq 0 ]; then
				echo "$libname"
			elif [ $ONLY_DISABLED -eq 0 ]; then
				echo "+$libname"
			fi
		else
			if [ $ONLY_DISABLED -eq 1 -o $FORMAT -eq 0  ]; then
				echo "$libname"
			elif [ $ONLY_ENABLED -eq 0 ]; then
				echo "-$libname"
			fi
		fi
	}
	
	lib_list_apply $OPTIONS $LIST_DIR --lib-function __lib_fun $*
	
	unset __lib_fun
}


# Restituisce le dipendenze di una libreria
lib_depend()
{
	__lib_depend_usage()
	{
		local CMD="$1"
		
		(cat << END
NAME
	${CMD:=lib_test} - Stampa la lista delle dipendenze di una librerie.
	
SYNOPSIS
	$CMD [OPTIONS]  <lib_name>
	
	$CMD [OPTIONS] -f|--file  <lib_file>
	
	
	$CMD [OPTIONS] -i|--inverse|--reverse  <lib_name>
	
	$CMD [OPTIONS] -i|--inverse|--reverse -f|--file  <lib_file>
	
	
	$CMD -h|--help
	
	
DESCRIPTION
	Il comando $CMD stampa la lista delle dipendenze di una librerie.
	
OPTIONS
	-f, --file 
	    La libreria è passato come path del file associato.
	
	-n, --libname
	    Stampa i nomi delle librerie (default)
	
	-m, --filename
	    Stampa i path dei file delle librerie
	
	-r, --recursive
	    Attiva la ricerca ricorsiva delle dipendenze (default)
	
	-R, --no-recursive
	    Disattiva la ricerca ricorsava delle dipendeze.
	
	-i, --inverse, --reverse
	    Abilità la modalità di ricerca inversa delle dipendenze.
	
	-I, --no-inverse, --no-reverse
	    Disabilità la modalità di ricerca inversa delle dipendenze. (default)
	
	-v, --verbose
	    Abilita la modalità verbosa dei messaggi.
	
	-V, --no-verbose
	    Disabilita la modalità verbosa dei messaggi. (defalut)
	
	-h, --help
	    Stampa questo messaggio ed esce
	
	
END
		) | less
		
		return 0
	}
	
	local ARGS=$(getopt -o hiIfmnhrRvV -l help,inverse,reverse,no-inverse,no-reverse,file,filename,libname,verbose,recursive,no-recursive,verbose,no-verbose -- "$@")
	eval set -- $ARGS
	
	local FIND_OPT=
	local NAME=1
	local RECURSIVE=1
	local REVERSE=0
	local VERBOSE=0
	
	while true ; do
		case "$1" in
		-f|--file)                    FIND_OPT="$1"   ; shift   ;;
		-n|--libname)                 NAME=1          ; shift   ;;
		-m|--filename)                NAME=0          ; shift   ;;
		-r|--recursive)               RECURSIVE=1     ; shift   ;;
		-R|--no-recursive)            RECURSIVE=0     ; shift   ;;
		-i|--inverse|--reverse)       REVERSE=1       ; shift   ;;
		-I|--no-inverse|--no-reverse) REVERSE=0       ; shift   ;;
		-v|--verbose)                 VERBOSE=1       ; shift   ;;
		-V|--no-verbose)              VERBOSE=0       ; shift   ;;
		-h|--help) __lib_depend_usage $FUNCNAME       ; return 0;;
		--) shift;;
		*) break;;
		esac
	done

	[ $# -eq 0 ] && return 1
	
	local LIB_FILE="$(lib_find $FIND_OPT "$1")"
	
	[ -n "$LIB_FILE" ] || return 2
	
	local DEPEND=
	
	__add_dependence()
	{
		[ $# -eq 0 ] && return 1
		
		DEPEND=$( echo -e "$DEPEND\n$1" |
			      grep -v -E -e '^$')
	}
	
	if [ $REVERSE -eq 0 ]; then
		
		__find_dependence()
		{
			[ $# -eq 0 ] && return 1
			
			echo "$DEPEND" | grep -E -q -e "$1"
		}
		
		__get_dependences()
		{
			[ -n "$1" -a -f "$1" ] || return 1
			
			local LIB_DEP=
			
			eval "LIB_DEP=($(cat "$1" | grep -E -e "lib_(import|include)" | 
			awk '{gsub("include","import -i"); print}' | tr ';' '\n' | 
			awk '{gsub(" *lib_import *",""); printf "\"%s\"\n", $0}' | tr \" \'))"
			
			local dep=
			local dep2=
			
			for dep in "${LIB_DEP[@]}"; do
				for dep2 in $(lib_import --quiet --force --dummy $dep); do
					if ! __find_dependence $dep2; then
						
						__add_dependence $dep2
						
						if [ $RECURSIVE -eq 1 ]; then
							$FUNCNAME $dep2
						fi
					fi
				done
			done
		}
		
		__get_dependences "$LIB_FILE"
		
		unset __find_dependence
		unset __get_dependences
		
		if [ $VERBOSE -eq 1 ]; then
			echo "Dipendenze trovate per la libreria '$1':"
		fi
		
	else
		__find_lib()
		{
			[ -n "$1" -a -f "$1" ] || return 1
			
			if cat "$1" | grep -E -e "lib_(import|include)" | grep -qo "$LIB_FILE"; then
				return 0
			fi
			
			local LIB_NAME="$(lib_name $LIB_FILE)"
			
			if cat "$1" | grep -E -e "lib_(import|include)" | grep -qo "$LIB_NAME"; then
				return 0
			fi
			
			return 1
		}
		
		
		for lib in $(lib_list --filename --no-format-list); do
			if __find_lib $lib; then
				__add_dependence $lib
			fi
		done
		
		unset __find_lib
		
		if [ $VERBOSE -eq 1 ]; then
			echo "Dipendenze inverse trovate per la libreria '$1':"
		fi
	fi
	
	if [ $NAME -eq 0 ]; then
		echo "$DEPEND" | grep -v -E -e '^$'
	else
		local dep=
		
		for dep in $DEPEND; do
			lib_name $dep
		done
	fi
	
	unset __add_dependences
	
}

lib_detect_collision()
{
	__lib_detect_collision()
	{
		local CMD="$1"
		
		(cat << END
NAME
	${CMD:=lib_test} - Verifica se ci sono delle collisioni nello spazio dei nomi.
	
SYNOPSIS
	$CMD [OPTIONS] [<libname> ...]
	
	$CMD -h|--help
	
	
DESCRIPTION
	Il comando $CMD verifica se ci sono delle collisioni nello spazio dei nomi.
	Utile per verificare che un nome sia univoco all'interno delle librerie.
	
OPTIONS
	-f, --print-files
	    Stampa i nomi delle librerie che collidono e i path dei file associati.
	
	-F, --no-print-files
	    Stampa solo i nomi delle librerie che collidono.
	
	-h, --help
	    Stampa questo messaggio ed esce
	
	
END
		) | less
		
		return 0
	}
	
	local ARGS=$(getopt -o hfF -l help,print-files,no-print-files -- "$@")
	eval set -- $ARGS
	
	
	local libs=""
	local lib=""
	local libfile=""
	local libpath=""
	local exit_code=1
	local PRINT_FILES=0
	
	while true ; do
		case "$1" in
		-f|--print-files)    PRINT_FILES=1                       ; shift   ;;
		-F|--no-print-files) PRINT_FILES=0                       ; shift   ;;
		-h|--help) __lib_detect_collision $FUNCNAME              ; return 0;;
		--) shift;;
		*) break;;
		esac
	done
	
	local ALL_LIBS=0
	
	if [ $# -eq 0 ]; then
		ALL_LIBS=1
		
		libs=$(
		for libpath in $(lib_path --list --absolute-path --real-path)
		do
			for libfile in $(__lib_list_dir "$libpath")
			do
				lib_name "$libfile"
			done
		done | sort | uniq -c | grep -E -e "^ *[2-9][0-9]*" | awk '{print $2}')
	else
		local libs="$@"
	fi
	
	for lib in $libs; do
		
		if [ $ALL_LIBS -eq 1 ]; then
			echo "$lib"
			
			if [ $PRINT_FILES -eq 1 ]; then
				lib_find --all "$lib"
				echo
			fi
		else
			local deps="$(lib_find --all "$lib")"
			
			if [ -n "$deps" ]; then
				echo "$lib"
				
				if [ $PRINT_FILES -eq 1 ]; then
					echo "$deps"
					echo
				fi
				
				exit_code=0
			fi
		fi
	done
	
	return $exit_code
}


### LSF MAIN SECTION ###########################################################


LSF_CMD_PREFIX="lsf_"
LSF_CMD=( log parse keywords main version exit )

LSF_LIB_CMD_PREFIX="lib_"
LSF_LIB_CMD=( apply archive depend detect_collision disable enable find import include update list list_apply name path test )


lsf_help()
{
	local LSF_PREFIX="lsf"
	local LIB_PREFIX="lib"
	local CMD="lsf"
	
	(cat << END
NAME
	$CMD - Library System Framework.
	
SYNOPSIS
	$CMD <command> [<options>]
	
	$CMD [-|--verbose]
	
	$CMD -h|--help|-?|help
	
	
DESCRIPTION
	Library System Framework (LSF) è un framework per l'import di librerie di script definite dall'utente.
	
GENERIC OPTIONS
	--file <sh_script>
	    Esegue lo script con sintassi bash, senza effettuare parsing.
	    I comandi LSF devono essere idenfificati per esteso: $LIB_PREFIX_<comando>.
	
	--script <lsf_script>
	    Esegue il parsing dello script LSF.
	    Negli script LSF il comando run e affini risulta superfluo.
	    NOTA: Al momento può eseguire solo comandi su una singola linea.
	
	-D, --dummy
	    Stampa il comando senza eseguirlo.
	
	--interactive
	    Esegue LSF in modalità interattiva.
	
	--no-interactive
	    Esegue LSF in modalità normale. (default)
	
	-v, --version
	    Stampa la versione di LSF.
	
	-h, --help, help [<command>]
	    Se non è specificato nessun comando, stampa questo messaggio ed esce.
	
COMMAND LIST
	LSF functions:
	  [${LSF_PREFIX}_]log                Log Manager di LSF.
	  [${LSF_PREFIX}_]parser             Parser di LSF.
	  [${LSF_PREFIX}_]keywords           Keywords di LSF.
	  [${LSF_PREFIX}_]main               Main di LSF.
	  [${LSF_PREFIX}_]version            Versione di LSF.
	
	Library functions:
	  [${LIB_PREFIX}_]apply              Trova la libreria e applica una funzione specifica su di essa.
	  [${LIB_PREFIX}_]archive            Crea e gestice gli archivi di libreria.
	  [${LIB_PREFIX}_]depend             Stampa la lista delle dipendenze di una librerie.
	  [${LIB_PREFIX}_]detect_collision   Verifica se ci sono delle collisioni nello spazio dei nomi.
	  [${LIB_PREFIX}_]disable            Disabilita una libreria per l'importazione.
	  [${LIB_PREFIX}_]enable             Abilita una libreria per l'importazione.
	  [${LIB_PREFIX}_]exit               Rimuove le definizioni di funzioni, variabili e alias di LSF.
	  [${LIB_PREFIX}_]find               Restituisce il path della libreria.
	  [${LIB_PREFIX}_]import             Importa librerie nell'ambiente corrente.
	  [${LIB_PREFIX}_]list               Stampa la lista delle librerie in una directory.
	  [${LIB_PREFIX}_]list_apply         Applica una funzione definita dall'utente per file, directory, e archivi.
	  [${LIB_PREFIX}_]name               Restituisce il nome della libreria.
	  [${LIB_PREFIX}_]path               Toolkit per la variabile LIB_PATH.
	  [${LIB_PREFIX}_]test               Esegue test sulla libreria
	
	Extended funcions:
	  ${LIB_PREFIX}_<command>            Esegue funzioni di LSF non appartenenti al core.
	
	Util funcions:
	  clear                              Pulisce lo schermo
	  dummy                              Stampa i comandi senza eseguirli (debug)
	  normal                             Esegue i comandi
	  script,source,.                    Importa una script
	
	Per ulteriri informazioni digitare:
	lsf help <command>  oppure  lsf <command> -h|--help
	
AUTHOR
	Written by Luigi Capraro (lugi.capraro@gmail.com)
	
COPYRIGHT
       Copyright © 2011 Free Software Foundation, Inc.  License GPLv3+: GNU GPL version 3 or later <http://gnu.org/licenses/gpl.html>.
       This is free software: you are free to change and redistribute it.  There is NO WARRANTY, to the extent permitted by law.
	
END
	) | less
	return 0
}

# Esce dall'ambiente corrente rimuovendo tutte le definizioni del framework
lsf_exit()
{
	__lsf_exit_usage()
	{
		local CMD="$1"
		
		(cat << END
NAME
	${CMD:=lib_test} - Rimuove le definizioni di funzioni, variabili e alias di LSF.
	
SYNOPSIS
	$CMD [-v|--verbose]
	
	$CMD -h|--help
	
	
DESCRIPTION
	Il comando $CMD rimuove le definizioni di funzioni, variabili e alias del framework LSF.
	
OPTIONS
	-v, --verbose
	    Stampa messagi dettagliati sulle operazioni di rimozione nel log.
	
	-h, --help
	    Stampa questo messaggio ed esce.
	
END
		) | less
		
		return 0
	}
	
	local ARGS=$(getopt -o rhf:d:l:a: -l recursive,help,function:,dir-function:,lib-function:,archive-function -- "$@")
	eval set -- $ARGS
	
	#echo "ARGS=$ARGS"
	
	local VERBOSE=0
	
	while true ; do
		case "$1" in
		-v|--verbose)  VERBOSE=1                    ; shift   ;;
		-h|--help)     __lsf_exit_usage "$FUNCNAME" ; return 0;;
		--) shift;;
		*) break;;
		esac
	done
	
	
	for al in $(alias | grep -E "lib_.*" | 
		awk '/^[[:blank:]]*(alias)[[:blank:]]*[a-zA-Z0-9_]+=/ {gsub("[[:blank:]]*|alias|=.*",""); print}'); do
		
		unalias $al
		[ $VERBOSE -eq 1 ] && echo "unalias $al"
	done
	
	for fun in $(set | grep -E "^_{0,3}lib_.* \(\)" | awk '{gsub(" \\(\\)",""); print}'); do
		
		unset $fun
		[ $VERBOSE -eq 1 ] && echo "unset $fun"
	done
	
	for var in $(set | grep -E "^LIB_*" | awk '{gsub("=.*",""); print}'); do
		
		unset $var
		[ $VERBOSE -eq 1 ] && echo "unset $var"
	done
}

# Restituisce la versione corrente di LSF.
lsf_version()
{
	[ -z "$LSF_VERSINFO" ] && return 1
	
	local VERBOSE=0
	
	[ "$1" == "-v" -o "$1" == "--verbose" ] && VERBOSE=1
	
	[ $VERBOSE -eq 1 ] && echo -n "LSF "
	
	local i=0
	
	for (( i=0; i<4; i++ )); do
		[ $i -gt 0 ] && echo -n "."
		[ -n "${LSF_VERSINFO[$i]}" ] && echo -n "${LSF_VERSINFO[$i]}"
	done | awk '{gsub("([.]0)+$",""); printf "%s", $0}'
	
	if [ $VERBOSE -eq 1 ]; then
		[ -n "${LSF_VERSINFO[4]}" ] && echo -n " ${LSF_VERSINFO[4]}"
		[ -n "${LSF_VERSINFO[5]}" ] && echo -n " ${LSF_VERSINFO[5]}"
	fi
	
	echo
}

# LSF Keywords
lsf_keywords()
{
	__lsf_keywords_usage()
{
		local CMD="$1"
		
		(cat << END
NAME
	${CMD:=lsf_keywords} - Stampa la lista delle keywords di LSF, o ne esegue la verifica.
	
SYNOPSIS
	$CMD [-v|--verbose]
	
	$CMD [-v|--verbose] <word>
	
	$CMD -h|--help
	
	
DESCRIPTION
	Il comando $CMD senza paramentri stampa la lista delle keywords del framework LSF,
	altrimenti verifica sei una parola o ne esegue la verifica.
	
OPTIONS
	-v, --verbose
	    Stampa messagi dettagliati sulle operazioni di rimozione nel log.
	
	-h, --help
	    Stampa questo messaggio ed esce.
	
END
		) | less
		
		return 0
	}
	
	local FNAME=0
	local TEST=0
	local VERBOSE=0
	local WORD=""
	local exit_code=0
	
	while [ -n "$1" ] ; do
		case "$1" in
		-f|--function-name) FNAME=1                     ; shift   ;;
		-v|--verbose)       VERBOSE=1                   ; shift   ;;
		-h|--help)     __lsf_keywords_usage "$FUNCNAME" ; return 0;;
		--) shift;;
		*) break;;
		esac
	done
	
	if [ $# -eq 0 ];then
		TEST=0
	else
		TEST=1
		WORD="$1"
		exit_code=1
	fi
	
	__lsf_keywords_test()
	{
		if [[ "$1" == "$2" || "$1" == "$3" ]]; then 
			[ $VERBOSE -eq 1 ] && echo -n "LSF: '$1' e' una keyword"
			
			if [ $FNAME -eq 1 ]; then
				[ $VERBOSE -eq 1 ] && echo -n " (function name: "
				echo -n $3
				[ $VERBOSE -eq 1 ] && echo -n ")"
				echo
			fi
			
			return 0
		fi
		
		return 1
	}
	
	local keyword=""
	local fun_keyword=""
	
	for keyword in ${LSF_CMD[@]}; do
		fun_keyword=${LSF_CMD_PREFIX}${keyword}
		if [ $TEST -eq 1 ]; then
			if __lsf_keywords_test "$WORD" "$keyword" "$fun_keyword"; then
				unset __lsf_keywords_test
				return 0
			fi
		else
			echo ${fun_keyword}
		fi
	done
	
	for keyword in ${LSF_LIB_CMD[@]}; do
		fun_keyword=${LSF_LIB_CMD_PREFIX}${keyword}
		if [ $TEST -eq 1 ]; then
			if __lsf_keywords_test "$WORD" "$keyword" "$fun_keyword"; then
				unset __lsf_keywords_test
				return 0
			fi
		else
			echo ${fun_keyword}
		fi
	done
	
	if [ $TEST -eq 1 -a $VERBOSE -eq 1 ]; then
		echo "LSF: '$WORD' non e' una keyword"
	fi
	
	unset __lsf_keywords_test
	
	return $exit_code
}

# Esegue il parsing dei comandi LSF.
lsf_parser()
{
	local SCRIPT_LINE=()
	local SCRIPT_FILE=""
	local CODE_PROMPT="> "
	local CHECK_IMPORT=1
	local INTERACTIVE=0
	local VERBOSE=0
	local DUMMY=0
	local SYNTAX_HELP=1
	
	while [ -n "$1" ]; do
		case "$1" in
		-h|--help)            lsf_help                           ; return $?;;
		-i|--interactive)     INTERACTIVE=1                      ; shift    ;;
		-s|--script)          SCRIPT_FILE="$2";
		   [ -f "$2" ] && mapfile SCRIPT_LINE < $2               ; shift   2;;
		-i|--check-import)    CHECK_IMPORT=1                     ; shift    ;;
		-I|--no-check-import) CHECK_IMPORT=0                     ; shift    ;;
		-D|--dummy)           DUMMY=1                            ; shift    ;;
		-d|--dump)            DUMMY=1; CODE_PROMPT=""; VERBOSE=1 ; shift    ;;
		-v|--verbose)         VERBOSE=1                          ; shift    ;;
		-c|--command)         shift                              ; break    ;;
		*) break;
		esac
	done
	
	local CMD="$@"
	local PREV_CMD=""
	local INDENT_LEVEL=0
	local FUN_START=0
	local STRING_START=0
	local SUBCMD_START=0
	local ARITM_SUBCMD_START=0
	
	__lsf_execute()
	{
		local CMD="$@"
		
		[ $VERBOSE -eq 1 ] && echo -e "${CODE_PROMPT}$CMD"
		if [ $DUMMY -eq 0 ]; then
			# esegui il comando
			eval "$(echo -e "$CMD")"
			
			# verifica degli import
			if [ $? -ne 0 -a $CHECK_IMPORT -eq 1 ]; then
				if echo "$CMD" | grep -q -E -e "^lib_(import|include)"; then
					echo "LSF: import error: $CMD" > /dev/stderr
					return 1
				fi
			fi
		fi
		
		return 0
	}
	
	__lsf_run()
	{
		if [ $INDENT_LEVEL -gt 0 ]; then
			[ -n "$CMD" ] && CMD="$CMD ;"
		else
			local exit_code=0
			
			CMD="$(echo $CMD)"
			
			if [ $INDENT_LEVEL -eq 0 ]; then
				__lsf_execute "$CMD"
				exit_code=$?
			else
				INDENT_LEVEL=0
				echo "LSF Parser: run error: '$CMD'" > /dev/stderr
				exit_code=1
			fi
			
			PREV_CMD="$CMD"
			CMD=""
			
			[ $exit_code -eq 0 ] || return $exit_code
		fi
		
		return 0
	}
	
	__lsf_parse_word()
	{
		[ $# -eq 0 ] && return 0
		
		local WORD="$1"
		local word="${1/"\n"}"
		
		# debug
		#echo "WORD=$1 -> $word"
		
		local kword=$(lsf_keywords --function-name "$word")
		
		if [ -n "$kword" ]; then
			if [ -z "$CMD" ]; then
				CMD="$kword"
			else
				CMD="$CMD \n$kword"
			fi
		else
			# '<string>'
			if [ $STRING_START -eq 1 ] && echo "$word" | grep -q -E -e "^[^']*'$"; then
				STRING_START=0
				let INDENT_LEVEL--
			elif echo "$word" | grep -q -E -e "^'(.*[^'])?$"; then
				STRING_START=1
				let INDENT_LEVEL++
			fi
			
			# $(<list>) (<list>) `<list>`
			if [ $SUBCMD_START -eq 1 ] && 
				echo "$word" | grep -q -E -e '^[^`]*`$' ||
				echo "$word" | grep -q -E -e '[)]'; then
				SUBCMD_START=0
				let INDENT_LEVEL--
			elif echo "$word" | grep -q -E -e '^`' ||
				 echo "$word" | grep -q -E -e '\$?[(]'; then
				SUBCMD_START=1
				let INDENT_LEVEL++
			fi
			
			# $(( <aritmetic expression> ))
			if [ $ARITM_SUBCMD_START -eq 1 ] && 
				echo "$word" | grep -q -E -e '[)][)]'; then
				ARITM_SUBCMD_START=0
				let INDENT_LEVEL--
				CMD="$(echo "$CMD" | awk '{gsub(";( |\\\n)*", ""); print}')"
			elif echo "$word" | grep -q -E -e '\$[(][(]'; then
				ARITM_SUBCMD_START=1
				let INDENT_LEVEL++
			fi
			
			
			if [ $STRING_START -eq 1 -o $SUBCMD_START -eq 1 -o $ARITM_SUBCMD_START -eq 1 ]; then
				CMD="$CMD $WORD"
			else
				# function support: <fun_id>() { ... }  function <fun_id>[( )] { ... }
				if echo "$word" | grep -q -E -e "^function$"; then
					FUN_START=2
					let INDENT_LEVEL++
				elif echo "$word" | grep -q -E -e ".*[^=]?[(][)]$"; then
					[ $FUN_START -gt 0 ] || let INDENT_LEVEL++
					FUN_START=1
				elif [ "$word" == "{" ]; then
					if [ $FUN_START -eq 0 ]; then
						let INDENT_LEVEL++
					elif [ $FUN_START -eq 1 ]; then
						FUN_START=0
					
						if [ $SYNTAX_HELP -eq 1 ]; then
							CMD="$(echo "$CMD" | awk '{gsub("(;|\\\\n)+ *",""); print}')"
						fi
					else
						echo "LSF: error: parse function failed!" > /dev/stderr
						return 1
					fi
				elif [ $FUN_START -eq 2 ]; then
					FUN_START=1
				elif [ $FUN_START -eq 1 ]; then
					if [ $SYNTAX_HELP -eq 0 ]; then
						echo "LSF: error: parse function failed!" > /dev/stderr
						return 1
					else
						WORD="{ $WORD"
					fi
				fi
				
				case "$word" in
				'if'|'for'|'while'|'case') let INDENT_LEVEL++;;
				'fi'|'done'|'esac'|'}') let INDENT_LEVEL--;;
				esac
			
				if [ $SYNTAX_HELP -eq 0 ]; then
					CMD="$CMD $WORD"
				else
					# auto syntax correction
					case "$word" in
#					then|else|elif|fi|do|done)
#						if [ -z "$CMD" ]; then
#							CMD="$word"
#						else
#							CMD="$CMD ; $word"
#							CMD="echo '$CMD' | awk '{ gsub(\"( *;)+ *$word\",\" ; $word\"); print}'"
#							CMD="$(eval $CMD)"
#						fi;;
					*) CMD="$CMD $WORD";;
					esac
				fi
			fi
		fi
		
		# debug
		#echo "CMD=$(echo -e $CMD)"
	}
	
	__lsf_parse_line()
	{
		local LINE="$*"
		
		local an=$(echo $LINE | tr \'  '#' | awk '{gsub("[^#]"," "); print}'| wc -w)
		local bn=$(echo $LINE | tr '`' '#' | awk '{gsub("[^#]"," "); print}'| wc -w)

		
		if (( $an%2==0 )) && (( $bn%2==0 )) &&
		   echo "$LINE" | grep -q -v -E -e "(if|do|then|in|;+|\{|\(|[^=][(] *[)]|function *) *$"; then
			LINE="$LINE;"
		fi
		
		LINE="$(echo "$LINE" | awk '{gsub("[(]", "( "  );
		                             gsub("[)]", " )"  );
		                             gsub("[(] *[)]", "()");
		                             gsub("[(] *[(]","((");
		                             gsub("[)] *[)]","))");
		                             gsub(" *; *"," ; ");
		                             gsub("; +;",";;");
		                             gsub("`", " ` ");
		                             print}')"
		
		# debug
		#echo "LINE=$LINE"
		
		CMD=""
		INDENT_LEVEL=0
		STRING_START=0
		SUBCMD_START=0
		ARITM_SUBCMD_START=0
		FUN_START=0
		
		local word=""
		
		for word in $LINE; do
			if [ "$word" == ";" ]; then
				__lsf_run "$CMD" && continue || return 1
			fi
			
			__lsf_parse_word $word || return 1
		done
		
		return 0
	}
	
	__lsf_parse()
	{
		if [ -z "$CMD" ]; then
			__lsf_parse_line "$*"
		else
			__lsf_parse_line "$CMD \n$*"
		fi
	}
	
	
	if [ -n "$SCRIPT_FILE" ]; then
		local i=0
		local lines=${#SCRIPT_LINE[@]}
		
		while [ $i -lt $lines ] ; do
			__lsf_parse "${SCRIPT_LINE[$i]}" || return 1
			let i++
		done
	elif [ $INTERACTIVE -eq 1 ]; then
		
		CMD=$ARGS
		
		while true; do
		
			local LSF_PROMPT="lsf > "
			
			[ $INDENT_LEVEL -ne 0 ] && LSF_PROMPT="> " 
			
			read -a WORDS -p "$LSF_PROMPT"
			
			local LINE="${WORDS[@]}"
			
			case "${WORDS[0]}" in
			q|quit|end)     [ -z "${WORDS[1]}" ] && break || continue;;
			c|cmd)          echo -e "$CMD"      ; continue;;
			r|reset_cmd)    CMD=""              ; continue;;
			p|prev_cmd)     echo -e "$PREV_CMD" ; continue;;
			i|indent_level) 
				if echo "${WORDS[1]}" | grep -q -E -e "[0-9][1-9]*"; then
					INDENT_LEVEL=${WORDS[1]}
				else
					echo $INDENT_LEVEL
				fi
				continue;;
			m|mode)
				case "${WORDS[1]}" in
				verbose) VERBOSE=1;;
				quiet)   VERBOSE=0;;
				dummy)   DUMMY=1;;
				dump)    VERBOSE=1; DUMMY=1; CODE_PROMPT="";;
				normal)  VERBOSE=0; DUMMY=0; CODE_PROMPT="> ";;
				*)       echo "LSF: mode error: ${WORDS[1]} invalid" > /dev/stderr;;
				esac
				continue;;
			esac
			
			__lsf_parse "$LINE"
		done
	else
		__lsf_parse_line "$CMD"
	fi
	
	if [ -n "$CMD" ]; then
		[ $VERBOSE -eq 1 ] && echo "No parse: $CMD"
	fi
}

lsf_main()
{
	local VERBOSE_OPT=""
	local LSF_PARSER_OPT=""
	
	while [ -n "$1" ]; do
		case "$1" in
		-p|--parser)                              shift; break;;
		-c|--command|-s|--script|-i|--interactive)
			LSF_PARSER_OPT="$1";                  shift; break;;
		-h|--help)        lsf_help                 ; return $?;;
		-k|--keywords)    shift; lsf_keywords "$@" ; return $?;;
		-v|--verbose)     VERBOSE_OPT="$1"         ; shift    ;;
		--version)        lsf_version $VERBOSE_OPT ; return $?;;
		*) if [ -f "$1" ]; then source "$1";
           else echo "lsf: $1: File o directory non esistente"; fi
           shift;;
		esac
	done
	
	lsf_parser $VERBOSE_OPT $LSF_PARSER_OPT "$@"
}

# main #########################################################################
#echo "lsf execute by $0"

if [ "sh" != "$0" -a "bash" != "$0" ]; then
	lsf_main "$@"
fi

################################################################################
