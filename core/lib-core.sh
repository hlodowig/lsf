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

# Lista dei moduli core.
LIB_MODULES=( path name archive find apply test enable disable import include
              update list_apply list depend check
              code/def_find code/def_get code/def_list code/unset )

# Lista dei file di libreria importati.
LIB_FILE_LIST="${LIB_FILE_LIST:-""}"

# Mappa che associa ad un archivio una directory temporanea
declare -gxA LIB_ARC_MAP


### LIB_LIST FILES SECTION #####################################################

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
	
	echo -e "$LIB_FILE_LIST" | grep -E -e "$lib" | awk '{gsub("/.*",""); print}'
}

for module in ${LIB_MODULES[@]}; do
	# module import
	lsf_log "LSF CORE: load module $module"
	source $(dirname $(readlink -f $BASH_SOURCE))/lib/$module.sh
done

