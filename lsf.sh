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


# Estensione dei file di libreria
export LIB_EXT="lib"
# Lista dei file di libreria importati.
export LIB_FILE_LIST=${LIB_FILE_LIST:-""}




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
	  # This is a relative path
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
	
	[ -f "$1" ] || [ -d "$1" ] || return 2
	
	local lib=$(__lib_get_absolute_path "$1")
	local dirs=""
	for libdir in ${LIB_PATH//:/ }; do
		local dir=$(__lib_get_absolute_path $libdir)
		[ "$lib" == $dir ] && return 3
		dirs="$dirs|$dir"
	done
	
	echo $lib |
	awk -v S="^($dirs)/|(.$LIB_EXT|/)$" '{gsub(S,""); print}' |
	tr / :
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
	$CMD [OPTIONS] LIBRARY_NAME...
	
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
	
	local ARGS=$(getopt -o hqQf:d:p:P: -l help,quiet,no-quiet,file:,dir:,add-libpath:,libpath: -- "$@")
	
	eval set -- $ARGS
	
	local QUIET=0
	local exit_code=1
	local libpath="$LIB_PATH"
	
	while true ; do
		case "$1" in
		-q|--quiet)        QUIET=1                    ; shift  ;;
		-Q|--no-quiet)     QUIET=0                    ; shift  ;;
		-p|--add-libpath)  libpath="${2}:${LIB_PATH}" ; shift 2;;
		-P|--libpath)      libpath="$2"               ; shift 2;;
		-f|--file) 
			if [ -f "$2" ]; then
			 [ $QUIET -eq 1 ] || __lib_get_absolute_path "$2"
			 exit_code=0
			fi
			unset __lib_find_usage
			return $exit_code;;
		-d|--dir)
			if [ -d "$2" ]; then
			 [ $QUIET -eq 1 ] || __lib_get_absolute_path "$2"
			 exit_code=0
			fi
			unset __lib_find_usage
			return $exit_code;;
		-h|--help) __lib_find_usage $FUNCNAME; unset __lib_find_usage; return 0;;
		--) shift;;
		*) break;;
		esac
	done
	
	local LIB="${1//://}"
	local libdir=
	
	for libdir in ${libpath//:/ }; do
		
		if [ -d "${libdir}/$LIB" ]; then
			[ $QUIET -eq 1 ] || __lib_get_absolute_path ${libdir}/$LIB
			exit_code=0
			break
		elif [ -f "${libdir}/$LIB.$LIB_EXT" ]; then
			[ $QUIET -eq 1 ] || __lib_get_absolute_path ${libdir}/$LIB.$LIB_EXT
			exit_code=0
			break
		fi
		
	done
	
	unset __lib_find_usage; 
	
	return $exit_code
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
	
	local ARGS=$(getopt -o h,F:fd -l help,lib-function:,file,dir -- "$@")
	eval set -- $ARGS
	
	local FIND_OPT=""
	local LIB_FUN=""
	local exit_code=
	
	while true ; do
		case "$1" in
		-F|--lib-function) LIB_FUN="$2" ; shift 2;;
		-f|--file) FIND_OPT="$1"        ; shift  ;;
		-d|--dir)  FIND_OPT="$1"        ; shift  ;;
		-h|--help) return 0;;
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
	
	-a, --all
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

	local ARGS=$(getopt -o hfdircCuDqQlLRFap:P: -l help,file,dir,include,recursive,check,no-check,update,dummy,quiet,no-quiet,list,list-files,list-clear,force,all,libpath:,add-libpath: -- "$@")
	eval set -- $ARGS
	
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
	
	while true ; do
		
		case "$1" in
		-a|--all)        ALL=1                                        ; shift  ;;
		-f|--file)       FIND_OPT="$1"                                ; shift  ;;
		-d|--dir)        FIND_OPT="$1"                                ; shift  ;;
		-r|--recursive)  RECURSIVE=1;        OPTIONS="$OPTIONS $1"    ; shift  ;;
		-c|--check)      CHECK=1;            OPTIONS="$OPTIONS $1"    ; shift  ;;
		-C|--no-check)   CHECK=0;            OPTIONS="$OPTIONS $1"    ; shift  ;;
		-i|--include)    INCLUDE=1;          OPTIONS="$OPTIONS $1"    ; shift  ;;
		-q|--quiet)      QUIET=1             OPTIONS="$OPTIONS $1"    ; shift  ;;
		-Q|--no-quiet)   QUIET=0             OPTIONS="$OPTIONS $1"    ; shift  ;;
		-D|--dummy)      DUMMY=1;            OPTIONS="$OPTIONS $1"    ; shift  ;;
		-F|--force)      CHECK=0; INCLUDE=1; OPTIONS="$OPTIONS -C -i" ; shift  ;;
		-p|--add-libpath)  LIB_PATH_OPT="$1 $2"                       ; shift 2;;
		-P|--libpath)      LIB_PATH_OPT="$1 $2"                       ; shift 2;;
		-l|--list)       __lib_list_names      ; unset __lib_import_usage     ; return ;; 
		-L|--list-files) __lib_list_files      ; unset __lib_import_usage     ; return ;;
		-R|--list-clear) __lib_list_files_clear; unset __lib_import_usage     ; return ;;
		-h|--help)     __lib_import_usage $FUNCNAME; unset __lib_import_usage ; return ;; 
		-u|--update)     UPDATE=1                                     ; break  ;;
		--) shift;;
		-*) echo "Usa $FUNCNAME -h oppure $FUNCNAME --help per ulteriori informazioni";
		    return 1;;
		*) break;;
		esac
	done
	
	
	# lib_import --all invocation
	if [ $ALL -eq 1 ]; then
		
		unset __lib_import_usage
		
		for dir in ${LIB_PATH//:/ }
		do
			$FUNCNAME $OPTIONS $LIB_PATH_OPT --recursive --dir $dir
		done
		
		return 0
	fi
	
	# lib_import --update invocation
	if [ $UPDATE -eq 1 ]; then
		
		unset __lib_import_usage
		
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
	
	
	if [ -z "$LIB_FILE" ]; then
		[ $QUIET -eq 1 ] || lib_log "Library '$LIB' not found!"	
		return 1
	fi
	
	if [ $INCLUDE -eq 0 -a ! -x "$LIB_FILE" ]; then
		[ $QUIET -eq 1 ] || lib_log "Library '$LIB' disable!"
		return 2
	fi
	
	if [ -f "$LIB_FILE" ]; then
		
		if [ $CHECK -eq 0 ] || 
		   ! $(lib_is_loaded -f "$LIB_FILE") ||
		   [ $(stat -c %Y "$LIB_FILE") -gt $(__lib_list_files_get_mod_time "$LIB_FILE") ]; 
		then
			if [ $DUMMY -eq 0 ]; then
				source "$LIB_FILE"
			else
				echo "$LIB_FILE"
			fi
			
			[ $QUIET -eq 1 ] || lib_log "Import library module:\t $LIB"
			
			[ $DUMMY -eq 1 ] || __lib_list_files_add "$LIB_FILE"
		fi
		
		unset __lib_import_usage
		
		return $?
		
	elif [ -d "$LIB_FILE" ]; then
		
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
			fi
		fi
		
		unset __lib_import_usage
		
		return $?
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



################################################################################



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



### FIND SECTION ###############################################################

lib_def_find()
{
	local ARGS=$(getopt -o edfmnhvAFVqtT -l help,file,only-enabled,only-disable,filename,libname,verbose,only-alias,only-variables,only-functions,quiet,print-type,no-print-type -- "$@")
	eval set -- $ARGS
	
	local FIND_OPT=
	local ONLY_ENABLED=0
	local ONLY_DISABLED=0
	local NAME=1
	local VERBOSE=0
	local QUIET=0
	local PRINT_TYPE=2
	local _alias=1
	local _variables=1
	local _functions=1
	
	while true ; do
		case "$1" in
		-A|--only-alias)     _alias=1; _functions=0; _variables=0 ;shift ;;
		-F|--only-functions) _alias=0; _functions=1; _variables=0 ;shift ;;
		-V|--only-variables) _alias=0; _functions=0; _variables=1 ;shift ;;
		-f|--file)           FIND_OPT="$1"   ; shift ;;
		-n|--libname)        NAME=1          ; shift ;;
		-m|--filename)       NAME=0          ; shift ;;
		-e|--only-enabled)   ONLY_ENABLED=1  ; shift ;;
		-d|--only-disabled)  ONLY_DISABLED=1 ; shift ;;
		-q|--quiet)          QUIET=1         ; shift ;;
		-v|--verbose)        VERBOSE=1       ; shift ;;
		-t|--print-type)     PRINT_TYPE=1    ; shift ;;
		-T|--no-print-type)  PRINT_TYPE=0    ; shift ;;
		-h|--help) echo "$FUNCNAME <options> [-r|--recursive] <dir>"; return 0;;
		--) shift;;
		*) break;;
		esac
	done
	
	local DEF_NAME="$1"
	shift
	
	local found=0
	local exit_code=1
	local s=$(echo $_alias $_functions $_variables | awk '{print $1+$2+$3}')
		
	if [ $PRINT_TYPE -eq 2 -a $s -eq 3 ]; then
		PRINT_TYPE=1
	fi
	
	__find_def()
	{
		local opt="$1"
		local library="$2"
		
		if [ "$opt" = "-A" -a $_alias     -eq 1 ] || 
		   [ "$opt" = "-F" -a $_functions -eq 1 ] || 
		   [ "$opt" = "-V" -a $_variables -eq 1 ]
		then
			for def in $(lib_def_list $opt -f $library); do
				if [ "$DEF_NAME" == $def ]; then
					
					if [ $QUIET -eq 0 ]; then
						if [ $VERBOSE -eq 1 ]; then
							echo -n "La definizione "
							case "$opt" in
							-V) echo -n "della variabile ";;
							-A) echo -n "dell'alias ";;
							-F) echo -n "della funzione ";;
							esac
							echo "'$DEF_NAME' e' stata trovata nella libreria: "
						elif [ $PRINT_TYPE -eq 1 ]; then
							case "$opt" in
							-V) echo -n "[VAR] ";;
							-A) echo -n "[ALS] ";;
							-F) echo -n "[FUN] ";;
							esac
						fi
						
						if [ $NAME -eq 1 ]; then
							echo "$( lib_name "$library")"
						else
							echo "$library"
						fi
					fi
					
					return 0
				fi
			done
		fi
		
		return 1
	}

	local libs=
	
	if [ $# -eq 0 ]; then
		libs="$(lib_list --no-format-list --filename)"
	else
		local lib=
		
		for lib in $@; do
			libs="$libs $(lib_find $FIND_OPT $lib)"
		done
	fi
	
	[ -n "$libs" ] || return 1
	
	for library in $libs; do
	
		__find_def -V "$library"; exit_code=$?; [ $exit_code -eq 0 ] && break
		__find_def -A "$library"; exit_code=$?; [ $exit_code -eq 0 ] && break
		__find_def -F "$library"; exit_code=$?; [ $exit_code -eq 0 ] && break
	done
	
	unset __find_def

	return $exit_code
}


