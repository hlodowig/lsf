### LIBRARY ARCHIVE SECTION ####################################################

# Costruisce un archivio o ne visualizza il contenuto.

__lib_archive_usage()
{
	local CMD="$1"
	
	(cat << END
NAME
	${CMD:=lib_archive} - Crea e gestice gli archivi di libreria.

SYNOPSIS
	Create command:
	    $CMD [OPTIONS] -c|--create|--build [-d|--dir .]             [lib.$LSF_ARC_EXT]
	    $CMD [OPTIONS] -c|--create|--build [-d|--dir .]              <archive_name>.$LSF_ARC_EXT
	    $CMD [OPTIONS] -c|--create|--build [-d|--dir <archive_name>] <archive_name>
	    $CMD [OPTIONS] -c|--create|--build  -d|--dir <dir>           <archive_name>[.$LSF_ARC_EXT]
	    $CMD [OPTIONS] -c|--create|--build  -d|--dir <dir>          [<dir>.$LSF_ARC_EXT]
	    
	    $CMD [OPTIONS] -c|--create|--build <archive_name>[.$LSF_ARC_EXT]:<dir>
	    $CMD [OPTIONS] -c|--create|--build <archive_name>.$LSF_ARC_EXT(:|/):<dir>
	
	
	Check command:
	    $CMD [OPTIONS] [NAMING_OPTIONS] -C|--check   <archive_file>[.$LSF_ARC_EXT]
	    
	    $CMD [OPTIONS] [NAMING_OPTIONS] -y|--verify  <archive_name>@
	
	
	List command:
	    $CMD [OPTIONS] [NAMING_OPTIONS] -l|--list  <archive_file>[.$LSF_ARC_EXT]
	    $CMD [OPTIONS] [NAMING_OPTIONS] -L|--ls    <archive_name>@
	
	
	Search command:
	    $CMD [OPTIONS] [NAMING_OPTIONS] -s|--search -m|--library <lib_file>  <archive_file>
	    $CMD [OPTIONS] [NAMING_OPTIONS] -s|--search  <archive_file>[:|/]<lib_file>
	    
	    $CMD [OPTIONS] [NAMING_OPTIONS] -f|--find    <archive_name>@[:]<lib_name>
	
	Extract command:
	    $CMD [OPTIONS] [NAMING_OPTIONS] [EXTRACT OPTIONS] [-d|--dir <dir>] -x|--extract [-m|--library <lib_file>]  <archive_file>
	    $CMD [OPTIONS] [NAMING_OPTIONS] [EXTRACT OPTIONS] [-d|--dir <dir>] -x|--extract  <archive_file>[[:|/]<lib_file>]
	    
	    $CMD [OPTIONS] [NAMING_OPTIONS] [EXTRACT OPTIONS] [-d|--dir DIR] -u|--unpack  <archive_name>@
	
	Clear command:
	    $CMD [OPTIONS] [NAMING_OPTIONS] --clean       [<archive_file>]
	    $CMD [OPTIONS] [NAMING_OPTIONS] --clean-temp  [<archive_file>]
	    $CMD [OPTIONS] [NAMING_OPTIONS] --clean-track [<archive_file>]
	
	    $CMD [OPTIONS] [NAMING_OPTIONS] --clean       [<archive_name>@]
	    $CMD [OPTIONS] [NAMING_OPTIONS] --clean-temp  [<archive_name>@]
	    $CMD [OPTIONS] [NAMING_OPTIONS] --clean-track [<archive_name>@]


DESCRIPTION
	Il comando $CMD crea e gestisce un archivio di libreria.


GENERIC OPTIONS
	-h, --help
	    Stampa questa messaggio e esce.
	
	-p, --add-libpath
	    Aggiuge temporaneamente una nuova lista di path di libreria a quelli presenti
	    nella variabile d'ambiente LIB_PATH.
	
	-P, --libpath
	    Imposta temporaneamente una nuova lista di path di libreria, invece di quelli 
	    presenti nella variabile d'ambiente LIB_PATH.
	
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
	
	--clear-temp
	    Senza parametri, cancella tutte le cartelle temporanee in /tmp/lst-*
	    Se viene passato l'indentificativo di un archivio, cancella solamente
	    la cartella temporanea associata a quest'ultimo, se esiste.
	
	--clear-track
	    Senza parametri, svuota la mappa per il tracking degli archivi estratti.
	    Se viene passato l'indentificativo di un archivio, cancella solamente
	    l'entri della mappa associata a quest'ultimo, se esiste.
	
	--clear
	    Equivale a: --clear-temp --clear-track

CREATE OPTIONS
	-d, --dir DIR
	    Imposta la directory ch

SEARCH OPTIONS
	-m, --library LIB_PATH
	    Imposta la libreria da ricercare all'interno dell'archivio.

EXTRACT OPTIONS
	-d, --dir DIR
	    Imposta la directory di estrazione per l'archivio.
	
	-m, --library LIB_PATH
	    Imposta la libreria da estrarre dall'archivio.
	
	-t, --temp-dir
	    Abilita la creazione automatica di una directory temporanea di estrazione.
	    Le directory temporanee seguono il seguente pattern: /tmp/lsf-[PID]-XXXXXXXX.
	
	--no-temp-dir (default)
	    Disabilita la creazione automatica di una directory temporanea di estrazione.
	
	-T, --track
	    Abilita la modalità di tracciamento.
	    Il comando salva nella variabile d'ambieante LIB_ARC_MAP la coppia 
	    archivio e directory di estrazione, considerando i path assoluti.
	
	--no-track  (default)
	    Disabilità la modalità di tracciamento.
	
	-r, --clean-dir
	    Rimuove il contenuto della cartella, prima di effettuare l'estrazione.
	
	-R, --no-clean-dir (default)
	    Non rimuove il contenuto della cartella, prima di effettuare l'estrazione.
	
	-F, --force
	    Anche se la modalità di tracking è attiva, forza l'estrazione dell'archivio.
	
	--no-force (default)
	    Non forza l'estrazione quando l'archivio è già stato tracciato come estratto.

NAMING OPTIONS
	-n, --naming
	    Abilita la modalità di naming.
	    Converte il nome di una libreria nei corrispondente path.
	    @see lib_name --help: NAMING SECTION
	
	-N, --no-naming   (default)
	    Disabilita la modalità di naming.
	
	-a, --auto-naming (default)
	    Abilita automaticamente la modalità naming se nel parametro di input compare '@'.
	
	-A, --no-auto-naming
	    Disabilita la modalità automatica di naming.

END
	) | less
	return 0
}

