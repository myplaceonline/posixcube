#!/bin/sh
# posixcube.sh
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
#   3. Use lower-case variables unless exporting an envar [4].
#   4. Try to keep lines less than 120 characters.
#   5. Use a separate [ invocation for each single test, combine them with && and ||.
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

  # When updating usage, also update README.md.
  cat <<'HEREDOC'
usage: posixcube.sh -h HOST... [OPTION]... COMMAND...

  posixcube.sh is a (hopefully) POSIX compliant shell script server automation
  framework. Use consistent APIs for common tasks and package functionality
  and file templates in cubes (like recipes/playbooks from other frameworks).

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
  -v        Show version information.
  -d        Print debugging information.
  -q        Quiet; minimize output.
  -i        If using bash, install programmable tab completion for SSH hosts.
  -s        Skip remote host initialization (making ~/posixcubes, uploading
            posixcube.sh, etc.
  -k        Keep the cube_exec.sh generated script.
  COMMAND   Remote command to run on each HOST. Option may be specified
            multiple times.

Description:

  posixcube.sh is used to execute CUBEs and/or COMMANDs on one or more HOSTs.
  
  A CUBE is a shell script or directory containing shell scripts. The CUBE
  is rsync'ed to each HOST. If CUBE is a shell script, it's executed. If
  CUBE is a directory, a shell script of the same name in that directory
  is executed. In both cases, the directory is changed to the directory
  containing the script before execution so that you may reference files
  such as templates using relative paths.
  
  Both CUBEs and COMMANDs may execute any of the functions defined in the
  "Public APIs" in the posixcube.sh script. Short descriptions of the functions
  follows. See the source comments above each function for details.
  
  * cube_log
      Print $1 to stdout prefixed with ([`date`] [`hostname`]) and
      suffixed with a newline (with optional printf arguments in $@).
      Example: cube_log "Hello World"

  * cube_error
      Same as cube_log except output to stderr and include a red "Error: "
      message prefix.
      Example: cube_error "Goodbye World"

  * cube_throw
      Same as cube_error but also print a stack of functions and processes
      (if available) and then call `exit 1`.
      Example: cube_throw "Expected some_file."

  * cube_check_return
      Check if $? is non-zero and call cube_throw if so.
      Example: some_command || cube_check_return

  * cube_check_numargs
      Call cube_throw if there are less than $1 arguments in $@
      Example: cube_check_numargs 2 "${@}"

  * cube_service
      Run the $1 action on the $2 service.
      Example: cube_service start crond

  * cube_check_command_exists
      Check if $1 command or function exists in the current context.
      Example: cube_check_command_exists systemctl

  * cube_check_dir_exists
      Check if $1 exists as a directory.
      Example: cube_check_dir_exists /etc/cron.d/

  * cube_check_file_exists
      Check if $1 exists as a file with read access.
      Example: cube_check_file_exists /etc/cron.d/0hourly

  * cube_operating_system
      Detect operating system and return one of the CUBE_OS_* values.
      Example: [ $(cube_operating_system) -eq ${POSIXCUBE_OS_LINUX} ] && ...

  * cube_current_script_name
      echo the basename of the currently executing script.
      Example: script_name=$(cube_current_script_name)

  * cube_current_script_abs_path
      echo the absolute path the currently executing script.
      Example: script_name=$(cube_current_script_abs_path)

  * cube_get_file_size
      echo the size of a file $1 in bytes
      Example: cube_get_file_size some_file

  * cube_set_file_contents
      Copy the contents of $2 on top of $1 if $1 doesn't exist or the contents
      are different than $2.
      Example: cube_set_file_contents "/etc/npt.conf" "templates/ntp.conf"

Philosophy:

  Fail hard and fast. In principle, a well written script would check ${?}
  after each command and either gracefully handle it, or report an error.
  Few people write scripts this well, so we enforce this check (using
  `cube_check_return` within all APIs) and we encourage you to do the same
  in your scripts with `some_command || cube_check_return`.

Frequently Asked Questions:

  * Why is there a long delay before the first remote execution?
  
    You can see details of what's happening with the `-d` flag. By default,
    the script first loops through every host and ensures that ~/posixcubes/
    exists, then it transfers itself to the remote host. These two actions
    may be skipped with the `-s` parameter if you've already run the script
    at least once and your version of this script hasn't been updated. Next,
    the script loops through every host and transfers any CUBEs and a script
    containing the CUBEs and COMMANDs to run (`cube_exec.sh`). Finally,
    you'll see the "Executing on HOST..." line and the real execution starts.

Examples:

  ./posixcube.sh -h socrates uptime
  
    Run the `uptime` command on host `socrates`. This is not very different
    from ssh ${USER}@socrates uptime, except that COMMANDs (`uptime`) have
    access to the cube_* public functions.
  
  ./posixcube.sh -h socrates -c test.sh
  
    Run the `test.sh` script (CUBE) on host `socrates`. The script has
    access to the cube_* public functions.
  
  ./posixcube.sh -h socrates -c test
  
    Upload the entire `test` directory (CUBE) to the host `socrates` and
    then execute the `test.sh` script within that directory (the name
    of the script is expected to be the same as the name of the CUBE). This
    allows for easily packaging other scripts and resources needed by
    `test.sh`.
  
  ./posixcube.sh -u root -h socrates -h seneca uptime
  
    Run the `uptime` command on hosts `socrates` and `seneca`
    as the user `root`.
  
  ./posixcube.sh -h web*.test.com uptime
  
    Run the `uptime` command on all hosts matching the regular expression
    web.*.test.com in the SSH configuration files.
  
  sudo ./posixcube.sh -i && . /etc/bash_completion.d/posixcube_completion.sh
  
    For Bash users, install a programmable completion script to support tab
    auto-completion of hosts from SSH configuration files.

Source: https://github.com/myplaceonline/posixcube

HEREDOC
  exit 1
}

