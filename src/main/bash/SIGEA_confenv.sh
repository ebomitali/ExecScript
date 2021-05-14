#!/bin/bash
#################################################################################
#
#  Variabili  e funzioni comuni agli script di BUILD e DEPLOY
#
#
#
#################################################################################
#
CATLOG="NO"
export SIGEA_TUXEDO_USER_HOME=/export/home
export SIGEA_SHARED_DIR=/nfsmount/rma_rehosting_sigea
export SIGEA_PROD_DIR=/nfsmount/rma_rehosting_sigea_PROD

# Cartella file configurazione
export SIGEA_CONF_DIR=$SIGEA_SHARED_DIR/scripts/cfg

# Prefisso Cartelle per istanze Tuxedo
export SIGEA_MOD=$SIGEA_SHARED_DIR/Mod

# Copia Baseline Produzione
export SIGEA_COPIA_BASELINE_PROD=$SIGEA_SHARED_DIR/BaselineProduzione

# Baseline Produzione
export SIGEA_BASELINE_PROD=$SIGEA_PROD_DIR/Baseline

# Cartelle per BUILD
export SIGEA_SHARED_BUILD_DIR=$SIGEA_SHARED_DIR/ExecBuild
export SIGEA_PRJ_STREAM_DIR=$SIGEA_SHARED_BUILD_DIR/ProjectStream
export SIGEA_BUILD_LOG_DIR=$SIGEA_SHARED_BUILD_DIR/log

# Cartelle per DEPLOY
export SIGEA_SHARED_DEPLOY_DIR=$SIGEA_SHARED_DIR/ExecDeploy
export SIGEA_DEPLOY_LOG_DIR=$SIGEA_SHARED_DEPLOY_DIR/log
export SIGEA_SHARED_DEPLOY_PROD_DIR=$SIGEA_PROD_DIR/ExecDeploy
#
#
##### Funzioni comuni 
#
function defineScriptLog() {
   if [[ ! -d $LOG_DIR ]]; then
      mkdir -p $LOG_DIR 
   fi

   # definizione log script corrente (SC_LOG_NAME)
   if [[ "A$SCRIPT_CALLED" != "ASI" ]]; then
      est="$(date +%Y%m%d_%H%M%S_%N).log"
      scnamebase=`echo $SC_NAME |cut -d. -f1`   
      SC_LOG_NAME=${LOG_DIR}/$scnamebase.$est 
      rm -f ${SC_LOG_NAME}
      touch ${SC_LOG_NAME}
   fi
}
function defineScriptDetailedLog() {
   if [[ ! -d $LOG_DIR ]]; then
      mkdir -p $LOG_DIR 
   fi

   # definizione log script corrente (SC_LOG_NAME)
   if [[ "A$SCRIPT_CALLED" != "ASI" ]]; then
      est="$(date +%Y%m%d_%H%M%S_%N).log"
      scnamebase=`echo $SC_NAME |cut -d. -f1`   
      SC_DET_LOG_NAME=${LOG_DIR}/$scnamebase.$est 
      rm -f ${SC_DET_LOG_NAME}
      touch ${SC_DET_LOG_NAME}
   fi
}
function catlog() {
   if [[ "A$CATLOG" == "ASI" ]]; then
      if [[ "A$SC_DET_LOG_NAME" == "A" ]]; then
         cat $SC_LOG_NAME
      else
         cat $SC_DET_LOG_NAME
      fi
   fi
}
