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

export LIB_EXT="lib"
export LIB_FILE_LIST=${LIB_FILE_LIST:-""}


######### UTILITY FUNCTIONS ####################################################

lib__get_absolute_path()
{
	local FILEPATH=$(
		if [ $# -eq 0 ]; then
			cat
		else
			echo "$1"
		fi | awk '{gsub("^ *| *$",""); print}'
	)
	
	echo "$STRING" | grep -E -q -e "$REGEXP" >/dev/null
	
	if ! echo "$FILEPATH" | grep -E -q -e "^/" >/dev/null; then
	  # This is a relative path
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

################################################################################



######### PATH FUNCTIONS #######################################################

lib_path_get()
{
	if [ -z "$*" ]; then
		echo $LIB_PATH
	else
		local LP=""
		for path_num in $(echo $* | tr : ' '); do
			local LP=$LP:$(echo $LIB_PATH | 
			               awk -F: -v PN=$path_num '{print $PN}')
		done
		
		echo ${LP#:}
	fi
}

lib_path_list()
{
	echo -e ${LIB_PATH//:/\\n}
}

lib_path_set()
{
	LIB_PATH=""
	
	local lib=""
	
	for lib in $(echo $1 | tr : ' '); do
		if [ -n "$LIB_PATH" ]; then
			LIB_PATH="$LIB_PATH:${lib%\/}"
		else
			LIB_PATH="${lib%\/}"
		fi
	done
	
	export LIB_PATH
}

lib_path_add()
{
	for lib in $*; do
		if [ -n "$LIB_PATH" ]; then
			LIB_PATH="${lib%\/}:$LIB_PATH"
		else
			LIB_PATH="${lib%\/}"	
		fi
	done
	
	export LIB_PATH
}

lib_path_remove()
{
	for lib in $*; do
		
		lib="${lib%\/}"
		
		LIB_PATH=$(echo $LIB_PATH | 
				   awk -v LIB="$lib/?" '{gsub(LIB, ""); print}' | 
			       awk '{gsub(":+",":"); print}' | 
			       awk '{gsub("^:|:$",""); print}')
	done

	export LIB_PATH
}

################################################################################


lib_list_files()
{
	[ -z "$LIB_FILE_LIST" ] && return

	echo -e "$LIB_FILE_LIST"
}

lib_list_files_add()
{
	local lib="$(lib__get_absolute_path "$1")"
	
	LIB_FILE_LIST=$(echo -e "${LIB_FILE_LIST}\n$lib" | 
	                sort | uniq | grep -v -E -e '^$')
}

lib_list_files_remove()
{
	local lib="$(lib__get_absolute_path "$1")"

	LIB_FILE_LIST=$( echo -e "$LIB_FILE_LIST" | 
					 awk -vLIB="$lib" '{gsub(LIB,""); print}' | 
					 grep -v -E -e '^$')
}

lib_list_names()
{
	[ -z "$LIB_FILE_LIST" ] && return

	local libfile=""
	
	for libfile in $LIB_FILE_LIST; do
		lib_name $libfile
	done
}




############# LOG SECTION ######################################################

export LIB_LOG_ENABLE=${LIB_LOG_ENABLE:-0}
#export LIB_LOG_OUT=${LIB_PATH}/log.txt
export LIB_LOG_OUT=${LIB_LOG_OUT:-"/dev/stderr"}



lib_log()
{
	if [ -d "$LIB_LOG_OUT" ]; then
		local LIB_LOG_DIR=$(dirname "$LIB_LOG_OUT")
	
		! test -d "$LIB_LOG_DIR" && mkdir "$LIB_LOG_DIR" || return 1
		! test -e "$LIB_LOG_OUT" && touch "$LIB_LOG_OUT" || return 2
	fi
	
	if [ $LIB_LOG_ENABLE -eq 1 ]; then
		echo -e $(date +"%Y-%m-%d %H:%M:%S") $(id -nu) $* >> ${LIB_LOG_OUT}
	fi
}

lib_log_is_enabled()
{
	test $LIB_LOG_ENABLE -eq 1 && return 0
	
	return 1 
}

lib_log_enable()
{
	export LIB_LOG_ENABLE=1
}

lib_log_disable()
{
	export LIB_LOG_ENABLE=0
}

lib_log_print()
{
	if [ -f "$LIB_LOG_OUT" ]; then
		less "$LIB_LOG_OUT"
	fi
}

lib_log_reset()
{
	if [ -f "$LIB_LOG_OUT" ]; then
		echo "" > "$LIB_LOG_OUT"
	fi
}

lib_log_out_get()
{
	echo $LIB_LOG_OUT
}


lib_log_out_set()
{
	case $1 in
	1|out|stdout) LIB_LOG_OUT="/dev/stdout";;
	2|err|stderr) LIB_LOG_OUT="/dev/stderr";;
	*) LIB_LOG_OUT="$1";;
	esac
	
	if [ -w "$LIB_LOG_OUT" ]; then
		export LIB_LOG_OUT
		return 0
	fi
	
	return 1
}
################################################################################


# Restituisce il nome di una libreria o di un modulo a partire dal file o dalla
# cartella.
#
# Se l'argomento è nullo o il file o cartella non esiste
lib_name()
{
	[ $# -gt 0 ] || [ -e "$1" ] || return 1
	
	[ -f "$1" ] || [ -d "$1" ] || return 2
	
	local dirs=""
	for libdir in ${LIB_PATH//:/ }; do
		dirs="$dirs|$(lib__get_absolute_path $libdir)"
	done
	
	lib__get_absolute_path "$1" |
	awk -v S="^($dirs)/|(.$LIB_EXT|/)$" '{gsub(S,""); print}' |
	tr / :
}


# Trova il file associato ad una libreria o ad una cartella
# lib_find
lib_find()
{
	[ $# -eq 0 -o -z "$*" ] && return 1
		
	local ARGS=$(getopt -o f:d: -l file:,dir: -- "$@")
	
	eval set -- $ARGS
	
	while true ; do
		case "$1" in
		-f|--file) [ -f "$2" ] || return 1; 
				   lib__get_absolute_path "$2"; return 0;; 
		-d|--dir)  [ -d "$2" ] || return 1; 
				   lib__get_absolute_path "$2"; return 0;;
		--) shift;;
		*) break;;
		esac
	done

	local LIB="${1//://}"	
	local libdir=

	for libdir in ${LIB_PATH//:/ }; do
		
		if [ -d "${libdir}/$LIB" ]; then
			lib__get_absolute_path ${libdir}/$LIB
			return 0
		elif [ -f "${libdir}/$LIB.$LIB_EXT" ]; then
			lib__get_absolute_path ${libdir}/$LIB.$LIB_EXT
			return 0		
		fi
				
	done
	
	return 1
}

lib_is_loaded()
{
	[ -n "$1" ] || return 1
	
	local lib=
	
	if [ "$1" == "-f" ]; then
		lib=$(lib_find -f $2)
	else
		lib=$(lib_find $1)
	fi
	
	[ -n "$lib" ] || return 1
	
	echo "$(lib_list_files)" | grep -E -q -e "$lib" > /dev/null
	
	return $?
}

lib_is_installed()
{
	lib_find "$1" > /dev/null
	
	return $?
}

lib_is_enabled()
{
	[ $# -eq 0 ] && return 1
	
	local ARGS=$(getopt -o f:d: -l file:,dir: -- "$@")
	
	eval set -- $ARGS

	local FIND_OPT=""
	local LIB=""

	while true ; do
		case "$1" in
		-f|--file) FIND_OPT="$1"; LIB="$2"; shift 2;;
		-d|--dir)  FIND_OPT="$1"; LIB="$2"; shift 2;;
		--) shift;;
		*) break;;
		esac
	done

	LIB_FILE=$(lib_find $FIND_OPT "$LIB")

	if [ -n "$LIB_FILE" ]; then

		test -x "$LIB_FILE" && return 0
		
		return 2
	fi
	
	return 1
}

