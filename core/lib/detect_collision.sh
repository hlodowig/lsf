# Verifica se ci sono collisioni nello spazio dei nomi dei path di libreria

__lib_detect_collision()
{
	local CMD="$1"
	
	(cat << END
NAME
	${CMD:=lib_test} - Verifica se ci sono delle collisioni nello spazio dei nomi.
	
SYNOPSIS
	$CMD [OPTIONS] [<libname> ...]
	
	$CMD -h|--help
	
	
DESCRIPTION
	Il comando $CMD verifica se ci sono delle collisioni nello spazio dei nomi.
	Utile per verificare che un nome sia univoco all'interno delle librerie.
	
OPTIONS
	-f, --print-files
	    Stampa i nomi delle librerie che collidono e i path dei file associati.
	
	-F, --no-print-files
	    Stampa solo i nomi delle librerie che collidono.
	
	-h, --help
	    Stampa questo messaggio ed esce
	
	
END
	) | less
	
	return 0
}



lib_detect_collision()
{
	local ARGS=$(getopt -o hfF -l help,print-files,no-print-files -- "$@")
	eval set -- $ARGS
	
	
	local libs=""
	local lib=""
	local libfile=""
	local libpath=""
	local exit_code=1
	local PRINT_FILES=0
	
	while true ; do
		case "$1" in
		-f|--print-files)    PRINT_FILES=1                       ; shift   ;;
		-F|--no-print-files) PRINT_FILES=0                       ; shift   ;;
		-h|--help) __lib_detect_collision $FUNCNAME              ; return 0;;
		--) shift;;
		*) break;;
		esac
	done
	
	local ALL_LIBS=0
	
	if [ $# -eq 0 ]; then
		ALL_LIBS=1
		
		libs=$(
		for libpath in $(lib_path --list --absolute-path --real-path)
		do
			for libfile in $(__lib_list_dir "$libpath")
			do
				lib_name "$libfile"
			done
		done | sort | uniq -c | grep -E -e "^ *[2-9][0-9]*" | awk '{print $2}')
	else
		local libs="$@"
	fi
	
	for lib in $libs; do
		
		if [ $ALL_LIBS -eq 1 ]; then
			echo "$lib"
			
			if [ $PRINT_FILES -eq 1 ]; then
				lib_find --all "$lib"
				echo
			fi
		else
			local deps="$(lib_find --all "$lib")"
			
			if [ -n "$deps" ]; then
				echo "$lib"
				
				if [ $PRINT_FILES -eq 1 ]; then
					echo "$deps"
					echo
				fi
				
				exit_code=0
			fi
		fi
	done
	
	return $exit_code
}