###############
# Public APIs #
###############

# Constants
POSIXCUBE_VERSION=0.1
POSIXCUBE_COLOR_RESET="\x1B[0m"
POSIXCUBE_COLOR_RED="\x1B[31m"
POSIXCUBE_COLOR_GREEN="\x1B[32m"

POSIXCUBE_NEWLINE="
"

POSIXCUBE_OS_UNKNOWN=-1
POSIXCUBE_OS_LINUX=1
POSIXCUBE_OS_MAC_OSX=2
POSIXCUBE_OS_WINDOWS=3

# Description:
#   Print $1 to stdout prefixed with ([`date`]  [`hostname`]) and suffixed with
#   a newline.
# Example call:
#   cube_log "Hello World"
# Example output:
#   [Sun Dec 18 09:40:22 PST 2016] [socrates] Hello World
# Arguments:
#   Required:
#     $1: String to print (printf-compatible)
#   Optional: 
#     $2: printf arguments 
cube_log() {
  cube_log_str=$1
  shift
  printf "[`date`] [${POSIXCUBE_COLOR_GREEN}`hostname`${POSIXCUBE_COLOR_RESET}] ${cube_log_str}\n" "${@}"
}

# Description:
#   Print $1 to stderr prefixed with ([`date`]  [`hostname`] Error: ) and
#   suffixed with a newline.
# Example call:
#   cube_error "Goodbye World"
# Example output:
#   [Sun Dec 18 09:40:22 PST 2016] [socrates] Goodbye World
# Arguments:
#   Required:
#     $1: String to print (printf-compatible)
#   Optional: 
#     $2: printf arguments 
cube_error() {
  cube_error_str=$1
  shift
  printf "[`date`] [${POSIXCUBE_COLOR_RED}`hostname`${POSIXCUBE_COLOR_RESET}] ${POSIXCUBE_COLOR_RED}Error${POSIXCUBE_COLOR_RESET}: ${cube_error_str}\n" "${@}" 1>&2
}

# Description:
#   Print $1 and a stack of functions and processes (if available) with
#   cube_error and then call `exit 1`.
# Example call:
#   cube_throw "Expected some_file to exist."
# Arguments:
#   Required:
#     $1: Error message
#   Optional: 
#     $2: printf arguments 
cube_throw() {
  cube_throw_str=$1
  shift
  cube_error "${cube_throw_str}" "${@}"
  
  cube_throw_pid=$$
  
  if cube_check_command_exists caller || [ -r /proc/${cube_throw_pid}/cmdline ]; then
    cube_error Stack:
  fi
  
  if cube_check_command_exists caller ; then
    x=0
    while true; do
      cube_error_caller=$(caller $x)
      cube_error_caller_result=${?}
      if [ ${cube_error_caller_result} -eq 0 ]; then
        cube_error_caller_result_lineno=$(echo "${cube_error_caller}" | awk '{ print $1 }')
        cube_error_caller_result_subroutine=$(echo "${cube_error_caller}" | awk '{ print $2 }')
        cube_error_caller_result_sourcefile=$(echo "${cube_error_caller}" | awk '{ for(i=3;i<=NF;i++){ printf "%s ", $i }; printf "\n" }')
        cube_error "  [func] %4s ${cube_error_caller_result_subroutine} ${cube_error_caller_result_sourcefile}" "${cube_error_caller_result_lineno}"
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
      cube_error "  [pid] %5s ${cube_throw_cmdline}" ${cube_throw_pid}
      if [ "${cube_throw_pid}" = "1" ]; then # init
        break
      fi
      cube_throw_pid=${cube_throw_ppid}
    done
  fi
  
  exit 1
}

