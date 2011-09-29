### LIBRARY NAMING SECTION #####################################################

# Restituisce il nome di una libreria o di un modulo a partire dal file o dalla
# cartella.
#
# Se l'argomento è nullo o il file o cartella non esiste

__lib_name_usage()
{
	local CMD="$1"

		(cat <<END
NAME
	${CMD:=lib_name} - Restituisce il nome della libreria.

SYNOPSIS
	$CMD  <lib_path>|<dir_path|<archive_path>
	
	
DESCRIPTION
	Il comando $CMD converte il path delle libreria (file, directory, archivio),
	nel nome associato secondo le regole di naming. 
	
	
OPTIONS
	-p, --add-libpath
	    Aggiuge temporaneamente una nuova lista di path di libreria a quelli presenti
	    nella variabile d'ambiente LIB_PATH.
	
	-P, --libpath
	    Imposta temporaneamente una nuova lista di path di libreria, invece di quelli 
	    presenti nella variabile d'ambiente LIB_PATH.
	
	-h| --help
	    Stampa questo messaggio ed esce.
	
NAMING
	_____________________________________________________
	
	Conversion Sintax:
	
	- Library File:
	    <lib_file_name>.$LIB_EXT  ==>  <lib_file_name>
	    
	- Library Directory:
	    <lib_dir_name>  ==>  <lib_dir_name>[:|/]
	
	- Library Archive:
	    <lib_arc_name>.$ARC_EXT  ==>  <lib_arc_name>@
	_____________________________________________________
	
	EXAMPLE:
	
	> LIB_PATH=lib
	
	> ls lib
	  core/ 
	  core.lsa 
	  core.lsf
	> lib_name lib/core.lsf
	  core
	> lib_name lib/core.lsa
	  core@
	> lib_name lib/core
	  core:
	  
	  # Per riferirsi al contenuto di un archivio
	> lib_name lib/core/archive.lsa:/cui/term.lsf
	  core:archive@:cui:term
	  
END
	
	) | less
	
	return 0
}


lib_name()
{
	[ $# -eq 0 -o -z "$*" ] && return 1
	
	local ARGS=$(getopt -o hp:P:vV -l help,add-libpath:,libpath:,verbose,no-verbose -- "$@")
	eval set -- $ARGS
	
	#echo "NAME ARGS=$ARGS" > /dev/stderr
	
	local libpath=""
	local add_libpath=1
	local VERBOSE=0
	
	while true ; do
		case "$1" in
		-p|--add-libpath)  libpath="${2} ${libpath}"  ; shift  2;;
		-P|--libpath)      libpath="$2"; add_libpath=0; shift  2;;
		-v|--verbose)      VERBOSE=1                  ; shift   ;;
		-V|--no-verbose)   VERBOSE=0                  ; shift   ;;
		-h|--help)         __lib_name_usage $FUNCNAME ; return 0;;
		--) shift;;
		*) break;;
		esac
	done
	
	local LIB_NAME=""
	local lib="$1"
	local sublib=""
	
	if [ $add_libpath -eq 1 ]; then
		libpath="${libpath} $(lib_path --list --absolute-path --real-path)"
	fi
	
	if echo "$lib" | grep -q -E -e"[.]$ARC_EXT"; then
		
		local regex="^.*.$ARC_EXT"
		
		sublib="$(echo "$lib" | awk -v S="$regex" '{gsub(S,""); print}')"
		lib="$(echo "$lib" | grep -o -E -e "$regex")"
	fi
	
	
	lib=$(__lib_get_absolute_path "$lib")
	
	local dirs=""
	
	for libdir in ${libpath}; do
		
		[ "$lib" == $libdir ] && return 3
		
		dirs="$dirs|$libdir"
	done
	
	dirs=${dirs#|}
	
	CMD="echo \"${lib}${sublib}\" |
	       awk '{ gsub(\"^($dirs)/\",\"\");    print }' | 
	       awk '{ gsub(\"(:|/)+\",\"/\");      print }' | 
	       awk '{ gsub(\"[.]$ARC_EXT\",\"@\"); print }' |
	       awk '! /[.]$LIB_EXT\$/ { printf \"%s/\n\", \$0 }
	              /[.]$LIB_EXT\$/ { gsub(\"[.]$LIB_EXT\$\",\"\"); print}' |
	       tr / :"
	
	LIB_NAME=$(eval "$CMD")
	
	if [ $VERBOSE -eq 1 ]; then
		echo "Il nome associato al file di libreria '$1' è il seguente:"
	fi
	
	echo $LIB_NAME
}

