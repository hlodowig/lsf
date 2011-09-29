
### UNSET SECTION ##############################################################

lib_unset()
{
	local ARGS=$(getopt -o f -l file -- "$@")
	
	eval set -- $ARGS
	
	local options=""
	local libs=""
		
	while true ; do
		case "$1" in
		-f|--file) options="$1"; shift;;
		--) shift;;
		*) break;;
		esac
	done
	
	__lib_unset()
	{		
		local VAR_AND_FUN=$(lib_def_list $options $1 | 
			awk '{gsub("\\[(VAR|FUN)\\]","unset"); gsub("\\[ALS\\]","unalias"); printf "%s:%s\n",$1,$2}')
	
		if [ -n "$VAR_AND_FUN" ]; then
			lsf_log "Library '$1': unset variables, functions and alias"
		
			for def in $VAR_AND_FUN; do
				local CMD=$(echo $def | tr : ' ')
				
				[ "$CMD" != "unset PATH" ] || continue 
				[ "$CMD" != "unset PS1"  ] || continue
				[ "$CMD" != "unset PS2"  ] || continue
				[ "$CMD" != "unset PS3"  ] || continue
				
				lsf_log "Library '$1': $CMD"
				eval "$CMD 2> /dev/null"
			done
		fi
	
		local lib="$(lib_find $options "$1")"
	
		__lib_list_files_remove "$lib"
	}
	
	if [ $# -eq 0 ]; then
		options="--file"
		libs="$(__lib_list_files)"
	else
		libs="$@"
	fi

	for libfile in $libs; do
		__lib_unset $libfile
	done
	
	unset __lib_unset
	
	return 0
}

