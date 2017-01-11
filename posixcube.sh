#!/bin/sh
# posixcube.sh
#   posixcube.sh is a POSIX compliant shell script server automation framework.
#   Use consistent APIs for common tasks and package functionality and file
#   templates in cubes (like recipes/playbooks from other frameworks).
#
# Authors:
#   Kevin Grigorenko (kevin@myplaceonline.com)
#
# Version History:
#   0.1
#     * Version 0.1
#
# Development guidelines:
#   1. See references [1, 2, 7].
#   2. Indent with two spaces.
#   3. Use lower-case variables unless an envar may be used by other scripts [4].
#      All scripts are `source`d together, so exporting is usually unnecessary.
#   4. Try to keep lines less than 120 characters.
#   5. Use [ for tests instead of [[ and use = instead of ==.
#   6. Use a separate [ invocation for each single test, combine them with && and ||.
#   7. Don't use `set -e`. Handle failures consciously (see Philosophy section).
#
# References:
#   1. http://pubs.opengroup.org/onlinepubs/9699919799/utilities/V3_chap02.html
#   2. https://www.gnu.org/software/autoconf/manual/autoconf.html#Portable-Shell
#   3. printf: http://pubs.opengroup.org/onlinepubs/9699919799/basedefs/V1_chap05.html
#   4. "The name space of environment variable names containing lowercase letters is reserved for applications."
#      http://pubs.opengroup.org/onlinepubs/009695399/basedefs/xbd_chap08.html
#   5. test: http://pubs.opengroup.org/onlinepubs/9699919799/utilities/test.html
#   6. expr: http://pubs.opengroup.org/onlinepubs/9699919799/utilities/expr.html
#   7. https://wiki.ubuntu.com/DashAsBinSh

