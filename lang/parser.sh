# Copyright (C) 2011 - Luigi Capraro (luigi.capraro@gmail.com)
#
# Import Utilities is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# Import Utilities is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
# See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Import Utilities; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, 
# Boston, MA  02110-1301  USA
#


# Esegue il parsing dei comandi LSF.
lsf_parser()
{
	local SCRIPT_LINE=()
	local SCRIPT_FILE=""
	local CODE_PROMPT="> "
	local CHECK_IMPORT=1
	local SHELL=0
	local VERBOSE=0
	local DEBUG=0
	local DUMMY=0
	local DUMP=0
	local SYNTAX_HELP=1
	local COMPILE=0
	
	while [ -n "$1" ]; do
		case "$1" in
		-h|--help)            lsf_help                           ; return $?;;
		-i|--interactive|--shell)       SHELL=1                  ; shift    ;;
		-I|--no-interactive|--no-shell) SHELL=0                  ; shift    ;;
		-s|--script)          SCRIPT_FILE="$2";
		   [ -f "$2" ] && mapfile SCRIPT_LINE < $2               ; shift   2;;
		-i|--check-import)    CHECK_IMPORT=1                     ; shift    ;;
		-I|--no-check-import) CHECK_IMPORT=0                     ; shift    ;;
		-D|--debug)           DEBUG=1                            ; shift    ;;
		-d|--dump)            DUMP=1                             ; shift    ;;
		-v|--verbose)         VERBOSE=1                          ; shift    ;;
		-c|--command)         shift                              ; break    ;;
		-C|--compile)         COMPILE=1                          ; shift    ;;
		*) break;
		esac
	done
	
	if [ $COMPILE -eq 1 ]; then
		DUMP=1
		VERBOSE=0
		DEBUG=0
	fi
	
	local CMD="$@"
	local INPUT_LINE=""
	local WORK_LINE=""
	local RUN_LINE=""
	local LINE=""
	
	local CONTEXT=0
	local CONTEXT_ID="main"
	
	local CONTEXT_PREVIOUS=0
	local CONTEXT_ID_PREVIOUS=""
	
	local CONTEXT_STACK=()
	local CONTEXT_STACK_ID=()
	local CONTEXT_SIZE=0
	
	# Context Types
	local CONTEXT_COMMAND=0
	local CONTEXT_CONDITION=1
	local CONTEXT_FUNCTION=2
	local CONTEXT_SUBSHELL=3
	local CONTEXT_STRING=4
	local CONTEXT_BLOCK=5
	local CONTEXT_MODULE=6
	local CONTEXT_COMMENT=7
	
	__context_print()
	{
		echo "Current Context   ID: $CONTEXT_ID"
		echo "Current Context Type: $CONTEXT"
		
		echo "Previous Context   ID: $CONTEXT_ID_PREVIOUS"
		echo "Previous Context Type: $CONTEXT_PREVIOUS"
		
		echo "Context Stack Size $CONTEXT_SIZE"
		
		echo "Context Stack Type: [${CONTEXT_STACK[@]}]"
		echo "Context Stack ID  : [${CONTEXT_STACK_ID[@]}]"
		
	}

	__context_reset()
	{
		CONTEXT_STACK=()
		CONTEXT_STACK_ID=()
		CONTEXT=0
		CONTEXT_ID=""
		CONTEXT_SIZE=0
		
	}
	
	__context_push()
	{
		CONTEXT_STACK[$CONTEXT_SIZE]=$1
		CONTEXT_PREVIOUS=$CONTEXT
		CONTEXT_ID_PREVIOUS=$CONTEXT_ID
		CONTEXT=$1
		CONTEXT_ID="$2"
		CONTEXT_STACK_ID[$CONTEXT_SIZE]="$2"
		let CONTEXT_SIZE++
	}
	
	__context_pop()
	{
		[ $CONTEXT_SIZE -eq 0 ] && return 1
		
		let CONTEXT_SIZE--
		CONTEXT_PREVIOUS=${CONTEXT_STACK[$CONTEXT_SIZE]}
		CONTEXT_ID_PREVIOUS=${CONTEXT_STACK_ID[$CONTEXT_SIZE]}
		unset CONTEXT_STACK[$CONTEXT_SIZE]
		unset CONTEXT_STACK_ID[$CONTEXT_SIZE]
		
		if [ $CONTEXT_SIZE -gt 0 ]; then
			CONTEXT=${CONTEXT_STACK[$CONTEXT_SIZE-1]}
			CONTEXT_ID=${CONTEXT_STACK_ID[$CONTEXT_SIZE-1]}
		else
			CONTEXT=0
			CONTEXT_ID="main"
		fi
	}
	
	__context_type()
	{
		[ $CONTEXT_SIZE -eq 0 ] && return 1
		
		echo ${CONTEXT_STACK[$CONTEXT_SIZE-1]}
	}
	
	__context_id()
	{
		[ $CONTEXT_SIZE -eq 0 ] && return 1
		
		echo ${CONTEXT_STACK_ID[$CONTEXT_SIZE-1]}
	}
	
	__context_previous_type()
	{
		echo ${CONTEXT_PREVIOUS}
	}
	
	__context_previous_id()
	{
		echo ${CONTEXT_ID_PREVIOUS}
	}
	__context_parent_type()
	{
		[ $CONTEXT_SIZE -lt 2 ] && return 1
		echo ${CONTEXT_STACK[$CONTEXT_SIZE-2]}
	}
	
	__context_parent_id()
	{
		[ $CONTEXT_SIZE -lt 2 ] && return 1
		echo ${CONTEXT_STACK_ID[$CONTEXT_SIZE-2]}
	}
	
	__context_is_root()
	{
		return $CONTEXT_SIZE
	}
	
	__context_size()
	{
		echo $CONTEXT_SIZE
	}
	
	__context_type_string()
	{
		case $1 in
		$CONTEXT_COMMAND)   echo -n "COMMAND";;
		$CONTEXT_CONDITION) echo -n "CONDITION";;
		$CONTEXT_STRING)    echo -n "STRING";;
		$CONTEXT_FUNCTION)  echo -n "FUNCTION";;
		$CONTEXT_BLOCK)     echo -n "BLOCK";;
		$CONTEXT_MODULE)    echo -n "MODULE";;
		$CONTEXT_COMMENT)   echo -n "COMMENT";;
		0)                  echo -n "NULL";;
		esac
	}
	
	__context_print_status()
	{
		echo "Current Context  : $(__context_type_string $CONTEXT) [$CONTEXT_ID]"
		if (( CONTEXT_SIZE > 1 )); then
		echo "Parent Context   : $(__context_type_string $(__context_parent_type)) [$(__context_parent_id)]"
		fi
		
		echo "Previous Context : $(__context_type_string $CONTEXT_PREVIOUS) [$CONTEXT_ID_PREVIOUS]"
	}
	
	__context_print_stack()
	{
		echo "Context Stack: [size: $(__context_size)]"
		
		local i=
		for (( i=$CONTEXT_SIZE-1; i>=0; i-- )); do
			echo " - $(__context_type_string ${CONTEXT_STACK[$i]}) [${CONTEXT_STACK_ID[$i]}]"
		done
	}
	
	local -a MODULES=()
	local -A NAMESPACES=()
	
	__module_add()
	{
		if echo "${MODULES[@]}" | grep -q -v -w $1; then
			MODULES=( ${MODULES[@]} $1 )
		fi
		
		NAMESPACES[$1]="$2 ${NAMESPACES[$1]}"
	}
	
	__module_remove()
	{
		unset NAMESPACES[$1]
	}
	
	__module_find_fun()
	{
		echo "${NAMESPACES[$1]}" | grep -q -w "$2"  && return 0
		
		return 1
	}
	
	__module_find()
	{
		local funcname="$1"
		local module=""
		
		for module in ${MODULES[@]}; do
			if __module_find_fun $module $funcname; then
				echo ${module}_${funcname}
				return 0
			fi
		done
		
		return 1
	}
	
	__module_print()
	{
		local module=""
		
		for module in ${MODULES[@]}; do
			echo "Module: $module { ${NAMESPACES[$module]} }"
		done
	}
	
	__module_reset()
	{
		unset MODULES
		unset NAMESPACES
	}
	
	__error()
	{
		echo "$*" > /dev/stderr
	}
	
	__debug()
	{
		[ $DEBUG -eq 1 ] && __error "$*"
	}
	
	__lsf_execute()
	{
		CMD="$@"
		
		local exit_code=0
		
		[ $VERBOSE -eq 1 ] && echo -e "${CODE_PROMPT}$CMD"
		
		if [ $DUMP -eq 0 ]; then
			# esegui il comando
			eval "$(echo -e "$CMD")"
			
			# verifica degli import
			if [ $? -ne 0 -a $CHECK_IMPORT -eq 1 ]; then
				if echo "$CMD" | grep -q -E -e "^(.*;[[:space:]]*)?lib_(import|include *[^;]+(;|$))"; then
					echo -e "LSF: import error: $CMD" > /dev/stderr
					exit_code=3
				fi
			fi
		else
			echo -ne "$CMD"
		fi
		
		PREV_CMD="$CMD"
		CMD=""
		
		return $exit_code
	}
	
	__lsf_status()
	{
		[ $DEBUG -eq 1 ] || return 0
		
		(
			echo "Parsing status:"
			echo " - WORD       : <$WORD>"
			echo " - LINE       : <$LINE>"
			echo
			echo "Command status:"
			echo " - WORK LINE  : <$WORK_LINE>"
			echo " - RUN  LINE  : <$RUN_LINE>"
			echo
			if [ "$WORD" != "$REAL_WORD" ]; then
			echo "Command substitution:"
			echo "- WORD : $WORD -> '$REAL_WORD'"
			fi
			echo
			echo "Current command    : $COMMAND"
			echo "Annidation level   : $CONTEXT_SIZE"
			echo
			__context_print_status
			echo
			if [ $VERBOSE -eq 1 ]; then
				__context_print_stack
			fi
			echo "----------------------------------"
			echo
		) > /dev/stderr
	}
	
	local WORD=""
	local PREV_WORD=""
	local COMMAND=""
	local MODULE=""
	
	__lsf_update_run_line()
	{
		[ $# -eq 0 ] && return 0
		
		local word="$1"
		shift
		local real_word="$@"
		
		#debug
		#echo "$word -> $real_word"
		
		word="${word//[/\[}"
		word="${word//]/\]}"
		word="${word//\//\\/}"
		word="${word//\\/\\}"
		word="${word//$/\\$}"
		word="${word//\*/[*]}"
		word="${word//+/[+]}"
		word="${word//|/[|]}"
		
		word="${word/()/[[:space:]]*()}"
		
		case "$word" in
		"\n") word="\\$word";;
		"}elif") word="}.*elif";;
		"}else{") word="}.*else.*{";;
		esac
		
		
		
		local regex="^[[:space:]]*$word"
		local match=$(echo "$WORK_LINE" | grep -o "$regex")
		
		if [ -z "$match" ]; then
			echo "LSF: Matching failed: regex='$regex' in '$WORK_LINE'" > /dev/stderr
			return 1
		fi
		
		local spaces="$(echo "$match" | grep -o "^[[:space:]]*")"
		
		#debug
		#echo "echo \"$WORK_LINE\" | grep -o \"$regex\""
		#echo "MATCH: [$match] (pos ${#match})"
		
		RUN_LINE="${RUN_LINE}${spaces}${real_word}"
		
		if [ "$WORK_LINE" != "$match" ]; then
			WORK_LINE="${WORK_LINE:${#match}}"
		else
			WORK_LINE=""
		fi
		
		#debug
		#echo "SPACES='$spaces' (${#spaces})"
		#echo "echo NEW RUN  LINE: \"$RUN_LINE\""
		#echo "echo NEW WORK LINE: \"$WORK_LINE\""
	}
	
	__lsf_parse_command()
	{
		if [ "$1" == "$COMMAND" ]; then
			COMMAND="${COMMAND//./_}"
			
			REAL_WORD=$(lsf_keywords --function-name "$COMMAND")
			[ -n "$REAL_WORD" ] && return 0
			
			REAL_WORD=$(__module_find $1)
			[ -n "$REAL_WORD" ] && return 0
			
			REAL_WORD="$COMMAND"
		fi
	}
	
	__lsf_parse_word()
	{
		[ $# -eq 0 ] && return 0
		
		__debug "Parse Word: '$1'"
		
		PREV_WORD="$WORD"
		WORD="$1"
		
		local REAL_WORD="$1"
		local NEW_LINE=0
		local exit_code=0
		local BLOCK_PARSE=1
		
		case $CONTEXT in
		$CONTEXT_COMMAND)
			case "$WORD" in
			"{")
				__context_push $CONTEXT_BLOCK "block {}"
				COMMAND="";;
			"}")
				__context_is_root ||
				[ $(__context_parent_type) -ne $CONTEXT_BLOCK ] && return 1
				
				__context_pop
				COMMAND="";;
			else|elif|"}else{"|"}elif"|fi|done|'esac')
				__context_pop
				COMMAND="";;
			'('|'$('|'$((')
				[ "$WORD" == "(" -a "$(__context_parent_id)" != "case" ] || 
				__context_push $CONTEXT_BLOCK "block ${WORD})"
				COMMAND="";;
			")")
				if [ "$(__context_parent_id)" != "case" ]; then
					__context_is_root && 
					[[ "$(__context_parent_id)" != 'block ()'  && 
					 "$(__context_parent_id)" != 'block $()' ]] && return 1
					__context_pop
					COMMAND=""
				fi;;
			'))')
				__context_is_root || [ "$(__context_parent_id)" != 'block $(())' ] && return 1
				__context_pop
				COMMAND="";;
			\'|\")
				__context_push $CONTEXT_STRING "$WORD";;
			function|*\(\))
				__context_push $CONTEXT_FUNCTION "$WORD"
				COMMAND="$WORD";;
			';'|'&'|'&&'|'||'|'!'|'|')
				if [ $CONTEXT_SIZE -eq 0 ]; then
					COMMAND=""
				fi;;
			'if'|'for'|'while'|'until'|'case'|'select')
				__context_push $CONTEXT_BLOCK "$WORD"
				COMMAND="$WORD";;
			module)
				__context_push $CONTEXT_MODULE "$WORD";;
			"\n")
				if __context_is_root; then
					COMMAND=""
					NEW_LINE=1
				fi;;
			\#*)
				__context_push $CONTEXT_COMMENT "#"
				COMMAND="";;
			*)
				if [[ -z "$COMMAND" && "$WORD" != "\n" ]]; then
					COMMAND="$WORD"
				fi
				[ $CONTEXT -ne $CONTEXT_COMMENT ] && __lsf_parse_command $WORD;;
			esac;;
		$CONTEXT_COMMENT)
			if [ "$WORD" == "\n" ]; then
				__context_pop
			fi;;
		$CONTEXT_STRING)
			case "$WORD" in
			\'|\")
				[ "$CONTEXT_ID" == "$WORD" ] && __context_pop;;
			esac;;
		$CONTEXT_CONDITION)
			BLOCK_PARSE=0
			case "$WORD" in
				"[")
					CONTEXT_ID="[";;
				"]")
					[ "$CONTEXT_ID" != "[" ] && return 1
					__context_pop
					COMMAND="";;
				"("|"[[")
					REAL_WORD="[["; CONTEXT_ID="[[";;
				")"|"]]")
					[ "$CONTEXT_ID" != "[[" ] && return 1
					REAL_WORD="]]"
					__context_pop
					COMMAND="";;
				"((")
					CONTEXT_ID="((";;
				"))")
					[ "$CONTEXT_ID" != "((" ] && return 1
					__context_pop
					COMMAND="";;
				"{" )
					BLOCK_PARSE=1
					__context_pop
					COMMAND="";;
			esac;;
		esac
		
		if [ "$CONTEXT" == "$CONTEXT_BLOCK" -a $BLOCK_PARSE -eq 1 ]; then
			case "$WORD" in
			if|while|until|for)
				__context_push $CONTEXT_CONDITION "?";;
			'fi'|'done'|'esac'|\)\)|\)|'}')
				
				local sep="$WORD"
				
				if [ "$WORD" == "}" ]; then
					
					case "$CONTEXT_ID" in
					'if')
						sep="fi" ;;
					while|until|for|select)
						sep="done";;
					'case')
						sep="esac";;
					esac
				fi
				
				REAL_WORD="$sep"
				
				if [[ "$sep" != "esac" && "$PREV_WORD" != "" && 
				   "$PREV_WORD" != ";" && "$PREV_WORD" != "\n" ]]; then
					REAL_WORD="; $sep"
				fi
				
				__context_pop
				COMMAND="";;
			'{'|then|do|in)
				
				local sep="$WORD"
				
				if [ "$WORD" == "{" ]; then
					
					case "$CONTEXT_ID" in
					if)
						sep="then" ;;
					while|until|for|select)
						sep="do" ;;
					'case')
						sep="in";;
					esac
				fi
				
				REAL_WORD="$sep"
				
				if [[ "$sep" != "in" && "$PREV_WORD" != "" &&
				   "$PREV_WORD" != ";" && "$PREV_WORD" != "\n" ]]; then
					REAL_WORD="; $sep"
				fi
				
				[ "$WORD" == "in" -a "$CONTEXT_ID" == "select" ] ||
				__context_push $CONTEXT_COMMAND "block {}"
				COMMAND=""
				;;
			'$('|'$((')
				__context_push $CONTEXT_COMMAND "block ${WORD})"
				COMMAND=""
				;;
			')')
				__context_pop
				COMMAND=""
				;;
			"else"|"}else{")
				if [ "$PREV_WORD" == ";" -o "$PREV_WORD" == "\n" ]; then
					REAL_WORD="else";
				else
					REAL_WORD="; else";
				fi
				__context_push $CONTEXT_COMMAND "else"
				COMMAND=""
				;;
			elif|"}elif")
				if [ "$PREV_WORD" == ";" -o "$PREV_WORD" == "\n" ]; then
					REAL_WORD="elif";
				else
					REAL_WORD="; elif";
				fi
				__context_push $CONTEXT_CONDITION "<"
				COMMAND="";;
			"\n"|";") ;;
			esac
		fi
		
		if [ $CONTEXT -eq $CONTEXT_FUNCTION ]; then
			case "$WORD" in
			function)
				COMMAND="$WORD";;
			*\(\))
				local funcname="$WORD"
				
				if [ -n "$MODULE" ]; then
					funcname="$MODULE.$WORD"
					__module_add $MODULE $WORD
				fi
				
				CONTEXT_ID="$funcname"
				COMMAND="$funcname"
				__lsf_parse_command $funcname;;
			"{")
				__context_push $CONTEXT_BLOCK   "function block"
				__context_push $CONTEXT_COMMAND "function body {}"
				COMMAND="";;
			"}")
				__context_pop
				COMMAND="";;
			esac
		fi
		
		if [ $CONTEXT -eq $CONTEXT_MODULE ]; then
			case "$WORD" in
			module)
				REAL_WORD=""
				COMMAND="$WORD";;
			"{")
				REAL_WORD=""
				__context_push $CONTEXT_BLOCK "module block"
				__context_push $CONTEXT_COMMAND "module definition"
				COMMAND="";;
			"}")
				REAL_WORD=""
				__module_remove $MODULE
				MODULE=""
				
				__context_pop
				COMMAND="";;
			*)
				REAL_WORD=""
				[ -n "$MODULE" ] && return 1
				CONTEXT_ID="module $WORD"
				MODULE="$WORD"
				COMMAND="";;
			esac
		fi
		
		__lsf_update_run_line $WORD $REAL_WORD || return $?
		
		# debug
		__lsf_status
		
		# try execute command
		if __context_is_root  && 
		   [ $NEW_LINE -eq 1 -o -z "$WORK_LINE" ]
		then
			__debug "RUN LINE: $RUN_LINE"
			__lsf_execute "$RUN_LINE"
			exit_code=$?
			RUN_LINE=""
			COMMAND=""
		fi
		
		return $exit_code
	}
	
	__lsf_setup_line()
	{
	
		INPUT_LINE="$@"
		
		WORK_LINE="$(echo -e "$INPUT_LINE" | awk '{ printf "%s\\n", $0 }' )"
		
		LINE="$(echo -e "$INPUT_LINE" | sed -e "s/'/ ' /g" | awk '{ printf "%s \\n ", $0 }')"
		
		LINE="$(echo "$LINE" | awk '{
				gsub("\"", " \" ");
				gsub("`", " ` ")  ;
				gsub("<", " < ")  ;
				gsub(">", " > ")  ;
				gsub("[{]", " { ");
				gsub("[}]", " } ");
				gsub("[(]", " ( "  );
				gsub("[)]", " ) "  );
				gsub("[\\\\] *\"", "\\\"");
				gsub("[\\\\] *`", "\\`");
				gsub("[\\\\] *[{]", "\\{");
				gsub("[\\\\] *[}]", "\\}");
				gsub("[\\\\] *[(]", "\\(");
				gsub("[\\\\] *[)]", "\\)");
				gsub(" *[(] *[)]", "()");
				gsub("[(] *[(]","((");
				gsub("[)] *[)]","))");
				gsub(";"," ; ");
				gsub("; +;",";;");
				gsub("[}]( |\\\\n)*else( |\\\\n)*[{]","}else{");
				gsub("[}]( |\\\\n)*elif","}elif");
				gsub("[$] *[(]", " $(")
				gsub("[$] *[(] *[(]", " $((")
				print}')"
		
		# elimina spazi superflui
		LINE="$(echo $LINE)"
		
		#echo "INPUT='$INPUT_LINE'"
		#echo "L=$LINE"
		#echo "W=$WORK_LINE"
	}
	
	__lsf_parse_line()
	{
		local exit_code=1
		#debug
		__lsf_status
		
		local word=""
		for word in $LINE; do
			__lsf_parse_word $word
			exit_code=$?
			if [ $exit_code -eq 1 ]; then
				echo "LSF: errore di sintassi vicino il simbono non atteso '$WORD'"
				if [ $DEBUG -eq 1 ]; then
					__context_print_status
					[ $VERBOSE -eq 1 ] && __context_print_stack
				fi
				return 1
			elif [ $exit_code -ne 0 ]; then
				return $exit_code
			fi
		done
		
		if [[ $CONTEXT_SIZE == 0 && -z "$WORK_LINE" ]]; then
			return 0
		fi
		
		return 2 # incomplete code line
	}
	
	__lsf_parse()
	{
		[ $# -eq 0 ] && return
		
		__lsf_setup_line "$@"
		
		__lsf_parse_line "$RUN_LINE"
		
		return $?
	}
	
	
	local LSF_HISTORY=()
	local LSF_HISTORY_INDEX=0
	local LSF_HISTORY_CMD=""
	
	__lsf_history()
	{
		local i=0
		
		if [ $# -eq 0 ] || echo "$*" | grep -q -E -e "^#$"; then
			for ((i=0; i<$LSF_HISTORY_INDEX; i++)); do
				echo "$i ${LSF_HISTORY[$i]}"
			done
			return
		fi
		
		i="$*"
		
		(echo "$i" | grep -q -E -e "^\!$" || [ "$i" == "last" ]) && i=-1
		
		if echo "$i" | grep -q -E -e "^(-[1-9]|[0-9])[0-9]*$"; then
			
			if [ $i -lt 0 ]; then
				i=$(($LSF_HISTORY_INDEX + $i))
			fi
			
			if [ $i -ge 0 ]; then
				LSF_HISTORY_CMD="${LSF_HISTORY[$i]}"
				echo ${LSF_HISTORY_CMD}
			fi
		else
			case "$i" in
			clear|--) LSF_HISTORY=(); LSF_HISTORY_INDEX=0;;
			+*) LSF_HISTORY[$((LSF_HISTORY_INDEX++))]="$(echo ${i:1})";;
			*) 
				local cmd="echo $i | awk '{gsub(\"?\", \".*\"); print}'"
				local regex="^$(eval $cmd)$"
				
				for (( i=${LSF_HISTORY_INDEX} - 1; i>=0; i-- )); do
					if echo "${LSF_HISTORY[$i]}" | grep -E -e "$regex"; then
						LSF_HISTORY_CMD="${LSF_HISTORY[$i]}"
						
						return 0
					fi
				done
				
				echo "LSF: history error: regex '$regex' not found" > /dev/stderr
				return 1;;
			esac
		fi
		
		return 0
	}
	
	__lsf_shell()
	{
		local SPECIAL_CMD=1
		local exit_code=0
		
		while true; do
			local LSF_PROMPT="lsf > "
			local WORDS=""
			
			[ $CONTEXT_SIZE -ne 0 ] && LSF_PROMPT="> "
			
			read -a WORDS -p "$LSF_PROMPT"
			
			local line="${WORDS[@]}"
			
			
			if [ $CONTEXT_SIZE -eq 0 -a $exit_code -ne 2 ]; then
				case "${WORDS[0]}" in
					@q|@quit|exit)     [ -z "${WORDS[1]}" ] && break || continue;;
					@1|@on)            SPECIAL_CMD=1                  ; continue;;
					@0|@off)           SPECIAL_CMD=0                  ; continue;;
				esac
		
				if [ $SPECIAL_CMD -eq 1 ]; then
					case "${WORDS[0]}" in
					@w|@word)          echo "${WORD/"\n"} [$WORD]"    ; continue;;
					@c|@cmd)           echo -e "$CMD"                 ; continue;;
					@C|@cmd_name)      echo -e "$COMMAND"             ; continue;;
					@p|@prev_cmd)      echo -e "$PREV_CMD"            ; continue;;
					@l|@line)          echo    "$RUN_LINE"            ; continue;;
					@r|@reset_cmd)     RUN_LINE=""                    ; continue;;
					@e|@exec)    __lsf_execute "$RUN_LINE"            ; continue;;
					@s|@stack)   __context_print_stack                ; continue;;
					@m|@module)  __module_print                       ; continue;;
					@i|@indent_level)
						if echo "${WORDS[1]}" | grep -q -E -e "[0-9][1-9]*"; then
							CONTEXT_SIZE=${WORDS[1]}
						else
							echo $CONTEXT_SIZE
						fi
						continue;;
					@m|@mode)
						case "${WORDS[1]}" in
						verbose) VERBOSE=1;;
						quiet)   VERBOSE=0;;
						dummy)   DUMMY=1;;
						dump)    VERBOSE=1; DUMMY=1; CODE_PROMPT="";;
						normal)  VERBOSE=0; DUMMY=0; CODE_PROMPT="> ";;
						*)       echo "LSF: mode error: ${WORDS[1]} invalid" > /dev/stderr;;
						esac
						continue;;
					@h|@history)
						__lsf_history ${WORDS[1]};
						[ -z "$LSF_HISTORY_CMD" ] && continue
						line="$LSF_HISTORY_CMD"
						LSF_HISTORY_CMD="";;
					*)
						if [ "${WORDS[0]:0:1}" == "!" ]; then
							__lsf_history ${WORDS[0]:1}
							[ -z "$LSF_HISTORY_CMD" ] && continue
							line="$LSF_HISTORY_CMD"
							LSF_HISTORY_CMD=""
						fi;;
					esac
				fi
			fi
			
			__lsf_history +$line
			
			__lsf_parse "$line"
			
			exit_code=$?
		done
	}
	
	__lsf_script()
	{
		local i=0
		local lines=${#SCRIPT_LINE[@]}
		local line=""
		
		while [ $i -lt $lines ] ; do
			line="${SCRIPT_LINE[$i]:0:${#SCRIPT_LINE[$i]}-1}"
			
			__debug "$((i+1)): $line"
			
			__lsf_parse "$line"
			
			if [ $? -eq 1 ]; then
				echo "LSF Script: errore linea $((i+1)): $line"
				return 1
			fi
			let i++
		done	
	}
	
	__lsf_parser_exit()
	{
		local exit_code=$1
		
		unset __context_id
		unset __context_parent_type
		unset __context_previous_type
		unset __context_print_status
		unset __context_size
		unset __context_is_root
		unset __context_pop
		unset __context_print
		unset __context_push
		unset __context_type
		unset __context_parent_id
		unset __context_previous_id
		unset __context_print_stack
		unset __context_reset
		unset __context_type_string
		
		unset __module_add
		unset __module_find
		unset __module_find_fun
		unset __module_print
		unset __module_remove
		unset __module_reset
		
		unset __lsf_execute
		unset __lsf_parse_command
		unset __lsf_script
		unset __lsf_status
		unset __lsf_history
		unset __lsf_parse_line
		unset __lsf_setup_line
		unset __lsf_update_run_line
		unset __lsf_parse
		unset __lsf_parse_word
		unset __lsf_shell
		
		unset __lsf_parser_exit
		
		return $exit_code
	}
	
	# lsf parser main #####################################
	if [ -n "$SCRIPT_FILE" ]; then
		__lsf_script
	elif [ $SHELL -eq 1 ]; then
		__lsf_shell
	else
		__debug "INPUT LINE: $CMD"
		__lsf_parse "$CMD"
	fi
	
	local exit_code=$?
	
	if [ -n "$RUN_LINE" ]; then
		__debug "No parse: $RUN_LINE"
	fi
	
	#__lsf_parser_exit $exit_code
	########################################################
}