### DEFINITION SECTION #########################################################

lib_def_list()
{
	[ $# -eq 0 ] && return 1
	
	local ARGS=$(getopt -o f:AFV -l file:,only-alias,only-functions,only-variables -- "$@")
	eval set -- $ARGS
	
	local _alias=1
	local _variables=1
	local _functions=1
	
	local LIB_FILE=""
	local FIND_OPT=""
	
	while true ; do
		case "$1" in
		-f|--file)           FIND_OPT="$1"                        ;shift ;;
		-A|--only-alias)     _alias=1; _functions=0; _variables=0 ;shift ;;
		-F|--only-functions) _alias=0; _functions=1; _variables=0 ;shift ;;
		-V|--only-variables) _alias=0; _functions=0; _variables=1 ;shift ;;
		--) shift;;
		*) break;;
		esac
	done
	
	local library="$1"
	LIB_FILE=$(lib_find $FIND_OPT $library)
	
	if [ -f "$LIB_FILE" ]; then
		__get_list()
		{
			cat "$1" | 
			awk '! /^[[:blank:]]*\#/ {gsub("^[[:blank:]]*",""); print}' |
			awk '
				/^[[:blank:]]*[a-zA-Z0-9_]+=/ {gsub("[[:blank:]]*|=.*",""); print "[VAR]",$0}
				/^[[:blank:]]*(function)?[[:blank:]]*[a-zA-Z0-9|_]+\(\)/ { gsub("function|[[:blank:]]*|\\(\\).*$",""); print "[FUN]",$0}
				/(alias)[[:blank:]]*[a-zA-Z0-9_]+=/ {gsub("=[^;]*","\n");  gsub("[^\n]*alias", "[ALS]");print}' |
			sort | uniq
		}
		
		__get_var_list()
		{
			__get_list "$1" | awk '/^\[VAR\]/ {print $2}'
		}
		
		__get_fun_list()
		{
			__get_list "$1" | awk '/^\[FUN\]/ {print $2}'
		}
		
		__get_alias_list()
		{
			__get_list "$1" | awk '/^\[ALS\]/ {print $2}'
		}
		
		__is_local_var()
		{
			cat "$1" | grep -q -E -e "local *$2 *($|=)|unset *$2 *($|;)?"
		}
		
		__is_local_fun()
		{
			cat "$1" | grep -q -E -e "unset *$2 *($|;)?"
		}
		
		__is_local_alias()
		{
			cat "$1" | grep -q -E -e "unalias *$2 *($|;)?"
		}
		
		if [ $_variables -eq 1 ]; then
			for var in $(__get_var_list "$LIB_FILE"); do
				
				if ! __is_local_var $LIB_FILE $var; then
					if [ $_functions -eq 1 -a $_alias -eq 1 ]; then
						echo -n "[VAR] "
					fi
					echo "$var"
				fi
			done
		fi
		
		if [ $_functions -eq 1 ]; then
			for fun in $(__get_fun_list "$LIB_FILE"); do
				
				if ! __is_local_fun $LIB_FILE $fun; then
					if [ $_variables -eq 1 -a $_alias -eq 1 ]; then
						echo -n "[FUN] "
					fi
					echo "$fun"
				fi
			done
		fi
		
		if [ $_alias -eq 1 ]; then
			for alias in $(__get_alias_list "$LIB_FILE"); do
				
				if ! __is_local_alias $LIB_FILE $alias; then
					if [ $_variables -eq 1 -a $_functions -eq 1 ]; then
						echo -n "[ALS] "
					fi
					echo "$alias"
				fi
			done
		fi
		
		unset __get_list
		unset __get_var_list
		unset __get_fun_list
		unset __get_alias_list
		unset __is_local_var
		unset __is_local_fun
		unset __is_local_alias
	else
		lib_log "Library '$library' not found!"
		return 1
	fi
	
	return 0
}


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
		-l|--libname) 	LIB_FILE=$(lib_find        $2) ; shift 2;;
		-f|--libfile)   LIB_FILE=$(lib_find --file $2) ; shift 2;;
		-A|--alias-name)    TYPE="-A"                  ; shift ;;
		-F|--function-name) TYPE="-F"                  ; shift ;;
		-V|--variable-name) TYPE="-V"                  ; shift ;;
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

