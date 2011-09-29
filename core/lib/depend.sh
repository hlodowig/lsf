# Restituisce le dipendenze di una libreria

__lib_depend_usage()
{
	local CMD="$1"
	
	(cat << END
NAME
	${CMD:=lib_test} - Stampa la lista delle dipendenze di una librerie.
	
SYNOPSIS
	$CMD [OPTIONS]  <lib_name>
	
	$CMD [OPTIONS] -f|--file  <lib_file>
	
	
	$CMD [OPTIONS] -i|--inverse|--reverse  <lib_name>
	
	$CMD [OPTIONS] -i|--inverse|--reverse -f|--file  <lib_file>
	
	
	$CMD -h|--help
	
	
DESCRIPTION
	Il comando $CMD stampa la lista delle dipendenze di una librerie.
	
OPTIONS
	-f, --file 
	    La libreria è passato come path del file associato.
	
	-n, --libname
	    Stampa i nomi delle librerie (default)
	
	-m, --filename
	    Stampa i path dei file delle librerie
	
	-r, --recursive
	    Attiva la ricerca ricorsiva delle dipendenze (default)
	
	-R, --no-recursive
	    Disattiva la ricerca ricorsava delle dipendeze.
	
	-i, --inverse, --reverse
	    Abilità la modalità di ricerca inversa delle dipendenze.
	
	-I, --no-inverse, --no-reverse
	    Disabilità la modalità di ricerca inversa delle dipendenze. (default)
	
	-v, --verbose
	    Abilita la modalità verbosa dei messaggi.
	
	-V, --no-verbose
	    Disabilita la modalità verbosa dei messaggi. (defalut)
	
	-h, --help
	    Stampa questo messaggio ed esce
	
	
END
	) | less
	
	return 0
}

lib_depend()
{
	
	local ARGS=$(getopt -o hiIfmnhrRvV -l help,inverse,reverse,no-inverse,no-reverse,file,filename,libname,verbose,recursive,no-recursive,verbose,no-verbose -- "$@")
	eval set -- $ARGS
	
	local FIND_OPT=
	local NAME=1
	local RECURSIVE=1
	local REVERSE=0
	local VERBOSE=0
	
	while true ; do
		case "$1" in
		-f|--file)                    FIND_OPT="$1"   ; shift   ;;
		-n|--libname)                 NAME=1          ; shift   ;;
		-m|--filename)                NAME=0          ; shift   ;;
		-r|--recursive)               RECURSIVE=1     ; shift   ;;
		-R|--no-recursive)            RECURSIVE=0     ; shift   ;;
		-i|--inverse|--reverse)       REVERSE=1       ; shift   ;;
		-I|--no-inverse|--no-reverse) REVERSE=0       ; shift   ;;
		-v|--verbose)                 VERBOSE=1       ; shift   ;;
		-V|--no-verbose)              VERBOSE=0       ; shift   ;;
		-h|--help) __lib_depend_usage $FUNCNAME       ; return 0;;
		--) shift;;
		*) break;;
		esac
	done

	[ $# -eq 0 ] && return 1
	
	local LIB_FILE="$(lib_find $FIND_OPT "$1")"
	
	[ -n "$LIB_FILE" ] || return 2
	
	local DEPEND=
	
	__add_dependence()
	{
		[ $# -eq 0 ] && return 1
		
		DEPEND=$( echo -e "$DEPEND\n$1" |
			      grep -v -E -e '^$')
	}
	
	if [ $REVERSE -eq 0 ]; then
		
		__find_dependence()
		{
			[ $# -eq 0 ] && return 1
			
			echo "$DEPEND" | grep -E -q -e "$1"
		}
		
		__get_dependences()
		{
			[ -n "$1" -a -f "$1" ] || return 1
			
			local LIB_DEP=
			
			eval "LIB_DEP=($(cat "$1" | grep -E -e "lib_(import|include)" | 
			awk '{gsub("include","import -i"); print}' | tr ';' '\n' | 
			awk '{gsub(" *lib_import *",""); printf "\"%s\"\n", $0}' | tr \" \'))"
			
			local dep=
			local dep2=
			
			for dep in "${LIB_DEP[@]}"; do
				for dep2 in $(lib_import --quiet --force --dummy $dep); do
					if ! __find_dependence $dep2; then
						
						__add_dependence $dep2
						
						if [ $RECURSIVE -eq 1 ]; then
							$FUNCNAME $dep2
						fi
					fi
				done
			done
		}
		
		__get_dependences "$LIB_FILE"
		
		unset __find_dependence
		unset __get_dependences
		
		if [ $VERBOSE -eq 1 ]; then
			echo "Dipendenze trovate per la libreria '$1':"
		fi
		
	else
		__find_lib()
		{
			[ -n "$1" -a -f "$1" ] || return 1
			
			if cat "$1" | grep -E -e "lib_(import|include)" | grep -qo "$LIB_FILE"; then
				return 0
			fi
			
			local LIB_NAME="$(lib_name $LIB_FILE)"
			
			if cat "$1" | grep -E -e "lib_(import|include)" | grep -qo "$LIB_NAME"; then
				return 0
			fi
			
			return 1
		}
		
		
		for lib in $(lib_list --filename --no-format-list); do
			if __find_lib $lib; then
				__add_dependence $lib
			fi
		done
		
		unset __find_lib
		
		if [ $VERBOSE -eq 1 ]; then
			echo "Dipendenze inverse trovate per la libreria '$1':"
		fi
	fi
	
	if [ $NAME -eq 0 ]; then
		echo "$DEPEND" | grep -v -E -e '^$'
	else
		local dep=
		
		for dep in $DEPEND; do
			lib_name $dep
		done
	fi
	
	unset __add_dependences
	
}

