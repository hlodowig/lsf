# LSF EXIT

# Esce dall'ambiente corrente rimuovendo tutte le definizioni del framework

__lsf_export_usage()
{
	local CMD="$1"
	
	(cat << END
NAME
	${CMD:=lib_test} - Esporta le definizioni di funzioni, variabili di LSF.
	
SYNOPSIS
	$CMD [-v|--verbose]
	
	$CMD -h|--help
	
	
DESCRIPTION
	Il comando $CMD rimuove le definizioni di funzioni, variabili e alias del framework LSF.
	
OPTIONS
	-n, --no-export
		Elimina le definizioni di funzioni e variabili dalla esportazione.
	
	-v, --verbose
	    Stampa messagi dettagliati sulle operazioni di rimozione nel log.
	
	-h, --help
	    Stampa questo messaggio ed esce.
	
END
	) | less
	
	return 0
}

lsf_export()
{
	local ARGS=$(getopt -o hnv -l help,no-export,verbose -- "$@")
	eval set -- $ARGS
	
	#echo "ARGS=$ARGS"
	
	local VERBOSE=0
	local EXPORT_OPTS=""
	
	while true ; do
		case "$1" in
		-n|--no-export) EXPORT_OPTS="-n"             ; shift   ;;
		-v|--verbose)   VERBOSE=1                    ; shift   ;;
		-h|--help)      __lsf_exit_usage "$FUNCNAME" ; return 0;;
		--) shift;;
		*) break;;
		esac
	done
	
	
	for fun in $(set | grep -E "^_{0,3}($LSF_CMD_PREFIX|$LSF_LIB_CMD_PREFIX).* \(\)" | awk '{gsub(" \\(\\)",""); print}'); do
		
		export $EXPORT_OPTS -f $fun
		[ $VERBOSE -eq 1 ] && echo "export $EXPORT_OPTS -f $fun"
	done
	
	for var in $(set | grep -E "^($LSF_VAR_PREFIX|$LSF_LIB_VAR_PREFIX).*" | awk '{gsub("=.*",""); print}'); do
		
		export $EXPORT_OPTS $var
		[ $VERBOSE -eq 1 ] && echo "export $EXPORT_OPTS $var"
	done
}

