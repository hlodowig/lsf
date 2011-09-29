# LSF Main Program

lsf_main()
{
	local VERBOSE_OPT=""
	local LSF_PARSER_OPT=""
	
	while [ -n "$1" ]; do
		case "$1" in
		-h|--help)        lsf_help                 ; return $?;;
		-k|--keywords)    shift; lsf_keywords "$@" ; return $?;;
		-v|--verbose)     VERBOSE_OPT="$1"         ; shift    ;;
		--version)        lsf_version $VERBOSE_OPT ; return $?;;
		*) if [ -f "$1" ]; then source "$1";
           else echo "lsf: $1: File o directory non esistente"; fi
           shift;;
		esac
	done
}

