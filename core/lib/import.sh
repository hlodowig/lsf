# Importa una libreria nell'ambiente corrente.

__lib_import_usage()
{
	local CMD=$1
	(cat << END
NAME
	${CMD:=lib_import} - Importa librerie nell'ambiente corrente.

SYNOPSIS
	$CMD
	
	$CMD [OPTIONS] <lib_name>
	
	$CMD [OPTIONS] -f|--file <lib_file>
	
	$CMD [OPTIONS] [-r|--recursive] -d|--dir <lib_dir>
	
	
	$CMD -i|--include    ( alias lib_include )
	
	$CMD -u|--update     ( alias lib_update  )
	
	$CMD -l|--list
	$CMD -L|--list-files
	$CMD -R|--list-clear
	
DESCRIPTION
	Il comando $CMD... 
	
OPTIONS
	
	-f, --file
	    Importa il file di libreria, specificandone il path, senza eseguire operazioni di naming.
	    Se il file non esiste, ritorna un codice di errore.
	
	-d, --dir
	    Importa gli script contenuti nella cartella specificata dal path,
	    senza eseguire operazioni di naming.
	    Se l'optione 'include' non è specificata, importa solo gli script abilitati,
	    altrimenti importa tutti gli script con estensione '.$LIB_EXT'.
	    (see: LIBRARY NAMING section of lib_find)
	
	-a, --archive
	    Importa gli script contenuti nella cartella specificata dal path,
	    senza eseguire operazioni di naming.
	    Se l'optione 'include' non è specificata, importa solo gli script abilitati,
	    altrimenti importa tutti gli script con estensione '.$LIB_EXT'.
	    (see: LIBRARY NAMING section of lib_find)
	
	-r, --recursive
	    Se la libreria è una cartella, importa ricorsivamente gli script nella cartella
	    e nelle sue sottocartelle.
	
	-i, --include
	    Importa una libreria senza controllare se è abilitata o meno.
	    (see: LIBRARY ACTIVATION section)
	
	-c, --check
	    Evita di importare la libreria se questa è gia stata precedentemente importata
	    nell'ambiente corrente. Qualora il sorgente della libreria è stato modificato
	    dopo l'import, questa viene importata nuovamente sovrascrivento la precedente
	    definizione.
	
	-C, --no-check
	    Importa la libreria anche se questa è già stata importata precedentemente.
	
	-F, --force
	    Forza l'import della libreria, non effettuando alcun controllo.
	    Equivale a: --include --no-check
	
	-q, --quiet
	    Disabilita la stampa dei messaggi nel log. (see: lsf_log funtions)
	
	-Q, --no-quiet
	    Abilita la stampa dei messaggi nel log. (see: lsf_log funtions)
	
	-p, --add-libpath
	    Aggiuge temporaneamente una nuova lista di path di libreria a quelli presenti
	    nella variabile d'ambiente LIB_PATH.
	
	-P, --libpath
	    Imposta temporaneamente una nuova lista di path di libreria, invece di quelli 
	    presenti nella variabile d'ambiente LIB_PATH.
	
	-s, --fast
	    Attiva la modalità fast quando è attiva l'opzione --all.
	    Disabilita i comandi di import o include per i sorgenti caricati nell'ambiente.
	    Non sicura se ci sono librerie dipendenti da librerie non attivate.
	    @see lib_enable, lib_disable
	
	-S, --no-fast
	    Disattiva la modalità fast quando è attiva l'opzione --all. (default)
	
	-D, --dummy
	    Esegue tutte le operazioni di checking, ma non importa la libreria.
	
	-h, --help
	    Stampa questo messaggio ed esce.
	
	
	Command list:
	
	-A, --all
	    Importa tutte le librerie abilitate presenti nei path della variabile
	    d'ambiente LIB_PATH.
	
	-u, --update
	    Se necessario, ricarica tutte le librerie importate se sono stati modificati
	    i sorgenti.
	
	-l, --list
	    Stampa l'elenco dei nomi di libreria importati nell'ambiente corrente.
	
	-L, --list-files
	    Stampa l'elenco dei nomi dei file di libreria importati nell'ambiente corrente.
	
	-R, --list-clear
	    Svuota la lista delle librerie attuamelmente importate.
	
	
LIBRARY ACTIVATION

	see: lib_enable, lib_disable, lib_test --is-enabled
	

EXAMPLES
	
	~ > LIB_PATH=$HOME/lib1:$HOME/lib2       oppure  
	~ > lib_path_set $HOME/lib1:$HOME/lib2   oppure
	~ > lib_path_add $HOME/lib1
	~ > lib_path_add $HOME/lib2
	
	~ > ls -R lib1
	    lib1/:
	    a.lib b.lib dir1
	    lib1/dir1:
	    c.lib dir2
	    lib1/dir1/dir2
	    d.lib f.lib 
	    ls -R lib2
	    lib2/:
	    g.lib
	
	~ > $CMD a
	    importa il file: lib1/a.lib
	
	~ > $CMD b
	    importa il file: lib1/b.lib
	
	~ > $CMD g
	    importa il file: lib2/g.lib
	
	~ > $CMD dir1
	    importa il file: lib1/dir1/c.lib
	
	~ > $CMD -r dir1
	    importa i files: lib1/dir1/c.lib, lib1/dir1/dir2/d.lib, lib1/dir1/dir2/f.lib
	
	~ > $CMD dir1:c          oppure     $CMD dir1/c
	    importa il file: lib1/dir1/c.lib
	
	~ > $CMD dir1:dir2       oppure     $CMD dir1/dir2
	    importa i files: lib1/dir1/dir2/d.lib, lib1/dir1/dir2/f.lib
	
	~ > $CMD dir1:dir2:d     oppure     $CMD dir1/dir2/d
	    importa il file: lib1/dir1/dir2/d.lib
	
	~ > $CMD dir1:dir2:f     oppure     $CMD dir1/dir2/f
	    importa il file: lib1/dir1/dir2/f.lib
	
END
	) | less
}

