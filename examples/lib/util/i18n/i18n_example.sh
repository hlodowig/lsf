#!/bin/bash

SCRIPT_HOME="$(dirname $(readlink -f $BASH_SOURCE))"

source $LSF_HOME/lsf.sh

lsf_log --disable

lib_path --set "$LSF_HOME/lib"

lib_include util:i18n

APP_ID=$$
LANG="${1:-default}"
LANG_DIR="$SCRIPT_HOME/lang"

echo "_________________________________________________________________"
echo
i18n_println "Test %FUN: i18n_init <app_id> <dir> <lang=$LANG>"
echo "_________________________________________________________________"
i18n_init $APP_ID "$LANG_DIR" $LANG
echo "_________________________________________________________________"
echo
i18n_println "Test %FUN: i18n_get_text <app_id> <message_id> [<params> ...]"
echo "_________________________________________________________________"
i18n_get_text $APP_ID WELCOME "$(basename $0)" "$USER" "$USER@$HOSTNAME"
echo "_________________________________________________________________"
echo
i18n_println "Test %FUN: i18n_get_message <message_id> [<params> ...]"
echo "_________________________________________________________________"
echo
echo "$(i18n_get_message HOST_MSG $HOSTNAME)"
echo "$(i18n_get_message USER_MSG $USER)"
echo "_________________________________________________________________"
echo
i18n_println "Test %FUN: i18n_print[ln] \"%<message_id>[(<param> [, ...])]\""
echo "_________________________________________________________________"
i18n_println "%HOST_MSG($HOSTNAME)"
i18n_println "%USER_MSG($USER)"
echo "_________________________________________________________________"
echo
i18n_println "Test %FUN: i18n_list_message <app_id> <lang>"
echo "_________________________________________________________________"
i18n_list_message $APP_ID $LANG
echo "_________________________________________________________________"
echo

