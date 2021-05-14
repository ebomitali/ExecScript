#!/bin/bash
##################################################################################
#   Autore: GFT                                                         07-12-2017
#<ini_par>  
#   Deploy dei programmi cobol (cics, programmi) presenti nel package o nella 
#   release predisposto/a da Ikan Alm sulle istanze tuxedo CICS e BATCH presenti
#   nell’enviroment specificato..
#
#   Sintassi:
#
#      SIGEA_Deploy_Cobol.sh <tipo_rilascio> <envir> <tipo_deploy> <ID_pkg> <ID_Rel> [<file_list>]
#
#           <tipo_rilascio>: correttiva|evolutiva     
#                   <envir>: INTR1, INTR2, SYSR2, PREPROD, PROD 
#             <tipo_deploy>: RESTART | NEWCOPY | PHASEIN
#                  <ID_pkg>: Identificativo del pacchetto
#                  <ID_Rel>: Identificativo della release.
#               <file_list>: (facoltativo) File o Lista di file con estensione seperati 
#                            da virgola per build specifico file
#          Se correttiva passare il valore ND
#
#         
#   Esempio di chiamata
#      SIGEA_Deploy_Cobol.sh correttiva PREPROD NEWCOPY pkg23 ND 
#      SIGEA_Deploy_Cobol.sh correttiva PREPROD NEWCOPY pkg23 ND pgm1.gnt,pgm2.gnt
#      SIGEA_Deploy_Cobol.sh evolutiva  PREPROD PHASEIN pkg01 rel01
#         
#<fin_par>              
#              
##################################################################################
clear
SC_NAME=SIGEA_Deploy_Cobol.sh
EXIT_CODE=0 
VERSIONE=1.0
export LISTA_PROGRAMMI=""

# pretty print log message
# par 1 is the log file, rest is message
pplog () {
    echo "$(date '+%Y-%m-%d %H:%M:%S') ${@}" | tee -a $SC_LOG_NAME
}

# pretty print echo
ppecho () {
    echo "$(date '+%Y-%m-%d %H:%M:%S') ${@}"
}

# pretty print echo
pperror () {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $SC_NAME error: $1"  | tee -a $SC_LOG_NAME
	echo "$(date '+%Y-%m-%d %H:%M:%S') $SC_NAME fine deploy with exitcode: $EXIT_CODE" | tee -a $SC_LOG_NAME
}

ppParametri() {
   pplog "Parametri acquisiti"
   pplog "tipo_rilascio: $TIPO_RILASCIO"
   pplog "envir: $ENVIR"
   pplog "tipo_deploy: $TIPO_DEPLOY"
   pplog "ID_pkg: $ID_PKG"
   pplog "ID_Rel: $ID_PRJ_STR"
   pplog "File configurazione: $FILE_CONFIG"
   pplog "Sorgente: $FROM_DIR"
   pplog "Destinazione: $TO_DIR"
}

function getPreviousEnvir() {
   env=$1
   tipo=$2
   PREV_ENVIR="ERROR"
   if [[ "ASYSR2" == "A$env" ]]; then
      PREV_ENVIR="INTR2"
   fi
   if [[ "APREPROD" == "A$env" ]]; then
      if [[ "A$tipo" == "Acorrettiva" ]]; then
         PREV_ENVIR="INTR1"
      else
         PREV_ENVIR="SYSR2"
      fi
   fi
   if [[ "APROD" == "A$env" ]]; then
      PREV_ENVIR="PREPROD"
   fi
}
   
