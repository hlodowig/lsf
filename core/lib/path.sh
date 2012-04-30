### PATH SECTION ###############################################################

# Variabile d'ambiente contenente la lista delle directory contenenti librerie.
LIB_PATH="${LIB_PATH:-"lib"}"


__lib_path_usage()
{
	local CMD="$1"
	
	(cat << END
NAME
	${CMD:=lib_path} - Toolkit per la variabile LIB_PATH.

SYNOPSIS
	$CMD [OPTIONS] [-g|--get] [i1:i2:i3]   con 1 < in < D+1, D=# path
	
	$CMD [OPTIONS] -s|--set <path>[:<path>...]
	
	$CMD [OPTIONS] -a|--add <path> [<path>...]
	
	$CMD [OPTIONS] -r|--remove <path> [<path>...]
	
	$CMD [OPTIONS] -l|--list
	
	$CMD [OPTIONS] -R|--reset
	
	$CMD -h|--help
	
DESCRIPTION
	Il comando $CMD gestisce e manipola la variabile d'ambiente LIB_PATH del framework LSF.
	
	
GENERIC OPTIONS
	-v, --verbose
	    Stampa informazioni dettagliate.
	
	-V, --no-verbose
	    Non stampa informazioni dettagliate.
	
	-A, --absolute-path
	    Converte i path relativi in assoluti.
	
	-w, --real-path
	    Converte i path relativi agli archivi nelle relative directory temporanee.
	
	-W, --no-real-path
	    Non converte i path relativi agli archivi. (default)
	
COMMAND OPTIONS
	-g, --get
	    Restituisce il valore della variabile d'ambiente LIB_PATH.
	
	-s, --set
	    Imposta il valore della variabile d'ambiente LIB_PATH.
	
	-f, --find
	    Verifica se un path appartiene alla lista della variabile d'ambiente LIB_PATH.
	
	-a, --add
	    Aggiunge un path o una lista di path alla variabile d'ambiente LIB_PATH.
	
	-r, --remove
	    Rimuove un path o una lista di path dalla variabile d'ambiente LIB_PATH.
	
	-R, --reset
	    Rimuove tutti i path dalla variabile d'ambiente LIB_PATH.
	
	-l, --list
	    Stampa la lista di path della variabile d'ambiente LIB_PATH.
	
	-h, --help
	    Stampa questa messaggio ed esce.
	
END
	) | less
	
	return 0
}