p666_show_usage() {
  if [ $# -ne 0 ]; then
    p666_printf_error "${@}"
  fi

  # When updating usage, also update README.md.
  cat <<'HEREDOC'
usage: posixcube.sh -h HOST... [OPTION]... COMMAND...

  posixcube.sh is a POSIX compliant shell script server automation framework.
  Use consistent APIs for common tasks and package functionality and file
  templates in cubes (like recipes/playbooks from other frameworks).

  -?        Help.
  -h HOST   Target host. Option may be specified multiple times. If a host has
            a wildcard ('*'), then HOST is interpeted as a regular expression,
            with '*' replaced with '.*' and any matching hosts in the following
            files are added to the HOST list: /etc/ssh_config,
            /etc/ssh/ssh_config, ~/.ssh/config, /etc/ssh_known_hosts,
            /etc/ssh/ssh_known_hosts, ~/.ssh/known_hosts, and /etc/hosts.
  -c CUBE   Execute a cube. Option may be specified multiple times. If COMMANDS
            are also specified, cubes are run first.
  -u USER   SSH user. Defaults to ${USER}.
  -e ENVAR  Shell script with environment variable assignments which is
            uploaded and sourced on each HOST. Option may be specified
            multiple times. Files ending with .enc will be decrypted
            temporarily. If not specified, defaults to envars*sh envars*sh.enc
  -p PWD    Password for decrypting .enc ENVAR files.
  -w PWDF   File that contains the password for decrypting .enc ENVAR files.
            Defaults to ~/.posixcube.pwd
  -r ROLE   Role name. Option may be specified multiple times.
  -o P=V    Set the specified parameter P with the value V. Do not put double
            quotes around V. If V contains *, try to find matching hosts per
            the -h algorithm. Option may be specified multiple times.
  -i CUBE   Upload a CUBE but do not execute it. This is needed when one CUBE
            includes this CUBE using cube_include.
  -v        Show version information.
  -d        Print debugging information.
  -q        Quiet; minimize output.
  -b        If using bash, install programmable tab completion for SSH hosts.
  -s        Skip remote host initialization (making ~/posixcubes, uploading
            posixcube.sh, etc.
  -k        Keep the cube_exec.sh generated script.
  -z SPEC   Use the SPEC set of options from the ./cubespecs.ini file
  -a        Asynchronously execute remote CUBEs/COMMANDs. Works on Bash only.
  -y        If a HOST returns a non-zero code, continue processing other HOSTs.
  COMMAND   Remote command to run on each HOST. Option may be specified
            multiple times. If no HOSTs are specified, available sub-commands:
              edit: Decrypt, edit, and re-encrypt ENVAR file with $EDITOR.
              show: Decrypt and print ENVAR file.
              source: Source all ENVAR files. Must be run with
                      POSIXCUBE_SOURCED (see Public Variables section below).

Description:

  posixcube.sh is used to execute CUBEs and/or COMMANDs on one or more HOSTs.
  
  A CUBE is a shell script or directory containing shell scripts. The CUBE
  is rsync'ed to each HOST. If CUBE is a shell script, it's executed. If
  CUBE is a directory, a shell script of the same name in that directory
  is executed. In both cases, the directory is changed to the directory
  containing the script before execution so that you may reference files
  such as templates using relative paths.
  
  An ENVAR script is encouraged to use environment variable names of the form
  cubevar_${uniquecontext}_envar="value". If a CUBE directory contains the
  file `envars.sh`, it's sourced before anything else (including `-e ENVARs`).
  
  Both CUBEs and COMMANDs may execute any of the functions defined in the
  "Public APIs" in the posixcube.sh script. Short descriptions of the functions
  are in the APIs section below. See the source comments above each function
  for details.
  
Examples (assuming posixcube.sh is on ${PATH}, or executed absolutely):

  posixcube.sh -h socrates uptime
  
    Run the `uptime` command on host `socrates`. This is not very different
    from ssh ${USER}@socrates uptime, except that COMMANDs (`uptime`) have
    access to the cube_* public functions.
  
  posixcube.sh -h socrates -c test.sh
  
    Run the `test.sh` script (CUBE) on host `socrates`. The script has
    access to the cube_* public functions.
  
  posixcube.sh -h socrates -c test
  
    Upload the entire `test` directory (CUBE) to the host `socrates` and
    then execute the `test.sh` script within that directory (the name
    of the script is expected to be the same as the name of the CUBE). This
    allows for easily packaging other scripts and resources needed by
    `test.sh`.
  
  posixcube.sh -u root -h socrates -h seneca uptime
  
    Run the `uptime` command on hosts `socrates` and `seneca`
    as the user `root`.
  
  posixcube.sh -h web*.test.com uptime
  
    Run the `uptime` command on all hosts matching the regular expression
    web.*.test.com in the SSH configuration files.
  
  sudo ${PATH_TO}/posixcube.sh -b && . /etc/bash_completion.d/posixcube_completion.sh
  
    For Bash users, install a programmable completion script to support tab
    auto-completion of hosts from SSH configuration files.

  posixcube.sh -e production.sh.enc show
  
    Decrypt and show the contents of production.sh
  
  posixcube.sh -e production.sh.enc edit
  
    Decrypt, edit, and re-encrypt the contents of production.sh with $EDITOR

Philosophy:

  Fail hard and fast. In principle, a well written script would check ${?}
  after each command and either gracefully handle it, or report an error.
  Few people write scripts this well, so we enforce this check (using
  `cube_check_return` within all APIs) and we encourage you to do the same
  in your scripts with `touch /etc/fstab || cube_check_return`. All cube_*
  APIs are guaranteed to do their own checks, so you don't have to do this
  for those calls; however, note that if you're executing a cube_* API in a
  sub-shell, although any failures will be reported by cube_check_return,
  the script will continue unless you also check the return of the sub-shell.
  For example: $(cube_readlink /etc/localtime) || cube_check_return
  With this strategy, unfortunately piping becomes more difficult. There are
  non-standard mechanisms like pipefail and PIPESTATUS, but the standardized
  approach is to run each command separately and check the status. For example:
  cube_app_result1="$(command1 || cube_check_return)" || cube_check_return
  cube_app_result2="$(printf '%s' "${cube_app_result1}" | command2 || cube_check_return)" || cube_check_return
  
  We do not use `set -e` because some functions may handle all errors
  internally (with `cube_check_return`) and use a positive return code as a
  "benign" result (e.g. `cube_set_file_contents`).

Frequently Asked Questions:

  * Why is there a long delay between "Preparing hosts" and the first remote
    execution?
  
    You can see details of what's happening with the `-d` flag. By default,
    the script first loops through every host and ensures that ~/posixcubes/
    exists, then it transfers itself to the remote host. These two actions
    may be skipped with the `-s` parameter if you've already run the script
    at least once and your version of this script hasn't been updated. Next,
    the script loops through every host and transfers any CUBEs and a script
    containing the CUBEs and COMMANDs to run (`cube_exec.sh`). Finally,
    you'll see the "Executing on HOST..." line and the real execution starts.

Cube Development:

  Shell scripts don't have scoping, so to reduce the chances of function name
  conflicts, name functions cube_${cubename}_${function} and name variables
  cubevar_${cubename}_${var}.

Public APIs:
  
  * cube_echo
      Print ${@} to stdout prefixed with ([$(date)] [$(hostname)]) and
      suffixed with a newline.
      Example: cube_echo "Hello World"

  * cube_printf
      Print $1 to stdout prefixed with ([$(date)] [$(hostname)]) and
      suffixed with a newline (with optional printf arguments in $@).
      Example: cube_printf "Hello World from PID %5s" $$

  * cube_error_echo
      Same as cube_echo except output to stderr and include a red "Error: "
      message prefix.
      Example: cube_error "Goodbye World"

  * cube_error_printf
      Same as cube_printf except output to stderr and include a red "Error: "
      message prefix.
      Example: cube_error "Goodbye World from PID %5s" $$

  * cube_throw
      Same as cube_error_echo but also print a stack of functions and processes
      (if available) and then call `exit 1`.
      Example: cube_throw "Expected some_file."

  * cube_check_return
      Check if $? is non-zero and call cube_throw if so.
      Example: some_command || cube_check_return

  * cube_include
      Include the ${1} cube
      Example: cube_include core_cube

  * cube_check_numargs
      Call cube_throw if there are less than $1 arguments in $@
      Example: cube_check_numargs 2 "${@}"

  * cube_service
      Run the $1 action on the $2 service.
      Example: cube_service start crond

  * cube_package
      Pass $@ to the package manager. Implicitly passes the the parameter
      to say yes to questions.
      Example: cube_package install python

  * cube_append_str
      Echo $1 with $2 appended after a space if $1 was not blank.
      Example: cubevar_app_str=$(cube_append_str "${cubevar_app_str}" "Test")

  * cube_command_exists
      Check if $1 command or function exists in the current context.
      Example: cube_command_exists systemctl

  * cube_dir_exists
      Check if $1 exists as a directory.
      Example: cube_dir_exists /etc/cron.d/

  * cube_file_exists
      Check if $1 exists as a file with read access.
      Example: cube_file_exists /etc/cron.d/0hourly

  * cube_operating_system
      Detect operating system and return one of the POSIXCUBE_OS_* values.
      Example: [ $(cube_operating_system) -eq ${POSIXCUBE_OS_LINUX} ] && ...

  * cube_operating_system_has_flavor
      Check if the operating system flavor includes the flavor specified in $1
      by one of the POSIXCUBE_OS_FLAVOR_* values.
      Example: cube_operating_system_has_flavor ${POSIXCUBE_OS_FLAVOR_FEDORA} && ...

  * cube_shell
      Detect running shell and return one of the CUBE_SHELL_* values.
      Example: [ $(cube_shell) -eq ${POSIXCUBE_SHELL_BASH} ] && ...

  * cube_current_script_name
      echo the basename of the currently executing script.
      Example: script_name=$(cube_current_script_name)

  * cube_current_script_abs_path
      echo the absolute path the currently executing script.
      Example: script_name=$(cube_current_script_abs_path)

  * cube_file_size
      echo the size of a file $1 in bytes
      Example: cube_file_size some_file

  * cube_set_file_contents
      Copy the contents of $2 on top of $1 if $1 doesn't exist or the contents
      are different than $2. If $2 ends with ".template", first evaluate all
      ${VARIABLE} expressions (except for \${VARIABLE}).
      Example: cube_set_file_contents "/etc/npt.conf" "templates/ntp.conf"

  * cube_set_file_contents_string
      Set the contents of $1 to the string $@. Create file if it doesn't exist.
      Example: cube_set_file_contents_string ~/.info "Hello World"

  * cube_expand_parameters
      echo stdin to stdout with all ${VAR}'s evaluated (except for \${VAR})
      Example: cube_expand_parameters < template > output

  * cube_readlink
      Echo the absolute path of $1 without any symbolic links.
      Example: cube_readlink /etc/localtime

  * cube_random_number
      Echo a random number between 1 and $1
      Example: cube_random_number 10

  * cube_tmpdir
      Echo a temporary directory
      Example: cube_tmpdir

  * cube_total_memory
      Echo total system memory in bytes
      Example: cube_total_memory

  * cube_ensure_directory
      Ensure directory $1 exists
      Example: cube_ensure_directory ~/.ssh/

  * cube_ensure_file
      Ensure file $1 exists
      Example: cube_ensure_file ~/.ssh/authorized_keys

  * cube_pushd
      Equivalent to `pushd` with $1
      Example: cube_pushd ~/.ssh/

  * cube_popd
      Equivalent to `popd`
      Example: cube_popd

  * cube_has_role
      Return true if the role $1 is set.
      Example: cube_has_role "database_backup"

  * cube_file_contains
      Check if the file $1 contains $2
      Example: cube_file_contains /etc/fstab nfsmount

  * cube_stdin_contains
      Check if stdin contains $1
      Example: echo "Hello World" | cube_stdin_contains "Hello"

  * cube_interface_ipv4_address
      Echo the IPv4 address of interface $1
      Example: cube_interface_ipv4_address eth0

  * cube_interface_ipv6_address
      Echo the IPv6 address of interface $1
      Example: cube_interface_ipv6_address eth0

  * cube_prompt
      Prompt the question $1 followed by " (y/N)" and prompt for an answer.
      A blank string answer is equivalent to No. Return true if yes, false otherwise.
      Example: cube_prompt "Are you sure?"

  * cube_hostname
      Echo full hostname.
      Example: cube_hostname

  * cube_user_exists
      Check if the $1 user exists
      Example: cube_user_exists nginx

  * cube_create_user
      Create the user $1
      Example: cube_create_user nginx

  * cube_group_exists
      Check if the $1 group exists
      Example: cube_group_exists nginx

  * cube_create_group
      Create the group $1
      Example: cube_create_group nginx

  * cube_group_contains_user
      Check if the $1 group contains the user $2
      Example: cube_group_contains_user nginx nginx

  * cube_add_group_user
      Add the user $2 to group $1
      Example: cube_add_group_user nginx nginx

Public Variables:

  * POSIXCUBE_APIS_ONLY
      Set this to any value to only source the public APIs in posixcube.sh.
      Example: POSIXCUBE_APIS_ONLY=true . posixcube.sh && cube_echo $(cube_random_number 10)
  
  * POSIXCUBE_SOURCED
      Set this to any value to only run a sub-COMMAND, most commonly `source`,
      to source in all ENVAR files, but skip actual execution of posixcube.
      Example: POSIXCUBE_SOURCED=true . posixcube.sh source; POSIXCUBE_SOURCED= ; cube_echo Test

Source: https://github.com/myplaceonline/posixcube
HEREDOC

  if [ $# -ne 0 ]; then
    p666_printf_error "${@}"
  fi

  if [ "${POSIXCUBE_SOURCED}" = "" ]; then
    exit 1
  fi
}

###############
# Public APIs #
###############

POSIXCUBE_VERSION=0.1
POSIXCUBE_DEBUG=0
POSIXCUBE_COLOR_RESET="\x1B[0m"
POSIXCUBE_COLOR_RED="\x1B[31m"
POSIXCUBE_COLOR_GREEN="\x1B[32m"
POSIXCUBE_COLOR_YELLOW="\x1B[33m"
POSIXCUBE_COLOR_BLUE="\x1B[34m"
POSIXCUBE_COLOR_PURPLE="\x1B[35m"
POSIXCUBE_COLOR_CYAN="\x1B[36m"
POSIXCUBE_COLOR_WHITE="\x1B[37m"

POSIXCUBE_NEWLINE="
"
POSIXCUBE_CUBE_NAME=""
POSIXCUBE_CUBE_NAME_WITH_PREFIX=""

POSIXCUBE_OS_UNKNOWN=-1
POSIXCUBE_OS_LINUX=1
POSIXCUBE_OS_MAC_OSX=2
POSIXCUBE_OS_WINDOWS=3

POSIXCUBE_OS_FLAVOR_UNKNOWN=-1
POSIXCUBE_OS_FLAVOR_FEDORA=1
POSIXCUBE_OS_FLAVOR_DEBIAN=2
POSIXCUBE_OS_FLAVOR_UBUNTU=3

POSIXCUBE_SHELL_UNKNOWN=-1
POSIXCUBE_SHELL_BASH=1

POSIXCUBE_NODE_HOSTNAME="$(hostname)"

# Description:
#   Print ${@} to stdout prefixed with ([$(date)]  [$(hostname)]) and suffixed with
#   a newline.
# Example call:
#   cube_echo "Hello World"
# Example output:
#   [Sun Dec 18 09:40:22 PST 2016] [socrates] Hello World
# Arguments: ${@} passed to echo
cube_echo() {
  if [ "${POSIXCUBE_CUBE_NAME_WITH_PREFIX}" = "" ]; then
    printf "[$(date)] [${POSIXCUBE_COLOR_GREEN}${POSIXCUBE_NODE_HOSTNAME}${POSIXCUBE_COLOR_RESET}] "
  else
    printf "[$(date)] [${POSIXCUBE_COLOR_GREEN}${POSIXCUBE_NODE_HOSTNAME}${POSIXCUBE_COLOR_RESET}${POSIXCUBE_COLOR_CYAN}${POSIXCUBE_CUBE_NAME_WITH_PREFIX}$(cube_line_number ":")${POSIXCUBE_COLOR_RESET}] "
  fi
  echo "${@}"
}

# Description:
#   Print $1 to stdout prefixed with ([$(date)]  [$(hostname)]) and suffixed with
#   a newline.
# Example call:
#   cube_printf "Hello World from PID %5s" $$
# Example output:
#   [Sun Dec 18 09:40:22 PST 2016] [socrates] Hello World from PID   123
# Arguments:
#   Required:
#     $1: String to print (printf-compatible)
#   Optional: 
#     $2: printf arguments 
cube_printf() {
  cube_printf_str=$1; shift
  if [ "${POSIXCUBE_CUBE_NAME_WITH_PREFIX}" = "" ]; then
    printf "[$(date)] [${POSIXCUBE_COLOR_GREEN}${POSIXCUBE_NODE_HOSTNAME}${POSIXCUBE_COLOR_RESET}] ${cube_printf_str}\n" "${@}"
  else
    printf "[$(date)] [${POSIXCUBE_COLOR_GREEN}${POSIXCUBE_NODE_HOSTNAME}${POSIXCUBE_COLOR_RESET}${POSIXCUBE_COLOR_CYAN}${POSIXCUBE_CUBE_NAME_WITH_PREFIX}$(cube_line_number ":")${POSIXCUBE_COLOR_RESET}] ${cube_printf_str}\n" "${@}"
  fi
}

# Description:
#   Print $1 to stderr prefixed with ([$(date)]  [$(hostname)] Error: ) and
#   suffixed with a newline.
# Example call:
#   cube_error_echo "Goodbye World"
# Example output:
#   [Sun Dec 18 09:40:22 PST 2016] [socrates] Goodbye World
# Arguments: ${@} passed to echo
cube_error_echo() {
  if [ "${POSIXCUBE_CUBE_NAME_WITH_PREFIX}" = "" ]; then
    printf "[$(date)] [${POSIXCUBE_COLOR_RED}${POSIXCUBE_NODE_HOSTNAME}${POSIXCUBE_COLOR_RESET}] ${POSIXCUBE_COLOR_RED}Error${POSIXCUBE_COLOR_RESET}: " 1>&2
  else
    printf "[$(date)] [${POSIXCUBE_COLOR_RED}${POSIXCUBE_NODE_HOSTNAME}${POSIXCUBE_CUBE_NAME_WITH_PREFIX}$(cube_line_number ":")${POSIXCUBE_COLOR_RESET}] ${POSIXCUBE_COLOR_RED}Error${POSIXCUBE_COLOR_RESET}: " 1>&2
  fi
  echo "${@}" 1>&2
}

# Description:
#   Print $1 to stderr prefixed with ([$(date)]  [$(hostname)] Error: ) and
#   suffixed with a newline.
# Example call:
#   cube_error_printf "Goodbye World from PID %5s" $$
# Example output:
#   [Sun Dec 18 09:40:22 PST 2016] [socrates] Goodbye World from PID   123
# Arguments:
#   Required:
#     $1: String to print (printf-compatible)
#   Optional: 
#     $2: printf arguments 
cube_error_printf() {
  cube_error_printf_str=$1; shift
  if [ "${POSIXCUBE_CUBE_NAME_WITH_PREFIX}" = "" ]; then
    printf "[$(date)] [${POSIXCUBE_COLOR_RED}${POSIXCUBE_NODE_HOSTNAME}${POSIXCUBE_COLOR_RESET}] ${POSIXCUBE_COLOR_RED}Error${POSIXCUBE_COLOR_RESET}: ${cube_error_printf_str}\n" "${@}" 1>&2
  else
    printf "[$(date)] [${POSIXCUBE_COLOR_RED}${POSIXCUBE_NODE_HOSTNAME}${POSIXCUBE_CUBE_NAME_WITH_PREFIX}$(cube_line_number ":")${POSIXCUBE_COLOR_RESET}] ${POSIXCUBE_COLOR_RED}Error${POSIXCUBE_COLOR_RESET}: ${cube_error_printf_str}\n" "${@}" 1>&2
  fi
}

# Description:
#   Print $1 and a stack of functions and processes (if available) with
#   cube_error_echo and then call `exit 1`.
# Example call:
#   cube_throw "Expected some_file to exist."
# Arguments: ${@} passed to cube_error_echo
cube_throw() {
  cube_error_echo "${@}"
  
  cube_throw_pid=$$
  
  if cube_command_exists caller || [ -r /proc/${cube_throw_pid}/cmdline ]; then
    cube_error_echo Stack:
  fi
  
  if cube_command_exists caller ; then
    x=0
    while true; do
      cube_error_caller=$(caller $x)
      cube_error_caller_result=${?}
      if [ ${cube_error_caller_result} -eq 0 ]; then
        cube_error_caller_result_lineno=$(echo "${cube_error_caller}" | awk '{ print $1 }')
        cube_error_caller_result_subroutine=$(echo "${cube_error_caller}" | awk '{ print $2 }')
        cube_error_caller_result_sourcefile=$(echo "${cube_error_caller}" | awk '{ for(i=3;i<=NF;i++){ printf "%s ", $i }; printf "\n" }' | sed 's/ $//')
        cube_error_printf "  [func] %4s ${cube_error_caller_result_subroutine} ${cube_error_caller_result_sourcefile}" "${cube_error_caller_result_lineno}"
      else
        break
      fi
      x=$((${x}+1))
    done
  fi
  
  # http://stackoverflow.com/a/1438241/5657303
  if [ -r /proc/${cube_throw_pid}/cmdline ]; then
    while true
    do
      cube_throw_cmdline=$(cat /proc/${cube_throw_pid}/cmdline)
      cube_throw_ppid=$(grep PPid /proc/${cube_throw_pid}/status | awk '{ print $2; }')
      cube_error_printf "  [pid] %5s ${cube_throw_cmdline}" ${cube_throw_pid}
      if [ "${cube_throw_pid}" = "1" ]; then # init
        break
      fi
      cube_throw_pid=${cube_throw_ppid}
    done
  fi
  
  exit 1
}

# Description:
#   Skipping any call stack frames in posixcube.sh, return the line number of the calling stack frame
# Example call:
#   cube_line_number
# Arguments:
#   Optional:
#     $1: If a result is returned, prepend with $1
cube_line_number() {
  if cube_command_exists caller ; then
    x=0
    while true; do
      cube_api_caller_output=$(caller $x)
      cube_api_caller_result=${?}
      if [ ${cube_api_caller_result} -eq 0 ]; then
        cube_api_caller_result_lineno=$(echo "${cube_api_caller_output}" | awk '{ print $1 }')
        cube_api_caller_result_subroutine=$(echo "${cube_api_caller_output}" | awk '{ print $2 }')
        cube_api_caller_result_sourcefile=$(echo "${cube_api_caller_output}" | awk '{ for(i=3;i<=NF;i++){ printf "%s ", $i }; printf "\n" }' | sed 's/ $//')
        cube_api_caller_result_sourcefile_basename=$(basename "${cube_api_caller_result_sourcefile}")
        if [ "${cube_api_caller_result_sourcefile_basename}" != "posixcube.sh" ]; then
          if [ "${1}" != "" ]; then
            printf "%s" "${1}"
          fi
          printf "%s" "${cube_api_caller_result_lineno}"
          break
        fi
      else
        break
      fi
      x=$((${x}+1))
    done
  fi
}

# Description:
#   Check if $? is non-zero and call cube_throw if so.
# Example call:
#   some_command || cube_check_return
# Arguments: None
cube_check_return() {
  cube_check_return_val=${?}
  if [ ${cube_check_return_val} -ne 0 ]; then
    cube_check_return_info=""
    if [ "${*}" != "" ]; then
      cube_check_return_info=" (${*})"
    fi
    cube_throw "Previous command failed with code ${cube_check_return_val}${cube_check_return_info}"
  fi
  return ${cube_check_return_val}
}

# Description:
#   Echo $1 with $2 appended after a space if $1 was not blank.
# Example call:
#   cubevar_app_str=$(cube_append_str "${cubevar_app_str}" "Test")
# Arguments:
#   Required:
#     $1: Original string
#     $2: Strings to append
#   Optional:
#     $3: Delimeter
cube_append_str() {
  cube_check_numargs 1 "${@}"
  
  if [ "${1}" = "" ]; then
    echo "${2}"
  else
    if [ "${3}" = "" ]; then
      echo "${1} ${2}"
    else
      echo "${1}${3}${2}"
    fi
  fi
}

# Description:
#   Check if $1 command or function exists in the current context.
# Example call:
#   cube_command_exists systemctl
# Arguments:
#   Required:
#     $1: Command or function name.
cube_command_exists() {
  cube_check_numargs 1 "${@}"
  command -v ${1} >/dev/null 2>&1
}

# Description:
#   Check if $1 exists as a directory.
# Example call:
#   cube_dir_exists /etc/cron.d/
# Arguments:
#   Required:
#     $1: Directory name.
cube_dir_exists() {
  cube_check_numargs 1 "${@}"
  [ -d "${1}" ]
}

# Description:
#   Check if $1 exists as a file with read access.
# Example call:
#   cube_file_exists /etc/cron.d/0hourly
# Arguments:
#   Required:
#     $1: File name.
cube_file_exists() {
  cube_check_numargs 1 "${@}"
  [ -r "${1}" ]
}

# Description:
#   Detect operating system and return one of the POSIXCUBE_OS_* values.
# Example call:
#   if [ $(cube_operating_system) -eq ${POSIXCUBE_OS_LINUX} ]; then ...
# Arguments: None
cube_operating_system() {
  # http://stackoverflow.com/a/27776822/5657303
  case "$(uname -s)" in
    Linux)
      echo ${POSIXCUBE_OS_LINUX}
      ;;
    Darwin)
      echo ${POSIXCUBE_OS_MAC_OSX}
      ;;
    CYGWIN*|MINGW32*|MSYS*)
      echo ${POSIXCUBE_OS_WINDOWS}
      ;;
    *)
      echo ${POSIXCUBE_OS_UNKNOWN}
      ;;
  esac
}