function verificaErrore() {
   err=$1
   if [[ $err -ne 0 ]]; then
      EXIT_CODE=$err
      msg="Errore_in operazione TUXEDO. Codice errore: $err"
      pperror "$msg"
      rm -f $TEMP_FILE
      exit $EXIT_CODE
   fi 
}
# RESTART
#      BATCH tmshutdown -y e tmboot -y
#      CICS  idem
# COMPANY;UNIX USER;HOME DIRECTORY;RUNTIME;SERVERNMAME; IP address;TuxDir;AppDir
function restartTuxedo() {
  # echo "$SC_NAME: RESTART TUXEDO"  | tee -a  $SC_LOG_NAME >> $SC_DET_LOG_NAME
   cat $FILE_CONFIG | grep -v "COMPANY" | grep -v  '^$'|
   while read riga
   do
      compagnia=$(echo $riga| cut -d";" -f1)
      user=$(echo $riga| cut -d";" -f2)
      homedir=$(echo $riga| cut -d";" -f3)
      runtime=$(echo $riga| cut -d";" -f4)
      hostname=$(echo $riga| cut -d";" -f5)
      appdir=$(echo $riga| cut -d";" -f8|sed "s#\$HOME#${homedir}#")
      pplog "Restart compagnia $compagnia"
      pplog "using command: $hostname $user $appdir tmshutdown -y -w 5 ; tmboot -y $runtime"
      tuxedo_command "$hostname" "$user" "$appdir" "tmshutdown -y -w 5 ; tmboot -y" "$runtime"
      ret=$?
      pplog "Tuxedo command Return Code $ret  "
      verificaErrore $ret
   done 
}

