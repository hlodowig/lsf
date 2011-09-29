# Implementa una serie di operatori booleani.

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

lib_test()
{
	
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

