# LSF EXIT

# Esce dall'ambiente corrente rimuovendo tutte le definizioni del framework

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

lsf_exit()
{
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
	
	
	for al in $(alias | grep -E -e "($LSF_CMD_PREFIX|$LSF_LIB_CMD_PREFIX)_.*" | 
		awk '/^[[:blank:]]*(alias)[[:blank:]]*[a-zA-Z0-9_]+=/ {gsub("[[:blank:]]*|alias|=.*",""); print}'); do
		
		unalias $al
		[ $VERBOSE -eq 1 ] && echo "unalias $al"
	done
	
	for fun in $(set | grep -E "^_{0,3}($LSF_CMD_PREFIX|$LSF_LIB_CMD_PREFIX)_.* \(\)" | awk '{gsub(" \\(\\)",""); print}'); do
		
		unset $fun
		[ $VERBOSE -eq 1 ] && echo "unset $fun"
	done
	
	for var in $(set | grep -E "^LIB_*" | awk '{gsub("=.*",""); print}'); do
		
		unset $var
		[ $VERBOSE -eq 1 ] && echo "unset $var"
	done
}

