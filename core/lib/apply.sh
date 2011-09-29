# Applica alla lista di librerie passate come parametri la funzione specificata,
# restituendo l'exit code relativo all'esecuzione di quest'ultima.
#
# library function definition:
#
# function_name() { ... }
#
# ES.
# > lib_set lib
#
# > function fun() { echo "$1 -> $2"; } # function definition
# >
# > lib_apply [-F|--lib-function] fun a mod mod:c
#   a -> lib/a.lib
#   mod -> lib/mod
#   mod:c -> lib/mod/c.lib
#
# > cd lib
# > lib_apply [-F|--lib-function] fun [-f|--file] a.lib mod/c.lib
#   a.lib -> lib/a.lib
#   mod/c.lib -> lib/mod/c.lib
#
# > cd lib
# > lib_apply [-F|--lib-function] fun [-d|--dir] mod
#   mod -> lib/mod
#

__lib_apply_usage()
{
	local CMD="$1"
	
	(cat <<END
NAME
	${CMD:=lib_apply} - Trova la libreria e applica una funzione specifica su di essa.
	
SYNOPSIS
	$CMD [OPTIONS] [dir:...][archive_name@[:]][dir:...]<lib_name>
	
	$CMD [OPTIONS] -f|--file    <lib_file_path>
	
	$CMD [OPTIONS] -d|--dir     <lib_dir_path>
	
	$CMD [OPTIONS] -a|--archive <lib_arc_path>
	
	
DESCRIPTION
	Il comando $CMD trova il path associato ad una libreria, sia essa file o cartella o archivio,
	e applica ai suddetti file una funzione definita dall'utente e passata come parametro.
	
	
OPTIONS
	-F, --lib-function
	    Funzione applicata alla libreria se viene trovata.
	    Sono disponibili due variabili: LIB_NAME e LIB_FILE (quest'ultimo passato come parametro).
	
	-E, --lib-error-function
	    Funzione applicata alla libreria se non viene trovata.
	    Sono disponibili due variabili: LIB_FILE e LIB_NAME (quest'ultimo passato come parametro)
	
	-f, --file
	    Verifica se il file di libreria esiste, senza eseguire operazioni di naming.
	    Se il file esiste, viene applicata la funzione specificata, altrimenti la funzione di error.
	
	-d, --dir
	    Verifica se la directory specificata dal path esiste, senza eseguire
	    operazioni di naming.
	    Se la directory esiste, viene applicata la funzione specificata, altrimenti la funzione di error.
	
	-a, --archive  
	    Verifica se l'archivio specificato dal path esiste, senza eseguire
	    operazioni di naming.
	    Se l'archivio esiste, viene applicata la funzione specificata, altrimenti la funzione di error.
	
	-h| --help
	    Stampa questo messaggio ed esce.
	
END
	) | less
	
	return 0
}


lib_apply()
{
	[ $# -eq 0 ] && return 1
	
	local ARGS=$(getopt -o h,F:E:fdaqQ -l help,lib-function:,lib-error-function:,file,dir,archive,quiet,no-quiet -- "$@")
	eval set -- $ARGS
	
	local LIB_FILE=
	local LIB_NAME=
	local SUB_LIB=
	local FIND_OPT=""
	local exit_code=
	local QUIET=0
	
	local IS_ARC=0
	local LIB_FUN="__lib_apply_default_lib_function"
	local ERR_FUN="__lib_apply_default_lib_error_function"
	
	
	while true ; do
		case "$1" in
		-F|--lib-function)       LIB_FUN="$2"   ; shift  2;;
		-E|--lib-error-function) ERR_FUN="$2"   ; shift  2;;
		-f|--file)               FIND_OPT="$1"  ; shift   ;;
		-d|--dir)                FIND_OPT="$1"  ; shift   ;;
		-a|--archive) IS_ARC=1;  FIND_OPT="$1"  ; shift   ;;
		-q|--quiet)              QUIET=1        ; shift   ;;
		-Q|--no-quiet)           QUIET=0        ; shift   ;;
		-h|--help) __lib_apply_usage $FUNCNAME  ; return 0;;
		--) shift;;
		*) break;;
		esac
	done
	
	__lib_apply_default_lib_function()
	{
		if [ $QUIET -eq 0 ]; then
			echo "$LIB_NAME=$LIB_FILE"
		fi
		
		test -n "$1"
	
	}
	
	__lib_apply_default_lib_error_function()
	{
		[ $# -eq 0 ] && return 0
		
		if [ $QUIET -eq 0 ]; then
			echo "Library '$1' not found!"
		fi
		
		return 1
	}
	
	[ -z "LIB_FUN" ] && return
	
	exit_code=0
	
	for LIB_NAME in "$@"; do
		LIB_FILE=$(lib_find $FIND_OPT $LIB_NAME)
		
		if [ -n "$LIB_FILE" ]; then
			
			if [ $IS_ARC -eq 1 ]; then
				LIB_FILE=$(lib_archive --no-verbose --no-quiet --clean-dir --track --temp-dir --extract "$LIB_FILE" | 
				           awk 'NR==1 {print}') 
				
				# WARNING: Il comando lib_archive viene eseguito un una subshell
				# per cui modifiche alla variabile LIB_ARC_MAP non verranno salvate.
			fi
		
			# esecuzione della user function
			$LIB_FUN "$LIB_FILE"
			
			exit_code=$((exit_code+$?))
			
			if [ $IS_ARC -eq 1 ]; then
				# rimozione dei file temporanei creati, se non erano stati
				# precedentemente mappati
				local path=
				local found=0
				for path in ${LIB_ARC_MAP[@]}; do
					if [ "$LIB_FILE" == "$path" ]; then
						found=1
						break
					fi
				done
			
				[ $found -eq 0 ] && rm -rf $LIB_FILE 2> /dev/null 
			fi
		else
			[ -n "$ERR_FUN" ] && $ERR_FUN "$LIB_NAME"
			
			exit_code=$((exit_code+1))
		fi
	done
	
	unset __lib_apply_default_lib_function
	unset __lib_apply_default_lib_error_function
	
	return $exit_code
}

