#!/bin/bash

# Copyright (C) 2010 - Luigi Capraro (luigi.capraro@gmail.com)
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

# Variabile d'ambiente contenente la lista delle directory contenenti librerie.
export LIB_PATH="${LIB_PATH:-"lib"}"

# Estensione dei file di libreria
export LIB_EXT="lsf"

# Estensione degli archivi di libreria
export ARC_EXT="lsa"

# Lista dei file di libreria importati.
export LIB_FILE_LIST="${LIB_FILE_LIST:-""}"

# Mappa che associa ad un archivio una directory temporanea
declare -gxA LIB_ARC_MAP


### UTILITY FUNCTIONS ##########################################################

# Restituisce il path assoluto.
__lib_get_absolute_path()
{
	local FILEPATH=$(
		if [ $# -eq 0 ]; then
			cat
		else
			echo "$1"
		fi | awk '{gsub("^ *| *$",""); print}'
	)
	
	echo "$STRING" | grep -E -q -e "$REGEXP" >/dev/null
	
	if ! echo "$FILEPATH" | grep -E -q -e "^/" >/dev/null; then
		
		FILEPATH="${PWD}/$FILEPATH"
	fi
	
	FILEPATH=$(echo "$FILEPATH" |
	awk '{
		 gsub("\\.(/|$)","#/");
		 gsub("/\\.#","/##");
		 gsub("/\\.$","/");
		 gsub("/#/","/");
		 while ($0~"//+|/#|/[^/]+/##") {
		     gsub("//+|/[^/]+/##(/|$)?","/");
		 }
		 gsub("/$","")
		 print
		}')
	if [ -z "$FILEPATH" ]; then
		FILEPATH="/"
	fi
	
	echo $FILEPATH
}




### PATH SECTION ###############################################################

# Restituisce il valore della variabile LIB_PATH, se non viene passato alcun
# parametro.
# Se come parametro viene passata una sequenza numerica separata da ':',vengono
# retituiti i path relativi alle posizioni.
#
# ES.
# > lib_path_get
#   .:lib:/home/user/lsf/lib
# > lib_path_get 2:3
#   lib:/home/user/lsf/lib
#
lib_path_get()
{
	if [ -z "$*" ]; then
		echo $LIB_PATH
	else
		local LP=""
		for path_num in $(echo $* | tr : ' '); do
			local LP=$LP:$(echo $LIB_PATH | 
			               awk -F: -v PN=$path_num '{print $PN}')
		done
		
		LP=${LP#:}
		
		echo ${LP%:}
	fi
}

# Stampa la lista dei path della variabile LIB_PATH, separati dal carattere di
# newline.
lib_path_list()
{
	echo -e ${LIB_PATH//:/\\n}
}

# Imposta la variabile LIB_PATH.
lib_path_set()
{
	LIB_PATH=""
	
	local lib=""
	
	for lib in $(echo $1 | tr : ' '); do
		if [ -n "$LIB_PATH" ]; then
			LIB_PATH="$LIB_PATH:${lib%\/}"
		else
			LIB_PATH="${lib%\/}"
		fi
	done
	
	export LIB_PATH
}

# Aggiunge un path alla lista contenuta nella variabile LIB_PATH.
lib_path_add()
{
	for lib in $*; do
		if [ -n "$LIB_PATH" ]; then
			LIB_PATH="${lib%\/}:$LIB_PATH"
		else
			LIB_PATH="${lib%\/}"
		fi
	done
	
	export LIB_PATH
}

# Rimuove un path dalla lista contenuta nella variabile LIB_PATH.
lib_path_remove()
{
	for lib in $*; do
		
		lib="${lib%\/}"
		
		LIB_PATH=$(echo $LIB_PATH |
				   awk -v LIB="$lib/?" '{gsub(LIB, ""); print}' |
				   awk '{gsub(":+",":"); print}' |
				   awk '{gsub("^:|:$",""); print}')
	done
	
	export LIB_PATH
}




### LIB_PATH SECTION ###########################################################

# Restituisce la lista dei file delle librerie importate nell'ambiente corrente.
__lib_list_files()
{
	[ -z "$LIB_FILE_LIST" ] && return
	
	local libfile=""
	
	for libfile in $LIB_FILE_LIST; do
		echo $libfile | awk '{gsub("^[0-9]+/","/"); print}'
	done
}

# Restituisce la lista dei nomi delle librerie importate nell'ambiente corrente.
__lib_list_names()
{
	[ -z "$LIB_FILE_LIST" ] && return
	
	local libfile=""
	
	for libfile in $LIB_FILE_LIST; do
		libfile=$(echo $libfile | awk '{gsub("^[0-9]+/","/"); print}')
		lib_name $libfile
	done
}

# Svuota la lista dei file delle librerie importate nell'ambiente corrente.
__lib_list_files_clear()
{
	LIB_FILE_LIST=""
}

# Rimuove il path di un file dalla lista dei file delle librerie importate
# nell'ambiente corrente.
__lib_list_files_remove()
{
	local lib=
	
	for lib in $@; do

		lib="$(__lib_get_absolute_path "$lib")"
	
		LIB_FILE_LIST=$( echo -e "$LIB_FILE_LIST" |
						 awk -vLIB="[0-9]+$lib" '{gsub(LIB,""); print}' |
						 grep -v -E -e '^$')
	done
	
}

# Aggiunge il path di un file alla lista dei file delle librerie importate
# nell'ambiente corrente.
__lib_list_files_add()
{	
	[ $# -eq 0 ] && return 1
	
	local lib=
	
	for lib in $@; do
		__lib_list_files_remove "$lib"

		lib="$(__lib_get_absolute_path "$lib")"
	
		LIB_FILE_LIST=$(echo -e "${LIB_FILE_LIST}\n$(stat -c %Y $lib)$lib" | 
			            grep -v -E -e '^$')
	done
}

# Restituisce la data di ultima modifica relativa al path della libreria 
# importata nell'ambiente corrente.
__lib_list_files_get_mod_time()
{
	local lib="$(__lib_get_absolute_path "$1")"
	
	echo -e "$LIB_FILE_LIST" | grep -E -e "$lib" | awk '{gsub("[^0-9]+",""); print}'
}





### LOG SECTION ################################################################

# Variabile booleana d'ambiente che indica se il log è attivo 
export LIB_LOG_ENABLE=${LIB_LOG_ENABLE:-0}
# Variabile d'ambiente contenente il path del dispositivo e file di output.
export LIB_LOG_OUT=${LIB_LOG_OUT:-"/dev/stderr"}

# Restituisce il device o il file di output del log.
lib_log_out_get()
{
	echo $LIB_LOG_OUT
}

# Imposta il device o il file di output del log.
lib_log_out_set()
{
	case $1 in
	1|out|stdout) LIB_LOG_OUT="/dev/stdout";;
	2|err|stderr) LIB_LOG_OUT="/dev/stderr";;
	*) LIB_LOG_OUT="$1";;
	esac
	
	if [ -w "$LIB_LOG_OUT" ]; then
		export LIB_LOG_OUT
		return 0
	fi
	
	return 1
}

# Stampa un messaggio di log.
lib_log()
{
	if [ -d "$LIB_LOG_OUT" ]; then
		local LIB_LOG_DIR=$(dirname "$LIB_LOG_OUT")
		
		! test -d "$LIB_LOG_DIR" && mkdir "$LIB_LOG_DIR" || return 1
		! test -e "$LIB_LOG_OUT" && touch "$LIB_LOG_OUT" || return 2
	fi
	
	if [ $LIB_LOG_ENABLE -eq 1 ]; then
		echo -e $(date +"%Y-%m-%d %H:%M:%S") $(id -nu) $* >> ${LIB_LOG_OUT}
	fi
}

# Resituisce exit code pari a 0 se il log è attivo, altrimenti 1.
lib_log_is_enabled()
{
	test $LIB_LOG_ENABLE -eq 1 && return 0
	
	return 1
}

# Abilita il log.
lib_log_enable()
{
	export LIB_LOG_ENABLE=1
}

# Disabilita il log.
lib_log_disable()
{
	export LIB_LOG_ENABLE=0
}

# Se l'output del log è un file, visualizza l'history del log.
lib_log_print()
{
	if [ -f "$LIB_LOG_OUT" ]; then
		less "$LIB_LOG_OUT"
	fi
}

# Se l'output del log è un file, cancella l'history del log.
lib_log_reset()
{
	if [ -f "$LIB_LOG_OUT" ]; then
		echo "" > "$LIB_LOG_OUT"
	fi
}






### LIBRARY SECTION ############################################################

# Restituisce il nome di una libreria o di un modulo a partire dal file o dalla
# cartella.
#
# Se l'argomento è nullo o il file o cartella non esiste
lib_name()
{
	[ $# -gt 0 ] || [ -e "$1" ] || return 1
	
	
	local lib="$1"
	local sublib=""
	
	if echo "$lib" | grep -q "\.$ARC_EXT"; then
		local regex="^.*.$ARC_EXT"
		lib="$(echo "$1" | grep -o -E -e "$regex")"
		sublib="$(echo "$1" | awk -v S="$regex" '{gsub(S,""); print}')"
	fi
	
	
	lib=$(__lib_get_absolute_path "$lib")
	local dirs=""
	for libdir in ${LIB_PATH//:/ }; do
		local dir=$(__lib_get_absolute_path $libdir)
		[ "$lib" == $dir ] && return 3
		dirs="$dirs|$dir"
	done
	
	echo ${lib}${sublib} | awk -v S=".$ARC_EXT" '{gsub(S,"@"); print}' |
	awk -v S="^($dirs)/|(.$LIB_EXT|/)$" '{gsub(S,""); print}' |
	tr / :
}


# Costruisce un archivio o ne visualizza il contenuto.
lib_archive()
{

	__lib_archive_usage()
	{
		local CMD="$1"
		
		cat << END
NAME
	$CMD - Crea e gestice gli archivi di libreria.

SYNOPSIS
	Create command:
		$CMD [OPTIONS] -c|--create|--build [-d|--dir DIR] ARCHIVE_FILE
		$CMD [OPTIONS] -c|--create|--build  -d|--dir DIR  [DIR.$ARC_EXT]
	
	Check command:
		$CMD [OPTIONS] -C|--check   ARCHIVE_FILE
		$CMD [OPTIONS] [NAMING_OPTIONS] -y|--verify  ARCHIVE_NAME@
	
	List command:
		$CMD [OPTIONS] -l|--list  ARCHIVE_FILE
		$CMD [OPTIONS] [NAMING_OPTIONS] -L|--ls    ARCHIVE_NAME@
	
	Search command:
		$CMD [OPTIONS] -s|--search LIB_FILE  ARCHIVE_FILE
		$CMD [OPTIONS] [NAMING_OPTIONS] -f|--find   ARCHIVE_NAME@LIB_NAME
	
	Extract command:
		$CMD [OPTIONS] [EXTRACT OPTIONS] [-d|--dir DIR] -x|--extract  ARCHIVE_FILE
		$CMD [OPTIONS] [EXTRACT OPTIONS] [NAMING_OPTIONS] [-d|--dir DIR] -u|--unpack   ARCHIVE_NAME@
	
	
DESCRIPTION
	Il comando $CMD crea e gestisce un archivio di libreria.
	
	
GENERIC OPTIONS
	-h, --help
		Stampa questa messaggio e esce.
	
	-q, --quiet
		Non stampa nulla sullo standard output.
	
	-Q, --no-quiet
		Stampa infomazioni essenziali.
	
	-v, --verbose
		Stampa informazioni dettagliate.
	
	-V, --no-verbose
		Non stampa informazioni dettagliate.
	
COMMAND OPTIONS
	-c, --create, --build
		Crea un nuovo archivio di libreria
	
	-C, --check
		Controlla se il file passato come parametro è un archivio di librerie
	
	-y, --verify
		Equivale a: --naming --check o in breve -nC
	
	-l, --list
		Stampa la lista dei file e delle directory contenute nell'archivio di librerie
	
	-L, --ls
		Equivale a: --naming --list  o in breve -nl
	
	-s, --search
		Verifica se il file o la directory specificata come parametro è contenuto
		all'interno dell'archivio di libreria.
	
	-f, --find
		Equivale a: --naming --search o in breve -ns
	
	-x, --extract
		Estrae il contenuto dell'archivio di librerie nella directory specificata.
	
	-u, --unpack
		Equivale a: --naming --extract o in brave -nx
	
CREATE OPTIONS
	-d, --dir

EXTRACT OPTIONS
	-d, --dir
	-t, --temp-dir
	--no-temp-dir
	-T, --track
	--no-track
	-r, --clean-dir
	-R, --no-clean-dir
	-F, --force
	    --no-force
	
NAMING OPTIONS
	-n, --naming
		
	
	-N, --no-naming
		
	
	-p, --add-libpath
		Aggiuge temporaneamente una nuova lista di path di libreria a quelli presenti
		nella variabile d'ambiente LIB_PATH.
	
	-P, --libpath
		Imposta temporaneamente una nuova lista di path di libreria, invece di quelli 
		presenti nella variabile d'ambiente LIB_PATH.
	

END
		return 0
	}
	
	local ARGS=$(getopt -o CyclLhs:fxud:nNvVqQrRtTFp:P: -l check,verify,create,build,list,ls,search:,find,extract,unpack,dir:,help,naming,no-naming,temp-dir,no-temp-dir,track,no-track,clean-dir,no-clean-dir,quiet,no-quiet,verbose,no-verbose,force,no-force,clean,clean-temp,clean-track,libpath:,add-libpath: -- "$@")
	eval set -- $ARGS
	
	
	local ARCHIVE_NAME=""
	local LIB=""
	local DIR=""
	local NAMING=0
	local TMP=0
	local TRACK=0
	local FORCE=0
	local QUIET=0
	local VERBOSE=0
	local CMD=""
	local SEARCH=0
	local CLEAN_DIR=0
	local CLEAN_TEMP=0
	local CLEAN_TRACK=0
	local LIB_PATH_OPT=
	local tar_verbose=
	local libpath=

	
	while true ; do
		case "$1" in
		-c|--create|--build) CMD="CREATE"                     ; shift  ;;
		-C|--check)          CMD="CHECK"                      ; shift  ;;
		-y|--verify)         CMD="CHECK"; NAMING=1            ; shift  ;;
		-l|--list)           CMD="LIST"                       ; shift  ;;
		-L|--ls)             CMD="LIST"; NAMING=1             ; shift  ;;
		-x|--extract)        CMD="EXTRACT"                    ; shift  ;;
		-u|--unpack)         CMD="EXTRACT"; NAMING=1          ; shift  ;;
		-s|--search)         CMD="SEARCH"; LIB="$2"           ; shift 2;;
		-f|--find)           CMD="SEARCH"; NAMING=1           ; shift  ;;
		-n|--naming)         NAMING=1                         ; shift  ;;
		-N|--no-naming)      NAMING=0                         ; shift  ;;
		-p|--add-libpath)    LIB_PATH_OPT="$1 $2"             ; shift 2;;
		-P|--libpath)        LIB_PATH_OPT="$1 $2"             ; shift 2;;
		--clean-temp)        CMD="CLEAN";
		                     CLEAN_TEMP=1                     ; shift  ;;
		--clean-track)       CMD="CLEAN";
		                     CLEAN_TRACK=1                    ; shift  ;;
		--clean)             CMD="CLEAN";
		                     CLEAN_TEMP=1;
		                     CLEAN_TRACK=1                    ; shift  ;;
		-d|--dir)            DIR="$2"                         ; shift 2;;
		-t|--temp-dir)       TMP=1                            ; shift  ;;
		--no-temp-dir)       TMP=0                            ; shift  ;;
		-T|--track)          TRACK=1                          ; shift  ;;
		--no-track)          TRACK=0                          ; shift  ;;
		-r|--clean-dir)      CLEAN_DIR=1                      ; shift  ;;
		-R|--no-clean-dir)   CLEAN_DIR=0                      ; shift  ;;
		-F|--force)          FORCE=1                          ; shift  ;;
		--no-force)          FORCE=0                          ; shift  ;;
		-q|--quiet)          QUIET=1                          ; shift  ;;
		-Q|--no-quiet)       QUIET=0                          ; shift  ;;
		-v|--verbose)        VERBOSE=1                        ; shift  ;;
		-V|--no-verbose)     VERBOSE=0                        ; shift  ;;
		-h|--help) __lib_archive_usage "$FUNCNAME"; return 0;;
		--) shift; break;;
		esac
	done
	
	if [ $QUIET -eq 0 -a $VERBOSE -eq 1 ]; then
		tar_verbose="-vv"
	elif [ $QUIET -eq 0 -o $VERBOSE -eq 1 ]; then
		tar_verbose="-v"
	fi
	
	if [ -z "$CMD" ]; then
		echo "$FUNCNAME: nessun comando specificato."
		echo
		echo "La lista dei comandi è la seguente:"
		echo "-c --create --build"
		echo "-C --check"
		echo "-y --verify"
		echo "-l --list"
		echo "-L --ls"
		echo "-s --search"
		echo "-f --find"
		echo "-x --extract"
		echo "-u --unpack"
		echo
		echo "Usa $FUNCNAME -h o $FUNCNAME --help per ulteriori informazioni."
		return 1
	fi
	
	
	__lib_archive_create()
	{
		[ $# -eq 0 ] && return 1
		
		local DIR="$1"
		local ARCHIVE_FILE="$2"
		
		if [ -z "$ARCHIVE_FILE" -a "$DIR" != "." ]; then
			ARCHIVE_FILE="$(basename "$DIR")"
		else
			ARCHIVE_FILE="lib"
		fi
		
		if ! echo $ARCHIVE_FILE | grep -q ".$ARC_EXT$"; then
			ARCHIVE_FILE="$ARCHIVE_FILE.$ARC_EXT"
		fi
		
		[ $VERBOSE -eq 1 ] && echo "Creazione archivio di librerie: $ARCHIVE_FILE"
		
		ARCHIVE_FILE="$(__lib_get_absolute_path "$ARCHIVE_FILE")"
		
		if [ ! -d "$DIR" ]; then
			if [ $VERBOSE -eq 1 ]; then
				echo "La directory '$DIR' non esiste."
				echo "Creazione archivio fallita!"
			fi
			return 2
		fi
		
		(cd "$DIR" && tar -czf "$ARCHIVE_FILE" *);
		
		local exit_code=$?
		
		if [ $VERBOSE -eq 1 ]; then
			if [ $exit_code -eq 0 ]; then
				echo "Creazione archivio completata con successo!"
			else
				echo "Creazione archivio fallita!"
			fi
		fi
		
		return $exit_code
	}
	
	__lib_is_archive()
	{
		[ $# -eq 0 ] && return 1
		
		local verbose=$VERBOSE
		
		if [ "$1" == "-q" ]; then
			verbose=0
			shift
		fi
		
		[ -f "$1" ] && file --mime-type "$1" | grep -q "gzip"
		
		local exit_code=$?
		
		if [ $verbose -eq 1 ]; then
			if [ $exit_code -eq 0 ]; then
				echo "Il file '$(basename "$1")' è un archivio di libreria"
			else
				echo "Il file '$(basename "$1")' non è un archivio di libreria"
			fi
		fi
		
		return $exit_code
	}
	
	__lib_archive_list()
	{
		[ $# -gt 0 ] && __lib_is_archive -q "$1"  || return 1 
		
		local ARCHIVE_NAME=$(__lib_get_absolute_path "$1")
		
		if [ $VERBOSE -eq 1 ]; then
			echo "Librerie dell'archivio '$(basename "$1")':"
		fi
		
		tar -tzf "$ARCHIVE_NAME" | awk '{gsub("^[.]?/?",""); print}'
	}
	
	__lib_archive_search()
	{
		[ $# -gt 0 ] && __lib_is_archive -q "$1"  || return 1 
		
		local ARCHIVE_NAME=$(__lib_get_absolute_path "$1")
		local LIB="$2"
		
		if [ -z "$LIB" ]; then
			
			[ $QUIET -eq 1 ] || echo "$ARCHIVE_NAME"
			return 0
		fi
		
		
		[ $VERBOSE -eq 1 ] &&
		echo -n "Ricerca della libreria '$LIB' nell'archivio '$(basename "$1")': "
		
		local libfile=""
		for libfile in $(__lib_archive_list "$ARCHIVE_NAME"); do
			if [ "$2" == "$libfile" ]; then
				[ $VERBOSE -eq 1 ] && echo "trovato!";
				[ $QUIET -eq 1 ] || echo "\n$ARCHIVE_NAME:$LIB";
				return 0
			elif [ "$2.$LIB_EXT" == "$libfile" ]; then
				[ $VERBOSE -eq 1 ] && echo "trovato!";
				[ $QUIET -eq 1 ] || echo "$ARCHIVE_NAME:$LIB.$LIB_EXT";
				return 0
			fi
		done
		
		[ $VERBOSE -eq 1 ] && echo "non trovato!"
		
		return 1
	}
	
	
	__lib_archive_extract()
	{
		[ $# -gt 1 ] && __lib_is_archive -q "$1"  || return 1
		
		local ARCHIVE_NAME=$(__lib_get_absolute_path "$1")
		local DIR="$2"
		
		local old_mod_time=0
		local new_mod_time=$(stat -c %Y $1)
		local exit_code=1
		
		if [ $TRACK -eq 1 -a -z "$DIR" ]; then
			
			[ $VERBOSE -eq 1 ] &&
			echo "Verifica se l'archivio '$(basename "$1")' è già stato estratto..."
			
			DIR="${LIB_ARC_MAP[$ARCHIVE_NAME]}"
			
			if [ -n "$DIR" ]; then 
				
				if [ ! -d "$DIR" ]; then
					
					[ $VERBOSE -eq 1 ] &&
					echo "La directory '$DIR' è stata rimossa."
					
					DIR=""
					
					unset LIB_ARC_MAP[$ARCHIVE_NAME]
				else
					[ $VERBOSE -eq 1 ] &&
					echo "Directory trovata: $DIR"
					
					old_mod_time=$(stat -c %Y "$DIR")
					
					if [ ${new_mod_time} -gt ${old_mod_time:=0} ]; then
						
						[ $VERBOSE -eq 1 ] &&
						echo "L'archivio è stato modificato, la directory non è valida!"
						
						#[ $? -eq 0 -a $VERBOSE -eq 1 ] &&
						#echo "Rimozione del contenuto della cartella associata all'archivio."
						#rm -r "$DIR/*"
					elif [ $FORCE -eq 0 ]; then
						
						[ $VERBOSE -eq 1 ] &&
						echo "Estrazione dell'archivio non necessaria."
						
						return 0
					fi
				fi
			else
				[ $VERBOSE -eq 1 ] &&
				echo "Directory non trovata"
			fi
		fi
		
		if [ $TMP -eq 1 ] && [ -z "$DIR" -o ! -d "$DIR" ]; then
			
			DIR=$(mktemp --tmpdir -d lsf-$$-XXXXXXXX)
			
			[ $VERBOSE -eq 1 ] &&
			echo "Creata nuova cartella temporanea per l'archivio': '$DIR'"
		fi
		
		if [ -z "$DIR" ]; then
			DIR=$(basename "$1" | awk -v S=".$ARC_EXT" '{gsub(S,""); print}')
		fi
		
		if [ ! -d "$DIR" ]; then
			
			[ $VERBOSE -eq 1 ] &&
			echo "La directory '$DIR' non esiste e verrà creata."
			
			mkdir -p "$DIR"
		elif [ $CLEAN_DIR -eq 1 ]; then
			
			[ $? -eq 0 -a $VERBOSE -eq 1 ] &&
			echo "Rimozione del contenuto della cartella associata all'archivio."
			
			rm -r $DIR/*
		fi
		
		[ $VERBOSE -eq 1 -o $QUIET -eq 0 ] &&
		echo -e "Estrazione dell'archivio '$(basename "$1")' nella directory: $DIR\n"
		
		# Estazione dell'archivio
		tar $tar_verbose -xzf "$ARCHIVE_NAME" -C $DIR
		
		local exit_code=$?
		
		if [ $VERBOSE -eq 1 ]; then
			if [ $exit_code -eq 0 ]; then
				echo -e "\nCompletata con successo!"
			else
				echo -e "\nEstrazione fallita!"
			fi
		fi
		
		if [ $TRACK -eq 1 ]; then
			LIB_ARC_MAP[$ARCHIVE_NAME]="$(__lib_get_absolute_path "$DIR")"
			if [ $VERBOSE -eq 1 ]; then
				echo "Salvataggio della directory corrente di estarzione nella mappa degli archivi."
				echo "LIB_ARC_MAP[$ARCHIVE_NAME]=${LIB_ARC_MAP[$ARCHIVE_NAME]}"
			fi
		fi
		
		return $exit_code
	}
	
	__lib_archive_clean()
	{
		if [ $CLEAN_TRACK -eq 1 ]; then
			
			[ $QUIET -eq 0 ] &&
			lib_log "Pulizia della mappa degli archivi."
			
			LIB_ARC_MAP=()
		fi
		
		if [ $CLEAN_TEMP -eq 1 ]; then
			
			[ $QUIET -eq 0 ] &&
			lib_log "Rimozione delle directory temporanee."
			
			local tmp_dir=
			
			for tmp_dir in $(ls /tmp/lsf-* 2> /dev/null); do
				[ $VERBOSE -eq 1 ] &&
				echo "Remove directory: $tmp_dir"
				rm -r $tmp_dir 2> /dev/null
			done
		fi
	}
	
	___exit()
	{
		unset __lib_is_archive
		unset __lib_archive_list
		unset __lib_archive_create
		unset __lib_archive_search
		unset __lib_archive_extract
		unset __lib_archive_clean
		unset ___exit
		
		return ${1:-0}
	}
	
	local ARCHIVE_FILE="$1"
	
	if [ $NAMING -eq 1 ]; then
		
		local arcname=$(lib_find $LIB_PATH_OPT "$1")
		LIB=$(echo $1 | awk '{gsub("^.*@:?",""); print}')
		
		[ $VERBOSE -eq 1 ] &&
		echo -n "Ricerca della libreria '$LIB' nell'archivio '$(basename "$1"| awk '{gsub("@.*$",""); print}').$ARC_EXT': "
		
		
		
		if [ "$CMD" == "SEARCH" ]; then
			if [ -z "$arcname" ]; then
				[ $VERBOSE -eq 1 ] && echo "non trovato!"
			else
				[ $VERBOSE -eq 1 ] && echo "trovato!"
				[ $QUIET -eq 0 ] && echo $arcname
				return 0
			fi
		fi
		
		[ -n "$arcname" ] || return 1
		
		LIB="$(echo "$arcname" | awk -F : '{ print $2 }')"
		ARCHIVE_FILE="$(echo "$arcname" | awk -F : '{ print $1 }')"
	fi
	
	case "$CMD" in
	"CHECK")   __lib_is_archive "$ARCHIVE_FILE";
	           ___exit $?; return $?;;
	"LIST")    __lib_archive_list    "$ARCHIVE_FILE";
	           ___exit $?; return $?;;
	"CREATE")  __lib_archive_create  "${DIR:=.}" "$ARCHIVE_FILE";
	           ___exit $?; return $?;;
	"SEARCH")  __lib_archive_search  "$ARCHIVE_FILE" "$LIB";
	           ___exit $?; return $?;;
	"EXTRACT") __lib_archive_extract "$ARCHIVE_FILE" "$DIR";
	           ___exit $?; return $?;;
	"CLEAN")   __lib_archive_clean;
	           ___exit $?; return $?;;
	esac
	
	return 1
}


# Trova il file associato ad una libreria o ad una cartella
# lib_find
lib_find()
{
	__lib_find_usage()
{
	local CMD="$1"

	(cat <<END
NAME
	$CMD - Restituisce il path della libreria passato come parametro.

SYNOPSIS
	$CMD [OPTIONS] [DIR:...][ARCHIVE@:][DIR:...]LIB_NAME
	
	$CMD [OPTIONS] -f|--file LIBRARY_FILE_PATH
	
	$CMD [OPTIONS] -d|--dir LIBRARY_DIR_PATH
	
DESCRIPTION
	Il comando $CMD trova il path associato ad una libreria, sia essa file o cartella.
	
	
OPTIONS
	
	-f, --file
		Verifica se il file di libreria esiste, senza eseguire operazioni di naming.
		Se il file non esiste, ritorna un exit code pari a 1, altrimenti ritorna 0
		e ne stampa il path sullo standard output (se l'optione quiet non è specificata).
	
	-d, --dir
		Verifica se la directory specificata dal path esiste, senza eseguire
		operazioni di naming.
		Se la directory non esiste, ritorna un exit code pari a 1, altrimenti ritorna 0
		e ne stampa il path sullo standard output (se l'optione quiet non è specificata).
	
	-a, --archive  ARCHIVE_PATH[:LIB_PATH]
		Verifica se l'archivio specificato, o il file contenuto in esso, esiste, senza eseguire
		operazioni di naming.
		Se l'archivio, o il file in esso specificato, non esiste, ritorna un exit code pari a 1, 
		altrimenti ritorna 0 e ne stampa il path sullo standard output 
		(se l'optione quiet non è specificata).
		
	-p, --add-libpath
		Aggiuge temporaneamente una nuova lista di path di libreria a quelli presenti
		nella variabile d'ambiente LIB_PATH.
	
	-P, --libpath
		Imposta temporaneamente una nuova lista di path di libreria, invece di quelli 
		presenti nella variabile d'ambiente LIB_PATH.
	
	-q, --quiet
		Non stampa il path sullo standard output.
	
	-Q, --no-quiet
		Se trova il file, lo stampa sullo standard output.
	
	
LIBRARY NAMING
	
	Il comando $CMD di default associa ad ogni file di libreria un nome.
	Una libreria potrebbe essere o un file o una cartella contenente altri file
	di libreria.
	
	Il nome di una libreria è così costruito:
	- se il file o la cartella di libreria ha una directory genitrice che si trova 
	  nella variabile LIB_PATH, questa è eliminata dal path.
	- se la libreria è un file l'estensione '.$LIB_EXT' viene omessa.
	- Optionalmente il carattere '/' può essere sostituito dal carattere ':'
	
	
EXAMPLES
	
	Se la libreria cercata è, ad esempio, 'math:sin', il comanando cerchera
	all'interno di ogni cartella della variabile LIB_PATH, o il file 'math/sin.$LIB_EXT'
	oppure la cartella math/sin.
	
	
	~ > LIB_PATH=$HOME/lib1:$HOME/lib2       oppure  
	~ > lib_path_set $HOME/lib1:$HOME/lib2   oppure
	~ > lib_path_add $HOME/lib1
	~ > lib_path_add $HOME/lib2
	
	~ > ls -R lib1
	    lib1/:
	    a.lib b.lib dir1
	    lib1/dir1:
	    c.lib dir2
	    lib1/dir1/dir2
	    d.lib f.lib 
	    ls -R lib2
	    lib2/:
	    g.lib
	
	~ > $CMD a
	    $HOME/lib1/a.lib (return 0)
	
	~ > $CMD b
	    $HOME/lib1/b.lib (return 0)
	
	~ > $CMD g
	    $HOME/lib2/g.lib (return 0)
	
	~ > $CMD dir1
	    $HOME/lib1/dir1 (return 0)
	
	~ > $CMD dir1:c          oppure     $CMD dir1/c
	    $HOME/lib1/dir1/c.lib (return 0)
	
	~ > $CMD dir1:dir2       oppure     $CMD dir1/dir2
	    $HOME/lib1/dir1/dir2 (return 0)
	
	~ > $CMD dir1:dir2:d     oppure     $CMD dir1/dir2/d
	    $HOME/lib1/dir1/dir2/d.lib (return 0)
	
	~ > $CMD dir1:dir2:f     oppure     $CMD dir1/dir2/f
	    $HOME/lib1/dir1/dir2/f.lib (return 0)
	
	~ > $CMD --file lib2/g.lib
	    $HOME/lib2/g.lib (return 0)
	
	~ > $CMD --file lib1/g.lib
	    (return 1)

	~ > $CMD --dir lib1/dir1
	    $HOME/lib1/dir1 (return 0)
	
	~ > $CMD --dir lib2/dir1
	    (return 1)
	
END
) | less
}

	[ $# -eq 0 -o -z "$*" ] && return 1
	
	local ARGS=$(getopt -o hqQf:d:a:p:P:vV -l help,quiet,no-quiet,file:,dir:,archive:,add-libpath:,libpath:,verbose,no-verbose -- "$@")
	
	eval set -- $ARGS
	
	local QUIET=0
	local libpath="$LIB_PATH"
	local ARCHIVE_MODE=0
	local VERBOSE=0
	local opts=
	
	while true ; do
		case "$1" in
		-q|--quiet)        QUIET=1                    ; shift  ;;
		-Q|--no-quiet)     QUIET=0                    ; shift  ;;
		-p|--add-libpath)  libpath="${2}:${LIB_PATH}" ; shift 2;;
		-P|--libpath)      libpath="$2"               ; shift 2;;
		-f|--file) 
			[ -f "$2" ] || return 1
			[ $QUIET -eq 1 ] || __lib_get_absolute_path "$2"
			return 0;;
		-d|--dir)
			[ -d "$2" ] || return 1
			[ $QUIET -eq 1 ] || __lib_get_absolute_path "$2"
			return 0;;
		-a|--archive) ARCHIVE_MODE=1                  ; shift  ;;
		-v|--verbose)        VERBOSE=1; opts="-v"     ; shift  ;;
		-V|--no-verbose)     VERBOSE=0                ; shift  ;;
		-h|--help) __lib_find_usage $FUNCNAME; return 0;;
		--) shift;;
		*) break;;
		esac
	done
	
	
	local LIB="${1//://}"
	local SUB_LIB=""
	
	if [ $ARCHIVE_MODE -eq 1 ]; then
		if echo "$LIB" | grep -q ".$ARC_EXT"; then
			local lib="$LIB"
			local regex="^.*.$ARC_EXT"
			
			LIB="$(echo "$lib" | grep -o -E -e "$regex")"
			SUB_LIB="$(echo "$lib" | awk -v S="$regex" '{gsub(S,""); print}')"
			SUB_LIB="${SUB_LIB#/}"
			
			lib_archive $opts --no-quiet --search "$SUB_LIB" $LIB
			
			return $?
			
		else # archivio con estensione errata
			return 1
		fi
	fi
	
	
	if echo "$LIB" | grep -q "@"; then
		local lib="$LIB"
		local regex="^.*@"
		
		LIB="$(echo "$lib" | grep -o -E -e "$regex" | awk '{gsub("@",""); print}').$ARC_EXT"
		SUB_LIB="$(echo "$lib" | awk -v S="$regex" '{gsub(S,""); print}')"
		SUB_LIB="${SUB_LIB#/}"
	fi
	
	local libdir=
	
	for libdir in ${libpath//:/ }; do
		
		if [ -d "${libdir}/$LIB" ]; then
			
			[ $QUIET -eq 1 ] || __lib_get_absolute_path ${libdir}/$LIB
			return 0
			
		elif [ -f "${libdir}/$LIB.$LIB_EXT" ]; then
			
			[ $QUIET -eq 1 ] || __lib_get_absolute_path ${libdir}/$LIB.$LIB_EXT
			return 0
		else
			lib_archive $opts --no-quiet --search "$SUB_LIB" "${libdir}/$LIB"
			
			return $?
		fi
	done
	
	return 1
}

# Restituisce un exit code pari a 0 se la libreria passata come parametro è
# presente nel path, altrimenti 1.
lib_is_installed()
{
	lib_find --quiet "$1"
}

# Restituisce un exit code pari a 0 se la libreria passata come parametro è
# stata importata, altrimenti 1.
lib_is_loaded()
{
	[ -n "$1" ] || return 1
	
	local lib=
	
	if [ "$1" == "-f" ]; then
		lib=$(lib_find -f $2)
	else
		lib=$(lib_find $1)
	fi
	
	[ -n "$lib" ] || return 1
	
	echo "$(__lib_list_files)" | grep -E -q -e "$lib" > /dev/null
	
	return $?
}

# Applica alla lista di librerie passate come parametri la funzione specificata,
# restituendo l'exit code relativo all'esecuzione di quest'ultima.
#
# library function definition:
#
# function_name() <lib_id> <lib_file> { ... }
#
# ES.
# > lib_set lib
#
# > function fun() { echo "$1 -> $2"; } # function definition
# >
# > lib_apply [-F|--lib-function] fun a mod mod:c
#   a -> lib/a.lib
#   mod -> lib/mod
#   mod:c -> lib/mod/c.lib
#
# > cd lib
# > lib_apply [-F|--lib-function] fun [-f|--file] a.lib mod/c.lib
#   a.lib -> lib/a.lib
#   mod/c.lib -> lib/mod/c.lib
#
# > cd lib
# > lib_apply [-F|--lib-function] fun [-d|--dir] mod
#   mod -> lib/mod
#
lib_apply()
{
	[ $# -eq 0 ] && return 1
	
	local ARGS=$(getopt -o h,F:fda -l help,lib-function:,file,dir,archive -- "$@")
	eval set -- $ARGS
	
	local FIND_OPT=""
	local LIB_FUN=""
	local exit_code=
	
	while true ; do
		case "$1" in
		-F|--lib-function) LIB_FUN="$2"   ; shift 2;;
		-f|--file)         FIND_OPT="$1"  ; shift  ;;
		-d|--dir)          FIND_OPT="$1"  ; shift  ;;
		-a|--archive)      FIND_OPT="$1"  ; shift  ;;
		-h|--help)         return 0;;
		--) shift;;
		*) break;;
		esac
	done
	
	for library in "$@"; do
		LIB_FILE=$(lib_find $FIND_OPT $library)
		
		$LIB_FUN "$library" "$LIB_FILE" 
		
		exit_code=$?
	done
	
	return $exit_code
}

lib_is_enabled()
{
	__lib_is_enabled()
	{
		local library="$1"
		local libfile="$2"
		
		if [ -n "$libfile" ]; then
			test -x "$libfile" && return 0
			return 1
		fi
		
		return 2
	}
	
	lib_apply --lib-function __lib_is_enabled $@
	
	local exit_code=$?
	
	unset __lib_is_enabled
	
	return $exit_code
}

# Abilita una libreria per l'import.
lib_enable()
{
	__lib_enable()
	{
		local library="$1"
		local libfile="$2"
		
		if [ -n "$libfile" ]; then
			lib_log "Enable library: $library"
			chmod a+x $libfile
		else
			lib_log "Library '$library' not found!"
		fi
	}
	
	lib_apply --lib-function __lib_enable $@
	
	local exit_code=$?
	
	unset __lib_enable
	
	return $exit_code
}

# Disabilita una libreria per l'import.
lib_disable()
{
	__lib_disable()
	{
		local library="$1"
		local libfile="$2"
		
		if [ -n "$libfile" ]; then
			lib_log "Disable library: $library"
			chmod a-x $libfile
		else
			lib_log "Library '$library' not found!"
		fi
	}
	
	lib_apply --lib-function __lib_disable $@
	
	local exit_code=$?
	
	unset __lib_disable
	
	return $exit_code
}



# Importa una libreria nell'ambiente corrente.
#
# lib_import [--file|-f] dir/library.lib
#
# lib_import [--include|-i] [--file|-f] dir/library.lib
#
# lib_import [--dir|-d] dir
#
# lib_import [--recursive|-r] [--dir|-d] dir
#
# lib_import [--include|-i] [--recursive|-r] [--dir|-d] dir
#
lib_import()
{
	__lib_import_usage()
	{
		local CMD=$1
		(cat << END
NAME
	$CMD - Importa librerie nell'ambiente corrente.

SYNOPSIS
	$CMD
	
	$CMD [OPTIONS] LIBRARY_NAME...
	
	$CMD [OPTIONS] -f|--file LIBRARY_FILE
	
	$CMD [OPTIONS] [-r|--recursive] -d|--dir LIBRARY_DIR
	
	
	$CMD -i|--include    ( alias lib_include )
	
	$CMD -u|--update     ( alias lib_update  )
	
	$CMD -l|--list
	$CMD -L|--list-files
	$CMD -R|--list-clear
	
DESCRIPTION
	Il comando $CMD... 
		
OPTIONS
	
	-f, --file
		Importa il file di libreria, specificandone il path, senza eseguire operazioni di naming.
		Se il file non esiste, ritorna un codice di errore.
	
	-d, --dir
		Importa gli script contenuti nella cartella specificata dal path,
		senza eseguire operazioni di naming.
		Se l'optione 'include' non è specificata, importa solo gli script abilitati,
		altrimenti importa tutti gli script con estensione '.$LIB_EXT'.
		(see: LIBRARY NAMING section of lib_find)
	
	-a, --archive
		Importa gli script contenuti nella cartella specificata dal path,
		senza eseguire operazioni di naming.
		Se l'optione 'include' non è specificata, importa solo gli script abilitati,
		altrimenti importa tutti gli script con estensione '.$LIB_EXT'.
		(see: LIBRARY NAMING section of lib_find)
	
	-r, --recursive
		Se la libreria è una cartella, importa ricorsivamente gli script nella cartella
		e nelle sue sottocartelle.
	
	-i, --include
		Importa una libreria senza controllare se è abilitata o meno.
		(see: LIBRARY ACTIVATION section)
	
	-c, --check
		Evita di importare la libreria se questa è gia stata precedentemente importata
		nell'ambiente corrente. Qualora il sorgente della libreria è stato modificato
		dopo l'import, questa viene importata nuovamente sovrascrivento la precedente
		definizione.
	
	-C, --no-check
		Importa la libreria anche se questa è già stata importata precedentemente.
	
	-F, --force
		Forza l'import della libreria, non effettuando alcun controllo.
		Equivale a: --include --no-check
	
	-q, --quiet
		Disabilita la stampa dei messaggi nel log. (see: lib_log funtions)
	
	-Q, --no-quiet
		Abilita la stampa dei messaggi nel log. (see: lib_log funtions)
	
	-D, --dummy
		Esegue tutte le operazioni di checking, ma non importa la libreria.
	
	-p, --add-libpath
		Aggiuge temporaneamente una nuova lista di path di libreria a quelli presenti
		nella variabile d'ambiente LIB_PATH.
	
	-P, --libpath
		Imposta temporaneamente una nuova lista di path di libreria, invece di quelli 
		presenti nella variabile d'ambiente LIB_PATH.
	
	-h, --help
		Stampa questo messaggio ed esce.
	
	
	Command list:
	
	-A, --all
		Importa tutte le librerie abilitate presenti nei path della variabile
		d'ambiente LIB_PATH.
	
	-u, --update
		Se necessario, ricarica tutte le librerie importate se sono stati modificati
		i sorgenti.
	
	-l, --list
		Stampa l'elenco dei nomi di libreria importati nell'ambiente corrente.
	
	-L, --list-files
		Stampa l'elenco dei nomi dei file di libreria importati nell'ambiente corrente.
	
	-R, --list-clear
		Svuota la lista delle librerie attuamelmente importate.
	
	
LIBRARY ACTIVATION

	see: lib_enable, lib_disable, lib_is_enabled
	

EXAMPLES
	
	~ > LIB_PATH=$HOME/lib1:$HOME/lib2       oppure  
	~ > lib_path_set $HOME/lib1:$HOME/lib2   oppure
	~ > lib_path_add $HOME/lib1
	~ > lib_path_add $HOME/lib2
	
	~ > ls -R lib1
		lib1/:
		a.lib b.lib dir1
		lib1/dir1:
		c.lib dir2
		lib1/dir1/dir2
		d.lib f.lib 
		ls -R lib2
		lib2/:
		g.lib
		
	~ > $CMD a
	    importa il file: lib1/a.lib
	
	~ > $CMD b
	    importa il file: lib1/b.lib
	
	~ > $CMD g
	    importa il file: lib2/g.lib
	
	~ > $CMD dir1
	    importa il file: lib1/dir1/c.lib
	
	~ > $CMD -r dir1
	    importa i files: lib1/dir1/c.lib, lib1/dir1/dir2/d.lib, lib1/dir1/dir2/f.lib
	
	~ > $CMD dir1:c          oppure     $CMD dir1/c
	    importa il file: lib1/dir1/c.lib
	
	~ > $CMD dir1:dir2       oppure     $CMD dir1/dir2
	    importa i files: lib1/dir1/dir2/d.lib, lib1/dir1/dir2/f.lib
	
	~ > $CMD dir1:dir2:d     oppure     $CMD dir1/dir2/d
	    importa il file: lib1/dir1/dir2/d.lib
	
	~ > $CMD dir1:dir2:f     oppure     $CMD dir1/dir2/f
	    importa il file: lib1/dir1/dir2/f.lib
	
	
END
) | less
	}
	
	local ARGS=$(getopt -o hfdircCuDqQlLRFaAp:P:vV -l help,file,dir,archive,include,recursive,check,no-check,update,dummy,quiet,no-quiet,list,list-files,list-clear,force,all,libpath:,add-libpath:,verbose,no-verbose -- "$@")
	eval set -- $ARGS
	
	#echo "___________________________________________________"
	#echo $ARGS
	
	local ALL=0
	local LIB=""
	local LIB_FILE=""
	local LIB_PATH_OPT=""
	local FIND_OPT=""
	local OPTIONS=""
	local INCLUDE=0
	local RECURSIVE=0
	local CHECK=1
	local UPDATE=0
	local DUMMY=0
	local QUIET=0
	local VERBOSE=0
	
	while true ; do
		
		case "$1" in
		-A|--all)        ALL=1                                        ; shift  ;;
		-f|--file)       FIND_OPT="$1"                                ; shift  ;;
		-d|--dir)        FIND_OPT="$1"                                ; shift  ;;
		-a|--archive)    FIND_OPT="$1"                                ; shift  ;;
		-r|--recursive)  RECURSIVE=1;        OPTIONS="$OPTIONS $1"    ; shift  ;;
		-c|--check)      CHECK=1;            OPTIONS="$OPTIONS $1"    ; shift  ;;
		-C|--no-check)   CHECK=0;            OPTIONS="$OPTIONS $1"    ; shift  ;;
		-i|--include)    INCLUDE=1;          OPTIONS="$OPTIONS $1"    ; shift  ;;
		-q|--quiet)      QUIET=1             OPTIONS="$OPTIONS $1"    ; shift  ;;
		-Q|--no-quiet)   QUIET=0             OPTIONS="$OPTIONS $1"    ; shift  ;;
		-v|--verbose)    VERBOSE=1           OPTIONS="$OPTIONS $1"    ; shift  ;;
		-V|--no-verbose) VERBOSE=0           OPTIONS="$OPTIONS $1"    ; shift  ;;
		-D|--dummy)      DUMMY=1;            OPTIONS="$OPTIONS $1"    ; shift  ;;
		-F|--force)      CHECK=0; INCLUDE=1; OPTIONS="$OPTIONS -C -i" ; shift  ;;
		-p|--add-libpath)  LIB_PATH_OPT="$1 $2"                       ; shift 2;;
		-P|--libpath)      LIB_PATH_OPT="$1 $2"                       ; shift 2;;
		-l|--list)       __lib_list_names      ; return ;; 
		-L|--list-files) __lib_list_files      ; return ;;
		-R|--list-clear)
			lib_archive --clean
			__lib_list_files_clear;
			return 0;;
		-h|--help)     __lib_import_usage $FUNCNAME;  return 0;; 
		-u|--update)     UPDATE=1                                     ; break  ;;
		--) shift;;
		-*) echo "Usa $FUNCNAME -h oppure $FUNCNAME --help per ulteriori informazioni";
		    return 1;;
		*) break;;
		esac
	done
	
	
	# lib_import --all invocation
	if [ $ALL -eq 1 ]; then
		
		for dir in ${LIB_PATH//:/ }
		do
			$FUNCNAME $OPTIONS $LIB_PATH_OPT --recursive --dir $dir
		done
		
		return 0
	fi
	
	# lib_import --update invocation
	if [ $UPDATE -eq 1 ]; then
		
		for lib_loaded in $(__lib_list_files); do
			$FUNCNAME $LIB_PATH_OPT --include --check --file "$lib_loaded"
		done
		
		return 0
	fi
	
	if [ $# -eq 0 ]; then
		FIND_OPT="--dir"
		LIB="."
	else
		LIB="$1"
	fi
	
	
	LIB_FILE=$(lib_find $LIB_PATH_OPT $FIND_OPT $LIB)
	
	#echo "___________________________________________________"
	#echo "FIND LIB_FILE=$LIB_FILE"
	
	SUB_LIB="$(echo "$LIB_FILE" | awk -F : '{ print $2 }')"
	LIB_FILE="$(echo "$LIB_FILE" | awk -F : '{ print $1 }')"
	
	#echo "LIB_FILE=$LIB_FILE, SUB_LIB=$SUB_LIB"
	
	
	if [ -z "$LIB_FILE" ]; then
		[ $QUIET -eq 1 ] || lib_log "Library '$LIB' not found!"	
		return 1
	fi
	
	if [ $INCLUDE -eq 0 -a ! -x "$LIB_FILE" ]; then
		[ $QUIET -eq 1 ] || lib_log "Library '$LIB' disable!"
		return 2
	fi
	
	
	if [ -f "$LIB_FILE" ]; then  # se la libreria è un file o un'archivio
		
		if [ $CHECK -eq 0 ] ||
		   ! $(lib_is_loaded -f "$LIB_FILE") ||
		   [ $(stat -c %Y "$LIB_FILE") -gt $(__lib_list_files_get_mod_time "$LIB_FILE") ]; 
		then
			if [ $DUMMY -eq 1 ]; then
				# Stampa semplicemente il path della libreria.
				echo "$LIB_FILE"
				
			else # importa un file
			
				if ! file --mime-type "$LIB_FILE" | grep -q "gzip"; then
					
					source "$LIB_FILE"
					
					__lib_list_files_add "$LIB_FILE"
					
					[ $QUIET -eq 1 ] || lib_log "Import library module:\t $LIB"
				
				else # importa un'archivio
					
					# Scompatta l'archivio in una directory temporanea, se non 
					# già stata associata all'archivio ne crea una nuova e ne 
					# tiene traccia.
					
					local opts=""
					
					[ $QUIET   -eq 1 ] && opts="--quiet"
					[ $VERBOSE -eq 1 ] && opts="$opts --verbose"
					
					lib_archive $opts --clean-dir --track --temp-dir --extract "$LIB_FILE"
					
					local tmp_dir="${LIB_ARC_MAP[$LIB_FILE]}"
					
					lib_path_add "$tmp_dir"
					
					if [ -n "$SUB_LIB" ]; then
						
						# importa un file dell'archivio
						$FUNCNAME $LIB_PATH_OPT $OPTIONS --file  "${tmp_dir}/${SUB_LIB}"
					else
						# importa tutto l'archivio
						$FUNCNAME --recursive $LIB_PATH_OPT $OPTIONS --dir  "$tmp_dir"
					fi
					
					lib_path_remove "$tmp_dir"
				fi
			fi
		fi
		
		return 0
		
	elif [ -d "$LIB_FILE" ]; then # importa una directory
		
		local DIR="$LIB_FILE"
		
		[ $QUIET -eq 1 ] || lib_log "Import library directory:\t $LIB_FILE"
		
		if [ $(ls -A1 "$DIR" | wc -l) -gt 0 ]; then
			
			for library in $DIR/*.$LIB_EXT; do
				if [ $INCLUDE -eq 1 -o -x $library ]; then
					$FUNCNAME $LIB_PATH_OPT $OPTIONS --file $library
				fi
			done
			
			if [ $RECURSIVE -eq 1 ]; then
				for libdir in $DIR/*; do
					
					test -d $libdir || continue
					
					if [ $INCLUDE -eq 1 -o  -x "$libdir" ]; then
						$FUNCNAME $LIB_PATH_OPT $OPTIONS --dir $libdir
					else
						[ $QUIET -eq 1 ] || lib_log "Library directory '$libdir' disable!"
					fi
				done
				
				for library in $DIR/*.$ARC_EXT; do
					if [ $INCLUDE -eq 1 -o -x $library ]; then
						$FUNCNAME $LIB_PATH_OPT $OPTIONS --archive $library
					fi
				done
			fi
		fi
		
		return 0
	fi
}


alias lib_include="lib_import -i"

alias lib_update="lib_import -u"


### List functions #############################################################

lib_list_apply()
{
	local ARGS=$(getopt -o rhd:l: -l recursive,help,dir-function:,lib-function: -- "$@")
	eval set -- $ARGS
	
	local DIR_FUN=""
	local LIB_FUN=""
	local RECURSIVE=0
	local libset=""
	
	while true ; do
		case "$1" in
		-d|--dir-function)  DIR_FUN="$2"; shift 2;;
		-l|--lib-function)  LIB_FUN="$2"; shift 2;;
		-r|--recursive)     RECURSIVE=1 ; shift  ;;
		-h|--help)
			echo "$FUNCNAME [-r|--recursive] [-d|--dir-function] <dir_fun> [-l|--lib-function] <lib_fun> [DIR ...]";
			 return 0;;
		--) shift;;
		*) break;;
		esac
	done
	
	__find()
	{
		[ -n "$libset" ] || return 2
		
		for lib in ${libset//;/ }; do
			if [ "$1" = "$lib" ]; then
				return 0
			fi
		done
		
		return 1
	}
	__list_lib()
	{
		local DIR="$(__lib_get_absolute_path "$1")"
		local libdir=""
		local libname=""
		
		[ -z "$DIR" ] || __find "$DIR" && return 1
		
		[ -z "$DIR_FUN" ] || $DIR_FUN "$DIR"
		libset="$libset;$DIR"		
		
		if [ `ls -A1 "$DIR" | wc -l` -gt 0 ]; then
			for library in $DIR/*.$LIB_EXT; do
				__find $library && continue
				
				[ -z "$LIB_FUN" ] || $LIB_FUN "$library"
				libset="$libset;$library"
			done
			
			if [ $RECURSIVE -eq 1 ]; then
				for libdir in $DIR/*; do
					test -d $libdir || continue
					
					if [ -x "$libdir" ]; then
						$FUNCNAME "$libdir"
					fi
				done
			fi
		
		fi
	}
	
	if [ $# -eq 0 ]; then
		local OPTIONS=""
		[ -z "$DIR_FUN" ] || OPTIONS="-d $DIR_FUN"
		[ -z "$LIB_FUN" ] || OPTIONS="$OPTIONS -l $LIB_FUN "
		
		$FUNCNAME $OPTIONS -r ${LIB_PATH//:/ }
	else
		for DIR in $*; do
		
			test -d "$DIR" || continue
	
			__list_lib $DIR	
		done
	fi
	
	unset __list_lib
}



# Mostra la lista delle librerie
#
# @see lib_name
# @see lib_list_apply
lib_list()
{
	local ARGS=$(getopt -o rednfhlLmM -l recursive,help,only-enabled,only-disable,filename,libname,format-list,no-format-list,list-dir,no-list-dir -- "$@")
	eval set -- $ARGS
	
	local OPTIONS=""
	local ONLY_ENABLED=0
	local ONLY_DISABLED=0
	local NAME=1
	local FORMAT=1
	local LIST_DIR=""
	local libset=""
	
	while true ; do
		case "$1" in
		-n|--libname)        NAME=1                              ; shift ;;
		-f|--filename)       NAME=0                              ; shift ;;
		-l|--format-list)    FORMAT=1                            ; shift ;;
		-L|--no-format-list) FORMAT=0                            ; shift ;;
		-r|--recursive)      OPTIONS="--recursive"               ; shift ;;
		-m|--list-dir)       LIST_DIR="--dir-function __lib_fun" ; shift ;;
		-M|--no-list-dir)    LIST_DIR=""                         ; shift ;;
		-e|--only-enabled)   ONLY_ENABLED=1                      ; shift ;;
		-d|--only-disabled)  ONLY_DISABLED=1                     ; shift ;;
		-h|--help) echo "$FUNCNAME <options> [-r|--recursive] <dir>"; return 0;;
		--) shift;;
		*) break;;
		esac
	done
	
	__lib_fun()
	{
		local library="$1"
		
		if [ $NAME -eq 1 ]; then
			libname=$(lib_name $library)
		else
			libname=$library
		fi
		
		[ -n "$libname" ] || return
		
		if [ -x $library ]; then
			if [ $ONLY_ENABLED -eq 1 -o $FORMAT -eq 0 ]; then
				echo "$libname"
			elif [ $ONLY_DISABLED -eq 0 ]; then
				echo "+$libname"
			fi
		else
			if [ $ONLY_DISABLED -eq 1 -o $FORMAT -eq 0  ]; then
				echo "$libname"
			elif [ $ONLY_ENABLED -eq 0 ]; then
				echo "-$libname"
			fi
		fi
	}
	
	lib_list_apply $OPTIONS $LIST_DIR --lib-function __lib_fun $*
	
	unset __lib_fun
}


# Restituisce le dipendenze di una libreria
lib_depend()
{
	local ARGS=$(getopt -o hiIfmnhrRvV -l help,inverse,reverse,no-inverse,no-reverse,file,filename,libname,verbose,recursive,no-recursive,verbose,no-verbose -- "$@")
	eval set -- $ARGS
	
	local FIND_OPT=
	local NAME=1
	local RECURSIVE=1
	local REVERSE=0
	local VERBOSE=0
	
	while true ; do
		case "$1" in
		-f|--file)                    FIND_OPT="$1"   ; shift ;;
		-n|--libname)                 NAME=1          ; shift ;;
		-m|--filename)                NAME=0          ; shift ;;
		-r|--recursive)               RECURSIVE=1     ; shift ;;
		-R|--no-recursive)            RECURSIVE=0     ; shift ;;
		-i|--inverse|--reverse)       REVERSE=1       ; shift ;;
		-I|--no-inverse|--no-reverse) REVERSE=0       ; shift ;;
		-v|--verbose)                 VERBOSE=1       ; shift ;;
		-V|--no-verbose)              VERBOSE=0       ; shift ;;
		-h|--help) 
			echo "$FUNCNAME [-nmvV] [-r|--recursive] LIB_NAME"; 
			echo "$FUNCNAME [-nmvV] [-r|--recursive] -f|--file LIB_FILE"; 
			echo "$FUNCNAME [-nmvV] -R|--no-recursive LIB_NAME"; 
			echo "$FUNCNAME [-nmvV] -R|--no-recursive -f|--file LIB_FILE"; 
			echo "$FUNCNAME [-nmvV] -i|--reverse|--inverse LIB_NAME"; 
			echo "$FUNCNAME [-nmvV] -i|--reverse|--inverse -f|--file LIB_FILE"; 
			echo "$FUNCNAME [-nmvV] [-I|--no-reverse|--no-inverse] LIB_NAME"; 
			echo "$FUNCNAME [-nmvV] [-I|--no-reverse|--no-inverse] -f|--file LIB_FILE"; 
			return 0;;
		--) shift;;
		*) break;;
		esac
	done

	[ $# -eq 0 ] && return 1
	
	local LIB_FILE="$(lib_find $FIND_OPT "$1")"
	
	[ -n "$LIB_FILE" ] || return 2
	
	local DEPEND=
	
	__add_dependence()
	{
		[ $# -eq 0 ] && return 1
		
		DEPEND=$( echo -e "$DEPEND\n$1" |
			      grep -v -E -e '^$')
	}
	
	if [ $REVERSE -eq 0 ]; then
		
		__find_dependence()
		{
			[ $# -eq 0 ] && return 1
			
			echo "$DEPEND" | grep -E -q -e "$1"
		}
		
		__get_dependences()
		{
			[ -n "$1" -a -f "$1" ] || return 1
			
			local LIB_DEP=
			
			eval "LIB_DEP=($(cat "$1" | grep -E -e "lib_(import|include)" | 
			awk '{gsub("include","import -i"); print}' | tr ';' '\n' | 
			awk '{gsub(" *lib_import *",""); printf "\"%s\"\n", $0}' | tr \" \'))"
			
			local dep=
			local dep2=
			
			for dep in "${LIB_DEP[@]}"; do
				for dep2 in $(lib_import --quiet --force --dummy $dep); do
					if ! __find_dependence $dep2; then
						
						__add_dependence $dep2
						
						if [ $RECURSIVE -eq 1 ]; then
							$FUNCNAME $dep2
						fi
					fi
				done
			done
		}
		
		__get_dependences "$LIB_FILE"
		
		unset __find_dependence
		unset __get_dependences
		
		if [ $VERBOSE -eq 1 ]; then
			echo "Dipendenze trovate per la libreria '$1':"
		fi
		
	else
		__find_lib()
		{
			[ -n "$1" -a -f "$1" ] || return 1
			
			if cat "$1" | grep -E -e "lib_(import|include)" | grep -qo "$LIB_FILE"; then
				return 0
			fi
			
			local LIB_NAME="$(lib_name $LIB_FILE)"
			
			if cat "$1" | grep -E -e "lib_(import|include)" | grep -qo "$LIB_NAME"; then
				return 0
			fi
			
			return 1
		}
		
		
		for lib in $(lib_list --filename --no-format-list); do
			if __find_lib $lib; then
				__add_dependence $lib
			fi
		done
		
		unset __find_lib
		
		if [ $VERBOSE -eq 1 ]; then
			echo "Dipendenze inverse trovate per la libreria '$1':"
		fi
	fi
	
	if [ $NAME -eq 0 ]; then
		echo "$DEPEND" | grep -v -E -e '^$'
	else
		local dep=
		
		for dep in $DEPEND; do
			lib_name $dep
		done
	fi
	
	unset __add_dependences
	
}


# Esce dall'ambiente corrente rimuovendo tutte le definizioni del framework
lib_exit()
{
	local VERBOSE=0
	
	if [ "$1" = "-v" -o "$1" = "--verbose" ]; then
		VERBOSE=1
	fi
	
	for al in $(alias | grep -E "lib_.*" | 
		awk '/^[[:blank:]]*(alias)[[:blank:]]*[a-zA-Z0-9_]+=/ {gsub("[[:blank:]]*|alias|=.*",""); print}'); do
		
		unalias $al
		[ $VERBOSE -eq 1 ] && echo "unalias $al"
	done
	
	for fun in $(set | grep -E "lib_.* \(\)" | awk '{gsub(" \\(\\)",""); print}'); do
		
		unset $fun
		[ $VERBOSE -eq 1 ] && echo "unset $fun"
	done
	
	for var in $(set | grep -E "^LIB_*" | awk '{gsub("=.*",""); print}'); do
		
		unset $var
		[ $VERBOSE -eq 1 ] && echo "unset $var"
	done
}


### MAIN SECTION ###############################################################

if [ "sh" != "$0" -a "bash" != "$0" ]; then 

	LIBSYS="lib"
	CMD=""
	
	while true; do
		case "$1" in
			-h|--help) echo "LibSys Help (not implementated)"; exit 0;;
			import*|include*|name|find|list*|enable|disable|unset|is_*|get_*|set_*)
				CMD=${LIBSYS}_$1; shift;;
			log*) CMD=${LIBSYS}_$1_$2; shift 2;;
			*) break
		esac
	done
	
	if [ -n "$CMD" ]; then
		$CMD $@
		exit $?
	fi
fi

################################################################################
