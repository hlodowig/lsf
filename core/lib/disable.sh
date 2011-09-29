# Disabilita una libreria per l'import.

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

lib_disable()
{
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