lib_archive()
{
	local ARGS=$(getopt -o CyclLhsfxud:nNvVqQrRtTFp:P:m:aAD -l check,verify,create,build,list,ls,search,find,extract,unpack,dir:,help,naming,no-naming,temp-dir,no-temp-dir,track,no-track,clean-dir,no-clean-dir,quiet,no-quiet,verbose,no-verbose,force,no-force,clean,clean-temp,clean-track,libpath:,add-libpath:,library:,auto-naming,no-auto-naming,diff -- "$@")
	eval set -- $ARGS
	
	#echo "ARCHIVE ARGS=$ARGS" > /dev/stderr
	
	local LIB_FILE=""
	local DIR=""
	local TMP=0
	local TRACK=0
	local REALPATH=0
	local FORCE=0
	local QUIET=0
	local VERBOSE=0
	local CMD=""
	local SEARCH=0
	local CLEAN_DIR=0
	local CLEAN_TEMP=0
	local CLEAN_TRACK=0
	local libpath=
	local tar_verbose=
	local libpath=
	local FIND_OPTS=
	local NAMING=0
	local AUTO_NAMING=1
	
	while true ; do
		case "$1" in
		-c|--create|--build) CMD="CREATE"                          ; shift    ;;
		-C|--check)          CMD="CHECK"                           ; shift    ;;
		-y|--verify)         CMD="CHECK"; NAMING=1                 ; shift    ;;
		-l|--list)           CMD="LIST"                            ; shift    ;;
		-L|--ls)             CMD="LIST"; NAMING=1                  ; shift    ;;
		-x|--extract)        CMD="EXTRACT"                         ; shift    ;;
		-u|--unpack)         CMD="EXTRACT"; NAMING=1               ; shift    ;;
		-s|--search)         CMD="SEARCH"                          ; shift    ;;
		-f|--find)           CMD="SEARCH"; NAMING=1                ; shift    ;;
		-D|--diff)           CMD="DIFF"                            ; shift    ;;
		-m|--library)        LIB_FILE="$2"                         ; shift   2;;
		-n|--naming)         NAMING=1                              ; shift    ;;
		-N|--no-naming)      NAMING=0                              ; shift    ;;
		-a|--auto-naming)    AUTO_NAMING=1                         ; shift    ;;
		-A|--no-auto-naming) AUTO_NAMING=0                         ; shift    ;;
		-p|--add-libpath)    libpath="${2}:${LIB_PATH}"            ; shift   2;;
		-P|--libpath)        libpath="$2"                          ; shift   2;;
		--clean-temp)        CMD="CLEAN";
		                     CLEAN_TEMP=1                          ; shift    ;;
		--clean-track)       CMD="CLEAN";
		                     CLEAN_TRACK=1                         ; shift    ;;
		--clean)             CMD="CLEAN";
		                     CLEAN_TEMP=1;
		                     CLEAN_TRACK=1                         ; shift    ;;
		-d|--dir)            DIR="$2"                              ; shift   2;;
		-t|--temp-dir)       TMP=1                                 ; shift    ;;
		--no-temp-dir)       TMP=0                                 ; shift    ;;
		-T|--track)          TRACK=1                               ; shift    ;;
		--no-track)          TRACK=0                               ; shift    ;;
		-r|--clean-dir)      CLEAN_DIR=1                           ; shift    ;;
		-R|--no-clean-dir)   CLEAN_DIR=0                           ; shift    ;;
		-F|--force)          FORCE=1                               ; shift    ;;
		--no-force)          FORCE=0                               ; shift    ;;
		-q|--quiet)          QUIET=1   ;FIND_OPTS="$FIND_OPTS $1"  ; shift    ;;
		-Q|--no-quiet)       QUIET=0   ;FIND_OPTS="$FIND_OPTS $1"  ; shift    ;;
		-v|--verbose)        VERBOSE=1 ;FIND_OPTS="$FIND_OPTS $1"  ; shift    ;;
		-V|--no-verbose)     VERBOSE=0 ;FIND_OPTS="$FIND_OPTS $1"  ; shift    ;;
		-h|--help) __lib_archive_usage "$FUNCNAME"                 ; return  0;;
		--) shift; break;;
		esac
	done
	
	if [ -z "$CMD" ]; then
		echo "$FUNCNAME: nessun comando specificato."
		echo
		echo "La lista dei comandi è la seguente:"
		echo "-c --create --build"
		echo "-C --check"
		echo "-y --verify"
		echo "-l --list"
		echo "-D --diff"
		echo "-L --ls"
		echo "-s --search"
		echo "-f --find"
		echo "-x --extract"
		echo "-u --unpack"
		echo "--clean"
		echo "--clean-temp"
		echo "--clean-track"
		echo
		echo "Usa $FUNCNAME -h o $FUNCNAME --help per ulteriori informazioni."
		return 1
	fi
	
	
	__lib_archive_create()
	{
		[ $# -eq 0 ] && return 1
		
		local DIR="$1"
		local ARCHIVE_FILE="$2"
		
		
		[ $QUIET -eq 0 -o $VERBOSE -eq 1 ] && 
		(echo "Creazione archivio di librerie: $ARCHIVE_FILE"
		 echo "Library directory: $DIR")
		
		ARCHIVE_FILE="$(__lib_get_absolute_path "$ARCHIVE_FILE")"
		
		if [ ! -d "$DIR" ]; then
			if [ $QUIET -eq 0 -o $VERBOSE -eq 1 ]; then
				echo "La directory '$DIR' non esiste."
				echo "Creazione archivio fallita!"
			fi
			return 2
		fi
		
		local tar_opts=
		[ $VERBOSE -eq 1 ] && tar_opts="-v"
		(cd "$DIR" && tar $tar_opts -czf "$ARCHIVE_FILE" * 2> /dev/null);
		
		local exit_code=$?
		
		if [ $QUIET -eq 0 -o $VERBOSE -eq 1 ]; then
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
		
		local verbose=0
		
		[ $QUIET -eq 0 -o $VERBOSE -eq 1 ] && verbose=1
		[ $QUIET -eq 1 ]                   && verbose=0
		
		if [ "$1" == "-q" ]; then
			verbose=0
			shift
		fi
		
		[ -f "$1" ] && 
		echo "$1" | grep -q ".$LSF_ARC_EXT" && 
		file --mime-type "$1" | grep -q "gzip"
		
		local exit_code=$?
		
		if [ $verbose -eq 1 ]; then
			if [ $exit_code -eq 0 ]; then
				echo "Il file '$1' è un archivio di libreria"
			else
				echo "Il file '$1' non è un archivio di libreria"
			fi
		fi
		
		return $exit_code
	}
	
	__lib_archive_list()
	{
		[ $# -gt 0 ] && __lib_is_archive -q "$1"  || return 1 
		
		local ARCHIVE_NAME=$(__lib_get_absolute_path "$1")
		
		if [ $VERBOSE -eq 1 ]; then
			echo "Librerie dell'archivio '$1':"
		fi
		
		tar -tzf "$ARCHIVE_NAME" | awk '{gsub("^[.]?/?",""); print}'
	}
	
	__lib_archive_diff_list()
	{
		[ $# -gt 1 ] || return 1
		
		(cd "$2" && tar -dzf "$1" "$3" 2>&1 | awk '{gsub ("tar: ",""); print}' | awk -F: '{print $1}' | sort | uniq)
	}
	
	__lib_archive_diff()
	{
		[ $# -gt 1 ] && __lib_is_archive -q "$1"  || return 1
		
		local ARCHIVE_NAME=$(__lib_get_absolute_path "$1")
		
		(cd "$2" && tar -dzf "$ARCHIVE_NAME" "$3" > /dev/null 2>&1)
		local exit_code=$?
		
		
		if [ $exit_code -eq 0 ]; then
			[ $QUIET -eq 0 -a $VERBOSE -eq 1 ] &&
			echo "Librerie contenute nella directory '$2' non differisco da quelle dell'archivio '$1'."
		else
			if [ $QUIET -eq 0 ]; then
				[ $VERBOSE -eq 1 ] &&
				echo "Librerie contenute nella directory '$2' che differisco da quelle dell'archivio '$1':"
				__lib_archive_diff_list "$ARCHIVE_NAME" "$2" "$3"
			fi
		fi
		
		return $exit_code
	}
	
	__lib_archive_search()
	{
		[ $# -gt 0 ] && __lib_is_archive -q "$1"  || return 1 
		
		local ARCHIVE_NAME=$(__lib_get_absolute_path "$1")
		local LIB="$2"
		
		if [ $TRACK -eq 1 ]; then
			local arc_dir="${LIB_ARC_MAP[$ARCHIVE_NAME]}"
			
			[ -n "$arc_dir" ] && echo "$arc_dir"
			
			return 0
		fi
		
		if [ -z "$LIB" ]; then
			
			[ $QUIET -eq 1 ] || echo "$ARCHIVE_NAME"
			return 0
		fi
		
		
		[ $VERBOSE -eq 1 ] &&
		echo -n "Ricerca della libreria '$LIB' nell'archivio '$1': "
		
		local libfile=""
		for libfile in $(__lib_archive_list "$ARCHIVE_NAME"); do
			if [ "$2" == "$libfile" ]; then
				[ $VERBOSE -eq 1 ] && echo "trovato!"
				if [ $QUIET -eq 0 ]; then
					if [ $REALPATH -eq 1 -a -n "${LIB_ARC_MAP[$ARCHIVE_NAME]}" ]; then
						echo "${LIB_ARC_MAP[$ARCHIVE_NAME]}:$LIB"
					else
						echo "$ARCHIVE_NAME:$LIB"
					fi
				fi
				return 0
			elif [ "$2.$LSF_LIB_EXT" == "$libfile" ]; then
				[ $VERBOSE -eq 1 ] && echo "trovato!"
				if [ $QUIET -eq 0 ]; then
					if [ $REALPATH -eq 1 -a -n "${LIB_ARC_MAP[$ARCHIVE_NAME]}" ]; then
						echo "${LIB_ARC_MAP[$ARCHIVE_NAME]}:$LIB.$LSF_LIB_EXT"
					else
						echo "$ARCHIVE_NAME:$LIB.$LSF_LIB_EXT"
					fi
				fi
				return 0
			elif [ "$2.$LSF_ARC_EXT" == "$libfile" ]; then
				[ $VERBOSE -eq 1 ] && echo "trovato!"
				if [ $QUIET -eq 0 ]; then
					if [ $REALPATH -eq 1 -a -n "${LIB_ARC_MAP[$ARCHIVE_NAME]}" ]; then
						echo "${LIB_ARC_MAP[$ARCHIVE_NAME]}:$LIB.$LSF_ARC_EXT"
					else
						echo "$ARCHIVE_NAME:$LIB.$LSF_ARC_EXT"
					fi
				fi
				return 0
			fi
		done
		
		[ $VERBOSE -eq 1 ] && echo "non trovato!"
		
		return 1
	}
	
	
	__lib_archive_extract()
	{
		[ $# -gt 1 ] && __lib_is_archive -q "$2"  || return 1
		
		local DIR="$1"
		local ARCHIVE_NAME=$(__lib_get_absolute_path "$2")
		local LIB="$3"
		
		[ "$DIR" == "--" ] && DIR=
		#echo "Extract:"           > /dev/stderr
		#echo "DIR=$DIR"           > /dev/stderr
		#echo "ARC_NAME=$ARC_NAME" > /dev/stderr
		#echo "LIB=$lIB"           > /dev/stderr
		
		local diff_list=
		#local old_mod_time=0
		#local new_mod_time=$(stat -c %Y $ARCHIVE_NAME)
		local exit_code=1
		
		if [ $TRACK -eq 1 -a -z "$DIR" ]; then
			
			[ $VERBOSE -eq 1 ] &&
			echo "Verifica se l'archivio '$2' è già stato estratto..."
			
			DIR="${LIB_ARC_MAP[$ARCHIVE_NAME]}"
			
			if [ -n "$DIR" ]; then 
				
				if [ ! -d "$DIR" ]; then
					
					[ $VERBOSE -eq 1 ] &&
					echo "La directory '$DIR' è stata rimossa o il file non è una directory."
					
					unset LIB_ARC_MAP[$ARCHIVE_NAME]
				else
					[ $VERBOSE -eq 1 ] &&
					echo "Directory trovata: $DIR"
					
					diff_list=$(__lib_archive_diff_list "$ARCHIVE_NAME" "$DIR" "$LIB")
					
					#old_mod_time=$(stat -c %Y "$DIR")
					
					#if [ ${new_mod_time} -gt ${old_mod_time:=0} ]; then
					if [ -n "$diff_list" ]; then
						
						[ $VERBOSE -eq 1 ] &&
						echo "L'archivio è stato modificato, la directory non è valida!"
						
						#[ $? -eq 0 -a $VERBOSE -eq 1 ] &&
						#echo "Rimozione del contenuto della cartella associata all'archivio."
						#rm -r "$DIR/*"
					elif [ $FORCE -eq 0 ]; then
						
						[ $VERBOSE -eq 1 ] &&
						echo "Estrazione di file dall'archivio non necessaria."
						
						if [ $QUIET -eq 0 ]; then
							__lib_list_dir "$DIR" #| awk -v DIR="$DIR" '{printf "%s/%s\n", DIR, $0}'
						fi
						
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
			DIR=$(basename "$ARCHIVE_NAME" | awk -v S=".$LSF_ARC_EXT" '{gsub(S,""); print}')
		fi
		
		if [ ! -d "$DIR" ]; then
			
			[ $VERBOSE -eq 1 ] &&
			echo "La directory '$DIR' non esiste e verrà creata."
			
			mkdir -p "$DIR"
			
			if [ $? -ne 0 ]; then
				[ $VERBOSE -eq 1 ] &&
				echo "Impossibile creare la directory '$DIR' per l'estrazione."
			
				return
			fi
			
		elif [ $CLEAN_DIR -eq 1 ]; then
			
			[ $? -eq 0 -a $VERBOSE -eq 1 ] &&
			echo "Rimozione del contenuto della cartella associata all'archivio."
			
			rm -r $DIR/* 2> /dev/null
		fi
		
		if [ $VERBOSE -eq 1 ]; then
			if [ -z "$LIB" ]; then
				echo -en "Estrazione dell'"
			else
				echo -en "Estrazione della libreria '$LIB' dall'"
			fi
			echo -e "archivio '$2' nella directory: $DIR\n"
		fi
		
		
		# Estazione dell'archivio
		tar -xzvf "$ARCHIVE_NAME" -C "$DIR" "$LIB" 2> /dev/null | 
		if [ $QUIET -eq 0 ]; then
			awk -v DIR="$DIR" 'BEGIN {print DIR } {printf "%s/%s\n", DIR, $0}'
		else
			cat > /dev/null
		fi
		
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
		local ARCHIVE_NAME=""
		
		[ -n "$1" ] && ARCHIVE_NAME=$(__lib_get_absolute_path "$1")
		
		if [ $CLEAN_TEMP -eq 1 ]; then
			
			if [ -z "$ARCHIVE_NAME" ]; then
				
				[ $QUIET -eq 0 ] &&
				lsf_log "Rimozione delle directory temporanee."
				
				local tmp_dir=
				
				for tmp_dir in $(ls -1d /tmp/lsf-* 2> /dev/null); do
					
					rm -r "$tmp_dir" 2> /dev/null
					[ $VERBOSE -eq 1 ] && (
					[ $? -eq 0 ] && echo -n "[OK] " || echo -n "[KO] "
					echo "Remove directory: $tmp_dir")
				done
			else
				local tmp_dir="${LIB_ARC_MAP[$ARCHIVE_NAME]}"
				
				if [ -n "$tmp_dir" -a -d "$tmp_dir" ]; then
					[ $QUIET -eq 0 ] &&
					lsf_log "Rimozione delle directory temporanea dell'archivio '$ARCHIVE_NAME'."
					rm -r "$tmp_dir" 2> /dev/null
				else
					[ $VERBOSE -eq 1 ] &&
					echo "Rimozione delle directory temporanea dell'archivio '$ARCHIVE_NAME' fallita."
				fi
			fi
		fi
		
		if [ $CLEAN_TRACK -eq 1 ]; then
			if [ -z "$ARCHIVE_NAME" ]; then
				[ $QUIET -eq 0 ] &&
				lsf_log "Pulizia della mappa degli archivi."
				
				LIB_ARC_MAP=()
			else
				[ $QUIET -eq 0 ] &&
				lsf_log "Rimozione dalla mappa degli archivi, del track di '$ARCHIVE_NAME'."
				
				unset LIB_ARC_MAP[$ARCHIVE_NAME]
			fi
		fi
	}
	
	__lib_archive_exit()
	{
		unset __lib_is_archive
		unset __lib_archive_list
		unset __lib_archive_create
		unset __lib_archive_diff
		unset __lib_archive_diff_list
		unset __lib_archive_search
		unset __lib_archive_extract
		unset __lib_archive_clean
		unset __lib_archive_exit
		
		return $1
	}
	
	
	#echo -e "Input: $1\n" > /dev/stderr
	
	if [ $NAMING -eq 0 -a $AUTO_NAMING -eq 1 ]; then
		echo $1 | grep -q "@" && NAMING=1
	fi
	
	
	local ARC_FILE="$1"
	
	if [ $NAMING -eq 1 ]; then
		
		#echo "Naming: enabled"
		
		local ARC_NAME=$(echo ${ARC_FILE} | awk '{gsub(":","/"); gsub("@.*$",""); printf "%s@\n", $0}')
		local LIB_NAME=$(echo ${ARC_FILE} | awk -v A="^$ARC_NAME" '{  gsub(A,""); print }')
		
		#echo "- ARC_NAME=$ARC_NAME" > /dev/stderr
		#echo "- LIB_NAME=$LIB_NAME" > /dev/stderr
		
		[ -n "$ARC_NAME" ] && ARC_FILE="${ARC_NAME/@/.$LSF_ARC_EXT}"
		
		if [ -n "$LIB_NAME" ]; then
			LIB_FILE=$(echo ${LIB_NAME//://} | awk -v E=".$LSF_ARC_EXT/" '
		               {  gsub("@", E); 
		                  gsub("//","/");
		                  gsub("^/",""); 
		                  print
		               }' | awk -v AE="[.]$LSF_ARC_EXT[/]$" -v AES=".$LSF_ARC_EXT" -v LE="$LSF_LIB_EXT" '
		               ! /[/]$/ { printf "%s.%s\n", $0, LE } 
		                 /[/]$/ { gsub(AE,AES); print      }')
		fi 
		
		for libdir in ${libpath//:/ }; do
		
			if [ -f "${libdir}/$ARC_FILE" ]; then
				ARC_FILE="${libdir}/$ARC_FILE"
				break
			fi
		done
	else
		
		#echo "Naming: disabled"
		
		local regex="^[^:]+(.$LSF_ARC_EXT|:)"
		local lib_file=
		
		lib_file="$(echo "$ARC_FILE" | awk -v S="${regex}/?" '{gsub(S,""); print}')"
		lib_file="${lib_file#/}"
		[ -z "$LIB_FILE" ] && LIB_FILE="$lib_file"
		
		ARC_FILE="$(echo "$ARC_FILE" | grep -o -E -e "$regex")"
		ARC_FILE=${ARC_FILE%:}
	fi
	
	#echo "- ARC_FILE=$ARC_FILE" > /dev/stderr
	#echo "- LIB_FILE=$LIB_FILE" > /dev/stderr
	#echo "- DIR=$DIR" > /dev/stderr
	#echo
	
	if echo $LIB_FILE | grep -q -E -e ".+[.]$LSF_ARC_EXT.+$"; then
		
		[ $QUIET -eq 0 -o $VERBOSE -eq 1 ] && (
 		echo "WARNING: LIB_FILE=$LIB_FILE"
 		echo "         Scanning of archive content in archive not yet implemented!")
		return 3
	fi
	
	if [ "$CMD" == "CREATE" ]; then
		
		[ -z "$DIR" -a -n "$LIB_FILE" -a -e "$LIB_FILE" ] &&
		DIR="$LIB_FILE"
		
		[ -z "$ARC_FILE" -a -n "$DIR" ] && 
		ARC_FILE="$(basename "$DIR").$LSF_ARC_EXT"
	fi
	
	if [ -z "$ARC_FILE" -a "$CMD" != "SEARCH" ]; then
		[ -z "$DIR" -a -n "$LIB_FILE" ] &&
		ARC_FILE="$LIB_FILE.$LSF_ARC_EXT"
		LIB_FILE=""
	fi
	
	if [ "$CMD" == "CREATE" ]; then
		ARC_FILE="${ARC_FILE:=lib.$LSF_ARC_EXT}"
		DIR="${DIR:=.}"
	fi
	
	if [ -n "$ARC_FILE" ]; then
		if ! echo $ARC_FILE | grep -q ".$LSF_ARC_EXT$"; then
			ARC_FILE="$ARC_FILE.$LSF_ARC_EXT"
		fi
	else
		ARC_FILE="lib.$LSF_ARC_EXT"
	fi
	
	#echo "Output:"
	#echo "- ARC_FILE=$ARC_FILE" > /dev/stderr
	#echo "- LIB_FILE=$LIB_FILE" > /dev/stderr
	#echo "- DIR=$DIR" > /dev/stderr
	#return
	
	case "$CMD" in
	CHECK)   __lib_is_archive      "$ARC_FILE";;
	LIST)    __lib_archive_list    "$ARC_FILE";;
	DIFF)    __lib_archive_diff "$ARC_FILE" "${DIR:=.}" "$LIB_FILE";;
	CREATE)  __lib_archive_create  "${DIR:=.}" "$ARC_FILE";;
	SEARCH)  __lib_archive_search  "$ARC_FILE" "$LIB_FILE";;
	EXTRACT) __lib_archive_extract "${DIR:=--}" "$ARC_FILE" "$LIB_FILE";;
	CLEAN)   __lib_archive_clean "$1";;
	esac
	
	__lib_archive_exit $?
}

