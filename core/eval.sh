# LSF COMMAND EVALUATOR

lsf_eval()
{
	[ $# -eq 0 ] && return
	
	if [ "$1" == "-h" -o "$1" == "--help" ]; then
		echo "lsf_eval help not define"
		return 0
	fi
	
	lsf_parser --command "$@"
}