# Description:
#   Check if the operating system flavor includes the flavor specified in $1 by one of the POSIXCUBE_OS_FLAVOR_* values.
# Example call:
#   if cube_operating_system_has_flavor ${POSIXCUBE_OS_FLAVOR_FEDORA} ; then ...
# Arguments:
#   Required:
#     $1: One of the POSIXCUBE_OS_FLAVOR_* values.
cube_operating_system_has_flavor() {
  cube_check_numargs 1 "${@}"
  case "${1}" in
    ${POSIXCUBE_OS_FLAVOR_FEDORA})
      if cube_file_exists "/etc/fedora-release"; then
        return 0
      fi
      ;;
    ${POSIXCUBE_OS_FLAVOR_UBUNTU})
      if cube_file_exists "/etc/lsb-release"; then
        return 0
      fi
      ;;
    ${POSIXCUBE_OS_FLAVOR_DEBIAN})
      if cube_file_contains /etc/os-release "NAME=\"Debian" || cube_file_exists "/etc/lsb-release"; then
        return 0
      fi
      ;;
    *)
      cube_throw "Unknown flavor ${1}"
      ;;
  esac
  return 1
}

# Description:
#   Detect current shell and return one of the CUBE_SHELL_* values.
# Example call:
#   if [ $(cube_shell) -eq ${POSIXCUBE_SHELL_BASH} ]; then ...
# Arguments: None
cube_shell() {
  # http://stackoverflow.com/questions/3327013/how-to-determine-the-current-shell-im-working-on
  if [ "$BASH" != "" ]; then
    echo ${POSIXCUBE_SHELL_BASH}
  else
    echo ${POSIXCUBE_SHELL_UNKNOWN}
  fi
}

# Description:
#   Throw an error if there are fewer than $1 arguments.
# Example call:
#   cube_check_numargs 2 "${@}"
# Arguments:
#   Required:
#     $1: String to print (printf-compatible)
#     $@: Arguments to check
cube_check_numargs() {
  cube_check_numargs_expected=$1; shift
  [ ${#} -lt ${cube_check_numargs_expected} ] && cube_throw "Expected ${cube_check_numargs_expected} arguments, received ${#}."
  return 0
}

# Description:
#   Run the $1 action on the $2 service.
# Example call:
#   cube_service start crond
# Arguments:
#   Required:
#     $1: Action name supported by $2 (e.g. start, stop, restart, enable, etc.)
#     $2: Service name.
cube_service() {
  cube_check_numargs 1 "${@}"
  if cube_command_exists systemctl ; then
    if [ "${1}" = "daemon-reload" ]; then
      systemctl $1 || cube_check_return
    else
      systemctl $1 $2 || cube_check_return
    fi
  elif cube_command_exists service ; then
    if [ "${1}" != "daemon-reload" ]; then
      service $2 $1 || cube_check_return
    fi
  else
    cube_throw "Could not find service program"
  fi
  if [ "${2}" != "" ]; then
    case "${1}" in
      stop)
        cube_service_verb="stopped"
        ;;
      enable|disable)
        cube_service_verb="${1}d"
        ;;
      *)
        cube_service_verb="${1}ed"
        ;;
    esac
    cube_echo "$(echo ${cube_service_verb} | cut -c1 | tr [a-z] [A-Z])$(echo ${cube_service_verb} | cut -c2-) $2 service"
  else
    cube_echo "Executed $1"
  fi
}

