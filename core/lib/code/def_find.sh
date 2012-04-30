lib_def_find()
{
	local ARGS=$(getopt -o edfmnhvAFVqtT -l help,file,only-enabled,only-disable,filename,libname,verbose,only-alias,only-variables,only-functions,quiet,print-type,no-print-type -- "$@")
	eval set -- $ARGS
	
	local FIND_OPT=
	local ONLY_ENABLED=0
	local ONLY_DISABLED=0
	local NAME=1
	local VERBOSE=0
	local QUIET=0
	local PRINT_TYPE=2
	local _alias=1
	local _variables=1
	local _functions=1
	
	while true ; do
		case "$1" in
		-A|--only-alias)     _alias=1; _functions=0; _variables=0 ;shift ;;
		-F|--only-functions) _alias=0; _functions=1; _variables=0 ;shift ;;
		-V|--only-variables) _alias=0; _functions=0; _variables=1 ;shift ;;
		-f|--file)           FIND_OPT="$1"   ; shift ;;
		-n|--libname)        NAME=1          ; shift ;;
		-m|--filename)       NAME=0          ; shift ;;
		-e|--only-enabled)   ONLY_ENABLED=1  ; shift ;;
		-d|--only-disabled)  ONLY_DISABLED=1 ; shift ;;
		-q|--quiet)          QUIET=1         ; shift ;;
		-v|--verbose)        VERBOSE=1       ; shift ;;
		-t|--print-type)     PRINT_TYPE=1    ; shift ;;
		-T|--no-print-type)  PRINT_TYPE=0    ; shift ;;
		-h|--help) echo "$FUNCNAME <options> [-r|--recursive] <dir>"; return 0;;
		--) shift;;
		*) break;;
		esac
	done
	
	local DEF_NAME="$1"
	shift
	
	local found=0
	local exit_code=1
	local s=$(echo $_alias $_functions $_variables | awk '{print $1+$2+$3}')
		
	if [ $PRINT_TYPE -eq 2 -a $s -eq 3 ]; then
		PRINT_TYPE=1
	fi
	
	__find_def()
	{
		local opt="$1"
		local library="$2"
		
		if [ "$opt" = "-A" -a $_alias     -eq 1 ] || 
		   [ "$opt" = "-F" -a $_functions -eq 1 ] || 
		   [ "$opt" = "-V" -a $_variables -eq 1 ]
		then
			for def in $(lib_def_list $opt -f $library); do
				if [ "$DEF_NAME" == $def ]; then
					
					if [ $QUIET -eq 0 ]; then
						if [ $VERBOSE -eq 1 ]; then
							echo -n "La definizione "
							case "$opt" in
							-V) echo -n "della variabile ";;
							-A) echo -n "dell'alias ";;
							-F) echo -n "della funzione ";;
							esac
							echo "'$DEF_NAME' e' stata trovata nella libreria: "
						elif [ $PRINT_TYPE -eq 1 ]; then
							case "$opt" in
							-V) echo -n "[VAR] ";;
							-A) echo -n "[ALS] ";;
							-F) echo -n "[FUN] ";;
							esac
						fi
						
						if [ $NAME -eq 1 ]; then
							echo "$( lib_name "$library")"
						else
							echo "$library"
						fi
					fi
					
					return 0
				fi
			done
		fi
		
		return 1
	}
	
	local libs=
	
	if [ $# -eq 0 ]; then
		libs="$(lib_list --no-format-list --filename)"
	else
		local lib=
		
		for lib in $@; do
			libs="$libs $(lib_find $FIND_OPT $lib)"
		done
	fi
	
	[ -n "$libs" ] || return 1
	
	for library in $libs; do
	
		__find_def -V "$library"; exit_code=$?; [ $exit_code -eq 0 ] && break
		__find_def -A "$library"; exit_code=$?; [ $exit_code -eq 0 ] && break
		__find_def -F "$library"; exit_code=$?; [ $exit_code -eq 0 ] && break
	done
	
	unset __find_def
	
	return $exit_code
}

