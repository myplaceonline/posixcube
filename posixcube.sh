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

posixcube_version=0.1

p666_show_usage () {

  # Try to keep lines for the usage output to less than 80 characters.
  # When updating usage, also update README.md, removing the ${posixcube_version} line,
  # replacing \` with `, and replacing \$ with $
  cat <<HEREDOC
usage: posixcube.sh -h HOST... [OPTION]... COMMAND...
version ${posixcube_version}

  -?        Help.
  -h HOST   Target host. Option may be specified multiple times. If a host has
            a wildcard ('*'), then HOST is interpeted as a regular expression,
            with '*' replaced with '.*' and any matching hosts in the following
            files are added to the HOST list: /etc/ssh_config,
            /etc/ssh/ssh_config, ~/.ssh/config, /etc/ssh_known_hosts,
            /etc/ssh/ssh_known_hosts, ~/.ssh/known_hosts, and /etc/hosts.
  -c CUBE   Execute a cube. Option may be specified multiple times. If COMMANDS
            are also specified, cubes are run first.
  -u USER   SSH user. Defaults to \${USER}.
  -v        Show version information.
  -d        Print debugging information.
  -q        Quiet; minimize output.
  -i        If using bash, install programmable tab completion for SSH hosts.
  COMMAND   Remote command to run on each HOST. Option may be specified
            multiple times.

Description:

  posixcube.sh is used to execute CUBEs and/or COMMANDs on one or more HOSTs.
  
  A CUBE is a shell script or directory containing shell scripts. The CUBE
  is rsync'ed to each HOST. If CUBE is a shell script, it's executed. If
  CUBE is a directory, a shell script of the same name in that directory
  is executed.
  
  Both CUBEs and COMMANDs may execute any of the functions defined in the
  "Public APIs" in the posixcube.sh script. Short descriptions of the functions
  follows. See the source comments above each function for details.
  
  * cube_log: Print $1 to stdout with a newline using printf (args in $*).

Examples:

  ./posixcube.sh -u root -h socrates -h seneca uptime
  
    Run the \`uptime\` command on hosts \`socrates\` and \`seneca\`
    as the user \`root\`.
  
  ./posixcube.sh -h socrates -c server_check.sh
  
    Run the \`server_check.sh\` cube (script) on the \`socrates\` host.
  
  ./posixcube.sh -h web*.test.com uptime
  
    Run the \`uptime\` command on all hosts matching the regular expression
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

# Description:
#   Print $1 to stdout prefixed with [`date`] and suffixed with a newline.
# Example call:
#   cube_log "Hello World"
# Example output:
#   [Sun Dec 18 09:40:22 PST 2016] Hello World
# Arguments:
#   Required:
#     $1: String to print (printf-compatible)
#   Optional: 
#     $2: printf arguments 
cube_log () {
  cuge_log_str=$1
  shift
  printf "[`date`] ${cuge_log_str}\n" ${*}
}

################################
# Core internal implementation #
################################

# If we're being sourced on the remote machine, then we don't want to run any of the below
if [ "${POSIXCUBE_SOURCED}" = "" ]; then
  p666_color_reset="\x1B[0m"
  p666_color_red="\x1B[31m"
  p666_color_green="\x1B[32m"

  p666_debug=0
  p666_quiet=0
  p666_hosts=""
  p666_cubes=""
  p666_user="${USER}"
  p666_cubedir="~/posixcubes/"

  p666_show_version () {
    p666_printf "posixcube.sh version ${posixcube_version}\n"
  }

  p666_printf () {
    p666_printf_str=$1
    shift
    printf "[`date`] ${p666_printf_str}" ${*}
  }

  p666_printf_error () {
    p666_printf_str=$1
    shift
    printf "\n[`date`] ${p666_color_red}Error${p666_color_reset}: ${p666_printf_str}\n\n" ${*} 1>&2
  }

  p666_install () {
    p666_func_result=0
    if [ -d "/etc/bash_completion.d/" ]; then
      p666_autocomplete_file=/etc/bash_completion.d/posixcube_completion.sh
      
      # Autocomplete Hostnames for SSH etc.
      # by Jean-Sebastien Morisset (http://surniaulula.com/)
      
      cat <<'HEREDOC' | tee ${p666_autocomplete_file} > /dev/null
_posixcube_complete_host () {
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

  p666_process_hostname () {
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

  while getopts "?vdqih:u:c:" p666_opt; do
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

  shift `expr ${OPTIND} - 1`

  [ "$1" = "--" ] && shift

  p666_commands="${@}"

  [ ${p666_debug} -eq 1 ] && p666_printf "debug=${p666_debug}, leftovers: ${p666_commands}\n"

  if [ "${p666_hosts}" = "" ]; then
    p666_printf_error "No hosts specified with -h."
    p666_show_usage
  fi

  if [ "${p666_commands}" = "" ] && [ "${p666_cubes}" = "" ]; then
    p666_printf_error "No COMMANDs or CUBEs specified."
    p666_show_usage
  fi

  [ ${p666_debug} -eq 1 ] && p666_show_version

  p666_remote_ssh () {
    p666_remote_ssh_commands="$1"
    [ ${p666_debug} -eq 1 ] && p666_printf "[${p666_color_green}${p666_host}${p666_color_reset}]: Executing ssh ${p666_user}@${p666_host} \"${p666_remote_ssh_commands}\" ...\n"
    
    # TODO not sure how to redirect stderr into our variable while using backticks. We do this with $() but reference [2]
    # says this isn't supported with backticks on Solaris and IRIX
    p666_host_output=$(ssh ${p666_user}@${p666_host} ${p666_remote_ssh_commands} 2>&1)
    p666_host_output_result=$?
    p666_host_output_color=${p666_color_green}
    if [ ${p666_host_output_result} -ne 0 ]; then
      p666_host_output_color=${p666_color_red}
      p666_printf "[${p666_host_output_color}${p666_host}${p666_color_reset}]: Last command failed with return code ${p666_host_output_result}\n"
      [ "${p666_host_output}" = "" ] && [ ${p666_debug} -eq 1 ] && p666_host_output="Commands failed with no output."
    else
      [ "${p666_host_output}" = "" ] && [ ${p666_debug} -eq 1 ] && p666_host_output="Commands succeeded with no output."
    fi
    if [ "${p666_host_output}" != "" ]; then
      p666_printf "[${p666_host_output_color}${p666_host}${p666_color_reset}]: ${p666_host_output}\n"
    fi
  }

  p666_remote_transfer () {
    p666_remote_transfer_source="$1"
    p666_remote_transfer_dest="$2"
    [ ${p666_debug} -eq 1 ] && p666_printf "[${p666_color_green}${p666_host}${p666_color_reset}]: Executing rsync ${p666_remote_transfer_source} to ${p666_user}@${p666_host}:${p666_remote_transfer_dest} ...\n"
    
    # Don't use -a so that ownership is picked up from the specified user
    p666_host_output=$(rsync -rlpt "${p666_remote_transfer_source}" "${p666_user}@${p666_host}:${p666_remote_transfer_dest}" 2>&1)
    p666_host_output_result=$?
    p666_host_output_color=${p666_color_green}
    if [ ${p666_host_output_result} -ne 0 ]; then
      p666_host_output_color=${p666_color_red}
      p666_printf "[${p666_host_output_color}${p666_host}${p666_color_reset}]: Last command failed with return code ${p666_host_output_result}\n"
      [ "${p666_host_output}" = "" ] && [ ${p666_debug} -eq 1 ] && p666_host_output="Commands failed with no output."
    else
      [ "${p666_host_output}" = "" ] && [ ${p666_debug} -eq 1 ] && p666_host_output="Commands succeeded with no output."
    fi
    if [ "${p666_host_output}" != "" ]; then
      p666_printf "[${p666_host_output_color}${p666_host}${p666_color_reset}]: ${p666_host_output}\n"
    fi
  }

  p666_cubedir=${p666_cubedir%/}
  
  p666_script_path=$( cd "$(dirname "$0")" ; pwd -P )
  p666_script_name=$( basename "$0" )
  p666_script_path="${p666_script_path}/${p666_script_name}"
  
  p666_remote_script="${p666_cubedir}/${p666_script_name}"

  [ ${p666_debug} -eq 1 ] && p666_printf "Hosts: ${p666_hosts}\n"
  
  for p666_host in ${p666_hosts}; do
    p666_remote_ssh "[ ! -d \"${p666_cubedir}\" ] && mkdir -p ${p666_cubedir}"
    p666_remote_transfer "${p666_script_path}" "${p666_cubedir}/"
    for p666_cube in ${p666_cubes}; do
    
      [ ${p666_quiet} -eq 0 ] && p666_printf "[${p666_color_green}${p666_host}${p666_color_reset}]: Executing cube ${p666_cube} ...\n"
      
      if [ -d "${p666_cube}" ]; then
        p666_cube_name=`basename "${p666_cube}"`
        if [ -r "${p666_cube}/${p666_cube_name}.sh" ]; then
          chmod u+x ${p666_cube}/*.sh
          p666_cube=${p666_cube%/}
          p666_remote_transfer "${p666_cube}" "${p666_cubedir}/"
          p666_remote_ssh "POSIXCUBE_SOURCED=1 source ${p666_remote_script} && source ${p666_cubedir}/${p666_cube}/${p666_cube_name}.sh"
        else
          p666_printf_error "Could not find ${p666_cube_name}.sh in cube ${p666_cube} directory."
        fi
      elif [ -r "${p666_cube}" ]; then
        p666_cube_name=`basename "${p666_cube}"`
        chmod u+x "${p666_cube}"
        p666_remote_transfer "${p666_cube}" "${p666_cubedir}/"
        p666_remote_ssh "POSIXCUBE_SOURCED=1 source ${p666_remote_script} && source ${p666_cubedir}/${p666_cube_name}"
      elif [ -r "${p666_cube}.sh" ]; then
        p666_cube_name=`basename "${p666_cube}.sh"`
        chmod u+x "${p666_cube}.sh"
        p666_remote_transfer "${p666_cube}.sh" "${p666_cubedir}/"
        p666_remote_ssh "POSIXCUBE_SOURCED=1 source ${p666_remote_script} && source ${p666_cubedir}/${p666_cube_name}"
      else
        p666_printf_error "Cube ${p666_cube} could not be found as a directory or script, or you don't have read permissions."
      fi
    done
    if [ "${p666_commands}" != "" ]; then
      [ ${p666_quiet} -eq 0 ] && p666_printf "[${p666_color_green}${p666_host}${p666_color_reset}]: Executing COMMAND(s) ...\n"
      
      p666_remote_ssh "POSIXCUBE_SOURCED=1 source ${p666_remote_script} && ${p666_commands}"
    fi
  done
fi