# Description:
#   Return 0 if service $1 exists; otherwise, 1
# Example call:
#   cube_service_exists kdump
# Arguments:
#   Required:
#     $1: Service name.
cube_service_exists() {
  cube_check_numargs 1 "${@}"
  if cube_command_exists systemctl ; then
    cube_service_exists_output="$(systemctl status ${1} 2>&1)"
    echo "${cube_service_exists_output}" | grep -l loaded >/dev/null 2>&1
    return $?
  else
    cube_throw "Not implemented"
  fi
}

# Description:
#   Pass $@ to the package manager. Implicitly passes the the parameter
#   to say yes to questions.
# Example call:
#   cube_package install python
# Arguments:
#   Required:
#     $@: Arguments to the package manager.
cube_package() {
  cube_check_numargs 1 "${@}"
  
  if cube_command_exists dnf ; then
    cube_echo "Executing dnf -y ${@}"
    dnf -y "${@}" || cube_check_return
  elif cube_command_exists yum ; then
    cube_echo "Executing yum -y ${@}"
    yum -y "${@}" || cube_check_return
  elif cube_command_exists apt-get ; then
    cube_echo "Executing apt-get -y ${@}"
    # -o Dpkg::Options::="--force-confnew"
    DEBIAN_FRONTEND=noninteractive apt-get -y "${@}" || cube_check_return
  else
    cube_throw "cube_package has not implemented your operating system yet"
  fi
}

# Description:
#   echo the basename of the currently executing script.
# Example call:
#   script_name=$(cube_current_script_name)
# Arguments: None
cube_current_script_name() {
  basename "$0"
}

# Description:
#   echo the absolute path the currently executing script.
# Example call:
#   script_abspath=$(cube_current_script_abs_path)
# Arguments: None
cube_current_script_abs_path() {
  cube_current_script_abs_path_dirname=$( cd "$(dirname "$0")" ; pwd -P )
  echo "${cube_current_script_abs_path_dirname}/$(cube_current_script_name)"
}

# Description:
#   echo the size of a file $1 in bytes
# Example call:
#   cube_file_size some_file
# Arguments:
#   Required:
#     $1: File
cube_file_size() {
  cube_check_numargs 1 "${@}"
  if cube_file_exists "${1}" ; then
    wc -c < "${1}"
  else
    cube_throw "Could not find or read file ${1}"
  fi
}

# Description:
#   echo stdin to stdout with all ${VAR}'s evaluated (except for \${VAR})
# Example call:
#   cube_expand_parameters < template > output
# Arguments: None
cube_expand_parameters() {
  # http://stackoverflow.com/a/40167919/5657303
  
  cube_expand_parameters_is_bash=0
  if [ $(cube_shell) -eq ${POSIXCUBE_SHELL_BASH} ]; then
    # No win from using regex in parameter expansion because we can't use backreferences to make sure we don't
    # unescape
    cube_expand_parameters_is_bash=0
    #cube_expand_parameters_is_bash=1
  fi
  
  # the `||` clause ensures that the last line is read even if it doesn't end with \n
  while IFS='' read -r cube_expand_parameters_line || [ -n "${cube_expand_parameters_line}" ]; do
    # Escape any characters that might trip up eval
    cube_expand_parameters_line_escaped=$(printf %s "${cube_expand_parameters_line}" | tr '`([$\\"' '\1\2\3\4\5\6')
    
    # Then re-enable un-escaped ${ references
    if [ $cube_expand_parameters_is_bash -eq 1 ]; then
      cube_expand_parameters_line_escaped=${cube_expand_parameters_line_escaped//$'\4'{/\${}
    else
      cube_expand_parameters_line_escaped=$(printf %s "${cube_expand_parameters_line_escaped}" | sed 's/\([^\x05]\)\x04{/\1${/g' | sed 's/^\x04{/${/g')
    fi
    
    cube_expand_parameters_output=$(eval "printf '%s\n' \"${cube_expand_parameters_line_escaped}\"") || cube_check_return "${cube_expand_parameters_line_escaped}"
    
    echo "${cube_expand_parameters_output}" | tr '\1\2\3\4\5\6' '`([$\\"'
  done
}

# Description:
#   Read stdin into ${cube_read_heredoc_result}
# Example call:
#   cube_read_heredoc <<'HEREDOC'; cubevar_app_str="${cube_read_heredoc_result}"
#     `([$\{\
#   HEREDOC
# Arguments: None
cube_read_heredoc() {
  cube_read_heredoc_first=1
  cube_read_heredoc_result=""
  while IFS='\n' read -r cube_read_heredoc_line; do
    if [ ${cube_read_heredoc_first} -eq 1 ]; then
      cube_read_heredoc_result="${cube_read_heredoc_line}"
      cube_read_heredoc_first=0
    else
      cube_read_heredoc_result="${cube_read_heredoc_result}${POSIXCUBE_NEWLINE}${cube_read_heredoc_line}"
    fi
  done
}

# Description:
#   Copy the contents of $2 on top of $1 if $1 doesn't exist or the contents
#   are different than $2. If $2 ends with ".template" then first process
#   the file with `cube_expand_parameters`.
# Example call:
#   cube_set_file_contents "/etc/npt.conf" "templates/ntp.conf"
# Arguments:
#   Required:
#     $1: Target file
#     $2: Source file
# Returns: success/true if the file was updated
cube_set_file_contents() {
  cube_check_numargs 2 "${@}"
  cube_set_file_contents_target_file="$1"; shift
  cube_set_file_contents_input_file="$1"; shift

  cube_set_file_contents_debug="${cube_set_file_contents_input_file}"
  
  cube_set_file_contents_needs_replace=0
  cube_set_file_contents_input_file_needs_remove=0
  
  if ! cube_file_exists "${cube_set_file_contents_input_file}" ; then
    cube_throw "Could not find or read input ${cube_set_file_contents_input_file}"
  fi
  
  cube_ensure_directory "$(dirname "${cube_set_file_contents_target_file}")"
  
  cube_set_file_contents_input_file_is_template=$(expr "${cube_set_file_contents_input_file}" : '.*\.template$')
  if [ ${cube_set_file_contents_input_file_is_template} -ne 0 ]; then
    
    cube_set_file_contents_input_file_original="${cube_set_file_contents_input_file}"
    cube_set_file_contents_input_file="${cube_set_file_contents_input_file}.tmp"

    # Parameter expansion can introduce very large delays with large files, so point that out
    #if [ ${POSIXCUBE_DEBUG} -eq 1 ]; then
      cube_echo "Expanding parameters of ${cube_set_file_contents_input_file_original}"
    #fi
    
    # awk, perl, sed, envsubst, etc. can do this easily but would require exported envars
    # perl -pe 's/([^\\]|^)\$\{([a-zA-Z_][a-zA-Z_0-9]*)\}/$1.$ENV{$2}/eg' < "${cube_set_file_contents_input_file_original}" > "${cube_set_file_contents_input_file}" || cube_check_return
    # http://stackoverflow.com/questions/415677/how-to-replace-placeholders-in-a-text-file
    # http://stackoverflow.com/questions/2914220/bash-templating-how-to-build-configuration-files-from-templates-with-bash
    cube_expand_parameters < "${cube_set_file_contents_input_file_original}" > "${cube_set_file_contents_input_file}" || cube_check_return
    
    #if [ ${POSIXCUBE_DEBUG} -eq 1 ]; then
      cube_echo "Expansion complete"
    #fi
    
    cube_set_file_contents_input_file_needs_remove=1
  fi
  
  if cube_file_exists "${cube_set_file_contents_target_file}" ; then
  
    # If the file sizes are different, then replace the file (http://stackoverflow.com/a/5920355/5657303)
    cube_set_file_contents_target_file_size=$(cube_file_size "${cube_set_file_contents_target_file}")
    cube_set_file_contents_input_file_size=$(cube_file_size "${cube_set_file_contents_input_file}")
    
    if [ ${POSIXCUBE_DEBUG} -eq 1 ]; then
      cube_echo "Target file ${cube_set_file_contents_target_file} exists. Target size: ${cube_set_file_contents_target_file_size}, source size: ${cube_set_file_contents_input_file_size}"
    fi
    
    if [ ${cube_set_file_contents_target_file_size} -eq ${cube_set_file_contents_input_file_size} ]; then

      # Sizes are equal, so do a quick cksum
      cube_set_file_contents_target_file_cksum=$(cksum "${cube_set_file_contents_target_file}" | awk '{print $1}')
      cube_set_file_contents_input_file_cksum=$(cksum "${cube_set_file_contents_input_file}" | awk '{print $1}')

      if [ ${POSIXCUBE_DEBUG} -eq 1 ]; then
        cube_echo "Target cksum: ${cube_set_file_contents_target_file_cksum}, source cksum: ${cube_set_file_contents_input_file_cksum}"
      fi
      
      if [ "${cube_set_file_contents_target_file_cksum}" != "${cube_set_file_contents_input_file_cksum}" ]; then
        cube_set_file_contents_needs_replace=1
      fi
    else
      cube_set_file_contents_needs_replace=1
    fi
  else
    cube_set_file_contents_needs_replace=1
  fi

  if [ ${cube_set_file_contents_needs_replace} -eq 1 ] ; then
    cube_echo "Updating file contents of ${cube_set_file_contents_target_file} with ${cube_set_file_contents_debug}"
    cp "${cube_set_file_contents_input_file}" "${cube_set_file_contents_target_file}" || cube_check_return
    if [ ${cube_set_file_contents_input_file_needs_remove} -eq 1 ] ; then
      rm -f "${cube_set_file_contents_input_file}" || cube_check_return
    fi
    return 0
  else
    if [ ${cube_set_file_contents_input_file_needs_remove} -eq 1 ] ; then
      rm -f "${cube_set_file_contents_input_file}" || cube_check_return
    fi
    return 1
  fi
}

# Description:
#   Echo a random number between 1 and $1
# Example call:
#   cube_random_number 10
# Arguments:
#   Required:
#     $1: Maximum value
cube_random_number() {
  cube_check_numargs 1 "${@}"
  echo "" | awk "{ srand(); print int(${1} * rand()) + 1; }"
}

# Description:
#   Echo a temporary directory
# Example call:
#   cube_tmpdir
# Arguments: None
cube_tmpdir() {
  echo "/tmp/"
}

# Description:
#   Set the contents of $1 to the string $@. Create file if it doesn't exist.
# Example call:
#   cube_set_file_contents_string ~/.info "Hello World"
# Arguments:
#   Required:
#     $1: Target file
#     $@: String contents
# Returns: success/true if the file was updated
cube_set_file_contents_string() {
  cube_check_numargs 2 "${@}"
  cube_set_file_contents_target_file="$1"; shift
  
  cube_set_file_contents_tmp="$(cube_tmpdir)/tmpcontents_$(cube_random_number 10000).template"
  echo "${@}" > "${cube_set_file_contents_tmp}"
  cube_set_file_contents "${cube_set_file_contents_target_file}" "${cube_set_file_contents_tmp}" "from string"
  cube_set_file_contents_result=$?
  rm "${cube_set_file_contents_tmp}"
  return ${cube_set_file_contents_result}
}

# Description:
#   Echo the absolute path of $1 without any symbolic links.
# Example call:
#   cube_readlink /etc/localtime
# Arguments:
#   Required:
#     $1: File
cube_readlink() {
  cube_check_numargs 1 "${@}"

  # http://stackoverflow.com/a/697552/5657303
  # Don't bother trying to short-circuit with readlink because of issues on
  # Mac. We could special case that, but meh.
  #if cube_command_exists readlink ; then
  #  readlink -f $1
  #else
    cube_readlink_target=$1
    cube_readlink_path=$(cd -P -- "$(dirname -- "${cube_readlink_target}")" && pwd -P) && cube_readlink_path=${cube_readlink_path}/$(basename -- "${cube_readlink_target}")
    
    while [ -h "${cube_readlink_path}" ]; do
      cube_readlink_dir=$(dirname -- "${cube_readlink_path}")
      cube_readlink_sym=$(readlink "${cube_readlink_path}")
      cube_readlink_path=$(cd "${cube_readlink_dir}" && cd "$(dirname -- "${cube_readlink_sym}")" && pwd)/$(basename -- "${cube_readlink_sym}")
    done
    
    echo ${cube_readlink_path}
  #fi
}

# Description:
#   Echo total system memory in bytes
# Example call:
#   cube_total_memory
# Arguments:
#   Optional:
#     #1: [kb|mb|gb| to return in that number
cube_total_memory() {
  case "${1}" in
    kb|KB)
      cube_total_memory_divisor=1024
      ;;
    mb|MB)
      cube_total_memory_divisor=1048576
      ;;
    gb|GB)
      cube_total_memory_divisor=1073741824
      ;;
    *)
      cube_total_memory_divisor=1
      ;;
  esac
  echo $((($(grep "^MemTotal:" /proc/meminfo | awk '{print $2}')*1024)/${cube_total_memory_divisor}))
}

