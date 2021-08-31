#!/bin/bash
IFS= read -r prefix
DATE=${1-today}
if [ -z ${DATE} ]; then
    DATE_PARAM="--date=${DATE}"
fi
gcalcli  --calendar "chrischen0618@gmail.com"  agenda --details all --tsv --nodeclined  "`date ${DATE_PARAM} '+%Y-%m-%d'`" "`date ${DATE_PARAM} '+%Y-%m-%d 23:59'`" | awk -vprefix="$prefix" -F $'\t' '{print prefix $2 "-" $4 " " $9 " " $8}' | grep -v '^\s*$'
