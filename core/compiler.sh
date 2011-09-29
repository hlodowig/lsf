# LSF COMPILER

lsf_compiler()
{
	[ $# -eq 0 ] && return
	
	local ARGS=$(getopt -o ho:IOEF -l help,output,stdin,stdout,stderr,no-filter -- "$@")
	eval set -- $ARGS
	
	__del_spaces()
	{
		grep -v -E -e '^[[:space:]]*$' | awk '{gsub("^( |\t)*",""); print}'
	}
	
	local output=""
	local filter="__del_spaces"
	local STDIN=0
	
	while true ; do
		case "$1" in
		-o|--output)    output="$2"                    ; shift  2;;
		-I|--stdin)     STDIN=1                        ; shift   ;;
		-O|--stdout)    output="/dev/stdout"           ; shift   ;;
		-E|--stderr)    output="/dev/stderr"           ; shift   ;;
		-F|--no-filter) filter="cat"                   ; shift   ;;
		-h|--help) echo "lsf_compile help not define"  ; return 0;;
		--) shift;;
		*) break;;
		esac
	done
	
	local script=""
	
	if [ $STDIN -eq 0 ]; then
		for script in $@; do
			if [ -z "$output" ]; then
				output="${script}.sh"
				lsf_parser --compile --script "$@" | $filter > $output
				output=""
			else
				lsf_parser --compile --script "$@" | $filter > $output
			fi
		done
	else
		local INPUT="$(cat)"
		
		[ -z "$output" ] && output=/dev/stdout
		
		lsf_parser --compile --command "$INPUT" | $filter > $output
	fi
	
	unset __del_spaces
}