# Description:
#   Ensure directory $1 exists
# Example call:
#   cube_ensure_directory ~/.ssh/
# Arguments:
#   Requires;
#     $1: Directory name
#   Optional:
#     $2: Permissions (passed to chmod)
#     $3: Owner (passed to chown)
#     $4: Group (passed to chgrp)
cube_ensure_directory() {
  cube_check_numargs 1 "${@}"
  cube_ensure_directory_result=1
  
  if ! cube_dir_exists "${1}"; then
    mkdir -p "${1}" || cube_check_return
    cube_ensure_directory_result=0
    cube_echo "Created directory ${1}"
  fi
  if [ "${2}" != "" ]; then
    chmod ${2} "${1}" || cube_check_return
  fi
  if [ "${3}" != "" ]; then
    chown ${3} "${1}" || cube_check_return
  fi
  if [ "${4}" != "" ]; then
    chgrp ${4} "${1}" || cube_check_return
  fi
  
  return ${cube_ensure_directory_result}
}

# Description:
#   Ensure file $1 exists
# Example call:
#   cube_ensure_file ~/.ssh/authorized_keys
# Arguments:
#   Requires;
#     $1: File name
#   Optional:
#     $2: Permissions (passed to chmod)
#     $3: Owner (passed to chown)
#     $4: Group (passed to chgrp)
cube_ensure_file() {
  cube_check_numargs 1 "${@}"
  cube_ensure_file_result=1
  
  if ! cube_file_exists "${1}"; then
  
    cube_ensure_directory "$(dirname "${1}")" $2 $3 $4
  
    touch "${1}" || cube_check_return
    cube_ensure_file_result=0
    cube_echo "Created file ${1}"
  fi
  if [ "${2}" != "" ]; then
    chmod ${2} "${1}" || cube_check_return
  fi
  if [ "${3}" != "" ]; then
    chown ${3} "${1}" || cube_check_return
  fi
  if [ "${4}" != "" ]; then
    chgrp ${4} "${1}" || cube_check_return
  fi

  return ${cube_ensure_file_result}
}

# Description:
#   Equivalent to `pushd` with $1
# Example call:
#   cube_pushd ~/.ssh/
# Arguments:
#   Requires;
#     $1: Directory
cube_pushd() {
  cube_check_numargs 1 "${@}"
  
  if cube_command_exists pushd ; then
    pushd "${@}" || cube_check_return
  else
    cube_throw "TODO: Not implemented"
  fi
}

# Description:
#   Equivalent to `popd`
# Example call:
#   cube_popd
# Arguments: None
cube_popd() {
  if cube_command_exists popd ; then
    popd "${@}" || cube_check_return
  else
    cube_throw "TODO: Not implemented"
  fi
}

# Description:
#   Return true if the role $1 is set.
# Example call:
#   cube_has_role "database_backup"
# Arguments:
#   Requires;
#     $1: Role name
cube_has_role() {
  cube_check_numargs 1 "${@}"
  
  for cube_has_role_name in ${cubevar_api_roles}; do
    if [ "${cube_has_role_name}" = "${1}" ]; then
      return 0
    fi
  done
  return 1
}

# Description:
#   Check if the file $1 contains $2
# Example call:
#   cube_file_contains /etc/fstab nfsmount
# Arguments:
#   Required:
#     $1: File name.
#     $2: Case sensitive search string
cube_file_contains() {
  cube_check_numargs 2 "${@}"
  
  # "Normally the exit status is 0 if a line is selected, 1 if no lines were selected, and 2 if an error occurred."
  cube_file_contains_grep_output="$(grep -l "${2}" "${1}")"
  cube_file_contains_grep_results=$?
  
  if [ ${cube_file_contains_grep_results} -eq 2 ]; then
    cube_throw "${cube_file_contains_grep_output}"
  else
    return ${cube_file_contains_grep_results}
  fi
}

# Description:
#   Check if stdin contains $1
# Example call:
#   echo "Hello World" | cube_stdin_contains "Hello"
# Arguments:
#   Required:
#     $1: Search
cube_stdin_contains() {
  cube_check_numargs 1 "${@}"
  cube_stdin_contains_output=$(grep -l "${1}" -)
  cube_stdin_contains_result=$?
  if [ ${cube_stdin_contains_result} -eq 2 ]; then
    cube_throw "${cube_stdin_contains_output}"
  else
    return ${cube_stdin_contains_result}
  fi
}

# Description:
#   Echo the IPv4 address of interface $1
# Example call:
#   cube_interface_ipv4_address eth0
# Arguments:
#   Required:
#     $1: Interface name
cube_interface_ipv4_address() {
  cube_check_numargs 1 "${@}"
  ip -4 -o address show dev ${1} | head -1 | awk '{print $4}' | sed 's/\/.*$//g' || cube_check_return
}

# Description:
#   Echo the IPv6 address of interface $1
# Example call:
#   cube_interface_ipv6_address eth0
# Arguments:
#   Required:
#     $1: Interface name
cube_interface_ipv6_address() {
  cube_check_numargs 1 "${@}"
  ip -6 -o address show dev ${1} | head -1 | awk '{print $4}' | sed 's/\/.*$//g' || cube_check_return
}

# Description:
#   Prompt the question $1 followed by " (y/N)" and prompt for an answer.
#   A blank string answer is equivalent to No. Return true if yes, false otherwise.
# Example call:
#   cube_prompt "Are you sure?"
# Arguments:
#   Required:
#     $1: Prompt test
cube_prompt() {
  cube_check_numargs 1 "${@}"
  while true; do
    printf "${1} (y/N)? "
    read cube_prompt_response || cube_check_return
    case "${cube_prompt_response}" in
      [Yy]*)
        return 0
        ;;
      ""|[Nn]*)
        return 1
        ;;
      *)
        echo "Please answer yes or no."
        ;;
    esac
  done
}

# Description:
#   Echo full hostname.
# Example call:
#   cube_hostname
# Arguments:
#   Optional:
#     $1: Pass true to return a hostname devoid of any domain.
cube_hostname() {
  if [ "${1}" = "" ]; then
    uname -n || cube_check_return
  else
    uname -n | sed 's/\..*$//g' || cube_check_return
  fi
}

# Description:
#   Check if the $1 user exists
# Example call:
#   cube_user_exists nginx
# Arguments:
#   Required:
#     $1: User name
cube_user_exists() {
  cube_check_numargs 1 "${@}"
  id -u "${1}" >/dev/null 2>&1
  return $?
}

# Description:
#   Create the user $1
# Example call:
#   cube_create_user nginx
# Arguments:
#   Required:
#     $1: User name
#   Optional:
#     $2: Shell
cube_create_user() {
  cube_check_numargs 1 "${@}"
  
  useradd "${1}" || cube_check_return
  
  if [ "${2}" != "" ]; then
    usermod -s "${2}" "${1}" || cube_check_return
  fi
}

# Description:
#   Check if the $1 group exists
# Example call:
#   cube_group_exists nginx
# Arguments:
#   Required:
#     $1: Group name
cube_group_exists() {
  cube_check_numargs 1 "${@}"
  cube_file_contains /etc/group "^${1}:"
}

# Description:
#   Create the group $1
# Example call:
#   cube_create_group nginx
# Arguments:
#   Required:
#     $1: Group name
cube_create_group() {
  cube_check_numargs 1 "${@}"
  
  groupadd "${1}" || cube_check_return
}

# Description:
#   Check if the $1 group contains the user $2
# Example call:
#   cube_group_contains_user nginx nginx
# Arguments:
#   Required:
#     $1: Group name
#     $2: User name
cube_group_contains_user() {
  cube_check_numargs 2 "${@}"
  
  for cube_group_contains_user in $(groups "${2}" | sed "s/${2} : //g"); do
    if [ "${cube_group_contains_user}" = "${1}" ]; then
      return 0
    fi
  done
  return 1
}

# Description:
#   Add the user $2 to group $1
# Example call:
#   cube_add_group_user nginx nginx
# Arguments:
#   Required:
#     $1: Group name
#     $2: User name
#   Optional:
#     $3: true if group is primary
cube_add_group_user() {
  cube_check_numargs 2 "${@}"
  
  if [ "${3}" = "" ]; then
    usermod -a -G "${1}" "${2}"
  else
    usermod -g "${1}" "${2}"
  fi
}

