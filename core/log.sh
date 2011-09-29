### LOG SECTION ################################################################

# Variabile booleana d'ambiente che indica se il log è attivo 
export LIB_LOG_ENABLE=${LIB_LOG_ENABLE:-0}
# Variabile d'ambiente contenente il path del dispositivo e file di output.
export LIB_LOG_OUT=${LIB_LOG_OUT:-"/dev/stderr"}


# Log Manager
#
# Stampa messaggi di log.

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


lsf_log()
{
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

