#!/bin/bash
FILE=""
URL=""
OIFS="$IFS"
IFS=$'\n'
for line in `cat $FILE | awk '{print $3,$4}'`; do
redirect_to=${line##* }
from_redirect=${line%% *}
location=$(curl -I -s https://$URL$from_redirect | grep "Location:" | awk '{ print $2 }')
[[ "${location%%[[:cntrl:]]}" == $redirect_to ]] && echo $from_redirect" OK" || echo ${from_redirect} "  " $redirect_to " NOK"
done