# Toolkit per la variabile LIB_PATH
lib_path()
{
	local ARGS=$(getopt -o hgsfarRlvVAwW -l help,get,set,find,add,remove,reset,list,verbose,no-verbose,absolute-path,real-path,no-real-path -- "$@")
	eval set -- $ARGS
	
	local CMD="GET"
	local VERBOSE=0
	local ABS_PATH=0
	local REAL_PATH=0
	
	while true ; do
		case "$1" in
		-g|--get)           CMD="GET"                              ; shift    ;;
		-s|--set)           CMD="SET"                              ; shift    ;;
		-f|--find)          CMD="FIND"                             ; shift    ;;
		-a|--add)           CMD="ADD"                              ; shift    ;;
		-r|--remove)        CMD="REMOVE"                           ; shift    ;;
		-R|--reset)         CMD="RESET"                            ; shift    ;;
		-l|--list)          CMD="LIST"                             ; shift    ;;
		-A|--absolute-path) ABS_PATH=1                             ; shift    ;;
		-w|--real-path)     REAL_PATH=1                            ; shift    ;;
		-W|--no-real-path)  REAL_PATH=0                            ; shift    ;;
		-v|--verbose)       VERBOSE=1                              ; shift    ;;
		-V|--no-verbose)    VERBOSE=0                              ; shift    ;;
		-h|--help)          __lib_path_usage "$FUNCNAME"           ; return  0;;
		--) shift; break;;
		esac
	done
	
	# Restituisce il valore della variabile LIB_PATH, se non viene passato alcun
	# parametro.
	# Se come parametro viene passata una sequenza numerica separata da ':',vengono
	# retituiti i path relativi alle posizioni.
	#
	# ES.
	# > lib_path_get
	#   .:lib:/home/user/lsf/lib
	# > lib_path_get 2:3
	#   lib:/home/user/lsf/lib
	#
	__lib_path_get()
	{
		[ $VERBOSE -eq 1 ] &&
		echo "LIB_PATH: Get $*"
		
		[ -z "$LIB_PATH" ] && return
		
		local LP=""
		local lib=
		
		if [ $# -eq 0 ]; then
			for lib in $(echo -e ${LIB_PATH//:/\\n}); do
				if [ $ABS_PATH -eq 1 ]; then
					lib="$(__lib_get_absolute_path "$lib")"
				fi
				
				if [ $REAL_PATH -eq 1 ] && lib_test --is-archive "$lib"; then
					lib="$(lib_archive --track --search $lib)"
				fi
				
				LP="${LP}:${lib}"
			done
		else
			
			for path_num in $(echo $* | tr : ' '); do
				
				lib=$(echo $LIB_PATH | awk -F: -v PN=$path_num '{print $PN}')
				
				[ $ABS_PATH -eq 1 ] && lib=$(__lib_get_absolute_path "$lib")
				
				if [ $REAL_PATH -eq 1 ] && lib_test --is-archive "$lib"; then
					lib="$(lib_archive --track --search $lib)"
				fi
				
				LP=${LP}:${lib}
			done
		fi
		
		LP=${LP#:}
		LP=${LP%:}
		
		echo $LP 
	}
	
	# Stampa la lista dei path della variabile LIB_PATH, separati dal carattere di
	# newline.
	__lib_path_list()
	{
		[ $VERBOSE -eq 1 ] && echo "LIB_PATH: List"
		
		local path_list="$(__lib_path_get)"
		echo -e ${path_list//:/\\n}
	}
	
	# Imposta la variabile LIB_PATH.
	__lib_path_set()
	{
		
		local libs="$(echo "$1" | awk -F: '{for (i=NF; i>0; i--) { if (i>1) printf "%s:", $i; else print $i; }; }')"
		local lib=""
		
		[ -z "$libs" -a $ABS_PATH -eq 1 ] && libs="$LIB_PATH"
		
		[ -z "$libs" ] && return 1
		
		[ $VERBOSE -eq 1 ] &&
		echo "LIB_PATH: Set path list"
		
		LIB_PATH=""
		
		for lib in $(echo "$libs" | tr : ' '); do
			
			__lib_path_add "$lib"
		done
		
		export LIB_PATH
	}
	
	# Verifica se un path appartiene alla lista contenuta nella variabile LIB_PATH
	__lib_path_find()
	{
		local verbose=$VERBOSE
		
		if [ "$1" == "-v" ]; then
			verbose=2
			shift
		fi
		
		local path=""
		
		path=$(echo $LIB_PATH | grep -o -E -e "(^|:)$1/?(:|$)")
		# test 1
		if [ -n "$path" ]; then
			path=${path#:}; path=${path%:}
			[ $verbose -eq 1 ] && echo "lib_path: found '$path'"
			[ $verbose -eq 2 ] && echo "$path"
			return 0
		fi
		
		local abs_path=$(__lib_get_absolute_path "$1")
		path=$(echo $LIB_PATH | grep -E -e "(^|:)$abs_path/?(:|$)")
		
		# test 2
		if [ -n "$path" ]; then
			[ $verbose -eq 1 ] && echo "lib_path: found '$abs_path'"
			[ $verbose -eq 2 ] && echo "$abs_path"
			return 0
		fi
		
		local path2=$(echo $LIB_PATH | grep -E -e "(^|:).*$(basename "$1")/?(:|$)")
		
		# test 3
		if [ -n "$path2" ]; then
			path2=${path2#:}; path2=${path2%:}
			local abs_path2=$(__lib_get_absolute_path "$path2")
			
			if [ "$abs_path" == "$abs_path2" ]; then
				[ $verbose -eq 1 ] && echo "lib_path: found '$path2'"
				[ $verbose -eq 2 ] && echo "$path2"
				return 0
			fi
		fi
		
		[ $verbose -eq 1 ] && echo "lib_path: '$1' not found"
		
		return 1
	}
	
	# Aggiunge un path alla lista contenuta nella variabile LIB_PATH.
	__lib_path_add()
	{
		
		for lib in $*; do
			
			__lib_path_find "$lib" && continue
			
			[ $ABS_PATH -eq 1 ] && lib=$(__lib_get_absolute_path "$lib")
			
			if   lib_test --is-file "$lib"; then
				[ $VERBOSE -eq 1 ] &&
				echo "LIB_PATH: Add file library path: $lib"
			elif lib_test --is-dir  "$lib"; then
				[ $VERBOSE -eq 1 ] &&
				echo "LIB_PATH: Add dir library path: $lib"
			elif lib_test --is-archive  "$lib"; then
				local larc_opts="--quiet"
				[ $VERBOSE -eq 1 ] && larc_opts="--verbose"
				
				lib_archive $larc_opts --temp-dir --track --clean-dir --extract "$lib"
				
				if [ $REAL_PATH -eq 1 ]; then
					lib="$(lib_archive --track --search $lib)"
				fi
				
				[ $VERBOSE -eq 1 ] &&
				echo "LIB_PATH: Add archive library path: $lib"
			else
				[ $VERBOSE -eq 1 ] &&
				echo "LIB_PATH: Add path: '$lib' failed! No type found."
				
				continue
			fi
			if [ -n "$LIB_PATH" ]; then
				LIB_PATH="${lib%\/}:$LIB_PATH"
			else
				LIB_PATH="${lib%\/}"
			fi
		done
		
		export LIB_PATH
	}

	# Rimuove un path dalla lista contenuta nella variabile LIB_PATH.
	__lib_path_remove()
	{
		for lib in $*; do
			
			local path=$(__lib_path_find -v "$lib")
			
			[ -z "$path" ] && continue
			
			if [ $VERBOSE -eq 1 ]; then
				echo -n "LIB_PATH: Remove path '$lib'"
				
				[ "$lib" != "$path" ] && echo -n " ($path)"
				echo
			fi
			
			LIB_PATH=$(echo $LIB_PATH |
					   awk -v LIB="$path" '{gsub(LIB, ""); print}' |
					   awk '{gsub(":+",":"); print}' |
					   awk '{gsub("^:|:$",""); print}')
			
			if lib_test --is-archive "$lib"; then
				local opts="--quiet"
				[ $VERBOSE -eq 1 ] && opts="--verbose"
				lib_archive $opts --clean "$lib"
			fi
		done
	
		export LIB_PATH
	}
	
	__lib_path_reset()
	{
		[ $VERBOSE -eq 1 ] &&
			echo "LIB_PATH: Reset"
			
		export LIB_PATH=""
	}
	
	
	__lib_path_exit()
	{
		unset __lib_path_get
		unset __lib_path_set
		unset __lib_path_find
		unset __lib_path_add
		unset __lib_path_list
		unset __lib_path_remove
		unset __lib_path_reset
		unset __lib_path_exit
		
		return $1
	}
	
	case "$CMD" in
	RESET)  __lib_path_reset      ;;
	LIST)   __lib_path_list       ;;
	FIND)   __lib_path_find   "$1";;
	ADD)    __lib_path_add    "$@";;
	REMOVE) __lib_path_remove "$@";;
	SET)    __lib_path_set    "$@";;
	GET|*)  __lib_path_get    "$@";;
	esac
	
	__lib_path_exit $?
}

