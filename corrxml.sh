#!/bin/bash
#  corrxml.sh
#
#
# corrxml - ImageJ-Elphel configuration file modifier
#
# Copyright (c) 2014 FOXEL SA - http://foxel.ch
# Please read <http://foxel.ch/license> for more information.
#
#
# Author(s):
#
#      Luc Deschenaux <l.deschenaux@foxel.ch>
#
#
# This file is part of the FOXEL project <http://foxel.ch>.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
#
# Additional Terms:
#
#      You are required to preserve legal notices and author attributions in
#      that material or in the Appropriate Legal Notices displayed by works
#      containing it.
#
#      You are required to attribute the work as explained in the "Usage and
#      Attribution" section of <http://foxel.ch/license>.

[ -n "$DEBUG" ] && set -x

if [ "$1" = "-s" -o "$1" = "--shuffle" ] ; then
  SHUFFLE=1
  shift
fi

if [ $# -lt 2 -o $# -gt 7 ] ; then
  echo "usage: $(basename $0) [ -s  | --shuffle ] <base_config> <path_to_jp4_files> [ <results_directory> <outfile> <split_at> <timestamp> <truncate> ]"
  echo
  echo "When <truncate> is specified after <timestamp>, <split_at> does skip remaining"
  echo "jp4s with the same timestamp (eg: when you want only the 8 first channels per"
  echo "timestamp). Otherwise a trailing sequence number is added to <outfile> for"
  echo "the remaining xml(s), like when <timestamp> is not specified."
  echo
  exit 1
fi

BASE_CONFIG="$1"
DIR="$2"
[ -n "$3" ] && export RESULTSDIRECTORY=$3
OUTFILE_EXT=$(basename "$4" | sed -r -e 's/.*\.([^\.]+)$/\1/')
OUTFILE=$(echo "$4" | sed -r -e 's/\.[^\.]+$//')
SPLIT_AT=$(($5+0))
TIMESTAMP=$6
TRUNCATE=$7
CHUNK_NUM=0
TMP_CONFIG="/tmp/config.$$.tmp"
TOSTDOUT=0
NOW=$(date +%s) # _%N

if [ -z "$OUTFILE" ] ; then
  TOSTDOUT=1
  OUTFILE=/tmp/tmp.$$
  # cannot split stdout
  [ -z "$TIMESTAMP" ] && SPLIT_AT=0
fi

footer() {
    echo "<entry key=\"CORRECTION_PARAMETERS.sourcePaths\">$1</entry>"
    echo '</properties>'
}

egrep -v -e 'CORRECTION_PARAMETERS\.sourcePaths' -e 'CORRECTION_PARAMETERS.sourcePath[0-9]+' -e '</properties>' "$BASE_CONFIG" > "$TMP_CONFIG"

for property in smoothKernelDirectory sharpKernelDirectory sensorDirectory equirectangularDirectory resultsDirectory ; do
  dir=$(env|grep -i $property | cut -f 2 -d '=')
  if [ -n "$dir" ] ; then
     sed -r -i -e 's#CORRECTION_PARAMETERS\.'$property'.*#CORRECTION_PARAMETERS.'$property'">'$dir'</entry>#' "$TMP_CONFIG"
  fi
done

cat "$TMP_CONFIG" > "${OUTFILE}.tmp"

NUM=0
COUNTFILE=/tmp/count.$$.tmp
echo 0 > $COUNTFILE

getTimestamps() {
  sed -r -n -e 's/.*([0-9]{10}_[0-9]{6}).*/\1/p'
}

getfilelist() {
  if [ -z "$FILELIST" ]; then
    FILELIST="/tmp/filelist_$NOW.tmp"
    find "$DIR" -name $TIMESTAMP\*.jp4 | sort > $FILELIST
  fi
  if [ -n "$TIMESTAMP" ] ; then
    grep -E -e "${TIMESTAMP}_[0-9]+.jp4" "$FILELIST"
  else
    if [ -n "$SHUFFLE" ] ; then
      cat "$FILELIST" | getTimestamps | sort -u | progressive | while read ts ; do
        grep $ts "$FILELIST"
      done
    else
      cat "$FILELIST"
    fi
  fi
}

getfilelist | while read JP4 ; do
  echo "<entry key=\"CORRECTION_PARAMETERS.sourcePath${NUM}\">$JP4</entry>" >> "${OUTFILE}.tmp"
  NUM=$(($NUM+1)) 
  if [ $SPLIT_AT -eq $NUM ] ; then
    footer $NUM >> "${OUTFILE}.tmp"
    if [ -n "$TIMESTAMP" -a -n "$TRUNCATE" ] ; then
        mv "${OUTFILE}.tmp" "${OUTFILE}.$OUTFILE_EXT"
        echo "${OUTFILE}.$OUTFILE_EXT"
        echo 0 > $COUNTFILE
        break
    fi
    CHUNK_NUM=$(($CHUNK_NUM+1))
    mv "${OUTFILE}.tmp" "${OUTFILE}.$(printf "%05d" $CHUNK_NUM).$OUTFILE_EXT"
    echo "${OUTFILE}.$(printf "%05d" $CHUNK_NUM).$OUTFILE_EXT"
    cat "$TMP_CONFIG" > "${OUTFILE}.tmp"
    NUM=0
  fi
  echo $NUM > $COUNTFILE
done

NUM=$(cat $COUNTFILE)
rm $COUNTFILE

if [ $NUM -eq 0 ] ; then 
  [ -f "${OUTFILE}.tmp" ] && rm "${OUTFILE}.tmp"
  if [ $TOSTDOUT -eq 1 ] ; then
    [ -s "$OUTFILE" ] && cat $OUTFILE
    rm $OUTFILE
  fi
  exit 0
fi

footer $NUM  >> "${OUTFILE}.tmp"

if [ $TOSTDOUT -eq 1 ] ; then
  cat "${OUTFILE}.tmp"
  rm "${OUTFILE}.tmp"
  exit 0
fi

[ $CHUNK_NUM -gt 1 ] && SUFFIX=.$((CHUNK_NUM-1))
mv "${OUTFILE}.tmp" "${OUTFILE}$SUFFIX.$OUTFILE_EXT"
echo "${OUTFILE}$SUFFIX.$OUTFILE_EXT"