# Description:
#   Include the ${1} cube
# Example call:
#   cube_include core_cube
# Arguments:
#   Required:
#     $1: CUBE name
cube_include() {
  cube_check_numargs 1 "${@}"
  
  cube_include_name="${1%%/}"
  if [ -d "../${cube_include_name}" ]; then
    cube_include_name_base=$(basename "${cube_include_name}" .sh)
    if [ -r "../${cube_include_name}/${cube_include_name_base}.sh" ]; then
      cube_echo "Including ${cube_include_name} cube..."
      . "../${cube_include_name}/${cube_include_name_base}.sh"
    else
      cube_throw "Cannot read ${cube_include_name}/${cube_include_name_base}.sh"
    fi
  elif [ -r "../${cube_include_name}" ]; then
    cube_echo "Including ${cube_include_name} cube..."
    . "../${cube_include_name}"
  elif [ -r "${cube_include_name}.sh" ]; then
    cube_echo "Including ${cube_include_name} cube..."
    . "../${cube_include_name}.sh"
  else
    cube_throw "Cube ${cube_include_name} not found (did you upload it with -i ${cube_include_name} ?)."
  fi
}

# Append space-delimited service names to this variable to restart services after all CUBEs and COMMANDs
cubevar_api_post_restart=""

cubevar_api_roles=""

###################
# End Public APIs #
###################

################################
# Core internal implementation #
################################

