#!/bin/bash

lsf_install()
{
	local ROOT="$1"
	
	[ -z $ROOT ] && ROOT="$HOME/config/"
	mkdir -p ${ROOT}/{lsf,profile.d}
	
	cp -r ../../* ${ROOT}/lsf
	cp -r ../../examples/asus/asus-webcam.sh ${ROOT}/profile.d
	
	(cat << END
### Load Library System Framework ##############################################

source $LSF_HOME/lsf.sh

export LSF_HOME="$HOME/config/lsf"
export PATH="$LSF_HOME/bin:$PATH"

lib_path --set "$LSF_HOME/lib"

echo -n "LSF: Loading libraries... "
lib_import --all --fast
echo "complete!"

#lib_log --output "$LOG_DIR/libsys.log"
#lib_log --enable

#sleep 1
#clear


### Load profile scripts #######################################################

profile_setup()
{
	LOG_DIR="$HOME/log"
	
	if [ ! -e $LOG_DIR ]; then
		mkdir $LOG_DIR
	fi
	
	export PROFILE_DIR="$HOME/config/profile.d"
	export PROFILE_LOG="$LOG_DIR/profile.log"
	
	echo -e "Load profile in : $PROFILE_DIR\n`date`" > $PROFILE_LOG      
	
	if [ `ls -A1 "$PROFILE_DIR" | wc -l` -gt 0 ]; then
	  for profile in $PROFILE_DIR/*.sh; do
		if [ -x $profile ]; then
		  . $profile
		  echo -e "Find profile: $profile\t[LOADED]" >> $PROFILE_LOG      
		else 
		  echo -e "Find profile: $profile\t[NOT LOADED]" >> $PROFILE_LOG
		fi
	  done
	  unset profile
	fi
}

profile_setup

################################################################################

# Abilita il log per l'utente
lib_log  --output out
lib_log --enable

END
) #>> $HOME/.bashrc

}

lsf_install $@