lib_unset()
{
	local ARGS=$(getopt -o f -l file -- "$@")
	
	eval set -- $ARGS
	
	local options=""
	local libs=""
		
	while true ; do
		case "$1" in
		-f|--file) options="$1"; shift;;
		--) shift;;
		*) break;;
		esac
	done
	
	__lib_unset()
	{		
		local VAR_AND_FUN=$(lib_def_list $options $1 | 
			awk '{gsub("\\[(VAR|FUN)\\]","unset"); gsub("\\[ALS\\]","unalias"); printf "%s:%s\n",$1,$2}')
	
		if [ -n "$VAR_AND_FUN" ]; then
			lib_log "Library '$lib': unset variables, functions and alias"
		
			for def in $VAR_AND_FUN; do
				local CMD=$(echo $def | tr : ' ')
				
				[ "$CMD" != "unset PATH" ] || continue 
				[ "$CMD" != "unset PS1"  ] || continue
				[ "$CMD" != "unset PS2"  ] || continue
				[ "$CMD" != "unset PS3"  ] || continue
				
				lib_log "Library '$1': $CMD"
				eval "$CMD 2> /dev/null"
			done
		fi
	
		local lib="$(lib_find $options "$1")"
	
		__lib_list_files_remove "$lib"
	}
	
	if [ $# -eq 0 ]; then
		options="--file"
		libs="$(__lib_list_files)"
	else
		libs="$@"
	fi

	for libfile in $libs; do
		__lib_unset $libfile
	done
	
	unset __lib_unset
	
	return 0
}


### MAIN SECTION ###############################################################

if [ "sh" != "$0" -a "bash" != "$0" ]; then 

	LIBSYS="lib"
	CMD=""
	
	while true; do
		case "$1" in
			-h|--help) echo "LibSys Help (not implementated)"; exit 0;;
			import*|include*|name|find|list*|enable|disable|unset|is_*|get_*|set_*) CMD=${LIBSYS}_$1; shift;;
			log*) CMD=${LIBSYS}_$1_$2; shift 2;;
			*) break
		esac
	done
	
	if [ -n "$CMD" ]; then
		$CMD $@
		exit $?
	fi
fi

