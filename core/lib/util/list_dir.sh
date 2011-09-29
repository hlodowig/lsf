
lib_list_dir()
{
	local ARGS=$(getopt -o rh -l recursive,help -- "$@")
	eval set -- $ARGS
	
	local OPTIONS=""
	
	while true ; do
		case "$1" in
		-r|--recursive) OPTIONS="--recursive"             ; shift    ;;
		-h|--help) echo "$FUNCNAME [-r|--recursive] <dir>"; return 0 ;;
		--) shift;;
		*) break;;
		esac
	done
	
	__dir_fun()
	{
		local libdir="$1"
		local libname="$(lib_name $libdir)"
		
		[ -n "$libname" ] || return
		
		if [ -x "$libdir" ]; then
			echo -e "[+] [DIR] [=] $(lib_name $libdir) \t $libdir"
		else
			echo -e "[-] [DIR] [=] $(lib_name $libdir) \t $libdir"
		fi
	}
	
	__lib_fun()
	{
		local library="$1"
		
		if [ -x $library ]; then
			echo -en "[+] [LIB] "
		else
			echo -en "[-] [LIB] "
		fi
		
		if lib_test --is-loaded --file $library; then
			echo -en "[*] "
		else
			echo -en "[O] "
		fi
		
		echo -e "$(lib_name $library) \t $library"
	}
	
	lib_list_apply $OPTIONS --dir-function __dir_fun --lib-function __lib_fun $*
	
	unset __lib_fun
	unset __dir_fun
}

alias lib_list_all=lib_list_dir

