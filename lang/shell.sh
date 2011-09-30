# LSF SHELL

lsf_shell()
{
	if [ "$1" == "-h" -o "$1" == "--help" ]; then
		echo "lsf_shell help not define"
		return 0
	fi
	
	cat << END

 /¯¯|      /¯¯¯¯¯\   /¯¯¯¯¯¯¯¯\   
 |  |     |  |¯¯¯    |  |¯¯¯¯¯¯   Library System Framework
 |  |      \__¯¯¯\   |  ¯¯¯¯/     
 |  |          \  \  |  |¯¯¯      GPL v.3
 |  |____   __ /  /  |  |
 \______/  /_____/   \__/         Version $(lsf_version -v)

END

	lsf_parser --shell "$@"
}