lib_enable()
{		
	[ $# -eq 0 ] && return 1
	
	local ARGS=$(getopt -o f:d: -l file:,dir: -- "$@")
	
	eval set -- $ARGS

	local FIND_OPT=""

	while true ; do
		case "$1" in
		-f|--file) FIND_OPT="$1"; shift ;;
		-d|--dir)  FIND_OPT="$1"; shift ;;
		--) shift;;
		*) break;;
		esac
	done
	
	for library in "$@"; do
		LIB_FILE=$(lib_find $FIND_OPT $library)

		if [ -n "$LIB_FILE" ]; then
			lib_log "Enable library: $library"
			chmod a+x $LIB_FILE
		else
			lib_log "Library '$library' not found!"		
		fi
	done
}

lib_disable()
{
	[ $# -eq 0 ] && return 1
	
	local ARGS=$(getopt -o f:d: -l file:,dir: -- "$@")
	
	eval set -- $ARGS

	local FIND_OPT=""

	while true ; do
		case "$1" in
		-f|--file) FIND_OPT="$1"; shift ;;
		-d|--dir)  FIND_OPT="$1"; shift ;;
		--) shift;;
		*) break;;
		esac
	done
	
	for library in "$@"; do
		LIB_FILE=$(lib_find $FIND_OPT $library)
		
		if [ -n "$LIB_FILE" ]; then
			lib_log "Disable library: $library"
			chmod a-x $LIB_FILE
		else
			lib_log "Library '$library' not found!"	
		fi
	done
}