# If we're being sourced on the remote machine, then we don't want to run any of the below
if [ "${POSIXCUBE_APIS_ONLY}" = "" ]; then
  p666_debug=0
  p666_quiet=0
  p666_skip_init=0
  p666_keep_exec=0
  p666_skip_host_errors=0
  p666_hosts=""
  p666_cubes=""
  p666_include_cubes=""
  p666_envar_scripts=""
  p666_envar_scripts_password=""
  p666_user="${USER}"
  p666_cubedir="~/posixcubes/"
  p666_roles=""
  p666_options=""
  p666_specfile="./cubespecs.ini"
  p666_parallel=0
  p666_async_cubes=0
  p666_default_envars="envars*sh envars*sh.enc"
  
  if [ $(cube_shell) -eq ${POSIXCUBE_SHELL_BASH} ]; then
    p666_parallel=64
  fi

  p666_show_version() {
    p666_printf "posixcube.sh version ${POSIXCUBE_VERSION}\n"
  }

  p666_printf() {
    p666_printf_str=$1
    shift
    printf "[$(date)] ${p666_printf_str}" "${@}"
  }

  p666_printf_error() {
    p666_printf_str=$1
    shift
    printf "\n[$(date)] ${POSIXCUBE_COLOR_RED}Error${POSIXCUBE_COLOR_RESET}: ${p666_printf_str}\n\n" "${@}" 1>&2
  }
  
  p666_exit() {
    for p666_envar_script in ${p666_envar_scripts}; do
      p666_envar_script_enc_matches=$(expr ${p666_envar_script} : '.*\.dec$')
      if [ ${p666_envar_script_enc_matches} -ne 0 ]; then
        # If multiple posixcube.sh executions run at the same time, then one of them might
        # delete the decryption file, but that's okay
        rm "${p666_envar_script}" 2>/dev/null
      fi
    done

    [ ${p666_keep_exec} -eq 0 ] && rm -f "${p666_script}" 2>/dev/null
    
    exit ${1}
  }

  p666_install() {
    p666_func_result=0
    if [ -d "/etc/bash_completion.d/" ]; then
      p666_autocomplete_file=/etc/bash_completion.d/posixcube_completion.sh
      
      # Autocomplete Hostnames for SSH etc.
      # by Jean-Sebastien Morisset (http://surniaulula.com/)
      
      cat <<'HEREDOC' | tee ${p666_autocomplete_file} > /dev/null
_posixcube_complete() {
  COMPREPLY=()
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD-1]}"
  case "${prev}" in
    \-h)
      p666_host_list=$({ 
        for c in /etc/ssh_config /etc/ssh/ssh_config ~/.ssh/config
        do [ -r $c ] && sed -n -e 's/^Host[[:space:]]//p' -e 's/^[[:space:]]*HostName[[:space:]]//p' $c
        done
        for k in /etc/ssh_known_hosts /etc/ssh/ssh_known_hosts ~/.ssh/known_hosts
        do [ -r $k ] && egrep -v '^[#\[]' $k|cut -f 1 -d ' '|sed -e 's/[,:].*//g'
        done
        sed -n -e 's/^[0-9][0-9\.]*//p' /etc/hosts; }|tr ' ' '\n'|grep -v '*')
      COMPREPLY=( $(compgen -W "${p666_host_list}" -- $cur))
      ;;
    \-z)
      p666_complete_specs="$(sed 's/=.*//g' cubespecs.ini)"
      COMPREPLY=( $(compgen -W "${p666_complete_specs}" -- $cur))
      ;;
    *)
      ;;
  esac
  return 0
}
complete -o default -F _posixcube_complete posixcube.sh
HEREDOC

      p666_func_result=$?
      if [ ${p666_func_result} -eq 0 ]; then
        chmod +x ${p666_autocomplete_file}
        p666_func_result=$?
        if [ ${p666_func_result} -eq 0 ]; then
          . ${p666_autocomplete_file}
          p666_func_result=$?
          if [ ${p666_func_result} -eq 0 ]; then
            p666_printf "Installed Bash programmable completion script into ${p666_autocomplete_file}\n"
          else
            p666_printf "Could not execute ${p666_autocomplete_file}\n"
          fi
        else
          p666_printf "Could not chmod +x ${p666_autocomplete_file}\n"
        fi
      else
        p666_printf "Could not create ${p666_autocomplete_file}\n"
        p666_printf "You may need to try with sudo. For example:\n"
        p666_printf "  sudo $(cube_current_script_abs_path) -b && . ${p666_autocomplete_file}\n"
        p666_printf "You only need to source the command the first time. Subsequent shells will automatically source it.\n"
      fi
    else
      p666_printf "No directory /etc/bash_completion.d/ found, skipping Bash programmable completion installation.\n"
    fi
    exit ${p666_func_result}
  }

  p666_all_hosts=""

  p666_process_hostname() {
    p666_hostname_wildcard=$(expr "${1}" : '.*\*.*')
    if [ ${p666_hostname_wildcard} -ne 0 ]; then
    
      # Use or create cache of hosts
      if [ "${p666_all_hosts}" = "" ]; then
        p666_all_hosts=$({ 
          for c in /etc/ssh_config /etc/ssh/ssh_config ~/.ssh/config
          do [ -r $c ] && sed -n -e 's/^Host[[:space:]]//p' -e 's/^[[:space:]]*HostName[[:space:]]//p' $c
          done
          for k in /etc/ssh_known_hosts /etc/ssh/ssh_known_hosts ~/.ssh/known_hosts
          do [ -r $k ] && egrep -v '^[#\[]' $k|cut -f 1 -d ' '|sed -e 's/[,:].*//g'
          done
          sed -n -e 's/^[0-9][0-9\.]*//p' /etc/hosts; }|tr '\n' ' '|grep -v '*')
      fi
      
      p666_process_hostname_search=$(printf "${1}" | sed 's/\*/\.\*/g')
      
      p666_process_hostname_list=""
      for p666_all_host in ${p666_all_hosts}; do
        p666_all_host_match=$(expr ${p666_all_host} : ${p666_process_hostname_search})
        if [ ${p666_all_host_match} -ne 0 ]; then
          p666_process_hostname_list=$(cube_append_str "${p666_process_hostname_list}" "${p666_all_host}")
        fi
      done
      echo "${p666_process_hostname_list}"
    else
      echo "${1}"
    fi
  }
  
  p666_process_options() {
    # getopts processing based on http://stackoverflow.com/a/14203146/5657303
    OPTIND=1 # Reset in case getopts has been used previously in the shell.
    
    while getopts "?vdqbskyah:u:c:e:p:w:r:o:z:i:" p666_opt "${@}"; do
      case "$p666_opt" in
      \?)
        p666_show_usage
        ;;
      v)
        p666_show_version
        exit 1
        ;;
      d)
        p666_debug=1
        ;;
      q)
        p666_quiet=1
        ;;
      s)
        p666_skip_init=1
        ;;
      k)
        p666_keep_exec=1
        ;;
      y)
        p666_skip_host_errors=1
        ;;
      a)
        p666_async_cubes=1
        ;;
      b)
        p666_install
        ;;
      h)
        p666_processed_hostname=$(p666_process_hostname "${OPTARG}")
        if [ "${p666_processed_hostname}" != "" ]; then
          p666_hosts=$(cube_append_str "${p666_hosts}" "${p666_processed_hostname}")
        else
          p666_printf_error "No known hosts match ${OPTARG} from ${p666_all_hosts}"
          exit 1
        fi
        ;;
      c)
        p666_cubes=$(cube_append_str "${p666_cubes}" "${OPTARG}")
        ;;
      i)
        p666_include_cubes=$(cube_append_str "${p666_include_cubes}" "${OPTARG}")
        ;;
      e)
        if [ ! -r "${OPTARG}" ]; then
          p666_printf_error "Could not find ${OPTARG} ENVAR script."
          exit 1
        fi
        p666_envar_scripts=$(cube_append_str "${p666_envar_scripts}" "${OPTARG}")
        ;;
      u)
        p666_user="${OPTARG}"
        ;;
      p)
        p666_envar_scripts_password="${OPTARG}"
        ;;
      w)
        p666_envar_scripts_password="$(cat ${OPTARG})" || cube_check_return
        ;;
      r)
        p666_roles=$(cube_append_str "${p666_roles}" "${OPTARG}")
        ;;
      o)
        # Break up into name and value
        p666_option_name=$(echo "${OPTARG}" | sed 's/=.*//')
        p666_option_value=$(echo "${OPTARG}" | sed "s/^${p666_option_name}=//")
        p666_option_value=$(p666_process_hostname "${p666_option_value}")
        p666_options=$(cube_append_str "${p666_options}" "${p666_option_name}=\"${p666_option_value}\"" "${POSIXCUBE_NEWLINE}")
        ;;
      z)
        if [ -r "${p666_specfile}" ]; then
          p666_foundspec=0
          
          p666_foundspec_names=""
          
          while read p666_specfile_line; do
            p666_specfile_line_name=$(echo "${p666_specfile_line}" | sed 's/=.*//')
            p666_foundspec_names=$(cube_append_str "${p666_foundspec_names}" "${p666_specfile_line_name}")
            if [ "${p666_specfile_line_name}" = "${OPTARG}" ]; then
              p666_foundspec=1
              p666_specfile_line_value=$(echo "${p666_specfile_line}" | sed "s/^${p666_specfile_line_name}=//")
              p666_process_options ${p666_specfile_line_value}
              break
            fi
          done < "${p666_specfile}"
          
          if [ ${p666_foundspec} -eq 0 ]; then
            p666_printf_error "Could not find ${OPTARG} in ${p666_specfile} file with specs ${p666_foundspec_names}"
            exit 1
          fi
        else
          p666_printf_error "Could not find ${p666_specfile} file"
          exit 1
        fi
        ;;
      esac
    done
  }

  p666_process_options "${@}"
  
  # If no password specified, check for the ~/.posixcube.pwd file
  if [ "${p666_envar_scripts_password}" = "" ] && [ -r ~/.posixcube.pwd ]; then
    p666_envar_scripts_password="$(cat ~/.posixcube.pwd)" || cube_check_return
  fi

  shift $((${OPTIND}-1))

  [ "$1" = "--" ] && shift
  
  if [ "${p666_envar_scripts}" = "" ]; then
    p666_envar_scripts="$(ls -1 ${p666_default_envars} 2>/dev/null | paste -sd ' ' -)"
  fi

  if [ "${p666_envar_scripts}" != "" ]; then
    [ ${p666_debug} -eq 1 ] && p666_printf "Using ENVAR files: ${p666_envar_scripts}\n"
  fi
  
  p666_commands="${@}"

  if [ "${p666_hosts}" = "" ]; then
    # If there are no hosts, check COMMANDs for sub-commands
    if [ "${p666_commands}" != "" ]; then
      case "${1}" in
        edit|show|source)
          if [ "${p666_envar_scripts}" != "" ]; then
            for p666_envar_script in ${p666_envar_scripts}; do
              p666_envar_scripts_enc=$(expr ${p666_envar_script} : '.*enc$')
              if [ ${p666_envar_scripts_enc} -ne 0 ]; then
                if cube_command_exists gpg ; then
                  p666_envar_script_new=$(echo "${p666_envar_script}" | sed 's/enc$/dec/g')
                  
                  if [ "${p666_envar_scripts_password}" = "" ]; then
                    p666_printf "Enter the password for ${p666_envar_script}:\n"
                    gpg --output "${p666_envar_script_new}" --yes --decrypt "${p666_envar_script}" || cube_check_return
                  else
                    [ ${p666_debug} -eq 1 ] && p666_printf "Decrypting ${p666_envar_script} ...\n"
                    p666_gpg_output="$(echo "${p666_envar_scripts_password}" | gpg --passphrase-fd 0 --batch --yes --output "${p666_envar_script_new}" --decrypt "${p666_envar_script}" 2>&1)" || cube_check_return "${p666_gpg_output}"
                  fi
                  
                  case "${1}" in
                    show)
                      p666_printf "Contents of ${p666_envar_script}:\n"
                      cat "${p666_envar_script_new}"
                      ;;
                    source)
                      chmod u+x "${p666_envar_script_new}"
                      . "$(cube_readlink "${p666_envar_script_new}")"
                      [ ${p666_debug} -eq 1 ] && p666_printf "Sourced ${p666_envar_script}...\n"
                      ;;
                    edit)
                      "${EDITOR:-vi}" "${p666_envar_script_new}" || cube_check_return
                      
                      if [ "${p666_envar_scripts_password}" = "" ]; then
                        p666_printf "Enter the password to re-encrypt ${p666_envar_script}:\n"
                        gpg --yes --s2k-mode 3 --s2k-count 65536 --force-mdc --cipher-algo AES256 --s2k-digest-algo SHA512 -o "${p666_envar_script}" --symmetric "${p666_envar_script_new}" || cube_check_return
                      else
                        [ ${p666_debug} -eq 1 ] && p666_printf "Re-encrypting ${p666_envar_script} ...\n"
                        
                        p666_gpg_output="$(echo "${p666_envar_scripts_password}" | gpg --batch --passphrase-fd 0 --yes --no-use-agent --s2k-mode 3 --s2k-count 65536 --force-mdc --cipher-algo AES256 --s2k-digest-algo SHA512 -o "${p666_envar_script}" --symmetric "${p666_envar_script_new}" 2>&1)" || cube_check_return "${p666_gpg_output}"
                      fi
                      ;;
                    *)
                      p666_show_usage "Not implemented"
                      ;;
                  esac
                  
                  rm -f "${p666_envar_script_new}" || cube_check_return
                else
                  p666_show_usage "gpg program not found on the PATH"
                fi
              else
                case "${1}" in
                  show)
                    cat "${p666_envar_script}" | grep -v "^#!/bin/sh$"
                    ;;
                  source)
                    . "$(cube_readlink "${p666_envar_script}")"
                    [ ${p666_debug} -eq 1 ] && p666_printf "Sourced ${p666_envar_script}...\n"
                    ;;
                  *)
                    p666_show_usage "Not implemented"
                    ;;
                esac
              fi
            done
            
            case "${1}" in
              source)
                true
                ;;
              *)
                exit 0
                ;;
            esac
          else
            p666_show_usage "Sub-COMMAND without -e ENVAR file and ${p666_default_envars} not found."
          fi
          case "${1}" in
            source)
              true
              ;;
            *)
              exit 0
              ;;
          esac
          ;;
        *)
          p666_show_usage "Unknown sub-COMMAND ${1}"
          ;;
      esac
    else
      p666_show_usage "No hosts specified with -h and no sub-COMMAND specified."
    fi
  fi
  
  if [ "${POSIXCUBE_SOURCED}" = "" ]; then
    if [ "${p666_commands}" = "" ] && [ "${p666_cubes}" = "" ]; then
      p666_show_usage "No COMMANDs or CUBEs specified."
    fi

    [ ${p666_debug} -eq 1 ] && p666_show_version
    
    p666_handle_remote_response() {
      p666_handle_remote_response_context="${1}"
      if [ "${p666_handle_remote_response_context}" = "" ]; then
        p666_handle_remote_response_context="Last command"
      fi
      p666_host_output_color=${POSIXCUBE_COLOR_GREEN}
      p666_host_output=""
      if [ ${p666_host_output_result} -ne 0 ]; then
        p666_host_output_color=${POSIXCUBE_COLOR_RED}
        p666_host_output="${p666_handle_remote_response_context} failed with return code ${p666_host_output_result}"
      else
        [ ${p666_debug} -eq 1 ] && p666_host_output="Commands succeeded."
      fi
      [ "${p666_host_output}" != "" ] && p666_printf "[${p666_host_output_color}${p666_host}${POSIXCUBE_COLOR_RESET}] %s\n" "${p666_host_output}"
      if [ ${p666_host_output_result} -ne 0 ]; then
        p666_exit ${p666_host_output_result}
      fi
    }

    p666_remote_ssh() {
      p666_remote_ssh_commands="$1"
      [ ${p666_debug} -eq 1 ] && p666_printf "[${POSIXCUBE_COLOR_GREEN}${p666_host}${POSIXCUBE_COLOR_RESET}] Executing ssh ${p666_user}@${p666_host} \"${p666_remote_ssh_commands}\" ...\n"
      
      if [ ${p666_parallel} -gt 0 ] && [ ${p666_async} -eq 1 ]; then
        ssh -o ConnectTimeout=10 ${p666_user}@${p666_host} ${p666_remote_ssh_commands} 2>&1 &
        p666_wait_pids=$(cube_append_str "${p666_wait_pids}" "$!")
      else
        ssh -o ConnectTimeout=10 ${p666_user}@${p666_host} ${p666_remote_ssh_commands} 2>&1
        p666_host_output_result=$?
        
        [ ${p666_debug} -eq 1 ] && p666_printf "Finished executing on ${p666_host}\n"
        
        p666_handle_remote_response "Remote commands through SSH"
        return ${p666_host_output_result}
      fi
    }

    p666_remote_transfer() {
      p666_remote_transfer_source="$1"
      p666_remote_transfer_dest="$2"
      [ ${p666_debug} -eq 1 ] && p666_printf "[${POSIXCUBE_COLOR_GREEN}${p666_host}${POSIXCUBE_COLOR_RESET}] Executing rsync ${p666_remote_transfer_source} to ${p666_user}@${p666_host}:${p666_remote_transfer_dest} ...\n"
      
      # Don't use -a so that ownership is picked up from the specified user
      if [ ${p666_parallel} -gt 0 ] && [ ${p666_async} -eq 1 ]; then
        [ ${p666_debug} -eq 1 ] && p666_printf "Rsyncing in background: ${p666_remote_transfer_source} ${p666_user}@${p666_host}:${p666_remote_transfer_dest}\n"
        rsync -rlpt ${p666_remote_transfer_source} "${p666_user}@${p666_host}:${p666_remote_transfer_dest}" &
        p666_wait_pids=$(cube_append_str "${p666_wait_pids}" "$!")
      else
        [ ${p666_debug} -eq 1 ] && p666_printf "Rsyncing in foreground: ${p666_remote_transfer_source} ${p666_user}@${p666_host}:${p666_remote_transfer_dest}\n"
        rsync -rlpt ${p666_remote_transfer_source} "${p666_user}@${p666_host}:${p666_remote_transfer_dest}"
        p666_host_output_result=$?
        p666_handle_remote_response "rsync"
      fi
    }

    p666_cubedir=${p666_cubedir%/}
    
    p666_script_name="$(cube_current_script_name)"
    p666_script_path="$(cube_current_script_abs_path)"
    
    p666_remote_script="${p666_cubedir}/${p666_script_name}"

    # Create a script that we'll execute on the remote end
    p666_script_contents="cube_initial_directory=\${PWD}"
    p666_script_envar_contents=""
    
    p666_envar_scripts_final=""

    for p666_envar_script in ${p666_envar_scripts}; do
    
      p666_envar_script_remove=0
    
      p666_envar_script_enc_matches=$(expr ${p666_envar_script} : '.*\.enc$')
      
      if [ ${p666_envar_script_enc_matches} -ne 0 ]; then
        if cube_command_exists gpg ; then
          [ ${p666_debug} -eq 1 ] && p666_printf "Decrypting ${p666_envar_script}"
          
          p666_envar_script_new=$(echo "${p666_envar_script}" | sed 's/enc$/dec/g')
          
          if [ "${p666_envar_scripts_password}" = "" ]; then
            p666_printf "Enter the password for ${p666_envar_script}:\n"
            gpg --output "${p666_envar_script_new}" --yes --decrypt "${p666_envar_script}" || cube_check_return
          else
            [ ${p666_debug} -eq 1 ] && p666_printf "Decrypting ${p666_envar_script} ...\n"
            p666_gpg_output="$(echo "${p666_envar_scripts_password}" | gpg --passphrase-fd 0 --batch --yes --output "${p666_envar_script_new}" --decrypt "${p666_envar_script}" 2>&1)" || cube_check_return "${p666_gpg_output}"
          fi
          
          p666_envar_script="${p666_envar_script_new}"
          p666_envar_script_remove=1
        else
          p666_printf_error "gpg program not found on the PATH"
          p666_exit 1
        fi
      fi
      
      p666_envar_scripts_final=$(cube_append_str "${p666_envar_scripts_final}" "${p666_envar_script}")
      
      chmod u+x "${p666_envar_script}"
      
      p666_script_contents="${p666_script_contents}
