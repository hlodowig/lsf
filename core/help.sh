# LSF HELP

lsf_help()
{
	local LSF_PREFIX="lsf"
	local LIB_PREFIX="lib"
	local CMD="lsf"
	
	(cat << END
NAME
	$CMD - Library System Framework.
	
SYNOPSIS
	$CMD <command> [<options>]
	
	$CMD [-|--verbose]
	
	$CMD -h|--help|-?|help
	
	
DESCRIPTION
	Library System Framework (LSF) è un framework per l'import di librerie di script definite dall'utente.
	
GENERIC OPTIONS
	--file <sh_script>
	    Esegue lo script con sintassi bash, senza effettuare parsing.
	    I comandi LSF devono essere idenfificati per esteso: $LIB_PREFIX_<comando>.
	
	--script <lsf_script>
	    Esegue il parsing dello script LSF.
	    Negli script LSF il comando run e affini risulta superfluo.
	    NOTA: Al momento può eseguire solo comandi su una singola linea.
	
	-D, --dummy
	    Stampa il comando senza eseguirlo.
	
	--interactive
	    Esegue LSF in modalità interattiva.
	
	--no-interactive
	    Esegue LSF in modalità normale. (default)
	
	-v, --version
	    Stampa la versione di LSF.
	
	-h, --help, help [<command>]
	    Se non è specificato nessun comando, stampa questo messaggio ed esce.
	
COMMAND LIST
	LSF functions:
	  [${LSF_PREFIX}_]log                Log Manager di LSF.
	  [${LSF_PREFIX}_]parser             Parser di LSF.
	  [${LSF_PREFIX}_]keywords           Keywords di LSF.
	  [${LSF_PREFIX}_]main               Main di LSF.
	  [${LSF_PREFIX}_]version            Versione di LSF.
	
	Library functions:
	  [${LIB_PREFIX}_]apply              Trova la libreria e applica una funzione specifica su di essa.
	  [${LIB_PREFIX}_]archive            Crea e gestice gli archivi di libreria.
	  [${LIB_PREFIX}_]depend             Stampa la lista delle dipendenze di una librerie.
	  [${LIB_PREFIX}_]detect_collision   Verifica se ci sono delle collisioni nello spazio dei nomi.
	  [${LIB_PREFIX}_]disable            Disabilita una libreria per l'importazione.
	  [${LIB_PREFIX}_]enable             Abilita una libreria per l'importazione.
	  [${LIB_PREFIX}_]exit               Rimuove le definizioni di funzioni, variabili e alias di LSF.
	  [${LIB_PREFIX}_]find               Restituisce il path della libreria.
	  [${LIB_PREFIX}_]import             Importa librerie nell'ambiente corrente.
	  [${LIB_PREFIX}_]list               Stampa la lista delle librerie in una directory.
	  [${LIB_PREFIX}_]list_apply         Applica una funzione definita dall'utente per file, directory, e archivi.
	  [${LIB_PREFIX}_]name               Restituisce il nome della libreria.
	  [${LIB_PREFIX}_]path               Toolkit per la variabile LIB_PATH.
	  [${LIB_PREFIX}_]test               Esegue test sulla libreria
	
	Extended funcions:
	  ${LIB_PREFIX}_<command>            Esegue funzioni di LSF non appartenenti al core.
	
	Util funcions:
	  clear                              Pulisce lo schermo
	  dummy                              Stampa i comandi senza eseguirli (debug)
	  normal                             Esegue i comandi
	  script,source,.                    Importa una script
	
	Per ulteriri informazioni digitare:
	lsf help <command>  oppure  lsf <command> -h|--help
	
AUTHOR
	Written by Luigi Capraro (lugi.capraro@gmail.com)
	
COPYRIGHT
       Copyright © 2011 Free Software Foundation, Inc.  License GPLv3+: GNU GPL version 3 or later <http://gnu.org/licenses/gpl.html>.
       This is free software: you are free to change and redistribute it.  There is NO WARRANTY, to the extent permitted by law.
	
END
	) | less
	return 0
}
