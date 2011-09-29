################################################################################
# Library System Framework - Code Library                                      #
################################################################################
#
# Libreria contenente definizioni di funzioni che estendono quelle basi del
# framework LSF relative al parsing del codice, e per la definizione di alias,
# funzioni e variabili.
#
# Copyright (C) 2010 - Luigi Capraro (luigi.capraro@gmail.com)
#


### DEFINITION SECTION #########################################################

lib_def_list()
{
	[ $# -eq 0 ] && return 1
	
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
		__get_list()
		{
			cat "$1" | 
			awk '! /^[[:blank:]]*\#/ {gsub("^[[:blank:]]*",""); print}' |
			awk '
				/^[[:blank:]]*[a-zA-Z0-9_]+=/ {gsub("[[:blank:]]*|=.*",""); print "[VAR]",$0}
				/^[[:blank:]]*(function)?[[:blank:]]*[a-zA-Z0-9|_]+\(\)/ { gsub("function|[[:blank:]]*|\\(\\).*$",""); print "[FUN]",$0}
				/(alias)[[:blank:]]*[a-zA-Z0-9_]+=/ {gsub("=[^;]*","\n");  gsub("[^\n]*alias", "[ALS]");print}' |
			sort | uniq
		}
		
		__get_var_list()
		{
			__get_list "$1" | awk '/^\[VAR\]/ {print $2}'
		}
		
		__get_fun_list()
		{
			__get_list "$1" | awk '/^\[FUN\]/ {print $2}'
		}
		
		__get_alias_list()
		{
			__get_list "$1" | awk '/^\[ALS\]/ {print $2}'
		}
		
		__is_local_var()
		{
			cat "$1" | grep -q -E -e "local *$2 *($|=)|unset *$2 *($|;)?"
		}
		
		__is_local_fun()
		{
			cat "$1" | grep -q -E -e "unset *$2 *($|;)?"
		}
		
		__is_local_alias()
		{
			cat "$1" | grep -q -E -e "unalias *$2 *($|;)?"
		}
		
		if [ $_variables -eq 1 ]; then
			for var in $(__get_var_list "$LIB_FILE"); do
				
				if ! __is_local_var $LIB_FILE $var; then
					if [ $_functions -eq 1 -a $_alias -eq 1 ]; then
						echo -n "[VAR] "
					fi
					echo "$var"
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
		lsf_log "Library '$library' not found!"
		return 1
	fi
	
	return 0
}

