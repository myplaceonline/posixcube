#!/bin/sh
# posixcube.sh: POSIX.1-2008-standard automation scripting.
#
# Authors:
#   Kevin Grigorenko (kevin@myplaceonline.com)
#
# Version History:
#   0.1
#     * Version 0.1
#
# Development guidelines:
#   1. See references [1, 2].
#   2. Indent with two spaces.
#
# References:
#   1. http://pubs.opengroup.org/onlinepubs/9699919799/utilities/V3_chap02.html
#   2. https://wiki.ubuntu.com/DashAsBinSh
#   3. printf: http://pubs.opengroup.org/onlinepubs/9699919799/basedefs/V1_chap05.html
#

P666_VERSION=0.1

p666_show_usage () {
  cat <<p666_show_usage_heredoc
usage: posixcube.sh [OPTION]...
POSIX.1-2008-standard automation scripting.

  -h, -?    Help.
  -v        Show version information.
  -d        Print debugging information.

Source: https://github.com/myplaceonline/posixcube
p666_show_usage_heredoc
  exit 1
}

p666_show_version () {
  cat <<p666_show_version_heredoc
posixcube.sh version ${P666_VERSION}
p666_show_version_heredoc
  exit 1
}

# getopts processing based on http://stackoverflow.com/a/14203146/5657303
OPTIND=1 # Reset in case getopts has been used previously in the shell.

# Initialize our own variables:
p666_debug=0

while getopts "h?vd" p666_opt; do
  case "$p666_opt" in
  h|\?)
    p666_show_usage
    ;;
  v)
    p666_show_version
    ;;
  d)
    p666_debug=1
    ;;
  esac
done

shift $((OPTIND-1))

[ "$1" = "--" ] && shift

[ "${p666_debug}" = 1 ] && printf "debug=%d, leftovers: %s\n" ${p666_debug} ${@}
