#!/usr/local/bin/lsf --file

lib_include fs
lib_include io
lib_include sys
lib_include cui:term
lib_include cui:label


WEBCAM_ARK="$PROFILE_DIR/syntek.tar.gz"
WEBCAM_MODULE="stk11xx"
MAKE_FILE="Makefile-syntekdriver"


syntek_compile()
{
	term_cursor_restore
	
	label --length 30 --fg-color YELLOW "compile sources"
	
	make -f $MAKE_FILE > /dev/null 2>&1
}

syntek_install()
{
	local INSTALL_CMD="make -f $MAKE_FILE install"
	
	term_cursor_restore
	
	label --length 30 --fg-color RED "install module"
	
	if sys_is_xterm; then
		gksudo  --description "Webcam Module Installation" "$INSTALL_CMD" > /dev/null
	else
		sudo $INSTALL_CMD > /dev/null
	fi
}


if ! lsmod | grep -q "^videodev .*$WEBCAM_MODULE"; then
	
	STATUS="${RED}fail"
	
	print "Updating webcam drivers... "
	term_cursor_save
	
	if [ -f "$WEBCAM_ARK" ]; then
		TMP_DIR="$(fs_make_tmp_dir)"
		
		label --length 30 --fg-color BLUE "extract module sources"
		
		tar xzf $WEBCAM_ARK -C $TMP_DIR > /dev/null 2>&1 
		
		sleep 1
		
		# save currenti dir
		pushd . > /dev/null
		
		cd $TMP_DIR/syntek/driver &&
		syntek_compile &&
		syntek_install &&
		STATUS="${GREEN}done"
		
		# restore previous dir
		popd > /dev/null
	fi
	
	term_cursor_restore
	label --length 35  "${STATUS}!${NORMAL}"
fi

unset syntek_compile
unset syntek_install

