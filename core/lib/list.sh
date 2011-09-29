# Mostra la lista delle librerie
#
# @see lib_name
# @see lib_list_apply

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


lib_list()
{
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

