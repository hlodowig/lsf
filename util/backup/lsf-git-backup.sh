#!/bin/bash

lsf_git_backup()
{
	__lsf_git_backup_usage()
	{
		local CMD="$1"
		
		[ "$0" != "bash" ] && CMD="$(basename $0)"
		
		(cat <<END
NAME
	${CMD} - Esegue il backup della directory git del framework LSF.
	
SYNOPSIS
	$CMD [OPTIONS] [<archive>]
	
DESCRIPTION
	Il comando $CMD esegue il backup della directory git del framework LSF.
	
	
OPTIONS
	-g, --git-dir
	    Il parametro è il path della directory git del framework LSF.
	
	-d, --dir
	    La directory dove verrà creato l'archivio.
	
	-v, --version
	    Inserisce la versione specificata per il framework LSF nel nome dell'archivio di backup.
	    Di default viene verificata automaticamente se LSF è caricato.
	
	-V, --no-version
	    Non inserisce la versione nel nome dell'archivio di backup.
	
	-D, --dummy
	    Non crea l'archivio.
	
	-q, --quiet
	    Disabilita la stampa di messaggi sullo standard out.
	
	-Q, --no-quiet
	    Abilita la stampa di messaggi sullo standard out.
	
	-h| --help
	    Stampa questo messaggio ed esce.
	
EXAMPLES
	> $CMD --version \$(lsf_version) --git-dir .git --dir \$HOME
	
END
		) | less
	}
	
	local ARGS=$(getopt -o hd:g:v:VqQD -l help,dir:,git-dir:,quiet,no-quiet,version:,no-version,dummy -- "$@")
	eval set -- $ARGS
	
	local LSF_TAR=""
	local LSF_VERSION=""
	local GIT_DIR=""
	local BAK_DIR=""
	local QUIET=0
	local DUMMY=0
	
	while true ; do
		case "$1" in
		-g|--git-dir)    GIT_DIR="$2"                    ; shift  2;;
		-d|--dir)        BAK_DIR="$2"                    ; shift  2;;
		-v|--version)    LSF_VERSION="$2"                ; shift  2;;
		-V|--no-version) LSF_VERSION=""                  ; shift   ;;
		-q|--quiet)      QUIET=1                         ; shift   ;;
		-Q|--no-quiet)   QUIET=0                         ; shift   ;;
		-D|--dummy)      DUMMY=1                         ; shift   ;;
		-h|--help)     __lsf_git_backup_usage $FUNCNAME  ; return 0;;
		--) shift;;
		*) break;;
		esac
	done
	
	if [ -z "$GIT_DIR" ]; then
		GIT_DIR=".git"
		[ -n "$LSF_HOME" ] && GIT_DIR="$LSF_HOME/$GIT_DIR"
	fi
	
	if [ ! -d "$GIT_DIR" ]; then
		[ $QUIET -eq 1 ] || echo "Error: directory '$GIT_DIR' non trovata!"
		
		return 1
	fi
	
	if [ ! -d "${BAK_DIR:-.}" ]; then
		[ $QUIET -eq 1 ] || echo "Error: directory '$BAK_DIR' per il backp non trovata!"
		
		return 1
	fi
	
	if [ -n "$1" ]; then
		LSF_TAR="$1"
	else
		LSF_TAR="lsf"
		
		if [ -n "$LSF_VERSION" ]; then
			LSF_TAR="${LSF_TAR}-${LSF_VERSION}"
		fi
		
		LSF_TAR="${LSF_TAR}.git.tar.gz"
	fi
	
	[ -n "$BAK_DIR" ] && LSF_TAR="$BAK_DIR/$LSF_TAR"
	
	[ $QUIET -eq 1 ] || echo -n "LSF GIT: Backup in corso..."
	[ $DUMMY -eq 1 ] || tar -czf "$LSF_TAR" -C $(dirname $GIT_DIR) $(basename $GIT_DIR) 2> /dev/null
	
	local exit_code=$?
	
	if [ $QUIET -eq 0 ]; then
		if [ $? -eq 0 ]; then 
			echo "done!"
			echo "Backup in $LSF_TAR"
		else
			echo "fail!"
		fi
	fi
	
	return $exit_code
}

lsf_git_backup $@

