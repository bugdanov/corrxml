#!/bin/bash
#
# corrxml - ImageJ-Elphel configuration file modifier
#
# Copyright (c) 2014 FOXEL SA - http://foxel.ch
# Copyright (c) 2016 ALSENET SA - http://alsenet.com
#
#
# Author(s):
#
#      Luc Deschenaux <luc.deschenaux@freesurf.ch>
#
#
# This file is part of the FOXEL project <http://foxel.ch>.
# Please read <http://foxel.ch/license> for more information.
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

usage() {
cat << EOF
NAME $(basename $0) - Generate xml file for imagej-elphel Eyesis_Correction

SYNOPSIS
    $(basename $0) -b <base_xml_config> [-f <jp4_file_list>] [-o <output_file>]

    -b|--base_config <base_xml_config>    The imagej-elphel base xml config

    -o|--output <output_file>             The resulting xml file

    -f|--filelist <jp4_file_list>         The list of jp4 files to process,
                                          if not specified, read from stdin

    -d|--define <variable=name>           CORRECTION_PARAMETERS to change
                                          Must be one of:
                                            - resultsDirectory
                                            - tiffCompression
                                            - smoothKernelDirectory
                                            - sharpKernelDirectory
                                            - sensorDirectory
                                            - equirectangularDirectory
DESCRIPTION
    The base config is stripped from existinig source paths.

    The defined CORRECTION_PARAMETERS are set.

    They can also be specified as environment variables.
    eg: resultsDirectory=\$HOME/here $(basename $0) ...

    Files in the given file list are added as sourcePaths in the output xml.

EOF
  exit 1
}

  # parse command line options
  if ! options=$(getopt -o hb:i:o:d: -l help,base-config:,input:,output:,define: -- "$@")
  then
      # something went wrong, getopt will put out an error message for us
      exit 1
  fi
 
  eval set -- "$options"

  FILELIST=/dev/stdin 

  while [ $# -gt 0 ] ; do
      case $1 in
      -h|--help) usage ;;
      -b|--base-config) BASE_CONFIG="$2" ; shift ;;
      -f|--filelist) FILELIST="$2" ; shift ;;
      -d|--define) eval "export $2" || usage ; shift ;;
      -o|--output) OUTFILE="$2" ; shift  ;;
      (--) shift; break;;
      (-*) echo "$(basename $0): error - unrecognized option $1" 1>&2; exit 1;;
      (*) break;;
      esac
      shift
  done
 

[ -f "$BASE_CONFIG" ] || usage
TEMPFILE=$(mktemp)


# remove sourcePaths and ending tag from base config
egrep -v -e 'CORRECTION_PARAMETERS\.sourcePaths' -e 'CORRECTION_PARAMETERS.sourcePath[0-9]+' -e '</properties>' "$BASE_CONFIG" > $TEMPFILE

# set parameters specified as environment variables
for property in smoothKernelDirectory sharpKernelDirectory sensorDirectory equirectangularDirectory resultsDirectory tiffCompression; do
  VALUE=$(env|grep -i $property | cut -f 2 -d '=')
  if [ -n "$VALUE" ] ; then
     sed -r -i -e 's#CORRECTION_PARAMETERS\.'$property'.*#CORRECTION_PARAMETERS.'$property'">'$VALUE'</entry>#' $TEMPFILE || echo "<entry key=\"CORRECTION_PARAMETERS.$property\">$VALUE</entry>" >> $TEMPFILE
  fi
done

# add files from list
INDEX=0
while read JP4 ; do
  ((++INDEX))
  echo "<entry key=\"CORRECTION_PARAMETERS.sourcePath${INDEX}\">$JP4</entry>" >> $TEMPFILE
done < $FILELIST

echo "<entry key=\"CORRECTION_PARAMETERS.sourcePaths\">$INDEX</entry>" >> $TEMPFILE
echo '</properties>' >> $TEMPFILE

if [ -n "$OUTFILE" ] ; then 
  mv $TEMPFILE "$OUTFILE"
else
  cat $TEMPFILE
fi


