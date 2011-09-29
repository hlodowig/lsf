# LSF Keywords

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

lsf_keywords()
{
	
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
	
	return $exit_code
}

