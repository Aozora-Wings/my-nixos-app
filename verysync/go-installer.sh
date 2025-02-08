#!/bin/bash
VERSION=1.2
TARFILE=verysync-linux-installer-${VERSION}.tar
TARURL=http://www.verysync.com/shell/verysync-linux-installer/$TARFILE

CURL=`command -v curl  2>/dev/null`
WGET=`command -v wget  2>/dev/null`

#######color code########
RED="31m"      # Error message
GREEN="32m"    # Success message
YELLOW="33m"   # Warning message
BLUE="36m"     # Info message

colorEcho(){
    COLOR=$1
    echo -e "\033[${COLOR}${@:2}\033[0m"
}

if [[ "$CURL" == "" && "$WGET" == "" ]]; then
	colorEcho ${RED} "Did not find the wget or curl command"
	exit 1;
fi


if [[ "$CURL" == "" ]]; then
	CURL="$WGET -k -O-"
else
	CURL="$CURL --connect-timeout 10 -k"
fi


colorEcho $GREEN "Downloading from $TARURL"
$CURL $TARURL > $TARFILE
if [[ $? -ne 0 ]]; then
    colorEcho ${RED} "Failed to fetch $TARURL Please check your network or try again."
    exit 3
fi

colorEcho $GREEN "Extracting installer"

mkdir -p verysync-installer
cd verysync-installer && tar xf "../$TARFILE"
if [[ $? -ne 0 ]]; then
	colorEcho ${RED} "Failed to extract verysync-installer."
	exit 4
fi

colorEcho $GREEN "Processing ..."
./go-inst.sh $@

