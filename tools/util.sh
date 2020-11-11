
wait_for_keypress() {
	echo "Press a key to continue..."
	read
}
step() {
	echo -e ${GREEN}-----------------------------------
	echo -e ${GREEN}$@${RESTORE}
	echo -en $RESTORE
	wait_for_keypress
}

run() {
	echo -e ${PURPLE}"$ "$@${RESTORE} >&2
	start=`date +%s`
	echo -en ${LIGHTGRAY}  >&2
	$@
	ret=$?
	echo -en ${RESTORE}  >&2
	end=`date +%s`
	runtime=$((end-start))
	echo -e ${PURPLE}"~ (exit:$ret) $runtime s"${RESTORE}  >&2
	return $ret
}