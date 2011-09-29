### List functions #############################################################

__lib_list_apply_usage()
{
	local CMD="$1"
	
	(cat << END
NAME
	${CMD:=lib_test} - Applica una funzione definita dall'utente per file, directory, e archivi, navigando le cartelle specificate.
	
SYNOPSIS
	$CMD [-r|--recursive] -f|--function         <fun>     [DIR ...]
	
	$CMD [-r|--recursive] -l|--lib-function     <lib_fun> [DIR ...]
	
	$CMD [-r|--recursive] -d|--dir-function     <dir_fun> [DIR ...]
	
	$CMD [-r|--recursive] -a|--archive-function <arc_fun> [DIR ...]
	
	
	$CMD [-r|--recursive] [-f <arc_fun>] [-l <lib_fun>] [-d <dir_fun>] [-a <arc_fun>] [DIR ...]
	
	
	$CMD -h|--help
	
	
DESCRIPTION
	Il comando $CMD applica una funzione definita dall'utente per file, directory, e archivi,
	navigando le cartelle specificate.
	
OPTIONS
	-f, --function <fun_name>
	    Imposta una generica user function per file di libreria, directory e archivi.
	
	-l, --lib-function <lib_name>
	    Imposta una generica user function per file di libreria.
	
	-d, --dir-function <dir_name>
	    Imposta una generica user function per directory di libreria.
	
	-a, --archive-function <archive_name>
	    Imposta una generica user function per archivi di libreria.
	
	-r, --recursive
	    Naviga ricorsivamente le directory.
	
END
	) | less
	
	return 0
}

lib_list_apply()
{
	local ARGS=$(getopt -o rhf:d:l:a: -l recursive,help,function:,dir-function:,lib-function:,archive-function -- "$@")
	eval set -- $ARGS
	
	#echo "ARGS=$ARGS"
	
	local DIR_FUN=""
	local LIB_FUN=""
	local ARC_FUN=""
	local RECURSIVE=0
	local libset=""
	
	while true ; do
		case "$1" in
		-f|--function) LIB_FUN="$2";DIR_FUN="$2";ARC_FUN="$2 "; shift  2;;
		-d|--dir-function)     DIR_FUN="$2"                   ; shift  2;;
		-l|--lib-function)     LIB_FUN="$2"                   ; shift  2;;
		-a|--archive-function) ARC_FUN="$2"                   ; shift  2;;
		-r|--recursive)        RECURSIVE=1                    ; shift   ;;
		-h|--help)       __lib_list_apply_usage "$FUNCNAME"   ; return 0;;
		--) shift;;
		*) break;;
		esac
	done
	
	[ -z "$LIB_FUN" ] && [ -z "$DIR_FUN" ] && [ -z "$ARC_FUN" ] && retunr 2
	 
	__already_visited()
	{
		[ -n "$libset" ] || return 2
		
		for lib in ${libset//;/ }; do
			if [ "$1" = "$lib" ]; then
				return 0
			fi
		done
		
		return 1
	}
	__list_lib()
	{
		local DIR="$(__lib_get_absolute_path "$1")"
		local libdir=""
		local libname=""
		
		! lib_test -d "$DIR" || __already_visited "$DIR" && return 1
		
		[ -z "$DIR_FUN" ] || $DIR_FUN "$DIR"
		libset="$libset;$DIR"
		
		if [ $(ls -A1 "$DIR" | wc -l) -gt 0 ]; then
		
			if [ -n "$LIB_FUN" ]; then
				for library in $DIR/*.$LIB_EXT; do
					! lib_test --file "$library"  || 
					__already_visited $library && 
					continue
					
					$LIB_FUN "$library"
					libset="$libset;$library"
				done
			fi
			
			if [ -n "$ARC_FUN" ]; then
				for library in $DIR/*.$ARC_EXT; do
					 ! lib_test --archive "$library"  || 
					 __already_visited $library && 
					 continue
					
					$ARC_FUN "$library"
					libset="$libset;$library"
				done
			fi
			
			if [ $RECURSIVE -eq 1 ]; then
				for libdir in $DIR/*; do
					test -d $libdir || continue
					
					if [ -x "$libdir" ]; then
						$FUNCNAME "$libdir"
					fi
				done
			fi
		
		fi
	}
	
	local paths="$*"
	
	if [ $# -eq 0 ]; then
		
		paths="$(lib_path --list --absolute-path --real-path)"
		RECURSIVE=1
	fi
	
	for DIR in $paths; do
		
		test -d "$DIR" || continue
		
		__list_lib $DIR
	done
	
	unset __list_lib
}