# Description:
#   Check if $? is non-zero and call cube_throw if so.
# Example call:
#   some_command || cube_check_return
# Arguments: None
cube_check_return() {
  cube_check_return_val=${?}
  [ ${cube_check_return_val} -ne 0 ] && cube_throw "Previous command failed with code ${cube_check_return_val}"
}

# Description:
#   Check if $1 command or function exists in the current context.
# Example call:
#   cube_check_command_exists systemctl
# Arguments:
#   Required:
#     $1: Command or function name.
cube_check_command_exists() {
  cube_check_numargs 1 "${@}"
  command -v ${1} >/dev/null 2>&1
}

# Description:
#   Check if $1 exists as a directory.
# Example call:
#   cube_check_dir_exists /etc/cron.d/
# Arguments:
#   Required:
#     $1: Directory name.
cube_check_dir_exists() {
  cube_check_numargs 1 "${@}"
  [ -d "${1}" ]
}

# Description:
#   Check if $1 exists as a file with read access.
# Example call:
#   cube_check_file_exists /etc/cron.d/0hourly
# Arguments:
#   Required:
#     $1: File name.
cube_check_file_exists() {
  cube_check_numargs 1 "${@}"
  [ -r "${1}" ]
}

# Description:
#   Detect operating system and return one of the CUBE_OS_* values.
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
#   Throw an error if there are fewer than $1 arguments.
# Example call:
#   cube_check_numargs 2 "${@}"
# Arguments:
#   Required:
#     $1: String to print (printf-compatible)
#     $@: Arguments to check
cube_check_numargs() {
  cube_check_numargs_expected=$1
  shift
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
  cube_check_numargs 2 "${@}"
  if cube_check_command_exists systemctl ; then
    systemctl $1 $2 || cube_check_return
  elif cube_check_command_exists service ; then
    service $2 $1 || cube_check_return
  else
    cube_throw "Could not find service program"
  fi
  case "${1}" in
    stop)
      cube_service_verb="stopped"
      ;;
    *)
      cube_service_verb="${1}ed"
      ;;
  esac
  cube_log "Successfully ${cube_service_verb} $2"
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
#   cube_get_file_size some_file
# Required:
#     $1: File
cube_get_file_size() {
  cube_check_numargs 1 "${@}"
  if cube_check_file_exists "${1}" ; then
    wc -c <"${1}"
  else
    cube_throw "Could not find or read file ${1}"
  fi
}

# Description:
#   Copy the contents of $2 on top of $1 if $1 doesn't exist or the contents
#   are different than $2.
# Example call:
#   cube_set_file_contents "/etc/npt.conf" "templates/ntp.conf"
# Required:
#     $1: Target file
#     $2: Source file
# Returns: success/true if the file was updated
cube_set_file_contents() {
  cube_check_numargs 2 "${@}"
  cube_set_file_contents_target_file="$1"; shift
  cube_set_file_contents_input_file="$1"; shift
  
  cube_set_file_contents_needs_replace=0
  
  if ! cube_check_file_exists "${cube_set_file_contents_input_file}" ; then
    cube_throw "Could not find or read input ${cube_set_file_contents_input_file}"
  fi
  
  if cube_check_file_exists "${cube_set_file_contents_target_file}" ; then
    # If the file sizes are different, then replace the file (http://stackoverflow.com/a/5920355/5657303)
    cube_set_file_contents_target_file_size=$(cube_get_file_size "${cube_set_file_contents_target_file}")
    cube_set_file_contents_input_file_size=$(cube_get_file_size "${cube_set_file_contents_input_file}")
    
    if [ ${cube_set_file_contents_target_file_size} -eq ${cube_set_file_contents_input_file_size} ]; then
      # Sizes are equal, so do a quick cksum
      cube_set_file_contents_target_file_cksum=$(cksum "${cube_set_file_contents_target_file}" | awk '{print $1}')
      cube_set_file_contents_input_file_cksum=$(cksum "${cube_set_file_contents_input_file}" | awk '{print $1}')
      if [ "${cube_set_file_contents_target_file_cksum}" != "${cube_set_file_contents_input_file_cksum}" ]; then
        cube_set_file_contents_needs_replace=1
      fi
    else
      cube_set_file_contents_needs_replace=1
    fi
  fi

  if [ ${cube_set_file_contents_needs_replace} -eq 1 ] ; then
    cube_log "Updating file contents of ${cube_set_file_contents_target_file} with ${cube_set_file_contents_input_file}"
    cp "${cube_set_file_contents_input_file}" "${cube_set_file_contents_target_file}" || cube_check_return
    return 0
  else
    return 1
  fi
}

