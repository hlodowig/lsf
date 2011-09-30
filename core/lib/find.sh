# Trova il file associato ad una libreria o ad una cartella
# lib_find

__lib_find_usage()
{
	local CMD="$1"

	(cat <<END
NAME
	${CMD:=lib_find} - Restituisce il path della libreria passato come parametro.

SYNOPSIS
	$CMD [OPTIONS] [dir:...][archive@:][dir:...]<lib_name>
	
	$CMD [OPTIONS] -f|--file <lib_file>
	
	$CMD [OPTIONS] -d|--dir <lib_dir>
	
DESCRIPTION
	Il comando $CMD trova il path associato ad una libreria, sia essa file o cartella.
	
	
OPTIONS
	
	-f, --file
	    Verifica se il file di libreria esiste, senza eseguire operazioni di naming.
	    Se il file non esiste, ritorna un exit code pari a 1, altrimenti ritorna 0
	    e ne stampa il path sullo standard output (se l'optione quiet non è specificata).
	
	-d, --dir
	    Verifica se la directory specificata dal path esiste, senza eseguire
	    operazioni di naming.
	    Se la directory non esiste, ritorna un exit code pari a 1, altrimenti ritorna 0
	    e ne stampa il path sullo standard output (se l'optione quiet non è specificata).
	
	-a, --archive  ARCHIVE_PATH[:LIB_PATH]
	    Verifica se l'archivio specificato, o il file contenuto in esso, esiste, senza eseguire
	    operazioni di naming.
	    Se l'archivio, o il file in esso specificato, non esiste, ritorna un exit code pari a 1, 
	    altrimenti ritorna 0 e ne stampa il path sullo standard output 
	    (se l'optione quiet non è specificata).
	
	-p, --add-libpath
	    Aggiuge temporaneamente una nuova lista di path di libreria a quelli presenti
	    nella variabile d'ambiente LIB_PATH.
	
	-P, --libpath
	    Imposta temporaneamente una nuova lista di path di libreria, invece di quelli 
	    presenti nella variabile d'ambiente LIB_PATH.
	
	-F, --first
	    Ritorna il primo path di libreria che corrisponde al nome di libreria cercato.
	
	-A, --all
	    Ritorna tutti i path di libreria che corrispondono al nome di libreria cercato.
	
	-q, --quiet
	    Non stampa il path sullo standard output.
	
	-Q, --no-quiet
	    Se trova il file, lo stampa sullo standard output.
	
	
LIBRARY NAMING
	
	Il comando $CMD di default associa ad ogni file di libreria un nome.
	Una libreria potrebbe essere o un file o una cartella contenente altri file
	di libreria.
	
	Il nome di una libreria è così costruito:
	- se il file o la cartella di libreria ha una directory genitrice che si trova 
	  nella variabile LIB_PATH, questa è eliminata dal path.
	- se la libreria è un file l'estensione '.$LSF_LIB_EXT' viene omessa.
	- Optionalmente il carattere '/' può essere sostituito dal carattere ':'
	
	
EXAMPLES
	
	Se la libreria cercata è, ad esempio, 'math:sin', il comanando cerchera
	all'interno di ogni cartella della variabile LIB_PATH, o il file 'math/sin.$LSF_LIB_EXT'
	oppure la cartella math/sin.
	
	
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
	    $HOME/lib1/a.lib (return 0)
	
	~ > $CMD b
	    $HOME/lib1/b.lib (return 0)
	
	~ > $CMD g
	    $HOME/lib2/g.lib (return 0)
	
	~ > $CMD dir1
	    $HOME/lib1/dir1 (return 0)
	
	~ > $CMD dir1:c          oppure     $CMD dir1/c
	    $HOME/lib1/dir1/c.lib (return 0)
	
	~ > $CMD dir1:dir2       oppure     $CMD dir1/dir2
	    $HOME/lib1/dir1/dir2 (return 0)
	
	~ > $CMD dir1:dir2:d     oppure     $CMD dir1/dir2/d
	    $HOME/lib1/dir1/dir2/d.lib (return 0)
	
	~ > $CMD dir1:dir2:f     oppure     $CMD dir1/dir2/f
	    $HOME/lib1/dir1/dir2/f.lib (return 0)
	
	~ > $CMD --file lib2/g.lib
	    $HOME/lib2/g.lib (return 0)
	
	~ > $CMD --file lib1/g.lib
	    (return 1)

	~ > $CMD --dir lib1/dir1
	    $HOME/lib1/dir1 (return 0)
	
	~ > $CMD --dir lib2/dir1
	    (return 1)
	
END
	) | less
	return 0
}

lib_find()
{
	[ $# -eq 0 -o -z "$*" ] && return 1
	
	local ARGS=$(getopt -o hf:d:a:p:P:FAqQvV -l help,file:,dir:,archive:,add-libpath:,libpath:,first,all,quiet,no-quiet,verbose,no-verbose -- "$@")
	eval set -- $ARGS
	
	#echo "FIND ARGS=$ARGS" > /dev/stderr
	
	local QUIET=0
	local libpath=""
	local ARCHIVE_MODE=0
	local VERBOSE=0
	local opts=
	local add_path=1
	local FIND_ALL=0
	
	while true ; do
		case "$1" in
		-q|--quiet)        QUIET=1; opts="$opts $1"   ; shift   ;;
		-Q|--no-quiet)     QUIET=0                    ; shift   ;;
		-p|--add-libpath)  libpath="$2"; add_path=1   ; shift  2;;
		-P|--libpath)      libpath="$2"; add_path=0   ; shift  2;;
		-f|--file) 
			[ -f "$2" ] && echo $2 | grep -q -E -e "[.]$LSF_LIB_EXT$" || return 1
			[ $QUIET -eq 1 ] || echo "$2" #__lib_get_absolute_path "$2"
			return 0;;
		-d|--dir)
			[ -d "$2" ] || return 1
			[ $QUIET -eq 1 ] || echo "$2" #__lib_get_absolute_path "$2"
			return 0;;
		-a|--archive)      ARCHIVE_MODE=1             ; shift   ;;
		-F|--first)        FIND_ALL=0                 ; shift   ;;
		-A|--all)          FIND_ALL=1                 ; shift   ;;
		-v|--verbose)      VERBOSE=1; opts="$opts $1" ; shift   ;;
		-V|--no-verbose)   VERBOSE=0                  ; shift   ;;
		-h|--help)         __lib_find_usage $FUNCNAME ; return 0;;
		--) shift;;
		*) break;;
		esac
	done
	
	#return 1
	
	local LIB="${1//://}"
	
	if [ $ARCHIVE_MODE -eq 1 ]; then
		lib_archive --no-quiet $opts --search $LIB
		
		return $?
	fi
	
	if [ $add_path -eq 1 ]; then
		#libpath="$libpath:$LIB_PATH"
		#libpath="$libpath:$(lib_path --list)"
		#libpath="$libpath:$(lib_path --list --absolute-path)"
		#libpath="$libpath:$(lib_path --list --real-path)"
		
		libpath="$libpath:$(lib_path --list --absolute-path --real-path)"
	fi
	
	
	local libdir=
	local exit_code=1
	
	for libdir in ${libpath//:/ }; do
		
		if [ -d "${libdir}/$LIB" ]; then
			
			[ $QUIET -eq 1 ] || echo ${libdir}/$LIB
			
			[ $FIND_ALL -eq 0 ] && return 0
			
			exit_code=0
			
		elif [ -f "${libdir}/$LIB.$LSF_LIB_EXT" ]; then
			
			[ $QUIET -eq 1 ] || echo  ${libdir}/$LIB.$LSF_LIB_EXT
			
			[ $FIND_ALL -eq 0 ] && return 0
			
			exit_code=0
			
		elif echo "$LIB" | grep -q "@"; then
			
			local lib="$LIB"
			local regex="^.*@"
			
			LIB="$(echo "$lib" | grep -o -E -e "$regex" | awk '{gsub("@",""); print}').$LSF_ARC_EXT"
			SUB_LIB="$(echo "$lib" | awk -v S="$regex" '{gsub(S,""); print}')"
			SUB_LIB="${SUB_LIB#/}"
			
			lib_archive --no-quiet $opts --search "${libdir}/$LIB:$SUB_LIB"
			
			[ $FIND_ALL -eq 0 ] && return 0
			
			exit_code=$?
		fi
	done
	
	return $exit_code
}