# NEWCOPY o PHASEIN
#      BATCH niente
#      CICS  echo "newcopy (n) {p|s} object_name1 object_name2 ... | artadmin
# COMPANY;UNIX USER;HOME DIRECTORY;RUNTIME;SERVERNMAME; IP address;TuxDir;AppDir
function newcopyTuxedo() {
   LISTA_PROGR=$1
   if [[ "A$LISTA_PROGR" == "A" ]]; then
      pplog "Nessun programma per deploy su TUXEDO"
      return 0
   fi 
# Lasciare l'EOF su prima colonna
   COM_TUX=$(echo "
      artadmin <<-EOF
      newcopy p ${LISTA_PROGR}
      p
      y
EOF"
      ) 

  # Per quella di produzione solo quella attiva 
   cat $FILE_CONFIG| grep -v "COMPANY" | grep -v  '^$'|
   while read riga
   do
      compagnia=$(echo $riga| cut -d";" -f1)
      user=$(echo $riga| cut -d";" -f2)
      homedir=$(echo $riga| cut -d";" -f3)
      runtime=$(echo $riga| cut -d";" -f4)
      hostname=$(echo $riga| cut -d";" -f5)
      #appdir=$(echo $riga| cut -d";" -f8)
      appdir=$(echo $riga| cut -d";" -f8|sed "s#\$HOME#${homedir}#")
      if [[ "A$runtime" != "ABATCH" ]]; then
         pplog " --> NewCopy compagnia $compagnia " 
         pplog " -->          runtime $runtime"  
         tuxedo_command "$hostname" "$user" "$appdir" "${COM_TUX}" "$runtime"
         ret=$?
         pplog " --> Tuxedo command Return Code $ret  "
         pplog " -----------------------------------------------"  
         pplog ""                            
         verificaErrore $ret
      fi
   done 
}
# Prima chiamare il setenv
function tuxedo_command() {
   SERVER_HOSTNAME=$1
   OS_USER_SH=$2
   APP_DIR=$3
   COMMAND=$4 # Comando da eseguire
   RUNTIME=$5 
   if [[ "A$RUNTIME" == "ABATCH" ]]; then
      APP_DIR="$APP_DIR/deploy"
   fi
   pplog "-->  Esecuzione remota comando TUXEDO: [$COMMAND]" 
   pplog "-->  Server: [$SERVER_HOSTNAME], Utente: [$OS_USER_SH] e APP_DIR [$APP_DIR]" 
   result=$(ssh -o "StrictHostKeyChecking no" $OS_USER_SH@$SERVER_HOSTNAME bash -c "'
      cd $APP_DIR
      . ./setenv   
      $COMMAND
      exit'" 2>&1)
   RET_CODE=$?
   return $RET_CODE
}

# Ricerca i programmi sotto source del package con suffisso TO_BE_DELETED e li
# elimina dalla cartella dell'ambiente di destinazione

function demote() {
   cartellaDest=$1
   #echo "$SC_NAME: DEMOTE UNDEPLOY "  | tee -a  $SC_LOG_NAME
   pplog "--> DEMOTE UNDEPLOY " 
   find ${FROM_DIR}/source  -name "*_TO_BE_DELETED" -type f > $TEMP_FILE
   rc=$?
   if [ $rc -gt 0 ] ; then
       EXIT_CODE=6
       pperror "Cartella source mancante"
       exit $EXIT_CODE
   fi
      
   while read -r file
   do
      # Prende la parte dopo /source/
      filebase=$(echo $file|sed 's#\(.*\)/source/\(. *\)#\2#')
      nome=$(echo $filebase|cut -d"." -f1|sed 's#programmi/#lbt/#' |sed 's#cics/#lcx/#')
      echo "   rm -f ${cartellaDest}/dest/$nome.*" | tee -a  $SC_LOG_NAME
      rm -f ${cartellaDest}/dest/$nome.*  2>&1

      # Aggiorna lista programmi per deploy
      #export LISTA_PROGRAMMI="${LISTA_PROGRAMMI} ${cartellaDest}/$nome.gnt"
      nomefile=$(basename "${cartellaDest}/$nome.gnt")
      export LISTA_PROGRAMMI="${LISTA_PROGRAMMI} $nomefile"
   done <  ${TEMP_FILE}
  # echo "$SC_NAME: Lista programmi per DEMOTE: ${LISTA_PROGRAMMI}" | tee -a  $SC_LOG_NAME >> $SC_DET_LOG_NAME
}
#
# Copia i programmi/file presenti nel package/release nella cartella di Mod dell'ambiente (cartellaDest)
function deployFile() {
   cartellaDest=$1
   if [[ "A$PATTERN_SOURCE" == "AALL" ]]; then
      find ${FROM_DIR}/dest -type f  > $TEMP_FILE
   else
      find ${FROM_DIR}/dest  -name "${PATTERN_SOURCE}" -type f > $TEMP_FILE
   fi
   while read file 
   do
      filebase=$(echo $file|sed 's#\(.*\)/dest/\(. *\)#\2#')
      # Copia la risorsa nell'ambiente
      #echo "  cp -f $file ${cartellaDest}/dest/$filebase "  | tee -a  $SC_LOG_NAME
      pplog "  cp -f $file ${cartellaDest}/dest/$filebase "  | tee -a  $SC_LOG_NAME
      cp -f $file ${cartellaDest}/dest/$filebase 2>&1
      # Aggiorna lista programmi per deploy
      num=$(echo $filebase|grep '\.gnt'|wc -l|sed 's/ //g')   
      if [[ "A$num" != "A0" ]]; then
        # if [[ ! -f ${cartellaDest}/dest/$filebase ]]; then
            #LISTA_PROGRAMMI="$LISTA_PROGRAMMI ${cartellaDest}/dest/$filebase"
            nomefile=$(basename "${cartellaDest}/dest/$filebase")
            export LISTA_PROGRAMMI="${LISTA_PROGRAMMI} $nomefile"
        # fi
      fi
   done < ${TEMP_FILE}
  # echo "$SC_NAME: Lista programmi per DEPLOY: ${LISTA_PROGRAMMI}" | tee -a  $SC_LOG_NAME >> $SC_DET_LOG_NAME
}
######### MAIN #############################################################################################################
clear
# Recupera path di esecuzione dello script
DIREXEC="`dirname \"$0\"`"              # relative
DIREXEC="`( cd \"$DIREXEC\" && pwd )`"  # absolutized and normalized
#Invocazione SIGEA_confenv.sh
. $DIREXEC/SIGEA_confenv.sh

LOG_DIR=$SIGEA_DEPLOY_LOG_DIR
defineScriptLog
ppecho "Logging to ${SC_LOG_NAME}"

ppecho "Inizio deploy versione: $VERSIONE"
#
#Controllo dei parametri
# 5 parametri
# $1 tipo rilascio, correttiva o evolutiva
# $2
# $3
# $4 nome package
# $5 release, ND o SIGE1701 etc
if [[ $# -lt 5 ]]; then
   EXIT_CODE=1
   pperror "Parametri insufficienti!!!"
   exit $EXIT_CODE
fi

IN_COPY_DIR=""
TIPO_RILASCIO=$1
ID_PKG=$4
ID_REL=$5
if [[ "A$TIPO_RILASCIO" == "Acorrettiva" ]]; then
   IN_COPY_DIR=$4
fi
if [[ "A$TIPO_RILASCIO" == "Aevolutiva" ]]; then
   if [[ "A$2" == "AINTR1" || "A$2" == "AINTR2" || "A$2" == "ASYSR2" ]]; then
      IN_COPY_DIR=$ID_PKG
   fi
   if [[ "A$2" == "APREPROD" || "A$2" == "APROD" ]]; then
      IN_COPY_DIR=$ID_REL    
   fi
fi
if [[ "A$IN_COPY_DIR" == "A" ]]; then
   EXIT_CODE=2
   pperror "Parametro <tipo_rilascio> $TIPO_RILASCIO non corretto!!!"
   exit $EXIT_CODE
fi
#
ENVIR=$2
if [[ "AINTR1" != "A$ENVIR" && "AINTR2" != "A$ENVIR" && "ASYSR2" != "A$ENVIR" && "APREPROD" != "A$ENVIR" && "APROD" != "A$ENVIR" ]]; then
   EXIT_CODE=3
   pperror "Parametro <envir> $ENVIR non corretto!!!"
   exit $EXIT_CODE
fi   
# File di configurazione
FILE_CONFIG=$SIGEA_CONF_DIR/Tuxedo_Instance_List_${ENVIR}.csv
#
TIPO_DEPLOY=$3
if [[ "ARESTART" != "A$TIPO_DEPLOY" && "ANEWCOPY" != "A$TIPO_DEPLOY" && "APHASEIN" != "A$TIPO_DEPLOY" ]]; then
   EXIT_CODE=4
   pperror "Parametro <tipo_deploy> $TIPO_DEPLOY non corretto!!!"
   exit $EXIT_CODE
fi   
#
if [[ "APROD" != "A$ENVIR" ]]; then
   BASE_DEPLOY_DIR=$SIGEA_SHARED_DEPLOY_DIR
   FROM_DIR=$BASE_DEPLOY_DIR/$ENVIR/${IN_COPY_DIR}
   TO_DIR=${SIGEA_MOD}$ENVIR 
else
   BASE_DEPLOY_DIR=$SIGEA_SHARED_DEPLOY_PROD_DIR
   FROM_DIR=$BASE_DEPLOY_DIR/${IN_COPY_DIR}
   #TO_DIR=$SIGEA_COPIA_BASELINE_PROD
   TO_DIR=$SIGEA__BASELINE_PROD
fi

if [[ ! -d $FROM_DIR ]]; then
   EXIT_CODE=5
   pperror "Cartella $FROM_DIR da cui copiare i programmi inesistente!!!"
   exit $EXIT_CODE
fi 
if [[ ! -d $TO_DIR ]]; then
   EXIT_CODE=5
   pperror "Cartella $TO_DIR su cui effettuare il deploy non esiste!!!"
   exit $EXIT_CODE
fi 
PATTERN_SOURCE="ALL"
if [[ $# -gt 5 ]]; then
   PATTERN_SOURCE=$(echo "$6" | sed 's/,/ /g')
fi

# Destination
mkdir -p ${FROM_DIR}/dest

# Definizione log di dettaglio
LOG_DIR=$FROM_DIR/log

#
# Visualizza i parametri
ppParametri $SC_LOG_NAME

#
TEMP_FILE=${SC_NAME}_$$.tmp
#
# STEP 1
#
# Eventuale DEMOTE/UNDEPLOY
#
if [[ "ANEWCOPY" == "A$TIPO_DEPLOY" || "APHASEIN" == "A$TIPO_DEPLOY" ]]; then
   # demote/undeploy per ogni istanza dei programmi cancellati:
   # tutti quelli con suffisso TO_BE_DELETED sotto la cartella di source $FROM_DIR
   pplog "--> STEP1 - Demote/Undeploy dei programmi:"
   demote "${TO_DIR}"
   # Successivamente al passo 3 si effettua il deploy/reboot TUXEDO per ogni istanza
   if [ $EXIT_CODE -gt 0 ] ; then   
        exit $EXIT_CODE     
   fi     
fi
#
# STEP 2
#
# Esegue la copia dei programmi/file presenti nel package/release eventualmente filtrati dal parametro <file_list>
#
pplog "--> STEP 2 - Copia dei programmi/file presenti nel pakage/release"
deployFile "${TO_DIR}"
#
# STEP 3
#
# Deploy per ogni istanza o riavvio 
#
if [[ "ANEWCOPY" == "A$TIPO_DEPLOY" || "APHASEIN" == "A$TIPO_DEPLOY" ]]; then
   # Lancia il comando di deploy per ogni istanza tuxedo
   pplog "--> STEP 3 - Deploy per ogni istanza "
   # Chiamare la funzione newcopyTuxedo che  effettua il deploy per ogni istanza presente nel file csv
   newcopyTuxedo "$LISTA_PROGRAMMI"
   EXIT_CODE=$? 
else
   # Riavvio del server 
   ppecho "--> STEP 3 - Riavvio dei server"
   # Chiamare la funzione restartTuxedo che  effettua il riavvio  per ogni istanza presente nel file csv
   restartTuxedo   
   EXIT_CODE=$? 
fi

# Matteo - Test EXIT CODE - inizio

if [[ "$EXIT_CODE" -ne "0" ]]; then
    pperror "Newcopy Tuxedo failed"
    exit $EXIT_CODE
fi

# Matteo - Test EXIT CODE - Fine

#
# STEP 4
#
# rimuove i file presenti nel package o nella release dall’ambiente precedente
#
if [[ "ASYSR2" == "A$ENVIR" || "APREPROD" == "A$ENVIR" || "APROD" == "A$ENVIR" ]]; then
   pplog "--> STEP 4 - Rimozione file da ambiente precedente "
   getPreviousEnvir $ENVIR $TIPO_RILASCIO
   # la funzione torna PREV_ENVIR
   PREVIOUS_ENVIR_DIR=${SIGEA_MOD}$PREV_ENVIR
   if [[ "A$PREV_ENVIR" != "AERROR" ]]; then
      if [[ "A$PATTERN_SOURCE" == "AALL" ]]; then
          find ${FROM_DIR}/dest -type f > $TEMP_FILE
      else
          find ${FROM_DIR}/dest  -name "${PATTERN_SOURCE}" -type f > $TEMP_FILE
      fi
      cat $TEMP_FILE |
      while read file
      do
         # Prende la parte dopo /dest/
         filebase=$(echo $file|sed 's#\(.*\)/dest/\(. *\)#\2#')
         pplog "    rm -f ${PREVIOUS_ENVIR_DIR}/dest/$filebase"
         rm -f ${PREVIOUS_ENVIR_DIR}/dest/$filebase  >> $SC_DET_LOG_NAME 2>&1
      done
      if [[ "APROD" == "A$ENVIR" ]]; then
         pplog "--> Allineamento copia di produzione"
         pplog "--> Cancellazione file con suffisso _TO_BE_DELETED da cartella $SIGEA_COPIA_BASELINE_PROD"
         demote "${SIGEA_COPIA_BASELINE_PROD}"

         # Esegue la copia dei programmi/file presenti nel package/release
         pplog "--> Copia dei programmi/file per allinemento copia baseline di produzione"
         deployFile "${SIGEA_COPIA_BASELINE_PROD}"
       fi
    else
      EXIT_CODE=10
      pperror "Errore nel calcolo dell'ambiente precedente!!!"
    fi
fi

rm -f $TEMP_FILE

pplog "Fine deploy with exitcode: $EXIT_CODE"
exit $EXIT_CODE

