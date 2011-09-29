# Crea uno script bash auto-contenuto

lib_make_script()
{
	local ARGS=$(getopt -o hl:f:m:cCvVdDxX -l help,libname:,libfile:,main:,verbose,no-verbose,dump,no-dump,executable,no-executable,print-comments,no-print-comments -- "$@")
	eval set -- $ARGS
	
	local MAIN=""
	local LIB=""
	local FILTER="^ *lib_(include|import).*"
	local VERBOSE=0
	local DUMP=0
	local EXE=1
	local EXT=".sh"
	
	while true ; do
		case "$1" in
		-l|--libname)           LIB=$(lib_find    "$2")                ; shift 2;;
		-f|--libfile)           LIB=$(lib_find -f "$2")                ; shift 2;;
		-m|--main)              MAIN="$2"                              ; shift 2;;
		-x|--executable)        EXE=1                                  ; shift  ;;
		-X|--no-executable)     EXE=0                                  ; shift  ;;
		-v|--verbose)           VERBOSE=1                              ; shift  ;;
		-V|--no-verbose)        VERBOSE=0                              ; shift  ;;
		-d|--dump)              DUMP=1                                 ; shift  ;;
		-D|--no-dump)           DUMP=0                                 ; shift  ;;
		-c|--print-comments)    FILTER="^ *lib_(include|import).*"     ; shift  ;;
		-C|--no-print-comments) FILTER="^ *(#|lib_(include|import)).*" ; shift  ;;
		-h|--help) echo "$FUNCNAME [OPTIONS] [-l|--libname] <libname> [[-m|--main] <main_function>] [<script_file>]";
		           echo "$FUNCNAME [OPTIONS] [-f|--libfile] <libname> [[-m|--main] <main_function>] [<script_file>]";
		           return 0 ;;
		--) shift;;
		*) break;;
		esac
	done
	
	[ -z "$LIB" ] && return 1
	
	local FILE_SCRIPT="$1"
	
	[ $DUMP -eq 1 ] && FILE_SCRIPT="/dev/stderr";
	 
	if [ -z "$FILE_SCRIPT" ]; then
		if [ -n "$MAIN" ]; then
			FILE_SCRIPT="${MAIN}${EXT}"
		else
			FILE_SCRIPT="${LIB%.lib}${EXT}"
		fi
	fi
	
	if [ $VERBOSE -eq 1 ]; then
		echo "Make script '$FILE_SCRIPT'..."
		echo
		echo "Output       : $FILE_SCRIPT"
		echo "Library      : $LIB"
		echo "Main function: $MAIN"
		echo
		echo "Dipendenze:"
		lib_depend -rmf "$LIB"
	fi
	
	(echo -e "#!/bin/bash\n";
	 echo "# Enable aliases";
	 echo "shopt -s expand_aliases") > "$FILE_SCRIPT"

	for lib in $(lib_depend -rmf "$LIB"); do
		
		(lib_cat -f "$lib" | grep -v -E -e "$FILTER"; echo) >> "$FILE_SCRIPT"
	done
	
	lib_cat -f "$LIB" | grep -v -E -e "$FILTER" >> "$FILE_SCRIPT"
	
	if [ -n "$MAIN" ]; then
		echo -e "\n# main\n$MAIN \$@" >> "$FILE_SCRIPT"
	fi
	
	[ $DUMP -eq 0 -a $EXE -eq 1 ] && chmod +x "$FILE_SCRIPT"
	
	return 0
}

