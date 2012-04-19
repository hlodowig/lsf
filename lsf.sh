#!/bin/bash

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

# LSF HOME #####################################################################
export LSF_HOME="${LSF_HOME:-$(dirname $(readlink -f $BASH_SOURCE))}"
################################################################################


### LSF INIT SECTION ###########################################################


lsf_load_module()
{
	local module="$*"
	local modfile="$LSF_HOME/core/$module.sh"
	
	if [ -f $modfile ]; then
		#echo "LSF INIT: Load module '$module [$modfile]"
		source $modfile
	else
		#echo "LSF ERROR: Module '$module [$modfile] not found!" > /dev/stderr
		return 1
	fi
}

LSF_MODULES=( common log version lib-core keywords export exit help shell main )

lsf_init()
{
	
	local module=""
	local modfile=""
	
	echo -e "Loading module... "
	for module in ${LSF_MODULES[@]}; do
		echo " - $module"
		lsf_load_module "$module"
	done
	echo -e "done.\n"
}

################################################################################


### LSF MAIN SECTION ###########################################################

#debug
#echo "lsf execute by $0"

# Attiva l'espansione degli alias
shopt -s expand_aliases

if echo "$0" | grep -q -E -e "^(/bin/)?(ba)?sh$"; then
	
	lsf_init || return 1
else
	if echo $0 | grep -q -E -e "lsf-shell$"    ; then
		lsf_load_module "version" &&
		lsf_load_module "shell"   &&
		lsf_shell "$@"
	else
		lsf_init > /dev/null &&
		lsf_main "$@"
	fi
fi

################################################################################

