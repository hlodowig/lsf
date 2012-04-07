# LSF VERSION


# LSF Version info #############################################################
LSF_VERSINFO=([0]="0" [1]="9" [2]="4" [3]="3" [4]="shell" [5]="stable")
################################################################################

# Restituisce la versione corrente di LSF.
lsf_version()
{
	[ -z "$LSF_VERSINFO" ] && return 1
	
	local VERBOSE=0
	
	[ "$1" == "-v" -o "$1" == "--verbose" ] && VERBOSE=1
	
	[ $VERBOSE -eq 1 ] && echo -n "LSF "
	
	local i=0
	
	for (( i=0; i<4; i++ )); do
		[ $i -gt 0 ] && echo -n "."
		[ -n "${LSF_VERSINFO[$i]}" ] && echo -n "${LSF_VERSINFO[$i]}"
	done | awk '{gsub("([.]0)+$",""); printf "%s", $0}'
	
	if [ $VERBOSE -eq 1 ]; then
		[ -n "${LSF_VERSINFO[4]}" ] && echo -n " ${LSF_VERSINFO[4]}"
		[ -n "${LSF_VERSINFO[5]}" ] && echo -n " ${LSF_VERSINFO[5]}"
	fi
	
	echo
}

################################################################################