cd ${p666_cubedir}/ || cube_check_return
. ${p666_cubedir}/$(basename ${p666_envar_script}) || cube_check_return"

      if [ ${p666_envar_script_remove} -eq 1 ]; then
        p666_script_contents="${p666_script_contents}
rm -f ${p666_cubedir}/$(basename ${p666_envar_script}) || cube_check_return"
      fi
    done
    
    p666_envar_scripts="${p666_envar_scripts_final}"
    
    for p666_cube in ${p666_cubes}; do
      if [ -d "${p666_cube}" ]; then
        p666_cube_name=$(basename "${p666_cube}")
        if [ -r "${p666_cube}/${p666_cube_name}.sh" ]; then
          chmod u+x ${p666_cube}/*.sh
          p666_cube=${p666_cube%/}
          p666_script_contents="${p666_script_contents}
cd ${p666_cubedir}/${p666_cube}/ || cube_check_return
cube_echo \"Started cube: ${p666_cube_name}\"
POSIXCUBE_CUBE_NAME=\"${p666_cube_name}\" POSIXCUBE_CUBE_NAME_WITH_PREFIX=\" ${p666_cube_name}.sh\" . ${p666_cubedir}/${p666_cube}/${p666_cube_name}.sh || cube_check_return \"Last command in cube\"
cube_echo \"Finished cube: ${p666_cube_name}\"
"
          if [ -r "${p666_cube}/envars.sh" ]; then
            p666_script_envar_contents="${p666_script_envar_contents}
. ${p666_cubedir}/${p666_cube}/envars.sh || cube_check_return \"Failed loading cube envars\"
"
          fi
        else
          p666_printf_error "Could not find ${p666_cube_name}.sh in cube ${p666_cube} directory."
          p666_exit 1
        fi
      elif [ -r "${p666_cube}" ]; then
        p666_cube_name=$(basename "${p666_cube}")
        chmod u+x "${p666_cube}"
        p666_script_contents="${p666_script_contents}
cd ${p666_cubedir}/ || cube_check_return
cube_echo \"Started cube: ${p666_cube_name}\"
POSIXCUBE_CUBE_NAME=\"${p666_cube_name}\" POSIXCUBE_CUBE_NAME_WITH_PREFIX=\" ${p666_cube_name}\" . ${p666_cubedir}/${p666_cube_name} || cube_check_return \"Last command in cube\"
cube_echo \"Finished cube: ${p666_cube_name}\"
"
      elif [ -r "${p666_cube}.sh" ]; then
        p666_cube_name=$(basename "${p666_cube}.sh")
        chmod u+x "${p666_cube}.sh"
        p666_script_contents="${p666_script_contents}
cd ${p666_cubedir}/ || cube_check_return
cube_echo \"Started cube: ${p666_cube_name}\"
POSIXCUBE_CUBE_NAME=\"${p666_cube_name}\" POSIXCUBE_CUBE_NAME_WITH_PREFIX=\" ${p666_cube_name}\" . ${p666_cubedir}/${p666_cube_name} || cube_check_return \"Last command in cube\"
cube_echo \"Finished cube: ${p666_cube_name}\"
"
      else
        p666_printf_error "Cube ${p666_cube} could not be found as a directory or script, or you don't have read permissions."
        p666_exit 1
      fi
      p666_script_contents="${p666_script_contents}${POSIXCUBE_NEWLINE}cd \${cube_initial_directory}"
    done
    
    for p666_cube in ${p666_include_cubes}; do
      if [ -d "${p666_cube}" ]; then
        p666_cube_name=$(basename "${p666_cube}")
        if [ -r "${p666_cube}/${p666_cube_name}.sh" ]; then
          chmod u+x ${p666_cube}/*.sh
        fi
      elif [ -r "${p666_cube}" ]; then
        chmod u+x "${p666_cube}"
      elif [ -r "${p666_cube}.sh" ]; then
        chmod u+x "${p666_cube}.sh"
      else
        p666_printf_error "Cube ${p666_cube} could not be found as a directory or script, or you don't have read permissions."
        p666_exit 1
      fi
    done
    
    if [ "${p666_commands}" != "" ]; then
      p666_script_contents="${p666_script_contents}
  ${p666_commands}"
    fi
    
    p666_script="./cube_exec.sh"
    
    cat <<HEREDOC > "${p666_script}"
#!/bin/sh
POSIXCUBE_APIS_ONLY=1
. ${p666_remote_script}
if [ \$? -ne 0 ] ; then
  echo "Could not source ${p666_remote_script} script" 1>&2
  exit 1
fi

POSIXCUBE_DEBUG=${p666_debug}
cubevar_api_roles="${p666_roles}"
${p666_script_envar_contents}
${p666_options}
${p666_script_contents}

if [ "\${cubevar_api_post_restart}" != "" ]; then
  for p666_post in \${cubevar_api_post_restart}; do
    cube_service restart "\${p666_post}"
  done
fi
HEREDOC

    chmod +x "${p666_script}"
    
    p666_upload="${p666_script} "

    if [ "${p666_cubes}" != "" ]; then
      for p666_cube in ${p666_cubes}; do
        if [ -d "${p666_cube}" ]; then
          p666_cube_name=$(basename "${p666_cube}")
          if [ -r "${p666_cube}/${p666_cube_name}.sh" ]; then
            p666_cube=${p666_cube%/}
            p666_upload="${p666_upload} ${p666_cube}"
          fi
        elif [ -r "${p666_cube}" ]; then
          p666_cube_name=$(basename "${p666_cube}")
          p666_upload="${p666_upload} ${p666_cube}"
        elif [ -r "${p666_cube}.sh" ]; then
          p666_cube_name=$(basename "${p666_cube}.sh")
          p666_upload="${p666_upload} ${p666_cube}.sh"
        fi
      done
    fi

    if [ "${p666_include_cubes}" != "" ]; then
      for p666_cube in ${p666_include_cubes}; do
        if [ -d "${p666_cube}" ]; then
          p666_cube_name=$(basename "${p666_cube}")
          if [ -r "${p666_cube}/${p666_cube_name}.sh" ]; then
            p666_cube=${p666_cube%/}
            p666_upload="${p666_upload} ${p666_cube}"
          fi
        elif [ -r "${p666_cube}" ]; then
          p666_cube_name=$(basename "${p666_cube}")
          p666_upload="${p666_upload} ${p666_cube}"
        elif [ -r "${p666_cube}.sh" ]; then
          p666_cube_name=$(basename "${p666_cube}.sh")
          p666_upload="${p666_upload} ${p666_cube}.sh"
        else
          p666_printf_error "Could not find ${p666_cube}"
          p666_exit 1
        fi
      done
    fi

    [ ${p666_quiet} -eq 0 ] && p666_printf "Transferring files to hosts: ${p666_hosts} ...\n"
    
    p666_async=1
    
    if [ ${p666_skip_init} -eq 0 ]; then
      p666_wait_pids=""
      for p666_host in ${p666_hosts}; do
        # Debian doesn't have rsync installed by default
        #p666_remote_ssh "[ ! -d \"${p666_cubedir}\" ] && mkdir -p ${p666_cubedir}"
        p666_remote_ssh "[ ! -d \"${p666_cubedir}\" ] && mkdir -p ${p666_cubedir}; RC=\$?; command -v rsync >/dev/null 2>&1 || (command -v apt-get >/dev/null 2>&1 && apt-get -y install rsync); exit \${RC};"
      done
      if [ "${p666_wait_pids}" != "" ]; then
        [ ${p666_debug} -eq 1 ] && p666_printf "Waiting on initialization PIDs: ${p666_wait_pids} ...\n"
        wait ${p666_wait_pids}
        p666_host_output_result=$?
        p666_handle_remote_response "Remote commands through SSH"
      fi
    fi
    
    p666_wait_pids=""
    for p666_host in ${p666_hosts}; do
      if [ ${p666_skip_init} -eq 0 ]; then
        p666_remote_transfer "${p666_upload} ${p666_script_path} ${p666_envar_scripts}" "${p666_cubedir}/"
      else
        p666_remote_transfer "${p666_upload} ${p666_envar_scripts}" "${p666_cubedir}/"
      fi
    done
    
    if [ "${p666_wait_pids}" != "" ]; then
      [ ${p666_debug} -eq 1 ] && p666_printf "Waiting on transfer PIDs: ${p666_wait_pids} ...\n"
      wait ${p666_wait_pids}
      p666_host_output_result=$?
      p666_handle_remote_response "rsync"
    fi

    p666_wait_pids=""
    p666_async=${p666_async_cubes}
    
    for p666_host in ${p666_hosts}; do
      [ ${p666_quiet} -eq 0 ] && p666_printf "[${POSIXCUBE_COLOR_GREEN}${p666_host}${POSIXCUBE_COLOR_RESET}] Executing on ${p666_host} ...\n"
      p666_remote_ssh ". ${p666_cubedir}/${p666_script}"
      p666_remote_ssh_result=$?
      if [ ${p666_async} -eq 0 ]; then
        [ ${p666_skip_host_errors} -eq 0 ] && [ ${p666_remote_ssh_result} -ne 0 ] && p666_exit ${p666_remote_ssh_result}
      fi
    done

    if [ "${p666_wait_pids}" != "" ]; then
      [ ${p666_debug} -eq 1 ] && p666_printf "Waiting on cube execution PIDs: ${p666_wait_pids} ...\n"
      wait ${p666_wait_pids}
      p666_host_output_result=$?
      p666_handle_remote_response "Cube execution"
    fi

    p666_exit 0
  fi
fi