lib_list_dir()
{
	
	local ARGS=$(getopt -o rh -l recursive,help -- "$@")
	
	eval set -- $ARGS

	local RECURSIVE=0

	while true ; do
		case "$1" in
		-r|--recursive) RECURSIVE=1; shift ;;
		-h|--help) echo "$FUNCNAME [-r|--recursive] <dir>"; return 0;;
		--) shift;;
		*) break;;
		esac
	done

	local DIR="."
	local libdir=
		
	if [ -n "$1" ]; then
		DIR="$1"
	fi
	
	test -d "$DIR" || return 1;
	
	if [ `ls -A1 "$DIR" | wc -l` -gt 0 ]; then
		for library in $DIR/*.$LIB_EXT; do
			test -f $library || continue
			
			if [ -x $library ]; then
				echo -en "[+] [LIB] "
			else
				echo -en "[-] [LIB] "
			fi
			
			if lib_is_loaded -f $library; then
				echo -en "[*] "
			else
				echo -en "[ ] "			
			fi
			
			echo -e "$(lib_name $library) \t $library"
		done

		if [ $RECURSIVE -eq 1 ]; then
			for libdir in $DIR/*; do

				test -d $libdir || continue
				
				if [ -x "$libdir" ]; then
					echo -e "[+] [DIR] [=] $(lib_name $libdir) \t $libdir"
					lib_list_dir -r "$libdir"
				else
					echo -e "[-] [DIR] [=] $(lib_name $libdir) \t $libdir"				
				fi
			done
		fi

	fi
}

lib_list()
{
	for dir in ${LIB_PATH//:/ }
	do
		lib_list_dir -r $dir
	done
}


lib_list_lib()
{	
	local ARGS=$(getopt -o rednfhlL -l recursive,help,only-enabled,only-disable,filename,libname,format-list,no-format-list -- "$@")
	
	eval set -- $ARGS

	local RECURSIVE=0
	local ONLY_ENABLED=0
	local ONLY_DISABLED=0
	local NAME=1
	local FORMAT=1
	local libset=""

	while true ; do
		case "$1" in
		-n|--libname)        NAME=1          ; shift ;;
		-f|--filename)       NAME=0          ; shift ;;		
		-l|--format-list)    FORMAT=1        ; shift ;;		
		-L|--no-format-list) FORMAT=0        ; shift ;;		
		-r|--recursive)      RECURSIVE=1     ; shift ;;
		-e|--only-enabled)   ONLY_ENABLED=1  ; shift ;;
		-d|--only-disabled)  ONLY_DISABLED=1 ; shift ;;
		-h|--help) echo "$FUNCNAME <options> [-r|--recursive] <dir>"; return 0;;
		--) shift;;
		*) break;;
		esac
	done



	__list_lib()
	{

		local DIR="$1"
		local libdir=""
		local libname=""	
		local found=0

		if [ `ls -A1 "$DIR" | wc -l` -gt 0 ]; then
			for library in $DIR/*.$LIB_EXT; do
		
				if [ $NAME -eq 1 ]; then
					libname=$(lib_name $library)
				else
					libname=$library
				fi
				
				found=0
			
				for lib in ${libset//;/ }; do
					if [ "$libname" = "$lib" ]; then
						found=1	
						break;
					fi
				done
				 
				[ $found -eq 0 -a -f $library ] || continue
			
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
			
				libset="$libset;$libname"
			done

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
	
	for DIR in $*; do
		
		test -d "$DIR" || continue
	
		__list_lib $DIR	
	done
	
	unset __list_lib
}

lib_list_all()
{
	lib_list_lib $* -r ${LIB_PATH//:/ }
}


# library import function:
#
# Importa un file o una dictory
#
# lib_import [--file|-f] dir/library.lib
#
# lib_import [--include|-i] [--file|-f] dir/library.lib
#
# lib_import [--dir|-d] dir
#
# lib_import [--recursive|-r] [--dir|-d] dir
#
# lib_import [--include|-i] [--recursive|-r] [--dir|-d] dir
#
lib_import()
{		
	
	local ARGS=$(getopt -o f:d:ircC -l file:,dir:,include,recursive,check,no-check -- "$@")

	eval set -- $ARGS

	local LIB=""
	local LIB_FILE=""
	local FIND_OPT=""
	local INC_OPT=""
	local REC_OPT=""
	local INCLUDE=0
	local RECURSIVE=0
	local CHECK=1
	local CHECK_OPT=""
	
	while true ; do
		case "$1" in
		-c|--check)     CHECK=1; CHECK_OPT="$1"   ; shift ;;
		-C|--no-check)  CHECK=0; CHECK_OPT="$1"   ; shift ;;
		-f|--file)      FIND_OPT="$1"             ; shift ;;
		-d|--dir)       FIND_OPT="$1"             ; shift ;;
		-i|--include)   INCLUDE=1; INC_OPT="$1"   ; shift ;;
		-r|--recursive) RECURSIVE=1; REC_OPT="$1" ; shift ;;
		--) shift;;
		*) break;;
		esac
	done
	
	if [ $# -eq 0 ]; then
		for dir in ${LIB_PATH//:/ }
		do
			$FUNCNAME $CHECK_OPT -d -r $dir
		done
		
		return 0
	fi
	
	if [ -n "$FIND_OPT" ]; then
		LIB_FILE="$1"
	else
		LIB="${1//://}"
		LIB_FILE=$(lib_find $FIND_OPT $LIB)		
	fi

	#LIB_FILE=$(lib__get_absolute_path $LIB_FILE)
		
	if [ -z "$LIB_FILE" ]; then
		lib_log "Library '$LIB' not found!"	
		return 1
	fi

	if [ $INCLUDE -eq 0 -a ! -x "$LIB_FILE" ]; then
		#if [ -n "$LIB" ]; then
		#	lib_log "Library '${LIB////:}' disable!"
		#else
			lib_log "Library '$LIB_FILE' disable!"		
		#fi
		return 2
	fi
	
	

	if [ -f "$LIB_FILE" ]; then
			
		if [ $CHECK -eq 0 ] || ! $(lib_is_loaded -f "$LIB_FILE"); then
			#if [ -n "$LIB" ]; then
			#	lib_log "Import library module:\t ${LIB////:}"
			#else
				lib_log "Import library module:\t $LIB_FILE"		
			#fi
		
			source "$LIB_FILE"
			
			lib_list_files_add "$LIB_FILE"
		fi	

		return $?

	elif [ -d "$LIB_FILE" ]; then
	
		local DIR="$LIB_FILE"
	
		lib_log "Import library directory:\t $DIR"
		
		if [ $(ls -A1 "$DIR" | wc -l) -gt 0 ]; then
			
			for library in $DIR/*.$LIB_EXT; do
				if [ $INCLUDE -eq 1 -o -x $library ]; then				
					$FUNCNAME $CHECK_OPT $INC_OPT -f $library
				fi
			done
		
			if [ $RECURSIVE -eq 1 ]; then
				for libdir in $DIR/*; do

					test -d $libdir || continue

					if [ $INCLUDE -eq 1 -o  -x "$libdir" ]; then
						$FUNCNAME $CHECK_OPT $INC_OPT $REC_OPT -d $libdir
					else
						lib_log "Library directory '$libdir' disable!"				
					fi
				done
			fi
		fi
		
		return $?
	fi
}


alias lib_import_file="lib_import -f"
alias lib_import_dir="lib_import -d"
alias lib_include="lib_import -i"
alias lib_include_file="lib_import -i -f"
alias lib_include_dir="lib_import -i -d"

lib_list_def()
{
	if [ $# -eq 0 ]; then
		return 1
	fi

	local ARGS=$(getopt -o f:AFV -l file:,only-alias,only-functions,only-variables -- "$@")

	eval set -- $ARGS
	
	local _alias=1
	local _variables=1
	local _functions=1
	
	local LIB_FILE=""
	local FIND_OPT=""
	
	while true ; do
		case "$1" in
		-f|--file)           FIND_OPT="$1"                        ;shift ;;
		-A|--only-alias)     _alias=1; _functions=0; _variables=0 ;shift ;;
		-F|--only-functions) _alias=0; _functions=1; _variables=0 ;shift ;;
		-V|--only-variables) _alias=0; _functions=0; _variables=1 ;shift ;;
		--) shift;;
		*) break;;
		esac
	done

	local library="$1"
	LIB_FILE=$(lib_find $FIND_OPT $library)

	
	if [ -f "$LIB_FILE" ]; then
	
		__get_list() {
			cat "$1" | 
			awk '! /^[[:blank:]]*\#/ {gsub("^[[:blank:]]*",""); print}' | 
			awk '
				/^[[:blank:]]*[a-zA-Z0-9_]+=/ {gsub("[[:blank:]]*|=.*",""); print "[VAR]",$0}
				/^[[:blank:]]*(function)?[[:blank:]]*[a-zA-Z0-9|_]+\(\)/ { gsub("function|[[:blank:]]*|\\(\\).*$",""); print "[FUN]",$0}
				/^[[:blank:]]*(alias)[[:blank:]]*[a-zA-Z0-9_]+=/ {gsub("[[:blank:]]*|alias|=.*",""); print "[ALS]",$0}' |
			sort |
			uniq	
		}
	
		__get_var_list() {
			__get_list "$1" | awk '/^\[VAR\]/ {print $2}'
		}

		__get_fun_list() {
			__get_list "$1" | awk '/^\[FUN\]/ {print $2}'
		}

		__get_alias_list() {
			__get_list "$1" | awk '/^\[ALS\]/ {print $2}'
		}
	
		__is_local_var() {
			cat "$1" | grep -q -E -e "local *$2 *($|=)|unset *$2 *($|;)?"
		}

		__is_local_fun() {
			cat "$1" | grep -q -E -e "unset *$2 *($|;)?"
		}

		__is_local_alias() {
			cat "$1" | grep -q -E -e "unalias *$2 *($|;)?"
		}

		if [ $_variables -eq 1 ]; then
	 		for var in $(__get_var_list "$LIB_FILE"); do
	 		
	 			if ! __is_local_var $LIB_FILE $var; then
	 				if [ $_functions -eq 1 -a $_alias -eq 1 ]; then
	 					echo -n "[VAR] "
	 				fi
	 				echo "$var"

	 			#else
	 			#	echo V " -- $var" 			
	 			fi
	 		done
 		fi

		if [ $_functions -eq 1 ]; then
			for fun in $(__get_fun_list "$LIB_FILE"); do
	 		
	 			if ! __is_local_fun $LIB_FILE $fun; then
	 				if [ $_variables -eq 1 -a $_alias -eq 1 ]; then
	 					echo -n "[FUN] "
	 				fi
	 				echo "$fun"
				#else
	 			#	echo F " -- $fun"
	 			fi
	 		done
		fi
		
		if [ $_alias -eq 1 ]; then
			for alias in $(__get_alias_list "$LIB_FILE"); do
	 		
	 			if ! __is_local_alias $LIB_FILE $alias; then
	 				if [ $_variables -eq 1 -a $_functions -eq 1 ]; then
	 					echo -n "[ALS] "
	 				fi
	 				echo "$alias"
	 			#else
	 			#	echo A " -- $alias" 			
	 			fi
	 		done
		fi
		
		unset __get_list
		unset __get_var_list
		unset __get_fun_list
		unset __get_alias_list
		unset __is_local_var
		unset __is_local_fun
		unset __is_local_alias

	else
		lib_log "Library '$library' not found!"	
		return 1
	fi

	return 0
}

lib_unset()
{
	if [ $# -eq 0 ]; then
		return 1
	fi
	
	local VAR_AND_FUN=$(lib_list_def $1 | 
		awk '{gsub("\\[(VAR|FUN)\\]","unset"); gsub("\\[ALS\\]","unalias"); printf "%s:%s\n",$1,$2}')
	
	if [ -n "$VAR_AND_FUN" ]; then
		lib_log "Library '$1': unset variables, functions and alias"	
	
		for def in $VAR_AND_FUN; do
			local CMD=$(echo $def | tr : ' ')
			lib_log "Library '$1': $CMD"
			eval "$CMD 2> /dev/null"
		done
	fi
	
	local lib="$(lib_find "$1")"
	
	lib_list_files_remove "$lib"
	
	return 0
}

lib_exit()
{
	local VERBOSE=0
	
	if [ "$1" = "-v" -o "$1" = "--verbose" ]; then
		VERBOSE=1
	fi
	
	for al in $(alias | grep -E "lib_.*" | 
		awk '/^[[:blank:]]*(alias)[[:blank:]]*[a-zA-Z0-9_]+=/ {gsub("[[:blank:]]*|alias|=.*",""); print}'); do
		
		unalias $al
		[ $VERBOSE -eq 1 ] && echo "unalias $al"
	done
	
	for fun in $(set | grep -E "lib_.* \(\)" | awk '{gsub(" \\(\\)",""); print}'); do
		
		unset $fun
		[ $VERBOSE -eq 1 ] && echo "unset $fun"
	done
	
	for var in $(set | grep -E "^LIB_*" | awk '{gsub("=.*",""); print}'); do
		
		unset $var
		[ $VERBOSE -eq 1 ] && echo "unset $var"
	done
}


lib_get_alias_definition()
{
	if [ $# -eq 0 ]; then
		return 1
	fi
	
	local LIB_FILE=""
	local FIND_OPT=""
	
	if [ "$1" == "-h" -o "$1" == "--help" ]; then
		echo "$FUNCNAME <libname> <alias_name>"
		echo "$FUNCNAME [-f|--file] <libfile> <alias_name>"
		return 0
	elif [ "$1" == "-f" -o "$1" == "--file" ]; then
		FIND_OPT="-f"
		shift
	fi

	local library="$1"
	LIB_FILE=$(lib_find $FIND_OPT $library)

	
	if [ -f "$LIB_FILE" ]; then

		local ALIAS_NAME="$2"
		
		for a in $(lib_list_def -A -f "$LIB_FILE"); do
			if [ "$ALIAS_NAME" == "$a" ]; then
				alias "$ALIAS_NAME"
			fi
		done
	fi
}

lib_get_variable_value()
{
	if [ $# -eq 0 ]; then
		return 1
	fi
	
	local LIB_FILE=""
	local FIND_OPT=""
	
	if [ "$1" == "-h" -o "$1" == "--help" ]; then
		echo "$FUNCNAME <libname> <variable_name>"
		echo "$FUNCNAME [-f|--file] <libfile> <variable_name>"
		return 0
	elif [ "$1" == "-f" -o "$1" == "--file" ]; then
		FIND_OPT="-f"
		shift
	fi

	local library="$1"
	LIB_FILE=$(lib_find $FIND_OPT $library)

	
	if [ -f "$LIB_FILE" ]; then

		local VAR_NAME="$2"
	
		for v in $(lib_list_def -V -f "$LIB_FILE"); do
			if [ "$VAR_NAME" == "$v" ]; then
				eval "echo $VAR_NAME=\${$VAR_NAME}"
			fi
		done
	fi
}


lib_get_function_code()
{
	if [ $# -eq 0 ]; then
		return 1
	fi
	
	local LIB_FILE=""
	local FIND_OPT=""
	
	if [ "$1" == "-h" -o "$1" == "--help" ]; then
		echo "$FUNCNAME <libname> <funcname>"
		echo "$FUNCNAME [-f|--file] <libfile> <funcname>"
		return 0
	elif [ "$1" == "-f" -o "$1" == "--file" ]; then
		FIND_OPT="-f"
		shift
	fi

	local library="$1"
	LIB_FILE=$(lib_find $FIND_OPT $library)

	
	if [ -f "$LIB_FILE" ]; then

		local FUN_NAME="$2"

		local LINE=$(eval "cat $LIB_FILE  | awk '/^$FUN_NAME\(\)/ { print FNR}'");

		local VARS=$(cat $LIB_FILE  | awk -v CSTART=$LINE '
		BEGIN {CEND=0; PAR=0}; 
		CEND==0 && FNR>=CSTART && /\{/ {PAR=PAR+1}
		CEND==0 && FNR>=CSTART && /\}/ {PAR=PAR-1; if (PAR==0) {CEND=FNR}}
		END {printf "-v CSTART=%d -v CEND=%d\n", CSTART, CEND}')

		local CODE=$(cat $LIB_FILE | awk $VARS 'FNR>=CSTART && FNR<=CEND {print}')

		echo -e "Codice della funzione '$FUN_NAME':\n\n$CODE"
		
		return 0
	fi
	
	return 2
}

lib_get_description()
{
	if [ $# -eq 0 ]; then
		return 1
	fi
	
	local ARGS=$(getopt -o hvA:F:V: -l help,verbose,alias:,variable:,function: -- "$@")
	
	eval set -- $ARGS

	local LIB_FILE=""
	local FIND_OPT=""
	local VERBOSE=1
	local alias_name=""
	local variable_name=""
	local function_name=""

	while true ; do
		case "$1" in
		-f|--file)           FIND_OPT="$1"     ; shift  ;;
		-A|--alias-name)    alias_name="$2"    ; shift 2;;
		-F|--function-name) function_name="$2" ; shift 2;;
		-V|--variable-name) variable_name="$2" ; shift 2;;
		-h|--help) echo "$FUNCNAME <libname> [-A|-V|-F] <name>"
				   echo "$FUNCNAME [-f|--file] <libfile> [-A|-V|-F] <name>"
		           return 0;;
		--) shift;;
		*) break;;
		esac
	done

	local library="$1"

	local ITEM_REGEX=""
			
	if [ -n "$alias_name" ]; then
		ITEM_REGEX="alias *${alias_name} *="

		if [ -z "$library" ]; then
			library=$(lib_find_def -f -A "$alias_name")
			FIND_OPT="-f"
		fi

	elif [ -n "$variable_name" ]; then
		ITEM_REGEX="${variable_name} *="		

		if [ -z "$library" ]; then
			library=$(lib_find_def -f -V "$variable_name")
			FIND_OPT="-f"
		fi

	elif [ -n "$function_name" ]; then
		ITEM_REGEX="${function_name}\(\)"

		if [ -z "$library" ]; then
			library=$(lib_find_def -f -F "$function_name")
			FIND_OPT="-f"
		fi
	fi
	
		
	LIB_FILE=$(lib_find $FIND_OPT $library)
	
	if [ -f "$LIB_FILE" ]; then


		[ -n "$ITEM_REGEX" ] || return 3
		
		local LINE=$(eval "cat $LIB_FILE  | awk 'BEGIN { first=0 }; first==0 && /^ *$ITEM_REGEX/ { print FNR; first=1}'");

		local VARS=$(cat $LIB_FILE  | awk -v LINE=$LINE '
		BEGIN {CSTART=0; CEND=0; START=1}; 
		/^#/ && FNR<LINE {if (START==1) { CSTART=FNR; CEND=CSTART; START=0} else {CEND=FNR}}
		/^$/ && FNR<LINE {START=1}
		/^ *[^#]+/ && FNR<LINE {START=1; CSTART=0; CEND=0}
		END {printf "-v CSTART=%d -v CEND=%d\n", CSTART, CEND}')

		local DESC=$(cat $LIB_FILE | awk $VARS 'FNR>=CSTART && FNR<=CEND {gsub("^# *",""); print}')

		echo "$DESC"
		
		return 0
	fi
	
	return 2
}


lib_find_def()
{
	local ARGS=$(getopt -o edfnhvAFV -l help,only-enabled,only-disable,filename,libname,verbose,only-alias,only-variables,only-functions -- "$@")
	
	eval set -- $ARGS

	local ONLY_ENABLED=0
	local ONLY_DISABLED=0
	local NAME=1
	local VERBOSE=1
	local _alias=1
	local _variables=1
	local _functions=1

	while true ; do
		case "$1" in
		-A|--only-alias)     _alias=1; _functions=0; _variables=0 ;shift ;;
		-F|--only-functions) _alias=0; _functions=1; _variables=0 ;shift ;;
		-V|--only-variables) _alias=0; _functions=0; _variables=1 ;shift ;;
		-n|--libname)        NAME=1          ; shift ;;
		-f|--filename)       NAME=0          ; shift ;;		
		-e|--only-enabled)   ONLY_ENABLED=1  ; shift ;;
		-d|--only-disabled)  ONLY_DISABLED=1 ; shift ;;
		-v|--verbose)        VERBOSE=1       ; shift ;;
		-h|--help) echo "$FUNCNAME <options> [-r|--recursive] <dir>"; return 0;;
		--) shift;;
		*) break;;
		esac
	done

	local DEF_NAME="$1"

	local found=0
	
	for library in $(lib_list_all --no-format-list --filename); do
		
		if [ $_variables -eq 1 ]; then
			for var in $(lib_list_def -V -f $library); do
				if [ "$DEF_NAME" == $var ]; then

					if [ $_alias -eq 1 -a $_functions -eq 1 ]; then
						echo -n "[VAR] "
					fi
					
					if [ $NAME -eq 1 ]; then
						echo "$( lib_name "$library")"					
					else
						echo "$library"				
					fi
				
					return 0
				fi
			done
		fi



		if [ $_alias -eq 1 ]; then
			for alias in $(lib_list_def -A -f $library); do
				if [ "$DEF_NAME" == $alias ]; then

					if [ $_alias -eq 1 -a $_variables -eq 1 ]; then
						echo -n "[ALS] "
					fi

					if [ $NAME -eq 1 ]; then
						echo "$( lib_name "$library")"					
					else
						echo "$library"				
					fi

					return 0
				fi		
			done
		fi
		
		if [ $_functions -eq 1 ]; then
			for fun in $(lib_list_def -F -f $library); do
				if [ "$DEF_NAME" == $fun ]; then

					if [ $_functions -eq 1 -a $_variables -eq 1 ]; then
						echo -n "[FUN] "
					fi

					if [ $NAME -eq 1 ]; then
						echo "$( lib_name "$library")"					
					else
						echo "$library"				
					fi

					return 0
				fi
			done
		fi
		
	done
	
	return 1
}


# main #########################################################################

if [ "sh" != "$0" -a "bash" != "$0" ]; then 

	LIBSYS="lib"
	CMD=""
	
	while true; do
		case "$1" in
			-h|--help) echo "LibSys Help (not implementated)"; exit 0;;
			import*|include*|name|find|list*|enable|disable|unset|is_*|get_*|set_*) CMD=${LIBSYS}_$1; shift;;
			log*) CMD=${LIBSYS}_$1_$2; shift 2;;
			*) break
		esac
	done

	if [ -n "$CMD" ]; then
		$CMD $@		
		exit $?
	fi
fi

