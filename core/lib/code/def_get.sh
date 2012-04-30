lib_def_get()
{
	[ $# -eq 0 ] && return 1
	
	local ARGS=$(getopt -o hvAFVl:f: -l help,verbose,alias,variable,function,libname,libfile -- "$@")
	eval set -- $ARGS
		
	local DEF_NAME=""
	local LIB_FILE=""
	local VERBOSE=1
	local TYPE=""
	
	while true ; do
		case "$1" in
		-l|--libname)       LIB_FILE=$(lib_find        $2) ; shift 2;;
		-f|--libfile)       LIB_FILE=$(lib_find --file $2) ; shift 2;;
		-A|--alias-name)    TYPE="-A"                      ; shift  ;;
		-F|--function-name) TYPE="-F"                      ; shift  ;;
		-V|--variable-name) TYPE="-V"                      ; shift  ;;
		-h|--help) echo "$FUNCNAME [-A|-V|-F] <name> [-l|--libname] <libname>"
		           echo "$FUNCNAME [-A|-V|-F] <name> [-f|--libfile] <libfile>"
		           return 0;;
		--) shift;;
		*) break;;
		esac
	done
	
	DEF_NAME="$1"
	
	if [ -z "$LIB_FILE" ]; then
		LIB_FILE=$(lib_def_find --filename $TYPE $DEF_NAME)
		
		if [ -z "$TYPE" ]; then
			TYPE="$(echo "$LIB_FILE" | awk '{print $1}')"
			LIB_FILE="$(echo "$LIB_FILE" | awk '{print $2}')"
			
			case "$TYPE" in
			\[ALS\]) TYPE="-A";;
			\[FUN\]) TYPE="-F";;
			\[VAR\]) TYPE="-V";;
			esac
		fi
	fi
	
	[ -n "$LIB_FILE" ] || return 2
	[ -n "$TYPE"     ] || return 3
	
	
	__get_alias_def()
	{
		local ALIAS_NAME="$1"
		local LIB_FILE="$2"
		
		for a in $(lib_def_list -A -f "$LIB_FILE"); do
			if [ "$ALIAS_NAME" == "$a" ]; then
				
				cat $LIB_FILE  | grep -o -E -e "alias $ALIAS_NAME=([^'\";]+|'.+'|\".*\") *;?" | awk '{gsub(";$","");print}'
				
				return 0
			fi
		done
		
		return 1
	}
	
	__get_variable_def()
	{
		local VAR_NAME="$1"
		local LIB_FILE="$2"
		
		for v in $(lib_def_list -V -f "$LIB_FILE"); do
			if [ "$VAR_NAME" == "$v" ]; then
				eval "echo $VAR_NAME=\${$VAR_NAME}"
				
				return 0
			fi
		done
		
		return 1
	}
	
	__get_function_def()
	{
		local FUN_NAME="$1"
		local LIB_FILE="$2"
		
		echo "F=$FUN_NAME, LIB=$LIB_NAME, LINE=$LINE"
		
		local LINE=$(eval "cat $LIB_FILE  | awk '/^$FUN_NAME\(\)/ { print FNR}'");
		
		[ -n "$LINE" ] || return 1
		
		
		local VARS=$(cat $LIB_FILE  | awk -v CSTART=$LINE '
		BEGIN {CEND=0; PAR=0}; 
		CEND==0 && FNR>=CSTART && /\{/ {PAR=PAR+1}
		CEND==0 && FNR>=CSTART && /\}/ {PAR=PAR-1; if (PAR==0) {CEND=FNR}}
		END {printf "-v CSTART=%d -v CEND=%d\n", CSTART, CEND}')
		
		local CODE=$(cat $LIB_FILE | awk $VARS 'FNR>=CSTART && FNR<=CEND {print}')
		
		echo "$CODE"
		
		return 0	
	}
						
	case "$TYPE" in
	-A) __get_alias_def    $DEF_NAME $LIB_FILE;;
	-F) __get_function_def $DEF_NAME $LIB_FILE;;
	-V) __get_variable_def $DEF_NAME $LIB_FILE;;
	esac
	
	
	unset __get_alias_def
	unset __get_variable_def
	unset __get_function_def
	
	return 0
}

lib_def_get_description()
{
	[ $# -eq 0 ] && return 1
	
	local ARGS=$(getopt -o hvA:F:V: -l help,verbose,alias:,variable:,function: -- "$@")
	eval set -- $ARGS
	
	local LIB_FILE=""
	local FIND_OPT=""
	local VERBOSE=1
	local alias_name=""
	local variable_name=""
	local function_name=""
	
	while true ; do
		case "$1" in
		-f|--file)          FIND_OPT="$1"      ; shift  ;;
		-A|--alias-name)    alias_name="$2"    ; shift 2;;
		-F|--function-name) function_name="$2" ; shift 2;;
		-V|--variable-name) variable_name="$2" ; shift 2;;
		-h|--help) echo "$FUNCNAME <libname> [-A|-V|-F] <name>"
		           echo "$FUNCNAME [-f|--file] <libfile> [-A|-V|-F] <name>"
		           return 0;;
		--) shift;;
		*) break;;
		esac
	done
	
	local library="$1"
	local ITEM_REGEX=""
	
	if [ -n "$alias_name" ]; then
		ITEM_REGEX="alias *${alias_name} *="
		
		if [ -z "$library" ]; then
			library=$(lib_def_find --filename -A "$alias_name")
			FIND_OPT="--file"
		fi
		
	elif [ -n "$variable_name" ]; then
		ITEM_REGEX="${variable_name} *="
		
		if [ -z "$library" ]; then
			library=$(lib_def_find --filename -V "$variable_name")
			FIND_OPT="--file"
		fi
		
	elif [ -n "$function_name" ]; then
		ITEM_REGEX="${function_name}\(\)"
		
		if [ -z "$library" ]; then
			library=$(lib_def_find --filename -F "$function_name")
			FIND_OPT="--file"
		fi
	fi
	
	LIB_FILE=$(lib_find $FIND_OPT $library)
	
	if [ -f "$LIB_FILE" ]; then
		[ -n "$ITEM_REGEX" ] || return 3
		
		local LINE=$(eval "cat $LIB_FILE  | awk 'BEGIN { first=0 }; first==0 && /^ *$ITEM_REGEX/ { print FNR; first=1}'");
		
		[ -n "$LINE" ] || return 1
		
		local VARS=$(cat $LIB_FILE  | awk -v LINE=$LINE '
		BEGIN {CSTART=0; CEND=0; START=1}; 
		/^#/ && FNR<LINE {if (START==1) { CSTART=FNR; CEND=CSTART; START=0} else {CEND=FNR}}
		/^$/ && FNR<LINE {START=1}
		/^ *[^#]+/ && FNR<LINE {START=1; CSTART=0; CEND=0}
		END {printf "-v CSTART=%d -v CEND=%d\n", CSTART, CEND}')
		
		local DESC=$(cat $LIB_FILE | awk $VARS 'FNR>=CSTART && FNR<=CEND {gsub("^# *",""); print}')
		
		echo "$DESC"
		
		return 0
	fi
	
	return 2
}