################################
# Core internal implementation #
################################

# If we're being sourced on the remote machine, then we don't want to run any of the below
if [ "${POSIXCUBE_SOURCED}" = "" ]; then
  p666_debug=0
  p666_quiet=0
  p666_skip_init=0
  p666_keep_exec=0
  p666_hosts=""
  p666_cubes=""
  p666_user="${USER}"
  p666_cubedir="~/posixcubes/"

  p666_show_version() {
    p666_printf "posixcube.sh version ${POSIXCUBE_VERSION}\n"
  }

  p666_printf() {
    p666_printf_str=$1
    shift
    printf "[`date`] ${p666_printf_str}" "${@}"
  }

  p666_printf_error() {
    p666_printf_str=$1
    shift
    printf "\n[`date`] ${POSIXCUBE_COLOR_RED}Error${POSIXCUBE_COLOR_RESET}: ${p666_printf_str}\n\n" "${@}" 1>&2
  }

  p666_install() {
    p666_func_result=0
    if [ -d "/etc/bash_completion.d/" ]; then
      p666_autocomplete_file=/etc/bash_completion.d/posixcube_completion.sh
      
      # Autocomplete Hostnames for SSH etc.
      # by Jean-Sebastien Morisset (http://surniaulula.com/)
      
      cat <<'HEREDOC' | tee ${p666_autocomplete_file} > /dev/null
_posixcube_complete_host() {
  COMPREPLY=()
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD-1]}"
  case "${prev}" in
    \-h)
      p666_host_list=`{ 
        for c in /etc/ssh_config /etc/ssh/ssh_config ~/.ssh/config
        do [ -r $c ] && sed -n -e 's/^Host[[:space:]]//p' -e 's/^[[:space:]]*HostName[[:space:]]//p' $c
        done
        for k in /etc/ssh_known_hosts /etc/ssh/ssh_known_hosts ~/.ssh/known_hosts
        do [ -r $k ] && egrep -v '^[#\[]' $k|cut -f 1 -d ' '|sed -e 's/[,:].*//g'
        done
        sed -n -e 's/^[0-9][0-9\.]*//p' /etc/hosts; }|tr ' ' '\n'|grep -v '*'`
      COMPREPLY=( $(compgen -W "${p666_host_list}" -- $cur))
      ;;
    *)
      ;;
  esac
  return 0
}
complete -o default -F _posixcube_complete_host posixcube.sh
HEREDOC

      p666_func_result=$?
      if [ ${p666_func_result} -eq 0 ]; then
        chmod +x ${p666_autocomplete_file}
        p666_func_result=$?
        if [ ${p666_func_result} -eq 0 ]; then
          source ${p666_autocomplete_file}
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
        p666_printf "  sudo ./posixcube.sh -i && source ${p666_autocomplete_file}\n"
        p666_printf "You only need to source the command the first time. Subsequent shells will automatically source it.\n"
      fi
    else
      p666_printf "No directory /etc/bash_completion.d/ found, skipping Bash programmable completion installation.\n"
    fi
    exit ${p666_func_result}
  }

  p666_all_hosts=""

  p666_process_hostname() {
    p666_processed_hostname="$1"
    p666_hostname_wildcard=`expr ${p666_processed_hostname} : '.*\*.*'`
    if [ ${p666_hostname_wildcard} -ne 0 ]; then
      if [ "${p666_all_hosts}" = "" ]; then
        p666_all_hosts=`{ 
          for c in /etc/ssh_config /etc/ssh/ssh_config ~/.ssh/config
          do [ -r $c ] && sed -n -e 's/^Host[[:space:]]//p' -e 's/^[[:space:]]*HostName[[:space:]]//p' $c
          done
          for k in /etc/ssh_known_hosts /etc/ssh/ssh_known_hosts ~/.ssh/known_hosts
          do [ -r $k ] && egrep -v '^[#\[]' $k|cut -f 1 -d ' '|sed -e 's/[,:].*//g'
          done
          sed -n -e 's/^[0-9][0-9\.]*//p' /etc/hosts; }|tr '\n' ' '|grep -v '*'`
      fi
      p666_processed_hostname_search=`printf "${p666_processed_hostname}" | sed 's/\*/\.\*/g'`
      p666_processed_hostname=""
      for p666_all_host in ${p666_all_hosts}; do
        p666_all_host_match=`expr ${p666_all_host} : ${p666_processed_hostname_search}`
        if [ ${p666_all_host_match} -ne 0 ]; then
          if [ "${p666_processed_hostname}" = "" ]; then
            p666_processed_hostname="${p666_all_host}"
          else
            p666_processed_hostname="${p666_processed_hostname} ${p666_all_host}"
          fi
        fi
      done
    fi
    return 0
  }

  # getopts processing based on http://stackoverflow.com/a/14203146/5657303
  OPTIND=1 # Reset in case getopts has been used previously in the shell.

  while getopts "?vdqiskh:u:c:" p666_opt; do
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
    i)
      p666_install
      ;;
    h)
      p666_process_hostname "${OPTARG}"
      if [ "${p666_processed_hostname}" != "" ]; then
        if [ "${p666_hosts}" = "" ]; then
          p666_hosts="${p666_processed_hostname}"
        else
          p666_hosts="${p666_hosts} ${p666_processed_hostname}"
        fi
      else
        p666_printf_error "No known hosts match ${OPTARG} from ${p666_all_hosts}"
        exit 1
      fi
      ;;
    c)
      if [ "${p666_cubes}" = "" ]; then
        p666_cubes="${OPTARG}"
      else
        p666_cubes="${p666_cubes} ${OPTARG}"
      fi
      ;;
    u)
      p666_user="${OPTARG}"
      ;;
    esac
  done

  shift $((${OPTIND}-1))

  [ "$1" = "--" ] && shift

  p666_commands="${@}"

  if [ "${p666_hosts}" = "" ]; then
    p666_printf_error "No hosts specified with -h."
    p666_show_usage
  fi

  if [ "${p666_commands}" = "" ] && [ "${p666_cubes}" = "" ]; then
    p666_printf_error "No COMMANDs or CUBEs specified."
    p666_show_usage
  fi

  [ ${p666_debug} -eq 1 ] && p666_show_version
  
  p666_handle_remote_response() {
    p666_host_output_color=${POSIXCUBE_COLOR_GREEN}
    p666_host_output=""
    if [ ${p666_host_output_result} -ne 0 ]; then
      p666_host_output_color=${POSIXCUBE_COLOR_RED}
      p666_host_output="Last command failed with return code ${p666_host_output_result}"
    else
      [ ${p666_debug} -eq 1 ] && p666_host_output="Commands succeeded."
    fi
    [ "${p666_host_output}" != "" ] && p666_printf "[${p666_host_output_color}${p666_host}${POSIXCUBE_COLOR_RESET}] %s\n" "${p666_host_output}"
  }

  p666_remote_ssh() {
    p666_remote_ssh_commands="$1"
    [ ${p666_debug} -eq 1 ] && p666_printf "[${POSIXCUBE_COLOR_GREEN}${p666_host}${POSIXCUBE_COLOR_RESET}] Executing ssh ${p666_user}@${p666_host} \"${p666_remote_ssh_commands}\" ...\n"
    
    ssh ${p666_user}@${p666_host} ${p666_remote_ssh_commands} 2>&1
    p666_host_output_result=$?
    p666_handle_remote_response
  }

  p666_remote_transfer() {
    p666_remote_transfer_source="$1"
    p666_remote_transfer_dest="$2"
    [ ${p666_debug} -eq 1 ] && p666_printf "[${POSIXCUBE_COLOR_GREEN}${p666_host}${POSIXCUBE_COLOR_RESET}] Executing rsync ${p666_remote_transfer_source} to ${p666_user}@${p666_host}:${p666_remote_transfer_dest} ...\n"
    
    # Don't use -a so that ownership is picked up from the specified user
    rsync -rlpt ${p666_remote_transfer_source} "${p666_user}@${p666_host}:${p666_remote_transfer_dest}"
    p666_host_output_result=$?
    p666_handle_remote_response
  }

  p666_cubedir=${p666_cubedir%/}
  
  p666_script_name="$(cube_current_script_name)"
  p666_script_path="$(cube_current_script_abs_path)"
  
  p666_remote_script="${p666_cubedir}/${p666_script_name}"

  [ ${p666_debug} -eq 1 ] && p666_printf "Hosts: ${p666_hosts}\n"
  
  if [ ${p666_skip_init} -eq 0 ]; then
    for p666_host in ${p666_hosts}; do
      p666_remote_ssh "[ ! -d \"${p666_cubedir}\" ] && mkdir -p ${p666_cubedir}"
      p666_remote_transfer "${p666_script_path}" "${p666_cubedir}/"
    done
  fi
  
  # Create a script that we'll execute on the remote end
  p666_script_contents="cube_initial_directory=\${PWD}"
  for p666_cube in ${p666_cubes}; do
    if [ -d "${p666_cube}" ]; then
      p666_cube_name=`basename "${p666_cube}"`
      if [ -r "${p666_cube}/${p666_cube_name}.sh" ]; then
        chmod u+x ${p666_cube}/*.sh
        p666_cube=${p666_cube%/}
        p666_script_contents="${p666_script_contents}
cd ${p666_cubedir}/${p666_cube}/
source ${p666_cubedir}/${p666_cube}/${p666_cube_name}.sh"
      else
        p666_printf_error "Could not find ${p666_cube_name}.sh in cube ${p666_cube} directory."
        exit 1
      fi
    elif [ -r "${p666_cube}" ]; then
      p666_cube_name=$(basename "${p666_cube}")
      chmod u+x "${p666_cube}"
      p666_script_contents="${p666_script_contents}
cd ${p666_cubedir}/
source ${p666_cubedir}/${p666_cube_name}"
    elif [ -r "${p666_cube}.sh" ]; then
      p666_cube_name=$(basename "${p666_cube}.sh")
      chmod u+x "${p666_cube}.sh"
      p666_script_contents="${p666_script_contents}
cd ${p666_cubedir}/
source ${p666_cubedir}/${p666_cube_name}"
    else
      p666_printf_error "Cube ${p666_cube} could not be found as a directory or script, or you don't have read permissions."
      exit 1
    fi
    p666_script_contents="${p666_script_contents}${POSIXCUBE_NEWLINE}cd \${cube_initial_directory}"
  done
  if [ "${p666_commands}" != "" ]; then
    p666_script_contents="${p666_script_contents}
${p666_commands}"
  fi
  
  p666_script="./cube_exec.sh"
  
  cat <<HEREDOC > "${p666_script}"
#!/bin/sh
POSIXCUBE_SOURCED=1
source ${p666_remote_script}
${p666_script_contents}
HEREDOC

  chmod +x "${p666_script}"
  
  # If there are some cubes, then combine uploading the cubes with the exec script
  if [ "${p666_cubes}" != "" ]; then
    p666_cubes_upload="${p666_script} "
    for p666_cube in ${p666_cubes}; do
      if [ -d "${p666_cube}" ]; then
        p666_cube_name=`basename "${p666_cube}"`
        if [ -r "${p666_cube}/${p666_cube_name}.sh" ]; then
          p666_cube=${p666_cube%/}
          p666_cubes_upload="${p666_cubes_upload} ${p666_cube}"
        fi
      elif [ -r "${p666_cube}" ]; then
        p666_cube_name=`basename "${p666_cube}"`
        p666_cubes_upload="${p666_cubes_upload} ${p666_cube}"
      elif [ -r "${p666_cube}.sh" ]; then
        p666_cube_name=`basename "${p666_cube}.sh"`
        p666_cubes_upload="${p666_cubes_upload} ${p666_cube}.sh"
      fi
    done
    for p666_host in ${p666_hosts}; do
      p666_remote_transfer "${p666_cubes_upload}" "${p666_cubedir}/"
    done
  else
    for p666_host in ${p666_hosts}; do
      p666_remote_transfer "${p666_script}" "${p666_cubedir}/"
    done
  fi

  for p666_host in ${p666_hosts}; do
    [ ${p666_quiet} -eq 0 ] && p666_printf "[${POSIXCUBE_COLOR_GREEN}${p666_host}${POSIXCUBE_COLOR_RESET}] Executing on ${p666_host} ...\n"
    p666_remote_ssh "source ${p666_cubedir}/${p666_script}"
  done
  
  [ ${p666_keep_exec} -eq 0 ] && rm -f "${p666_script}"
fi