LIB_IMPORT=1
LIB_IMPORT_ALL=0

lib_import()
{
	[ $LIB_IMPORT -eq 1 ] || return 0
	
	local ARGS=$(getopt -o hfdircCuDqQlLRFaAp:P:sSvV -l help,file,dir,archive,include,recursive,check,no-check,update,dummy,quiet,no-quiet,list,list-files,list-clear,force,all,libpath:,add-libpath:,fast,no-fast,verbose,no-verbose -- "$@")
	eval set -- $ARGS
	
	#echo "___________________________________________________"
	#echo $ARGS
	
	local ALL=0
	local LIB=""
	local LIB_FILE=""
	local LIB_PATH_OPT=""
	local FIND_OPT=""
	local OPTIONS=""
	local INCLUDE=0
	local RECURSIVE=0
	local CHECK=1
	local UPDATE=0
	local DUMMY=0
	local QUIET=0
	local VERBOSE=0
	local FAST=0
	
	while true ; do
		
		case "$1" in
		-A|--all)        ALL=1                                        ; shift  ;;
		-f|--file)       FIND_OPT="$1"                                ; shift  ;;
		-d|--dir)        FIND_OPT="$1"                                ; shift  ;;
		-a|--archive)    FIND_OPT="$1"                                ; shift  ;;
		-r|--recursive)  RECURSIVE=1;        OPTIONS="$OPTIONS $1"    ; shift  ;;
		-c|--check)      CHECK=1;            OPTIONS="$OPTIONS $1"    ; shift  ;;
		-C|--no-check)   CHECK=0;            OPTIONS="$OPTIONS $1"    ; shift  ;;
		-i|--include)    INCLUDE=1;          OPTIONS="$OPTIONS $1"    ; shift  ;;
		-q|--quiet)      QUIET=1             OPTIONS="$OPTIONS $1"    ; shift  ;;
		-Q|--no-quiet)   QUIET=0             OPTIONS="$OPTIONS $1"    ; shift  ;;
		-v|--verbose)    VERBOSE=1           OPTIONS="$OPTIONS $1"    ; shift  ;;
		-V|--no-verbose) VERBOSE=0           OPTIONS="$OPTIONS $1"    ; shift  ;;
		-D|--dummy)      DUMMY=1;            OPTIONS="$OPTIONS $1"    ; shift  ;;
		-F|--force)      CHECK=0; INCLUDE=1; OPTIONS="$OPTIONS -C -i" ; shift  ;;
		-s|--fast)       FAST=1                                       ; shift  ;;
		-S|--no-fast)    FAST=0                                       ; shift  ;;
		-p|--add-libpath)  LIB_PATH_OPT="$1 $2"                       ; shift 2;;
		-P|--libpath)      LIB_PATH_OPT="$1 $2"                       ; shift 2;;
		-l|--list)       __lib_list_names      ; return ;; 
		-L|--list-files) __lib_list_files      ; return ;;
		-R|--list-clear)
			lib_archive --clean
			__lib_list_files_clear;
			return 0;;
		-h|--help)     __lib_import_usage $FUNCNAME;  return 0;; 
		-u|--update)     UPDATE=1                                     ; break  ;;
		--) shift;;
		-*) echo "Usa $FUNCNAME -h oppure $FUNCNAME --help per ulteriori informazioni";
		    return 1;;
		*) break;;
		esac
	done
	
	
	# lib_import --all invocation
	if [ $ALL -eq 1 ]; then
		
		[ $FAST -eq 1 ] && LIB_IMPORT_ALL=1
		
		for dir in $(lib_path --list --absolute-path --real-path)
		do
			$FUNCNAME $OPTIONS $LIB_PATH_OPT --recursive --dir $dir
		done
		
		LIB_IMPORT_ALL=0
		
		return 0
	fi
	
	# lib_import --update invocation
	if [ $UPDATE -eq 1 ]; then
		
		for lib_loaded in $(__lib_list_files); do
			$FUNCNAME $LIB_PATH_OPT --include --check --file "$lib_loaded"
		done
		
		return 0
	fi
	
	if [ $# -eq 0 ]; then
		FIND_OPT="--dir"
		LIB="."
	else
		LIB="$1"
	fi
	
	# verifica se la pathname expansion di bash è fallita
	echo "$LIB" | grep -q -E -e "[*][.]($LIB_EXT|$ARC_EXT)$" && return 3
	
	LIB_FILE=$(lib_find $LIB_PATH_OPT $FIND_OPT $LIB)
	
	if [ -z "$LIB_FILE" ]; then
		[ $QUIET -eq 1 ] || lsf_log "Library '$LIB' not found!"	
		return 1
	fi
	
	if echo "$LIB_FILE" | grep ":"; then
		SUB_LIB="$(echo "$LIB_FILE" | awk -F : '{ print $2 }')"
		LIB_FILE="$(echo "$LIB_FILE" | awk -F : '{ print $1 }')"
		#echo "LIB_FILE=$LIB_FILE, SUB_LIB=$SUB_LIB"
	fi
	
	if [ $INCLUDE -eq 0 -a ! -x "$LIB_FILE" ]; then
		[ $QUIET -eq 1 ] || lsf_log "Library '$LIB' disable!"
		return 2
	fi
	
	if [ -f "$LIB_FILE" ]; then  # se la libreria è un file o un'archivio
		
		if [ $CHECK -eq 0 ] ||
		   ! $(lib_test --is-loaded --file "$LIB_FILE") ||
		   [ $(stat -c %Y "$LIB_FILE") -gt $(__lib_list_files_get_mod_time "$LIB_FILE") ]; 
		then
			if [ $DUMMY -eq 1 ]; then
				# Stampa semplicemente il path della libreria.
				echo "$LIB_FILE"
				
			else # importa un file
			
				if ! file --mime-type "$LIB_FILE" | grep -q "gzip"; then
					
					[ $LIB_IMPORT_ALL -eq 1 ] && LIB_IMPORT=0
					source "$LIB_FILE"
					[ $LIB_IMPORT_ALL -eq 1 ] && LIB_IMPORT=1
					
					__lib_list_files_add "$LIB_FILE"
					
					[ $QUIET -eq 1 ] || lsf_log "Import library module:\t $LIB"
				
				else # importa un'archivio
					
					# Scompatta l'archivio in una directory temporanea, se non 
					# già stata associata all'archivio ne crea una nuova e ne 
					# tiene traccia.
					
					local opts="--quiet"
					
					#[ $QUIET   -eq 1 ] && opts="--quiet"
					[ $VERBOSE -eq 1 ] && opts="$opts --verbose"
					
					local lib_opts=
					
					[ -n "$SUB_LIB" ] && lib_opts="--library "$SUB_LIB""
					
					lib_archive $opts --clean-dir --track --temp-dir --extract "$LIB_FILE" $lib_opts
					
					local tmp_dir="${LIB_ARC_MAP[$LIB_FILE]}"
					
					lib_path --add "$tmp_dir"
					
					if [ -n "$SUB_LIB" ]; then
						local type_opt=
						
						if   echo "$SUB_LIB" | grep -q ".$LIB_EXT$"; then
							type_opt="--file"
						elif echo "$SUB_LIB" | grep -q ".$ARC_EXT$"; then
							type_opt="--archive"
						else
							type_opt="--dir"
						fi
						
						# importa un file dell'archivio
						$FUNCNAME $LIB_PATH_OPT $OPTIONS $type_opt  "${tmp_dir}/${SUB_LIB}"
					else
						# importa tutto l'archivio
						$FUNCNAME --recursive $LIB_PATH_OPT $OPTIONS --dir  "$tmp_dir"
					fi
					
					lib_path --remove "$tmp_dir"
				fi
			fi
		fi
		
		return 0
		
	elif [ -d "$LIB_FILE" ]; then # importa una directory
		
		local DIR="$LIB_FILE"
		
		[ $QUIET -eq 1 ] || lsf_log "Import library directory:\t $LIB_FILE"
		
		if [ $(ls -A1 "$DIR" | wc -l) -gt 0 ]; then
			
			# importa tutti i file di libreria
			for library in $DIR/*.$LIB_EXT; do
				if [ $INCLUDE -eq 1 -o -x $library ]; then
					$FUNCNAME $LIB_PATH_OPT $OPTIONS --file $library
				fi
			done
			
			# se in modalità ricorsiva
			if [ $RECURSIVE -eq 1 ]; then
			
				# importa tutte le directory
				for libdir in $DIR/*; do
					
					test -d $libdir || continue
					
					if [ $INCLUDE -eq 1 -o  -x "$libdir" ]; then
						$FUNCNAME $LIB_PATH_OPT $OPTIONS --dir $libdir
					else
						[ $QUIET -eq 1 ] || lsf_log "Library directory '$libdir' disable!"
					fi
				done
				
				# importa tutti gli archivi
				for library in $DIR/*.$ARC_EXT; do
					if [ $INCLUDE -eq 1 -o -x $library ]; then
						$FUNCNAME $LIB_PATH_OPT $OPTIONS --archive $library
					fi
				done
			fi
		fi
		
		return 0
	fi
}

