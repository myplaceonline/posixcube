#!/bin/sh
# shellcheck disable=SC1117

# posixcube.sh
#   A POSIX compliant, shell script-based server automation framework.

POSIXCUBE_VERSION=0.2.1

# On why we don't use `set -e` or `set -u`, see the Philosophy section, #2.

p_show_usage() {
  if [ ${#} -ne 0 ]; then
    p_printf_error "${@}"
  fi

  cat <<'HEREDOC'
usage: posixcube.sh -h HOST... [-l] [-c CUBE_DIR...] [OPTION]... COMMAND...

  A POSIX compliant, shell script-based server automation framework.

  -?        Help.
  -a        If using Bash, asynchronously execute remote CUBEs/COMMANDs.
  -b        If using Bash, install programmable tab completion for SSH hosts.
  -c CUBE   Execute a cube. Option may be specified multiple times. If COMMANDS
            are also specified, cubes are run first.
  -d        Print debugging information.
  -D CMD    Use `CMD` as the superuser command instead of `sudo`.
  -e ENVAR  Shell script with environment variable assignments which is
            uploaded and sourced on each HOST. Option may be specified
            multiple times. Files ending with .enc will be decrypted
            temporarily. If not specified, defaults to envars*sh envars*sh.enc
  -F FILE   SSH `-F` option.
  -h HOST   Target host. Option may be specified multiple times. The HOST may
            be preceded with USER@ to specify the remote user. If a host has
            a wildcard ('*'), then HOST is interpeted as a regular expression,
            with '*' replaced with '.*' and any matching hosts in the following
            files are added to the HOST list: /etc/ssh_config,
            /etc/ssh/ssh_config, ~/.ssh/config, /etc/ssh_known_hosts,
            /etc/ssh/ssh_known_hosts, ~/.ssh/known_hosts, and /etc/hosts.
  -i FILE   SSH `-i` option for identity file.
  -k        Keep the cube_exec.sh generated script.
  -l        Local execution. Instead of (or in addition to) `-h HOST`s or a
            sub-COMMAND, run the `-c` cubes or `COMMAND`s locally.
  -o K=V    SSH `-o` option. Option may be specified multiple times. Defaults
            to `-o ConnectTimeout=5`.
  -O P=V    Set the specified variable P with the value V. Option may be
            specified multiple times. Do not put double quotes around V. If
            V contains *, replace with matching hosts per the -h algorithm.
  -p PORT   SSH `-p` option.
  -P PWD    Password for decrypting .enc ENVAR files.
  -q        Quiet; minimize output.
  -r ROLE   Role name. Option may be specified multiple times.
  -R        Use `rsync` instead of scp.
  -s        Skip remote host initialization (making ~/.posixcube, uploading
            posixcube.sh, etc.). Assumes at least one run completed without -s.
            Does not support encrypted ENVAR files.
  -S        Run cube_package and cube_service APIs as superuser.
  -t        SSH `-t` option.
  -u USER   SSH user. Defaults to ${USER}. This may also be specified in HOST.
  -U CUBE   Upload a CUBE but do not execute it. This is needed when one CUBE
            includes this CUBE using cube_include.
  -v        Show version information.
  -w PWDF   File that contains the password for decrypting .enc ENVAR files.
            Defaults to ~/.posixcube.pwd
  -z SPEC   Use the SPEC set of options from the ./cubespecs.ini file
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
  is transferred to each HOST. If CUBE is a shell script, it's executed. If
  CUBE is a directory, a shell script of the same name in that directory
  is executed. In both cases, the directory is changed to the directory
  containing the script before execution so that you may reference files
  such as templates using relative paths.
  
  An ENVAR script is encouraged to use environment variable names of the form
  cubevar_${uniquecontext}_envar="value". If a CUBE directory contains the
  file `envars.sh`, it's sourced before anything else (including `-e ENVARs`).
  
  Both CUBEs and COMMANDs may execute any of the functions defined in the
  "Public APIs" in the posixcube.sh script. Short descriptions of the
  functions are in the APIs section below. See the source comments above each
  function for details.
  
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
  
  posixcube.sh -S -h plato@socrates cube_package install atop
  
    As the remote user `plato` on the host `socrates`, install the package
    `atop`. The `-S` option is required to run the commands within
    cube_package as the superuser (see the Philosophy section, #3).
  
  posixcube.sh -h root@socrates -h seneca uptime
  
    Run the `uptime` command on hosts `socrates` and `seneca`
    as the user `root`.
  
  posixcube.sh -h web*.test.com uptime
  
    Run the `uptime` command on all hosts matching the regular expression
    web.*.test.com in the SSH configuration files.
  
  sudo posixcube.sh -b && . /etc/bash_completion.d/posixcube_completion.sh
  
    For Bash users, install a programmable completion script to support tab
    auto-completion of hosts from SSH configuration files.

  posixcube.sh -e production.sh.enc show
  
    Decrypt and show the contents of production.sh
  
  posixcube.sh -e production.sh.enc edit
  
    Decrypt, edit, and re-encrypt the contents of production.sh with $EDITOR

  posixcube.sh -i ~/.ssh/plato -o LogLevel=VERBOSE -o ConnectTimeout=30 \
               -h plato@socrates uptime
  
    Run the `uptime` command on host `socrates` as the remote user `plato`
    using the SSH identity file ~/.ssh/plato and specifying the SSH options
    LogLevel=VERBOSE and ConnectTimeout=30
  
Philosophy:

  1. Fail hard and fast. In principle, a well written script would check ${?}
  after each command and either gracefully handle it, or report an error.
  Few people write scripts this well, so we enforce this check (using
  `cube_check_return` within all APIs) and we encourage you to do the same;
  for example, `touch /etc/fstab || cube_check_return`. All cube_*
  APIs are guaranteed to do their own checks, so you don't have to do this
  for those calls; however, note that if you're executing a cube_* API in a
  sub-shell, although any failures will be reported by cube_check_return,
  the script will continue unless you also check the return of the sub-shell.
  For example: $(cube_readlink /etc/localtime) || cube_check_return
  
  With this strategy, unfortunately, piping becomes more difficult. There are
  non-standard mechanisms like pipefail and PIPESTATUS, but the standardized
  approach is to run each command separately and check the status. For example:
  
  cubevar_app_x="$(cmd1)" || cube_check_return
  cubevar_app_y="$(printf '%s' "${cubevar_app_x}" | cmd2)" || cube_check_return
  
  2. We don't use `set -e` because some functions may handle all errors
  internally (with `cube_check_return`) and use a positive return code as a
  "benign" result (e.g. `cube_set_file_contents`). We don't use `set -u`
  because we source in the user's scripts and they may not want this behavior.
  
  3. Recent versions of many distributions encourage running most commands
  as a non-superuser, and then using `sudo` if needed, with some distributions
  disallowing remote SSH using the `root` account by default. First, the `sudo`
  command is not standardized (see https://unix.stackexchange.com/a/48553).
  Moreoever, it is not enough to prefix posixcube APIs with `sudo` because
  `sudo` doesn't pass along functions (even if they're exported and `sudo` is
  executed with --preserve-env). `su -c` may be used but it requires
  password input. For the most common use case of requiring `sudo` for
  cube_package and cube_service, if `-S` is specified, the commands within
  those APIs are executed using `sudo`. If you need to run something else as a
  superuser and you need access to the posixcube APIs, see the `cube_sudo` API.

Frequently Asked Questions:

  * Why is there a long delay between "Preparing hosts" and the first remote
    execution?
  
    You can see details of what's happening with the `-d` flag. By default,
    the script first loops through every host and ensures that ~/.posixcube/
    exists, then it transfers itself to the remote host. These two actions
    may be skipped with the `-s` parameter if you've already run the script
    at least once and your version of this script hasn't been updated. Next,
    the script loops through every host and transfers any CUBEs and a script
    containing the CUBEs and COMMANDs to run (`cube_exec.sh`). If the shell
    is detected to be `bash`, then the above occurs asynchronously across the
    HOSTs. Finally, you'll see the "Executing on HOST..." line and the real
    execution starts.

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
      Example: cube_error_echo "Goodbye World"

  * cube_error_printf
      Same as cube_printf except output to stderr and include a red "Error: "
      message prefix.
      Example: cube_error_printf "Goodbye World from PID %5s" $$

  * cube_warning_echo
      Same as cube_echo except output to stderr and include a yellow
      "Warning: " message prefix.
      Example: cube_warning_echo "Watch out, World"

  * cube_warning_printf
      Same as cube_printf except output to stderr and include a yellow
      "Warning: " message prefix.
      Example: cube_warning_printf "Watch out, World from PID %5s" $$

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
      Pass $@ to the package manager. Implicitly passes the parameter
      to say yes to questions. On Debian-based systems, uses --force-confold
      Example: cube_package install python

  * cube_package_uninstall
      Same as cube_package, except that you only specify the packages
      to uninstall, and this will figure out the right operation to
      pass to the package manager (e.g. dnf=remove, apt=purge).
      Example: cube_package_uninstall python

  * cube_append_str
      Print $1 to stdout with $2 appended after a space if $1 was not blank.
      Example: cubevar_app_str=$(cube_append_str "${cubevar_app_str}" "Test")

  * cube_element_exists
      Check if $1 contains the $2 element with the $3 delimiter (default space).
      Example: cube_element_exists "${cubevar_str}" "X"

  * cube_elements_count
      Print to stdout the number of elements in the string $1 as separated by
      the delimeter $2 (default space).
      Example: cubevar_app_count=$(cube_elements_count "${cubevar_str}")

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

  * cube_operating_system_version_major
      Returns the major version of the operating system distribution.
      Example: [ $(cube_operating_system_version_major) -gt 10 ] && ...

  * cube_operating_system_version_minor
      Returns the minor version of the operating system distribution.
      Example: [ $(cube_operating_system_version_minor) -gt 10 ] && ...

  * cube_operating_system_has_flavor
      Check if the operating system flavor includes the flavor specified in $1
      by one of the POSIXCUBE_OS_FLAVOR_* values.
      Example: cube_operating_system_has_flavor ${POSIXCUBE_OS_FLAVOR_FEDORA} \
                 && ...

  * cube_shell
      Detect running shell and return one of the CUBE_SHELL_* values.
      Example: [ $(cube_shell) -eq ${POSIXCUBE_SHELL_BASH} ] && ...

  * cube_current_script_name
      Print to stdout the basename of the currently executing script.
      Example: script_name=$(cube_current_script_name)

  * cube_current_script_abs_path
      Print to stdout the absolute path the currently executing script.
      Example: script_name=$(cube_current_script_abs_path)

  * cube_file_size
      Print to stdout the size of a file $1 in bytes
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
      Print stdin to stdout with all ${VAR}'s evaluated (except for \${VAR})
      Example: cube_expand_parameters < template > output

  * cube_readlink
      Print to stdout the absolute path of $1 without any symbolic links.
      Example: cube_readlink /etc/localtime

  * cube_random_number
      Print to stdout a random number between 1 and $1
      Example: cube_random_number 10

  * cube_tmpdir
      Print to stdout a temporary directory
      Example: cube_tmpdir

  * cube_total_memory
      Print to stdout total system memory in bytes
      Example: cube_total_memory

  * cube_ensure_directory
      Ensure directory $1, and parent directories, exist. Return true if the
      directory is created; otherwise, false.
      Example: cube_ensure_directory ~/.ssh/

  * cube_ensure_file
      Ensure file $1, and parent directories, exist. Return true if the file is
      created; otherwise, false.
      Example: cube_ensure_file ~/.ssh/authorized_keys

  * cube_pushd
      Add the current directory to a stack of directories and change directory
      to ${1}
      Example: cube_pushd ~/.ssh/

  * cube_popd
      Pop the top of the stack of directories from `cube_pushd` and change
      directory to that directory.
      Example: cube_popd

  * cube_has_role
      Return true if the role $1 is set.
      Example: cube_has_role "database_backup"

  * cube_file_contains
      Check if the file $1 contains $2. Uses grep with default arguments
      (e.g. regex).
      Example: cube_file_contains /etc/fstab nfsmount

  * cube_stdin_contains
      Check if stdin contains $1
      Example: echo "Hello World" | cube_stdin_contains "Hello"

  * cube_interface_ipv4_address
      Print to stdout the IPv4 address of interface $1
      Example: cube_interface_ipv4_address eth0

  * cube_interface_ipv6_address
      Print to stdout the IPv6 address of interface $1
      Example: cube_interface_ipv6_address eth0

  * cube_prompt
      Prompt the question $1 followed by " (y/N)" and prompt for an answer.
      A blank string answer is equivalent to No. Return true if yes, false
      otherwise.
      Example: cube_prompt "Are you sure?"

  * cube_hostname
      Print to stdout the full hostname.
      Example: cube_hostname

  * cube_string_contains
      Return true if $1 contains $2; otherwise, false.
      Example: cube_string_contains "${cubevar_app_str}" "@" && ...
  
  * cube_string_substring_before
      Print to stdout a substring of $1 strictly before the first match of the
      regular expression $2.
      Example: cubevar_app_x="$(cube_string_substring_before "${somevar}" "@")"

  * cube_string_substring_after
      Print to stdout a substring of $1 strictly after the first match of the
      regular expression $2.
      Example: cubevar_app_x="$(cube_string_substring_after "${somevar}" "@")"
  
  * cube_sudo
      Execute $* as superuser with all posixcube APIs available
      (see Philosophy #3).
      Example: cube_sudo cube_ensure_file /etc/app.txt
  
  * cube_read_stdin
      Read stdin (e.g. HEREDOC) into the variable named by the first argument.

  * cube_ensure_user
      Create the user $1 if it doesn't already exist (with group name $1)
      Example: cube_ensure_user nginx

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
  
  * cube_current_user
      Print to stdout the current user
      Example: cube_current_user
  
  * cube_user_home_dir
      Print to stdout the home directory of user $1 (defaults to
      `cube_current_user`)
      Example: cube_user_home_dir root
  
  * cube_user_ensure_private_key
      Ensure the SSH private key contents $1 are placed in a file named $2
      (defaults to `id_rsa`) for the user $3 (defaults to `cube_current_user`)
      Example: cube_user_ensure_private_key "${cubevar_app_key1_private}"
  
  * cube_user_ensure_authorized_public_key
      Ensure the SSH public key contents $1 exist in the `.ssh/authorized_keys`
      file in the home directory of user $2 (defaults to `cube_current_user`)
      Example: cube_user_ensure_authorized_public_key "${cubevar_app_key1_pub}"
  
  * cube_user_authorize_known_host
      Ensure the public key(s) of the host $1 are in the `.ssh/known_hosts` file
      in the home directory of user $2 (defaults to `cube_current_user`). Note:
      the fingerprints are currently not checked, but you may review STDOUT.
      To reduce the risks of MITM attacks, you can call this only after a
      successful call to `cube_user_ensure_private_key` so that the scan is
      only done once on private key setup.
      Example: cube_user_ensure_private_key "${cubevar_app_host_privkey}" && \
                 cube_user_authorize_known_host some_host
  
Public Variables:

  * POSIXCUBE_APIS_ONLY
      Set this to any value to only source the public APIs in posixcube.sh.
      Example: POSIXCUBE_APIS_ONLY=true . posixcube.sh && cube_echo \
                 $(cube_random_number 10)
  
  * POSIXCUBE_SOURCED
      Set this to any value to only run a sub-COMMAND, most commonly `source`,
      to source in all ENVAR files, but skip actual execution of posixcube.
      Example: POSIXCUBE_SOURCED=true . posixcube.sh source; \
                 POSIXCUBE_SOURCED= ; cube_echo Test

Source: https://github.com/myplaceonline/posixcube
HEREDOC

  if [ $# -ne 0 ]; then
    p_printf_error "${@}"
  fi

  if [ "${POSIXCUBE_SOURCED}" = "" ]; then
    exit 1
  fi
}

###############
# Public APIs #
###############

export POSIXCUBE_NEWLINE="
"
export POSIXCUBE_CUBE_NAME=""
export POSIXCUBE_CUBE_NAME_WITH_PREFIX=""

export POSIXCUBE_OS_LINUX=1
export POSIXCUBE_OS_MAC_OSX=2
export POSIXCUBE_OS_WINDOWS=3
export POSIXCUBE_OS_OPENBSD=4

export POSIXCUBE_OS_FLAVOR_UNKNOWN=-1
export POSIXCUBE_OS_FLAVOR_FEDORA=1
export POSIXCUBE_OS_FLAVOR_DEBIAN=2
export POSIXCUBE_OS_FLAVOR_UBUNTU=3
export POSIXCUBE_OS_FLAVOR_RHEL=4
export POSIXCUBE_OS_FLAVOR_CENTOS=5
export POSIXCUBE_OS_FLAVOR_VOID=6

export POSIXCUBE_SHELL_UNKNOWN=-1
export POSIXCUBE_SHELL_BASH=1

export POSIXCUBE_TRANSFER_SCP="scp -rCpq"
export POSIXCUBE_TRANSFER_RSYNC="rsync -rlpt" # Don't use -a on rsync so that
                                              # ownership is picked up from the
                                              # specified user

# shellcheck disable=SC2088
export POSIXCUBE_CACHE_DIRECTORY="~/.posixcube/"

export POSIXCUBE_COLOR_RESET=""
export POSIXCUBE_COLOR_RED=""
export POSIXCUBE_COLOR_GREEN=""
export POSIXCUBE_COLOR_YELLOW=""
export POSIXCUBE_COLOR_BLUE=""
export POSIXCUBE_COLOR_PURPLE=""
export POSIXCUBE_COLOR_CYAN=""
export POSIXCUBE_COLOR_WHITE=""

# http://unix.stackexchange.com/a/10065
if [ -t 1 ]; then
  tput_colors_output=$(tput colors)
  if [ -n "${tput_colors_output}" ] && [ "${tput_colors_output}" -ge 8 ]; then
    # Separate exports due to https://github.com/koalaman/shellcheck/wiki/SC2155
    POSIXCUBE_COLOR_RESET="$(tput sgr0)" || echo "Failure calling tput"
    export POSIXCUBE_COLOR_RESET
    POSIXCUBE_COLOR_RED="$(tput setaf 1)" || echo "Failure calling tput"
    export POSIXCUBE_COLOR_RED
    POSIXCUBE_COLOR_GREEN="$(tput setaf 2)" || echo "Failure calling tput"
    export POSIXCUBE_COLOR_GREEN
    POSIXCUBE_COLOR_YELLOW="$(tput setaf 3)" || echo "Failure calling tput"
    export POSIXCUBE_COLOR_YELLOW
    POSIXCUBE_COLOR_BLUE="$(tput setaf 4)" || echo "Failure calling tput"
    export POSIXCUBE_COLOR_BLUE
    POSIXCUBE_COLOR_PURPLE="$(tput setaf 5)" || echo "Failure calling tput"
    export POSIXCUBE_COLOR_PURPLE
    POSIXCUBE_COLOR_CYAN="$(tput setaf 6)" || echo "Failure calling tput"
    export POSIXCUBE_COLOR_CYAN
    POSIXCUBE_COLOR_WHITE="$(tput setaf 7)" || echo "Failure calling tput"
    export POSIXCUBE_COLOR_WHITE
  fi
elif [ "${POSIXCUBE_COLORS}" != "" ]; then
  export POSIXCUBE_COLOR_RESET="\x1B[0m"
  export POSIXCUBE_COLOR_RED="\x1B[31m"
  export POSIXCUBE_COLOR_GREEN="\x1B[32m"
  export POSIXCUBE_COLOR_YELLOW="\x1B[33m"
  export POSIXCUBE_COLOR_BLUE="\x1B[34m"
  export POSIXCUBE_COLOR_PURPLE="\x1B[35m"
  export POSIXCUBE_COLOR_CYAN="\x1B[36m"
  export POSIXCUBE_COLOR_WHITE="\x1B[37m"
fi

cubevar_api_debug=0
cubevar_api_superuser=""
cubevar_api_superuser_command=""
cubevar_api_node_hostname="$(hostname)"

#############
# Functions #
#############

# Print ${@} to stdout prefixed with ([$(date)] [$(hostname)]) and suffixed with
# a newline.
#
# Example:
#   cube_echo "Hello World"
# Example output:
#   [Sun Dec 18 09:40:22 PST 2016] [socrates] Hello World
# Arguments: ${@} passed to echo
cube_echo() {
  if [ "${POSIXCUBE_CUBE_NAME_WITH_PREFIX}" = "" ]; then
    # shellcheck disable=SC2059
    printf "[$(date)] [${POSIXCUBE_COLOR_GREEN}${cubevar_api_node_hostname}${POSIXCUBE_COLOR_RESET}] "
  else
    # shellcheck disable=SC2059
    printf "[$(date)] [${POSIXCUBE_COLOR_GREEN}${cubevar_api_node_hostname}${POSIXCUBE_COLOR_RESET}${POSIXCUBE_COLOR_CYAN}${POSIXCUBE_CUBE_NAME_WITH_PREFIX}$(cube_line_number ":")${POSIXCUBE_COLOR_RESET}] "
  fi
  echo "${@}"
}

# Print $1 to stdout prefixed with ([$(date)] [$(hostname)]) and suffixed with
# a newline.
#
# Example:
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
    # shellcheck disable=SC2059
    printf "[$(date)] [${POSIXCUBE_COLOR_GREEN}${cubevar_api_node_hostname}${POSIXCUBE_COLOR_RESET}] ${cube_printf_str}\n" "${@}"
  else
    # shellcheck disable=SC2059
    printf "[$(date)] [${POSIXCUBE_COLOR_GREEN}${cubevar_api_node_hostname}${POSIXCUBE_COLOR_RESET}${POSIXCUBE_COLOR_CYAN}${POSIXCUBE_CUBE_NAME_WITH_PREFIX}$(cube_line_number ":")${POSIXCUBE_COLOR_RESET}] ${cube_printf_str}\n" "${@}"
  fi
}

# Print ${@} to stderr prefixed with ([$(date)] [$(hostname)] Error: ) and
# suffixed with a newline.
#
# Example:
#   cube_error_echo "Goodbye World"
# Example output:
#   [Sun Dec 18 09:40:22 PST 2016] [socrates] Error: Goodbye World
# Arguments: ${@} passed to echo
cube_error_echo() {
  if [ "${POSIXCUBE_CUBE_NAME_WITH_PREFIX}" = "" ]; then
    # shellcheck disable=SC2059
    printf "[$(date)] [${POSIXCUBE_COLOR_RED}${cubevar_api_node_hostname}${POSIXCUBE_COLOR_RESET}] ${POSIXCUBE_COLOR_RED}Error${POSIXCUBE_COLOR_RESET}: " 1>&2
  else
    # shellcheck disable=SC2059
    printf "[$(date)] [${POSIXCUBE_COLOR_RED}${cubevar_api_node_hostname}${POSIXCUBE_CUBE_NAME_WITH_PREFIX}$(cube_line_number ":")${POSIXCUBE_COLOR_RESET}] ${POSIXCUBE_COLOR_RED}Error${POSIXCUBE_COLOR_RESET}: " 1>&2
  fi
  echo "${@}" 1>&2
}

# Print $1 to stderr prefixed with ([$(date)] [$(hostname)] Error: ) and
# suffixed with a newline.
#
# Example:
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
    # shellcheck disable=SC2059
    printf "[$(date)] [${POSIXCUBE_COLOR_RED}${cubevar_api_node_hostname}${POSIXCUBE_COLOR_RESET}] ${POSIXCUBE_COLOR_RED}Error${POSIXCUBE_COLOR_RESET}: ${cube_error_printf_str}\n" "${@}" 1>&2
  else
    # shellcheck disable=SC2059
    printf "[$(date)] [${POSIXCUBE_COLOR_RED}${cubevar_api_node_hostname}${POSIXCUBE_CUBE_NAME_WITH_PREFIX}$(cube_line_number ":")${POSIXCUBE_COLOR_RESET}] ${POSIXCUBE_COLOR_RED}Error${POSIXCUBE_COLOR_RESET}: ${cube_error_printf_str}\n" "${@}" 1>&2
  fi
}

# Print ${@} to stderr prefixed with ([$(date)] [$(hostname)] Warning: ) and
# suffixed with a newline.
#
# Example:
#   cube_warning_echo "Watch out, World"
# Example output:
#   [Sun Dec 18 09:40:22 PST 2016] [socrates] Warning: Watch out, World
# Arguments: ${@} passed to echo
cube_warning_echo() {
  if [ "${POSIXCUBE_CUBE_NAME_WITH_PREFIX}" = "" ]; then
    # shellcheck disable=SC2059
    printf "[$(date)] [${POSIXCUBE_COLOR_YELLOW}${cubevar_api_node_hostname}${POSIXCUBE_COLOR_RESET}] ${POSIXCUBE_COLOR_YELLOW}Warning${POSIXCUBE_COLOR_RESET}: " 1>&2
  else
    # shellcheck disable=SC2059
    printf "[$(date)] [${POSIXCUBE_COLOR_YELLOW}${cubevar_api_node_hostname}${POSIXCUBE_CUBE_NAME_WITH_PREFIX}$(cube_line_number ":")${POSIXCUBE_COLOR_RESET}] ${POSIXCUBE_COLOR_YELLOW}Warning${POSIXCUBE_COLOR_RESET}: " 1>&2
  fi
  echo "${@}" 1>&2
}

# Print $1 to stderr prefixed with ([$(date)] [$(hostname)] Warning: ) and
# suffixed with a newline.
#
# Example:
#   cube_warning_printf "Watch out, World from PID %5s" $$
# Example output:
#   [Sun Dec 18 09:40:22 PST 2016] [socrates] Watch out, World from PID   123
# Arguments:
#   Required:
#     $1: String to print (printf-compatible)
#   Optional:
#     $2: printf arguments
cube_warning_printf() {
  cube_warning_printf_str=$1; shift
  if [ "${POSIXCUBE_CUBE_NAME_WITH_PREFIX}" = "" ]; then
    # shellcheck disable=SC2059
    printf "[$(date)] [${POSIXCUBE_COLOR_YELLOW}${cubevar_api_node_hostname}${POSIXCUBE_COLOR_RESET}] ${POSIXCUBE_COLOR_YELLOW}Warning${POSIXCUBE_COLOR_RESET}: ${cube_warning_printf_str}\n" "${@}" 1>&2
  else
    # shellcheck disable=SC2059
    printf "[$(date)] [${POSIXCUBE_COLOR_YELLOW}${cubevar_api_node_hostname}${POSIXCUBE_CUBE_NAME_WITH_PREFIX}$(cube_line_number ":")${POSIXCUBE_COLOR_RESET}] ${POSIXCUBE_COLOR_YELLOW}Warning${POSIXCUBE_COLOR_RESET}: ${cube_error_printf_str}\n" "${@}" 1>&2
  fi
}

# Print $1 and a stack of functions and processes (if available) with
# cube_error_echo and then call `exit 1`.
#
# Example:
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
      # shellcheck disable=SC2039
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
      x=$((x+1))
    done
  fi
  
  # http://stackoverflow.com/a/1438241/5657303
  if [ -r /proc/${cube_throw_pid}/cmdline ]; then
    while true
    do
      # shellcheck disable=SC2002
      cube_throw_cmdline=$(cat /proc/${cube_throw_pid}/cmdline | tr -d '\0')
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

# Skipping any call stack frames in posixcube.sh, return the line number of the calling stack frame
#
# Example:
#   cube_line_number
# Arguments:
#   Optional:
#     $1: If a result is returned, prepend with $1
cube_line_number() {
  if cube_command_exists caller ; then
    x=0
    while true; do
      # shellcheck disable=SC2039
      cube_api_caller_output=$(caller $x)
      cube_api_caller_result=${?}
      if [ ${cube_api_caller_result} -eq 0 ]; then
        cube_api_caller_result_lineno=$(echo "${cube_api_caller_output}" | awk '{ print $1 }')
        #cube_api_caller_result_subroutine=$(echo "${cube_api_caller_output}" | awk '{ print $2 }')
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
      x=$((x+1))
    done
  fi
}

# Check if $? is non-zero and call cube_throw if so.
#
# Example:
#   some_command || cube_check_return
# Arguments:
#   Optional:
#     $*: Additional information to include in the error message.
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

# Echo $1 with $2 appended after a space if $1 was not blank.
#
# Example:
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

# Check if $1 contains the $2 element with the $3 delimiter (default space).
#
# Example:
#   cube_element_exists "${cubevar_str}" "X"
# Arguments:
#   Required:
#     $1: String of elements separated by $3
#     $2: Element to search for
#   Optional:
#     $3: Delimeter (default space)
cube_element_exists() {
  cube_check_numargs 2 "${@}"
  
  if [ "${3}" != "" ]; then
    cube_throw "Not implemented (cube_element_exists)."
  fi
  
  for cube_element_exists_element in ${1}; do
    if [ "${cube_element_exists_element}" = "${2}" ]; then
      return 0
    fi
  done

  return 1
}

# Print to stdout the number of elements in the string $1 as separated by the delimeter $2 (default space).
#
# Example:
#   cubevar_app_count=$(cube_elements_count "${cubevar_str}")
# Arguments:
#   Required:
#     $1: String of elements separated by $2
#   Optional:
#     $2: Delimeter (default space)
cube_elements_count() {
  cube_check_numargs 1 "${@}"
  
  if [ "${2}" != "" ]; then
    cube_throw "Not implemented (cube_elements_count)."
  fi
  
  cube_elements_count_result=0
  
  # shellcheck disable=SC2034
  for cube_elements_count_element in ${1}; do
    cube_elements_count_result=$((cube_elements_count_result+1))
  done

  echo ${cube_elements_count_result}
}

# Check if $1 command or function exists in the current context.
#
# Example:
#   cube_command_exists systemctl
# Arguments:
#   Required:
#     $1: Command or function name.
cube_command_exists() {
  cube_check_numargs 1 "${@}"
  command -v "${1}" >/dev/null 2>&1
}

# Check if $1 exists as a directory.
#
# Example:
#   cube_dir_exists /etc/cron.d/
# Arguments:
#   Required:
#     $1: Directory name.
cube_dir_exists() {
  cube_check_numargs 1 "${@}"
  [ -d "${1}" ]
}

# Check if $1 exists as a file with read access.
#
# Example:
#   cube_file_exists /etc/cron.d/0hourly
# Arguments:
#   Required:
#     $1: File name.
cube_file_exists() {
  cube_check_numargs 1 "${@}"
  [ -r "${1}" ]
}

# Detect operating system and return one of the POSIXCUBE_OS_* values.
#
# Example:
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
    OpenBSD)
      echo ${POSIXCUBE_OS_OPENBSD}
      ;;
    *)
      cube_throw "Unknown operating system $(uname -s)"
      ;;
  esac
}

# Check if the operating system flavor includes the flavor specified in $1 by one of the POSIXCUBE_OS_FLAVOR_* values.
# Flavors are inherited. For example, checking for FEDORA on RHEL/CentOS, or DEBIAN on Ubuntu, will return true.
#
# Example:
#   if cube_operating_system_has_flavor ${POSIXCUBE_OS_FLAVOR_FEDORA} ; then ...
# Arguments:
#   Required:
#     $1: One of the POSIXCUBE_OS_FLAVOR_* values.
cube_operating_system_has_flavor() {
  cube_check_numargs 1 "${@}"
  case "${1}" in
    ${POSIXCUBE_OS_FLAVOR_FEDORA})
      if cube_file_exists "/etc/fedora-release" || cube_file_exists "/etc/redhat-release"; then
        return 0
      fi
      ;;
    ${POSIXCUBE_OS_FLAVOR_RHEL})
      if cube_file_exists "/etc/redhat-release" && cube_file_contains /etc/redhat-release "Red Hat Enterprise"; then
        return 0
      fi
      ;;
    ${POSIXCUBE_OS_FLAVOR_CENTOS})
      if cube_file_exists "/etc/redhat-release" && cube_file_contains /etc/redhat-release "CentOS"; then
        return 0
      fi
      ;;
    ${POSIXCUBE_OS_FLAVOR_UBUNTU})
      if cube_file_exists "/etc/os-release" && cube_file_contains /etc/os-release "Ubuntu"; then
        return 0
      fi
      ;;
    ${POSIXCUBE_OS_FLAVOR_DEBIAN})
      if cube_file_exists "/etc/debian_version"; then
        return 0
      fi
      ;;
    ${POSIXCUBE_OS_FLAVOR_VOID})
      if cube_file_exists "/etc/os-release" && cube_file_contains /etc/os-release "void"; then
        return 0
      fi
      ;;
    *)
      cube_throw "Unknown operating system flavor ${1}"
      ;;
  esac
  return 1
}

# Returns the major version of the operating system distribution.
#
# Example:
#   if [ $(cube_operating_system_version_major) -gt 10 ]; then ...
# Arguments: None
cube_operating_system_version_major() {
  if cube_file_exists "/etc/centos-release"; then
    sed 's/.*release \([0-9]\+\).*/\1/g' /etc/centos-release
  elif cube_file_exists "/etc/redhat-release"; then
    sed 's/.*release \([0-9]\+\).*/\1/g' /etc/redhat-release
  elif cube_file_exists "/etc/os-release"; then
    grep VERSION_ID /etc/os-release | sed 's/VERSION_ID=//g' | sed 's/"//g' | sed 's/\..*//g'
  else
    cube_throw "Not implemented. Please open an issue with OS details."
  fi
}

# Returns the minor version of the operating system distribution.
#
# Example:
#   if [ $(cube_operating_system_version_minor) -gt 10 ]; then ...
# Arguments: None
cube_operating_system_version_minor() {
  if cube_file_exists "/etc/centos-release"; then
    if cube_file_contains "/etc/centos-release" "\."; then
      sed 's/.*release [0-9]\+\.\([0-9]\)\+.*/\1/g' /etc/centos-release
    else
      echo "0"
    fi
  elif cube_file_exists "/etc/redhat-release"; then
    if cube_file_contains "/etc/redhat-release" "\."; then
      sed 's/.*release [0-9]\+\.\([0-9]\)\+.*/\1/g' /etc/redhat-release
    else
      echo "0"
    fi
  elif cube_operating_system_has_flavor ${POSIXCUBE_OS_FLAVOR_DEBIAN}; then
    grep VERSION_ID /etc/os-release | sed 's/VERSION_ID=//g' | sed 's/"//g' | sed 's/.*\.0*//g'
  elif cube_operating_system_has_flavor ${POSIXCUBE_OS_FLAVOR_FEDORA}; then
    echo "0"
  else
    cube_throw "Not implemented. Please open an issue with OS details."
  fi
}

# Detect current shell and return one of the CUBE_SHELL_* values.
#
# Example:
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

# Throw an error if there are fewer than $1 arguments.
#
# Example:
#   cube_check_numargs 2 "${@}"
# Arguments:
#   Required:
#     $1: String to print (printf-compatible)
#     $@: Arguments to check
cube_check_numargs() {
  cube_check_numargs_expected=$1; shift
  [ ${#} -lt "${cube_check_numargs_expected}" ] && cube_throw "Expected ${cube_check_numargs_expected} arguments, received ${#}."
  return 0
}

# Run the $1 action on the $2 service.
#
# Example:
#   cube_service start crond
# Arguments:
#   Required:
#     $1: Action name supported by $2 (e.g. start, stop, restart, enable, etc.)
#     $2: Service name.
cube_service() {
  cube_check_numargs 1 "${@}"
  if [ "${2}" != "" ]; then
    case "${1}" in
      stop)
        cube_service_verb="stopping"
        ;;
      enable)
        cube_service_verb="enabling"
        ;;
      disable)
        cube_service_verb="disabling"
        ;;
      *)
        cube_service_verb="${1}ing"
        ;;
    esac
    cube_echo "$(echo "${cube_service_verb}" | cut -c1 | tr '[:lower:]' '[:upper:]')$(echo "${cube_service_verb}" | cut -c2-) $2 service"
  fi
  if cube_command_exists systemctl ; then
    if [ "${1}" = "daemon-reload" ]; then
      cube_echo "Executing ${cubevar_api_superuser} systemctl ${1}"
      ${cubevar_api_superuser} systemctl "${1}" || cube_check_return
    else
      cube_echo "Executing ${cubevar_api_superuser} systemctl ${1} ${2}"
      ${cubevar_api_superuser} systemctl "${1}" "${2}" || cube_check_return
    fi
  elif cube_command_exists service ; then
    if [ "${1}" = "enable" ]; then
      if cube_operating_system_has_flavor ${POSIXCUBE_OS_FLAVOR_FEDORA}; then
        cube_echo "Executing ${cubevar_api_superuser} chkconfig ${2} on"
        ${cubevar_api_superuser} chkconfig "${2}" on || cube_check_return
      elif cube_operating_system_has_flavor ${POSIXCUBE_OS_FLAVOR_DEBIAN}; then
        cube_echo "Executing ${cubevar_api_superuser} update-rc.d ${2} defaults"
        ${cubevar_api_superuser} update-rc.d "${2}" defaults || cube_check_return
      else
        cube_throw "Not implemented (cube_service 1)"
      fi
    elif [ "${1}" = "disable" ]; then
      if cube_operating_system_has_flavor ${POSIXCUBE_OS_FLAVOR_FEDORA}; then
        cube_echo "Executing ${cubevar_api_superuser} chkconfig ${2} off"
        ${cubevar_api_superuser} chkconfig "${2}" off || cube_check_return
      elif cube_operating_system_has_flavor ${POSIXCUBE_OS_FLAVOR_DEBIAN}; then
        cube_echo "Executing ${cubevar_api_superuser} update-rc.d -f ${2} remove"
        ${cubevar_api_superuser} update-rc.d -f "${2}" remove || cube_check_return
        cube_echo "Executing ${cubevar_api_superuser} update-rc.d ${2} stop 80 0 1 2 3 4 5 6 ."
        ${cubevar_api_superuser} update-rc.d "${2}" stop 80 0 1 2 3 4 5 6 . || cube_check_return
      else
        cube_throw "Not implemented (cube_service 1)"
      fi
    elif [ "${1}" != "daemon-reload" ]; then
      cube_echo "Executing ${cubevar_api_superuser} service ${2} ${1}"
      ${cubevar_api_superuser} service "${2}" "${1}" || cube_check_return
    fi
  elif cube_command_exists sv ; then
    if [ "${1}" = "enable" ]; then
      cube_echo "Executing ${cubevar_api_superuser} ln -s /etc/sv/${2} /var/service"
      ${cubevar_api_superuser} ln -s /etc/sv/${2} /var/service || cube_check_return
    elif [ "${1}" = "disable" ]; then
      cube_echo "Executing ${cubevar_api_superuser} rm -rf /var/service/${2}"
      ${cubevar_api_superuser} rm -rf /var/service/${2} || cube_check_return
    else
      cube_echo "Executing ${cubevar_api_superuser}  sv ${1} ${2}"
      ${cubevar_api_superuser} sv ${1} ${2}
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
    cube_echo "$(echo "${cube_service_verb}" | cut -c1 | tr '[:lower:]' '[:upper:]')$(echo "${cube_service_verb}" | cut -c2-) $2 service"
  else
    cube_echo "Executed $1"
  fi
}

# Return true if service $1 exists; otherwise, false.
#
# Example:
#   cube_service_exists kdump
# Arguments:
#   Required:
#     $1: Service name.
cube_service_exists() {
  cube_check_numargs 1 "${@}"
  if cube_command_exists systemctl ; then
    cube_service_exists_output="$(systemctl status "${1}" 2>&1)"
    echo "${cube_service_exists_output}" | grep -l loaded >/dev/null 2>&1
    return $?
  else
    cube_throw "Not implemented (cube_service_exists)"
  fi
}

# Pass $@ to the package manager. Implicitly passes the parameter
# to say yes to questions. On Debian-based systems, uses --force-confold --force-confdef.
#
# Example:
#   cube_package install python
# Arguments:
#   Required:
#     $@: Arguments to the package manager.
cube_package() {
  cube_check_numargs 1 "${@}"
  
  # shellcheck disable=SC2154,SC2235
  if [ "${cube_package_skip_update}" = "1" ] && ( [ "${1}" = "update" ] || [ "${1}" = "upgrade" ] || [ "${1}" = "upgrade" ] ); then
    cube_warning_echo "cube_package ${1} skipped because cube_package_skip_update=1"
    return 0
  fi
  
  if cube_command_exists dnf ; then
    cube_echo "Executing dnf -y ${*}"
    ${cubevar_api_superuser} dnf -y "${@}" || cube_check_return
  elif cube_command_exists yum ; then
    cube_echo "Executing yum -y ${*}"
    ${cubevar_api_superuser} yum -y "${@}" || cube_check_return
  elif cube_command_exists apt-get ; then
    cube_echo "Executing apt-get -y ${*}"

    # If another process is currently using apt, then we'll get errors such as:
    #   E: Could not get lock /var/lib/dpkg/lock - open (11: Resource temporarily unavailable)
    #   E: Unable to lock the administration directory (/var/lib/dpkg/), is another process using it?
    #   E: Could not get lock /var/lib/apt/lists/lock - open (11: Resource temporarily unavailable)
    #   E: Unable to lock directory /var/lib/apt/lists/
    # Unfortunately, apt uses two `flock`s individually, so we can't just use `flock -eow`. Separate `flock -ne`
    # return checks still required a loop because of a race condition, so instead we just repeat if we see the error.
    cube_package_iterations=0
    cube_package_max_iterations=6
    cube_package_sleep_time=10
    while [ "${cube_package_iterations}" -lt "${cube_package_max_iterations}" ]; do
      cube_package_iterations=$((cube_package_iterations+1))
      
      cube_package_tmp_file="${TMPDIR:-/tmp}/posixcube_stderr.$$"
      
      (
        export DEBIAN_FRONTEND=noninteractive
        # http://askubuntu.com/a/389933
        ${cubevar_api_superuser} apt-get -y -o Dpkg::Options::="--force-confold" -o Dpkg::Options::="--force-confdef" "${@}" 2>"${cube_package_tmp_file}"
      )
      
      cube_package_apt_result=${?}
      
      if cube_file_contains "${cube_package_tmp_file}" "E: Could not get lock /var/lib/" ; then
        rm "${cube_package_tmp_file}" || cube_check_return
        cube_warning_echo "Some apt process is currently running. Sleeping for ${cube_package_sleep_time}s. Iteration ${cube_package_iterations}/${cube_package_max_iterations}"
        sleep ${cube_package_sleep_time}
      else
        cat "${cube_package_tmp_file}" 1>&2
        rm "${cube_package_tmp_file}" || cube_check_return
        if [ ${cube_package_apt_result} -ne 0 ]; then
          cube_throw "apt command failed with code ${cube_package_apt_result}"
        fi
        return 0
      fi
    done
    cube_throw "cube_package failed because another process has f-locked /var/lib/dpkg/lock or /var/lib/apt/lists/lock"
  elif cube_command_exists xbps-install ; then
    cube_echo "Executing xbps-install -y ${*}"
    ${cubevar_api_superuser} xbps-install -y "${@}" || cube_check_return
  else
    cube_throw "cube_package has not implemented your operating system yet"
  fi
}

# Same as cube_package, except that you only specify the packages
# to uninstall, and this will figure out the right operation to
# pass to the package manager (e.g. dnf=remove, apt=purge).
#
# Example:
#   cube_package_uninstall python
# Arguments:
#   Required:
#     $@: Packages to uninstall
cube_package_uninstall() {
  cube_check_numargs 1 "${@}"

  if cube_command_exists dnf || cube_command_exists yum ; then
    cube_package remove "${@}"
  elif cube_command_exists apt-get ; then
    cube_package purge "${@}"
  elif cube_command_exists xbps-remove ; then
    cube_echo "Executing xbps-remove -y ${*}"
    ${cubevar_api_superuser} xbps-remove -y "${@}" || cube_check_return
  else
    cube_throw "cube_package_uninstall has not implemented your operating system yet"
  fi
}

# Echo the basename of the currently executing script.
#
# Example:
#   script_name=$(cube_current_script_name)
# Arguments: None
cube_current_script_name() {
  basename "$0"
}

# Echo the absolute path the currently executing script.
#
# Example:
#   script_abspath=$(cube_current_script_abs_path)
# Arguments: None
cube_current_script_abs_path() {
  cube_current_script_abs_path_dirname="$( cd "$(dirname "$0")" && pwd -P )" || cube_check_return
  echo "${cube_current_script_abs_path_dirname}/$(cube_current_script_name)"
}

# Echo the size of a file $1 in bytes
#
# Example:
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

# Echo stdin to stdout with all ${VAR}'s evaluated (except for \${VAR})
#
# Example:
#   cube_expand_parameters < template > output
# Arguments: None
cube_expand_parameters() {
  # http://stackoverflow.com/a/40167919/5657303
  
  cube_expand_parameters_is_bash=0
  if [ "$(cube_shell)" -eq ${POSIXCUBE_SHELL_BASH} ]; then
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
      # shellcheck disable=SC2039
      cube_expand_parameters_line_escaped="${cube_expand_parameters_line_escaped//$'\4'{/\${}"
    else
      cube_expand_parameters_line_escaped=$(printf %s "${cube_expand_parameters_line_escaped}" | sed 's/\([^\x05]\)\x04{/\1${/g' | sed 's/^\x04{/${/g')
    fi
    
    cube_expand_parameters_output=$(eval "printf '%s\n' \"${cube_expand_parameters_line_escaped}\"") || cube_check_return "${cube_expand_parameters_line_escaped}"
    
    echo "${cube_expand_parameters_output}" | tr '\1\2\3\4\5\6' '`([$\\"'
  done
}

# Read stdin into the variable named by the first argument. Always ends in a newline.
# Do not use in a pipeline (http://unix.stackexchange.com/a/340932/212882).
#
# Example:
#   cube_read_stdin cubevar_app_str <<'HEREDOC'
#     `([$\{\
#   HEREDOC
#   echo "${cubevar_app_str}"
# Arguments:
#   Required:
#     $1: Result variable name
cube_read_stdin() {
  cube_check_numargs 1 "${@}"

  # http://unix.stackexchange.com/q/340718/212882
  cube_read_stdin_result=""
  while IFS="${POSIXCUBE_NEWLINE}" read -r cube_read_stdin_line; do
    cube_read_stdin_result="${cube_read_stdin_result}${cube_read_stdin_line}${POSIXCUBE_NEWLINE}"
  done
  # shellcheck disable=SC2086
  eval $1'=${cube_read_stdin_result}'
}

# Copy the contents of $2 on top of $1 if $1 doesn't exist or the contents
# are different than $2. If $2 ends with ".template" then first process
# the file with `cube_expand_parameters`.
#
# Example:
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
    cube_throw "Could not find or read input ${cube_set_file_contents_input_file} from $(pwd -P)"
  fi
  
  cube_ensure_directory "$(dirname "${cube_set_file_contents_target_file}")"
  
  cube_set_file_contents_input_file_is_template=$(expr "${cube_set_file_contents_input_file}" : '.*\.template$')
  if [ "${cube_set_file_contents_input_file_is_template}" -ne 0 ]; then
    
    cube_set_file_contents_input_file_original="${cube_set_file_contents_input_file}"
    cube_set_file_contents_input_file="${cube_set_file_contents_input_file}.tmp"

    # Parameter expansion can introduce very large delays with large files, so point that out
    #if [ ${cubevar_api_debug} -eq 1 ]; then
      cube_echo "Expanding parameters of ${cube_set_file_contents_input_file_original}"
    #fi
    
    # awk, perl, sed, envsubst, etc. can do this easily but would require exported envars
    # perl -pe 's/([^\\]|^)\$\{([a-zA-Z_][a-zA-Z_0-9]*)\}/$1.$ENV{$2}/eg' < "${cube_set_file_contents_input_file_original}" > "${cube_set_file_contents_input_file}" || cube_check_return
    # http://stackoverflow.com/questions/415677/how-to-replace-placeholders-in-a-text-file
    # http://stackoverflow.com/questions/2914220/bash-templating-how-to-build-configuration-files-from-templates-with-bash
    cube_expand_parameters < "${cube_set_file_contents_input_file_original}" > "${cube_set_file_contents_input_file}" || cube_check_return
    
    #if [ ${cubevar_api_debug} -eq 1 ]; then
      cube_echo "Expansion complete"
    #fi
    
    cube_set_file_contents_input_file_needs_remove=1
  fi
  
  if cube_file_exists "${cube_set_file_contents_target_file}" ; then
  
    # If the file sizes are different, then replace the file (http://stackoverflow.com/a/5920355/5657303)
    cube_set_file_contents_target_file_size=$(cube_file_size "${cube_set_file_contents_target_file}")
    cube_set_file_contents_input_file_size=$(cube_file_size "${cube_set_file_contents_input_file}")
    
    if [ ${cubevar_api_debug} -eq 1 ]; then
      cube_echo "Target file ${cube_set_file_contents_target_file} exists. Target size: ${cube_set_file_contents_target_file_size}, source size: ${cube_set_file_contents_input_file_size}"
    fi
    
    if [ "${cube_set_file_contents_target_file_size}" -eq "${cube_set_file_contents_input_file_size}" ]; then

      # Sizes are equal, so do a quick cksum
      cube_set_file_contents_target_file_cksum=$(cksum "${cube_set_file_contents_target_file}" | awk '{print $1}')
      cube_set_file_contents_input_file_cksum=$(cksum "${cube_set_file_contents_input_file}" | awk '{print $1}')

      if [ ${cubevar_api_debug} -eq 1 ]; then
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

# Echo a random number between 1 and $1
#
# Example:
#   cube_random_number 10
# Arguments:
#   Required:
#     $1: Maximum value
cube_random_number() {
  cube_check_numargs 1 "${@}"
  echo "" | awk "{ srand(); print int(${1} * rand()) + 1; }"
}

# Echo a temporary directory
#
# Example:
#   cube_tmpdir
# Arguments: None
cube_tmpdir() {
  echo "/tmp/"
}

# Set the contents of $1 to the string $@. Create file if it doesn't exist.
#
# Example:
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

# Echo the absolute path of $1 without any symbolic links.
#
# Example:
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
    
    echo "${cube_readlink_path}"
  #fi
}

# Echo total system memory in bytes
#
# Example:
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
  echo $((($(grep "^MemTotal:" /proc/meminfo | awk '{print $2}')*1024)/cube_total_memory_divisor))
}

# Ensure directory $1, and parent directories, exist. Return true if the directory is created; otherwise, false.
#
# Example:
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
    chmod "${2}" "${1}" || cube_check_return
  fi
  if [ "${3}" != "" ]; then
    chown "${3}" "${1}" || cube_check_return
  fi
  if [ "${4}" != "" ]; then
    chgrp "${4}" "${1}" || cube_check_return
  fi
  
  return ${cube_ensure_directory_result}
}

# Ensure file $1, and parent directories, exist. Return true if the file is created; otherwise, false.
#
# Example:
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
    # shellcheck disable=SC2086
    cube_ensure_directory "$(dirname "${1}")" $2 $3 $4
  
    touch "${1}" || cube_check_return
    cube_ensure_file_result=0
    cube_echo "Created file ${1}"
  fi
  if [ "${2}" != "" ]; then
    chmod "${2}" "${1}" || cube_check_return
  fi
  if [ "${3}" != "" ]; then
    chown "${3}" "${1}" || cube_check_return
  fi
  if [ "${4}" != "" ]; then
    chgrp "${4}" "${1}" || cube_check_return
  fi

  return ${cube_ensure_file_result}
}

# Add the current directory to a stack of directories and change directory to ${1}
#
# Example:
#   cube_pushd ~/.ssh/
# Arguments:
#   Requires;
#     $1: Directory
cube_pushd() {
  cube_check_numargs 1 "${@}"
  
  if cube_command_exists pushd ; then
    # shellcheck disable=SC2039
    pushd "${1}" || cube_check_return
  else
    #cube_throw "Not implemented (cube_pushd)"
    cd "${1}" || cube_check_return
  fi
}

# Pop the top of the stack of directories from `cube_pushd` and change
# directory to that directory.
#
# Example:
#   cube_popd
# Arguments: None
cube_popd() {
  if cube_command_exists popd ; then
    # shellcheck disable=SC2039
    popd || cube_check_return
  else
    #cube_throw "Not implemented (cube_popd)"
    # shellcheck disable=SC2164
    cd -
  fi
}

# Return true if the role $1 is set.
#
# Example:
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

# Check if the file $1 contains $2. Uses grep with default arguments (e.g. regex).
#
# Example:
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

# Check if stdin contains $1
#
# Example:
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

# Echo the IPv4 address of interface $1
#
# Example:
#   cube_interface_ipv4_address eth0
# Arguments:
#   Required:
#     $1: Interface name
cube_interface_ipv4_address() {
  cube_check_numargs 1 "${@}"
  ip -4 -o address show dev "${1}" | head -1 | awk '{print $4}' | sed 's/\/.*$//g' || cube_check_return
}

# Echo the IPv6 address of interface $1
#
# Example:
#   cube_interface_ipv6_address eth0
# Arguments:
#   Required:
#     $1: Interface name
cube_interface_ipv6_address() {
  cube_check_numargs 1 "${@}"
  ip -6 -o address show dev "${1}" | head -1 | awk '{print $4}' | sed 's/\/.*$//g' || cube_check_return
}

# Prompt the question $1 followed by " (y/N)" and prompt for an answer.
# A blank string answer is equivalent to No. Return true if yes, false otherwise.
#
# Example:
#   cube_prompt "Are you sure?"
# Arguments:
#   Required:
#     $1: Prompt test
cube_prompt() {
  cube_check_numargs 1 "${@}"
  while true; do
    printf "%s (y/N)? " "${1}"
    read -r cube_prompt_response || cube_check_return
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

# Echo full hostname.
#
# Example:
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

# Include the ${1} cube
#
# Example:
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
      
      cubevar_api_cube_include_pwd="$(pwd)" || cube_check_return
      
      cd "../${cube_include_name}/" || cube_check_return
      
      # shellcheck disable=SC1090
      . "./${cube_include_name_base}.sh" || cube_check_return
      
      cd "${cubevar_api_cube_include_pwd}" || cube_check_return
    else
      cube_throw "Cannot read ${cube_include_name}/${cube_include_name_base}.sh"
    fi
  elif [ -r "../${cube_include_name}" ]; then
    cube_echo "Including ${cube_include_name} cube..."
    # shellcheck disable=SC1090
    . "../${cube_include_name}" || cube_check_return
  elif [ -r "${cube_include_name}.sh" ]; then
    cube_echo "Including ${cube_include_name} cube..."
    # shellcheck disable=SC1090
    . "../${cube_include_name}.sh" || cube_check_return
  else
    cube_throw "Cube ${cube_include_name} not found. Did you upload it with -U ${cube_include_name} ?"
  fi
}

# Return true if $1 contains $2; otherwise, false.
#
# Example:
#   cube_string_contains "${cubevar_app_str}" "@" && ...
# Arguments:
#   Required:
#     $1: String that is checked for the presence of $2
#     $2: The search string
cube_string_contains() {
  cube_check_numargs 2 "${@}"
  printf "%s" "${1}" | grep -lq "${2}"
  return $?
}

# Print to stdout a substring of $1 strictly before the first match of the regular expression $2.
#
# Example:
#   cubevar_app_str="$(cube_string_substring_before "${cubevar_app_str}" "@")"
# Arguments:
#   Required:
#     $1: String that is checked for the presence of $2
#     $2: The search string
cube_string_substring_before() {
  cube_check_numargs 2 "${@}"
  printf "%s" "${1}" | sed "s/\\(^.*\\)${2}.*$/\\1/g"
}

# Print to stdout a substring of $1 strictly after the first match of the regular expression $2.
#
# Example:
#   cubevar_app_str="$(cube_string_substring_after "${cubevar_app_str}" "@")"
# Arguments:
#   Required:
#     $1: String that is checked for the presence of $2
#     $2: The search string
cube_string_substring_after() {
  cube_check_numargs 2 "${@}"
  printf "%s" "${1}" | sed "s/^.*${2}\\(.*\\)$/\\1/g"
}

# Execute $* as superuser with all posixcube APIs available (see Philosophy #3).
#
# Example:
#   cube_sudo cube_ensure_file /etc/app.txt
# Arguments:
#   Required:
#     $*: Arguments to pass to superuser sub-shell
cube_sudo() {
  cube_check_numargs 1 "${@}"
  cubevar_api_sudo_path="${POSIXCUBE_CACHE_DIRECTORY%/}/posixcube.sh"
  cubevar_api_cube_sudo_user_home="$(cube_user_home_dir)" || cube_check_return
  cubevar_api_sudo_path="$(printf '%s' "${cubevar_api_sudo_path}" | sed "s@~@${cubevar_api_cube_sudo_user_home}@g")"
  cube_echo "Executing cube_sudo with: $*"
  ${cubevar_api_superuser_command} sh -c "POSIXCUBE_APIS_ONLY=true . ${cubevar_api_sudo_path} && $*" || cube_check_return
}

# Check if the $1 user exists
#
# Example:
#   cube_user_exists nginx
# Arguments:
#   Required:
#     $1: User name
cube_user_exists() {
  cube_check_numargs 1 "${@}"
  id -u "${1}" >/dev/null 2>&1
  return $?
}

# Create the user $1
#
# Example:
#   cube_create_user nginx
# Arguments:
#   Required:
#     $1: User name
#   Optional:
#     $2: Shell
#     $3: Password
cube_create_user() {
  cube_check_numargs 1 "${@}"
  
  useradd -m "${1}" || cube_check_return
  
  if [ "${2}" != "" ]; then
    usermod -s "${2}" "${1}" || cube_check_return
  fi

  if [ "${3}" != "" ]; then
    echo "${1}:${3}" | chpasswd || cube_check_return
  fi
  
  cube_echo "Created user ${1}"
}

# Create the user $1 if it doesn't already exist (with group name $1)
#
# Example:
#   cube_ensure_user nginx
# Arguments:
#   Required:
#     $1: User name
#   Optional:
#     $2: Shell
#     $3: Password
cube_ensure_user() {
  cube_check_numargs 1 "${@}"

  if ! cube_user_exists "${1}" ; then
    cube_create_user "${@}"
    return 0
  else
    return 1
  fi
}

# Check if the $1 group exists
#
# Example:
#   cube_group_exists nginx
# Arguments:
#   Required:
#     $1: Group name
cube_group_exists() {
  cube_check_numargs 1 "${@}"
  cube_file_contains /etc/group "^${1}:"
}

# Create the group $1
#
# Example:
#   cube_create_group nginx
# Arguments:
#   Required:
#     $1: Group name
cube_create_group() {
  cube_check_numargs 1 "${@}"
  
  groupadd "${1}" || cube_check_return

  cube_echo "Created group ${1}"
}

# Check if the $1 group contains the user $2
#
# Example:
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

# Add the user $2 to group $1
#
# Example:
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
    ${cubevar_api_superuser} usermod -a -G "${1}" "${2}"
  else
    ${cubevar_api_superuser} usermod -g "${1}" "${2}"
  fi

  cube_echo "Added user ${2} to group ${1}"
}

# Print to stdout the current user
#
# Example:
#   cube_current_user
# Arguments: None
cube_current_user() {
  if [ "${USER}" != "" ]; then
    echo "${USER}"
  elif [ "${LOGNAME}" != "" ]; then
    echo "${LOGNAME}"
  else
    cube_throw "Current user cannot be inferred from the environment"
  fi
}

# Print to stdout the home directory of user $1 (defaults to `cube_current_user`)
#
# Example:
#   cube_user_home_dir root
# Arguments:
#   Optional:
#     $1: User name
cube_user_home_dir() {
  cubevar_api_cube_user_home_dir_user="${1}"
  
  if [ "${cubevar_api_cube_user_home_dir_user}" = "" ]; then
    cubevar_api_cube_user_home_dir_user="$(cube_current_user)"
  fi
  
  # shellcheck disable=SC2046
  if [ $(cube_operating_system) -eq ${POSIXCUBE_OS_MAC_OSX} ]; then
    cubevar_api_cube_user_home_dir_line="$(dscl . -read "/Users/${cubevar_api_cube_user_home_dir_user}" NFSHomeDirectory)" || cube_check_return
    cubevar_api_cube_user_home_dir_result="$(printf '%s' "${cubevar_api_cube_user_home_dir_line}" | sed 's/^NFSHomeDirectory: //g')" || cube_check_return
  else
    cubevar_api_cube_user_home_dir_line=$(grep -E "^${cubevar_api_cube_user_home_dir_user}:" /etc/passwd) || cube_check_return "User ${cubevar_api_cube_user_home_dir_user} not found"
    cubevar_api_cube_user_home_dir_result=$(printf '%s' "${cubevar_api_cube_user_home_dir_line}" | cut -d: -f6) || cube_check_return "Parsing /etc/passwd for user ${cubevar_api_cube_user_home_dir_user} failed"
  fi
  
  echo "${cubevar_api_cube_user_home_dir_result}"
}

# Ensure the SSH private key contents $1 are placed in a file named $2
# (defaults to `id_rsa`) for the user $3 (defaults to `cube_current_user`)
#
# Example:
#   cube_user_ensure_private_key "${cubevar_app_key1}"
# Arguments:
#   Required:
#     $1: SSH private key contents
#   Optional:
#     $2: SSH private key file name
#     $3: User name
cube_user_ensure_private_key() {
  cube_check_numargs 1 "${@}"
  
  cubevar_api_cube_user_ensure_private_key_file="${2}"
  
  if [ "${cubevar_api_cube_user_ensure_private_key_file}" = "" ]; then
    cubevar_api_cube_user_ensure_private_key_file="id_rsa"
  fi

  cubevar_api_cube_user_ensure_private_key_user="${3}"
  
  if [ "${cubevar_api_cube_user_ensure_private_key_user}" = "" ]; then
    cubevar_api_cube_user_ensure_private_key_user="$(cube_current_user)"
  fi
  
  cubevar_api_cube_user_ensure_private_key_user_home="$(cube_user_home_dir "${cubevar_api_cube_user_ensure_private_key_user}")" || cube_check_return
  
  cube_ensure_directory "${cubevar_api_cube_user_ensure_private_key_user_home}/.ssh/" 700 "${cubevar_api_cube_user_ensure_private_key_user}" "${cubevar_api_cube_user_ensure_private_key_user}"
  
  cube_set_file_contents_string "${cubevar_api_cube_user_ensure_private_key_user_home}/.ssh/${cubevar_api_cube_user_ensure_private_key_file}" "${1}"
  cubevar_api_result=$?
  
  chown "${cubevar_api_cube_user_ensure_private_key_user}:${cubevar_api_cube_user_ensure_private_key_user}" "${cubevar_api_cube_user_ensure_private_key_user_home}/.ssh/${cubevar_api_cube_user_ensure_private_key_file}" || cube_check_return
  
  chmod 600 "${cubevar_api_cube_user_ensure_private_key_user_home}/.ssh/${cubevar_api_cube_user_ensure_private_key_file}" || cube_check_return
  
  return ${cubevar_api_result}
}

# Ensure the SSH public key contents $1 exist in the `.ssh/authorized_keys`
# file in the home directory of user $2 (defaults to `cube_current_user`)
#
# Example:
#   cube_user_ensure_authorized_public_key "${cubevar_app_key1_pub}"
# Arguments:
#   Required:
#     $1: SSH private key contents
#   Optional:
#     $2: User name
cube_user_ensure_authorized_public_key() {
  cube_check_numargs 1 "${@}"
  
  cubevar_api_cube_user_ensure_authorized_public_key_user="${2}"
  
  if [ "${cubevar_api_cube_user_ensure_authorized_public_key_user}" = "" ]; then
    cubevar_api_cube_user_ensure_authorized_public_key_user="$(cube_current_user)"
  fi
  
  cubevar_api_cube_user_ensure_authorized_public_key_user_home="$(cube_user_home_dir "${cubevar_api_cube_user_ensure_authorized_public_key_user}")" || cube_check_return
  
  cube_ensure_directory "${cubevar_api_cube_user_ensure_authorized_public_key_user_home}/.ssh/" 700 "${cubevar_api_cube_user_ensure_authorized_public_key_user}" "${cubevar_api_cube_user_ensure_authorized_public_key_user}"
  
  touch "${cubevar_api_cube_user_ensure_authorized_public_key_user_home}/.ssh/authorized_keys" || cube_check_return
  
  chown "${cubevar_api_cube_user_ensure_authorized_public_key_user}:${cubevar_api_cube_user_ensure_authorized_public_key_user}" "${cubevar_api_cube_user_ensure_authorized_public_key_user_home}/.ssh/authorized_keys" || cube_check_return
  
  chmod 600 "${cubevar_api_cube_user_ensure_authorized_public_key_user_home}/.ssh/authorized_keys" || cube_check_return
  
  if ! cube_file_contains "${cubevar_api_cube_user_ensure_authorized_public_key_user_home}/.ssh/authorized_keys" "${1}" ; then
    echo "${1}" >> "${cubevar_api_cube_user_ensure_authorized_public_key_user_home}/.ssh/authorized_keys" || cube_check_return
    
    cube_echo "Installed public key into ${cubevar_api_cube_user_ensure_authorized_public_key_user_home}/.ssh/authorized_keys"
  fi
}

# Ensure the public key(s) of the host $1 are in the `.ssh/known_hosts` file
# in the home directory of user $2 (defaults to `cube_current_user`). Note:
# the fingerprints are currently not checked, but you may review STDOUT.
# To reduce the risks of MITM attacks, you can call this only after a
# successful call to `cube_user_ensure_private_key` so that the scan is
# only done once on private key setup.
#
# Example:
#   cube_user_ensure_private_key "${cubevar_app_host_privkey}" && cube_user_authorize_known_host some_host
# Arguments:
#   Required:
#     $1: Remote host
#   Optional:
#     $2: User name
cube_user_authorize_known_host() {
  cube_check_numargs 1 "${@}"
  
  cubevar_api_cube_user_authorize_known_host_user="${2}"
  
  if [ "${cubevar_api_cube_user_authorize_known_host_user}" = "" ]; then
    cubevar_api_cube_user_authorize_known_host_user="$(cube_current_user)"
  fi
  
  cubevar_api_cube_user_authorize_known_host_user_home="$(cube_user_home_dir "${cubevar_api_cube_user_authorize_known_host_user}")" || cube_check_return
  
  cube_ensure_directory "${cubevar_api_cube_user_authorize_known_host_user_home}/.ssh/" 700 "${cubevar_api_cube_user_authorize_known_host_user}" "${cubevar_api_cube_user_authorize_known_host_user}"
  
  touch "${cubevar_api_cube_user_authorize_known_host_user_home}/.ssh/known_hosts" || cube_check_return
  
  chown "${cubevar_api_cube_user_authorize_known_host_user}:${cubevar_api_cube_user_authorize_known_host_user}" "${cubevar_api_cube_user_authorize_known_host_user_home}/.ssh/known_hosts" || cube_check_return
  
  chmod 600 "${cubevar_api_cube_user_authorize_known_host_user_home}/.ssh/known_hosts" || cube_check_return
  
  if ! ssh-keygen -F "${1}" -f "${cubevar_api_cube_user_authorize_known_host_user_home}/.ssh/known_hosts" >/dev/null ; then
    cube_echo "Installing public keys for ${1} into ${cubevar_api_cube_user_authorize_known_host_user_home}/.ssh/known_hosts"

    ssh-keyscan "${1}" | tee -a "${cubevar_api_cube_user_authorize_known_host_user_home}/.ssh/known_hosts" || cube_check_return
  fi
}

# Append space-delimited service names to this variable to restart services after all CUBEs and COMMANDs
# shellcheck disable=SC2034
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
  p_debug=0
  p_quiet=0
  p_skip_init=0
  p_keep_exec=0
  p_skip_host_errors=0
  p_hosts=""
  p_cubes=""
  p_include_cubes=""
  p_envar_scripts=""
  p_envar_scripts_specified=0
  p_envar_scripts_password=""
  p_user="${USER}"
  # shellcheck disable=SC2088
  p_cubedir="${POSIXCUBE_CACHE_DIRECTORY}"
  p_roles=""
  p_options=""
  p_specfile="./cubespecs.ini"
  p_parallel=0
  p_async_cubes=0
  p_default_envars="envars*sh envars*sh.enc"
  p_ssh_o_options_default="ConnectTimeout=5"
  p_ssh_o_options="${p_ssh_o_options_default}"
  p_ssh_i_option=""
  p_ssh_F_option=""
  p_ssh_p_option=""
  # http://serverfault.com/a/593419/259410
  p_ssh_t_option=""
  p_superuser_command="sudo"
  p_superuser=""
  p_transfer_command="${POSIXCUBE_TRANSFER_SCP}"
  p_local=0
  p_shells=""
  p_exec_shell="/bin/sh"
  
  if [ "$(cube_shell)" -eq ${POSIXCUBE_SHELL_BASH} ]; then
    p_parallel=64
  fi

  p_show_version() {
    p_printf "posixcube.sh version ${POSIXCUBE_VERSION}\n"
  }

  p_printf() {
    p_printf_str=$1; shift
    # shellcheck disable=SC2059
    printf "[$(date)] ${p_printf_str}" "${@}"
  }

  p_printf_error() {
    p_printf_str=$1; shift
    # shellcheck disable=SC2059
    printf "\n[$(date)] ${POSIXCUBE_COLOR_RED}Error${POSIXCUBE_COLOR_RESET}: ${p_printf_str}\n\n" "${@}" 1>&2
  }
  
  p_exit() {
    for p_envar_script in ${p_envar_scripts}; do
      p_envar_script_enc_matches=$(expr ${p_envar_script} : '.*\.dec$')
      if [ "${p_envar_script_enc_matches}" -ne 0 ]; then
        # If multiple posixcube.sh executions run at the same time, then one of them might
        # delete the decryption file, but that's okay
        rm "${p_envar_script}" 2>/dev/null
      fi
    done

    [ ${p_keep_exec} -eq 0 ] && rm -f "${p_script}" 2>/dev/null
    
    exit "${1}"
  }

  p_install() {
    p_func_result=0
    if [ -d "/etc/bash_completion.d/" ]; then
      p_autocomplete_file=/etc/bash_completion.d/posixcube_completion.sh
      
      # Autocomplete Hostnames for SSH etc.
      # by Jean-Sebastien Morisset (http://surniaulula.com/)
      
      cat <<'HEREDOC' | tee ${p_autocomplete_file} > /dev/null
_posixcube_complete() {
  COMPREPLY=()
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD-1]}"
  case "${prev}" in
    \-h)
      p_host_list=$({
        for c in /etc/ssh_config /etc/ssh/ssh_config ~/.ssh/config
        do [ -r $c ] && sed -n -e 's/^Host[[:space:]]//p' -e 's/^[[:space:]]*HostName[[:space:]]//p' $c
        done
        for k in /etc/ssh_known_hosts /etc/ssh/ssh_known_hosts ~/.ssh/known_hosts
        do [ -r $k ] && egrep -v '^[#\[]' $k|cut -f 1 -d ' '|sed -e 's/[,:].*//g'
        done
        sed -n -e 's/^[0-9][0-9\.]*//p' /etc/hosts; }|tr ' ' '\n'|sort|uniq|grep -Fv '*')
      if printf "%s" "${cur}" | grep -lq @; then
        p_autocomplete_user="$(printf "%s" "${cur}" | sed "s/\\(^.*\\)@.*$/\\1/g")"
        p_host_list="$(printf "%s" "${p_host_list}" | sed "s/^[ \t]*/${p_autocomplete_user}@/g")"
      fi
      COMPREPLY=($(compgen -W "${p_host_list}" -- $cur))
      ;;
    \-z)
      p_complete_specs="$(sed 's/=.*//g' cubespecs.ini)"
      COMPREPLY=($(compgen -W "${p_complete_specs}" -- $cur))
      ;;
    *)
      ;;
  esac
  return 0
}
# -o default is needed so that after a host autocomplete, a cube can be auto-completed,
# although the side effect is that not matching on a non-blank -h will start to match files/dirs
complete -o default -F _posixcube_complete posixcube.sh
HEREDOC

      p_func_result=$?
      if [ ${p_func_result} -eq 0 ]; then
        chmod +x ${p_autocomplete_file}
        p_func_result=$?
        if [ ${p_func_result} -eq 0 ]; then
          # shellcheck disable=SC1090
          . ${p_autocomplete_file}
          p_func_result=$?
          if [ ${p_func_result} -eq 0 ]; then
            p_printf "Installed Bash programmable completion script into ${p_autocomplete_file}\n"
          else
            p_printf "Could not execute ${p_autocomplete_file}\n"
          fi
        else
          p_printf "Could not chmod +x ${p_autocomplete_file}\n"
        fi
      else
        p_printf "Could not create ${p_autocomplete_file}\n"
        p_printf "You may need to try with sudo. For example:\n"
        p_printf "  sudo $(cube_current_script_abs_path) -b && . ${p_autocomplete_file}\n"
        p_printf "You only need to source the command the first time. Subsequent shells will automatically source it.\n"
      fi
    else
      p_printf "No directory /etc/bash_completion.d/ found, skipping Bash programmable completion installation.\n"
    fi
    exit ${p_func_result}
  }

  p_all_hosts=""

  p_process_hostname() {
    p_hostname_wildcard=$(expr "${1}" : '.*\*.*')
    if [ "${p_hostname_wildcard}" -ne 0 ]; then
    
      # Use or create cache of hosts
      if [ "${p_all_hosts}" = "" ]; then
        # shellcheck disable=SC2063
        p_all_hosts=$({ 
          for c in /etc/ssh_config /etc/ssh/ssh_config ~/.ssh/config
          do [ -r $c ] && sed -n -e 's/^Host[[:space:]]//p' -e 's/^[[:space:]]*HostName[[:space:]]//p' $c
          done
          for k in /etc/ssh_known_hosts /etc/ssh/ssh_known_hosts ~/.ssh/known_hosts
          do [ -r $k ] && grep -E -v '^[#\[]' $k|cut -f 1 -d ' '|sed -e 's/[,:].*//g'
          done
          sed -n -e 's/^[0-9][0-9\.]*//p' /etc/hosts; }|sort|uniq|grep -Fv '*'|tr '\n' ' ')
      fi
      
      p_process_hostname_search=$(printf "%s" "${1}" | sed 's/\*/\.\*/g')
      
      p_process_hostname_list=""
      for p_all_host in ${p_all_hosts}; do
        p_all_host_match=$(expr "${p_all_host}" : "${p_process_hostname_search}")
        if [ "${p_all_host_match}" -ne 0 ]; then
          p_process_hostname_list=$(cube_append_str "${p_process_hostname_list}" "${p_all_host}")
        fi
      done
      echo "${p_process_hostname_list}"
    else
      echo "${1}"
    fi
  }
  
  p_process_options() {
    # getopts processing based on http://stackoverflow.com/a/14203146/5657303
    OPTIND=1 # Reset in case getopts has been used previously in the shell.
    
    while getopts "?abc:dD:e:F:h:i:klO:o:p:P:qr:RsStu:U:vw:yz:" p_opt "${@}"; do
      case "$p_opt" in
      \?)
        p_show_usage
        ;;
      a)
        p_async_cubes=1
        ;;
      b)
        p_install
        ;;
      c)
        p_cubes=$(cube_append_str "${p_cubes}" "${OPTARG}")
        ;;
      d)
        p_debug=1
        ;;
      D)
        p_superuser_command="${OPTARG}"
        ;;
      e)
        p_envar_scripts_specified=1
        if [ "${OPTARG}" != "" ] && [ ! -r "${OPTARG}" ]; then
          p_printf_error "Could not find ${OPTARG} ENVAR script."
          exit 1
        fi
        p_envar_scripts=$(cube_append_str "${p_envar_scripts}" "${OPTARG}")
        ;;
      F)
        p_ssh_F_option="-F ${OPTARG}"
        ;;
      h)
        p_processed_hostname=$(p_process_hostname "${OPTARG}")
        if [ "${p_processed_hostname}" != "" ]; then
          p_hosts=$(cube_append_str "${p_hosts}" "${p_processed_hostname}")
        else
          p_printf_error "No known hosts match ${OPTARG} from ${p_all_hosts}"
          exit 1
        fi
        ;;
      i)
        p_ssh_i_option="-i ${OPTARG}"
        ;;
      k)
        p_keep_exec=1
        ;;
      l)
        p_local=1
        ;;
      o)
        if [ "${p_ssh_o_options}" = "${p_ssh_o_options_default}" ]; then
          p_ssh_o_options=""
        fi
        p_ssh_o_options=$(cube_append_str "${p_ssh_o_options}" "${OPTARG}")
        ;;
      O)
        # Break up into name and value
        p_option_name=$(echo "${OPTARG}" | sed 's/=.*//')
        p_option_value=$(echo "${OPTARG}" | sed "s/^${p_option_name}=//")
        p_option_value=$(p_process_hostname "${p_option_value}")
        p_options=$(cube_append_str "${p_options}" "${p_option_name}=\"${p_option_value}\"" "${POSIXCUBE_NEWLINE}")
        ;;
      p)
        p_ssh_p_option="-p ${OPTARG}"
        ;;
      P)
        p_envar_scripts_password="${OPTARG}"
        ;;
      q)
        p_quiet=1
        ;;
      r)
        p_roles=$(cube_append_str "${p_roles}" "${OPTARG}")
        ;;
      R)
        p_transfer_command="${POSIXCUBE_TRANSFER_RSYNC}"
        ;;
      s)
        p_skip_init=1
        ;;
      S)
        p_superuser="${p_superuser_command}"
        ;;
      t)
        p_ssh_t_option="-t"
        ;;
      u)
        p_user="${OPTARG}"
        ;;
      U)
        p_include_cubes=$(cube_append_str "${p_include_cubes}" "${OPTARG}")
        ;;
      v)
        p_show_version
        exit 1
        ;;
      w)
        p_envar_scripts_password="$(cat "${OPTARG}")" || cube_check_return
        ;;
      y)
        p_skip_host_errors=1
        ;;
      z)
        if [ -r "${p_specfile}" ]; then
          p_foundspec=0
          
          p_foundspec_names=""
          
          while read -r p_specfile_line; do
            p_specfile_line_name=$(echo "${p_specfile_line}" | sed 's/=.*//')
            p_foundspec_names=$(cube_append_str "${p_foundspec_names}" "${p_specfile_line_name}")
            if [ "${p_specfile_line_name}" = "${OPTARG}" ]; then
              p_foundspec=1
              p_specfile_line_value=$(echo "${p_specfile_line}" | sed "s/^${p_specfile_line_name}=//")
              # shellcheck disable=SC2086
              p_process_options ${p_specfile_line_value}
              break
            fi
          done < "${p_specfile}"
          
          if [ ${p_foundspec} -eq 0 ]; then
            p_printf_error "Could not find ${OPTARG} in ${p_specfile} file with specs ${p_foundspec_names}"
            exit 1
          fi
        else
          p_printf_error "Could not find ${p_specfile} file"
          exit 1
        fi
        ;;
      esac
    done
  }

  p_process_options "${@}"
  
  shift $((OPTIND-1))

  [ "$1" = "--" ] && shift
  
  # If no password specified, check for the ~/.posixcube.pwd file
  if [ "${p_envar_scripts_password}" = "" ] && [ -r ~/.posixcube.pwd ]; then
    p_envar_scripts_password="$(cat ~/.posixcube.pwd)" || cube_check_return
  fi

  if [ ${p_envar_scripts_specified} -eq 0 ] && [ "${p_envar_scripts}" = "" ]; then
    # shellcheck disable=SC2012
    # shellcheck disable=SC2086
    p_envar_scripts="$(ls -1 ${p_default_envars} 2>/dev/null | paste -sd ' ' -)"
  fi
  
  if [ "${p_envar_scripts}" != "" ]; then
    [ ${p_debug} -eq 1 ] && p_printf "Using ENVAR files: ${p_envar_scripts}\n"
  fi
  
  # Convert ssh -o options to final form
  p_ssh_o_options_exec=""
  for p_ssh_o_option in ${p_ssh_o_options}; do
    p_ssh_o_options_exec=$(cube_append_str "${p_ssh_o_options_exec}" "-o ${p_ssh_o_option}")
  done
  
  p_commands="${*}"

  if [ "${p_hosts}" = "" ] && [ ${p_local} -eq 0 ]; then
    # If there are no hosts and it's not a local execution, check COMMANDs for sub-commands
    if [ "${p_commands}" != "" ]; then
      case "${1}" in
        edit|show|source)
          if [ "${p_envar_scripts}" != "" ]; then
            for p_envar_script in ${p_envar_scripts}; do
              p_envar_scripts_enc=$(expr "${p_envar_script}" : '.*enc$')
              if [ "${p_envar_scripts_enc}" -ne 0 ]; then
                if cube_command_exists gpg ; then
                  p_envar_script_new=$(echo "${p_envar_script}" | sed 's/enc$/dec/g')
                  
                  if [ "${p_envar_scripts_password}" = "" ]; then
                    p_printf "Enter the password for ${p_envar_script}:\n"
                    gpg --output "${p_envar_script_new}" --yes --decrypt "${p_envar_script}" || cube_check_return
                  else
                    [ ${p_debug} -eq 1 ] && p_printf "Decrypting ${p_envar_script} ...\n"
                    p_gpg_output="$(echo "${p_envar_scripts_password}" | gpg --passphrase-fd 0 --batch --yes --output "${p_envar_script_new}" --decrypt "${p_envar_script}" 2>&1)" || cube_check_return "${p_gpg_output}"
                  fi
                  
                  case "${1}" in
                    show)
                      p_printf "Contents of ${p_envar_script}:\n"
                      sed 's/\\\$/$/g' "${p_envar_script_new}"
                      ;;
                    source)
                      chmod u+x "${p_envar_script_new}"
                      # shellcheck disable=SC1090
                      . "$(cube_readlink "${p_envar_script_new}")"
                      [ ${p_debug} -eq 1 ] && p_printf "Sourced ${p_envar_script}...\n"
                      ;;
                    edit)
                      "${EDITOR:-vi}" "${p_envar_script_new}" || cube_check_return
                      
                      if [ "${p_envar_scripts_password}" = "" ]; then
                        p_printf "Enter the password to re-encrypt ${p_envar_script}:\n"
                        gpg --yes --s2k-mode 3 --s2k-count 65536 --force-mdc --cipher-algo AES256 --s2k-digest-algo SHA512 -o "${p_envar_script}" --symmetric "${p_envar_script_new}" || cube_check_return
                      else
                        [ ${p_debug} -eq 1 ] && p_printf "Re-encrypting ${p_envar_script} ...\n"
                        
                        p_gpg_output="$(echo "${p_envar_scripts_password}" | gpg --batch --passphrase-fd 0 --yes --no-use-agent --s2k-mode 3 --s2k-count 65536 --force-mdc --cipher-algo AES256 --s2k-digest-algo SHA512 -o "${p_envar_script}" --symmetric "${p_envar_script_new}" 2>&1)" || cube_check_return "${p_gpg_output}"
                      fi
                      ;;
                    *)
                      p_show_usage "${1} Not implemented (encrypted case)"
                      ;;
                  esac
                  
                  rm -f "${p_envar_script_new}" || cube_check_return
                else
                  p_show_usage "gpg program not found on the PATH"
                fi
              else
                case "${1}" in
                  show)
                    grep -v "^#!/bin/sh$" "${p_envar_script}" | sed 's/\\\$/$/g'
                    ;;
                  source)
                    # shellcheck disable=SC1090
                    . "$(cube_readlink "${p_envar_script}")"
                    [ ${p_debug} -eq 1 ] && p_printf "Sourced ${p_envar_script}...\n"
                    ;;
                  edit)
                    # We assume the user will edit a non-encrypted file on their own
                    ;;
                  *)
                    p_show_usage "${1} Not implemented (non-encrypted case)"
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
            p_show_usage "Sub-COMMAND without -e ENVAR file and ${p_default_envars} not found."
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
          p_show_usage "Unknown sub-COMMAND ${1}"
          ;;
      esac
    else
      p_show_usage "Specify either target host(s) with -h, local execution with -l, or a sub-COMMAND."
    fi
  fi
  
  if [ "${POSIXCUBE_SOURCED}" = "" ]; then
    if [ "${p_commands}" = "" ] && [ "${p_cubes}" = "" ]; then
      p_show_usage "No COMMANDs or CUBEs specified."
    fi

    [ ${p_debug} -eq 1 ] && p_show_version
    
    p_handle_remote_response() {
      p_handle_remote_response_result=${1}; shift
      p_handle_remote_response_host="${1}"; shift
      p_handle_remote_response_context="${1}"; shift
      
      if [ "${p_handle_remote_response_context}" = "" ]; then
        p_handle_remote_response_context="Last command"
      fi

      if cube_string_contains "${p_handle_remote_response_host}" "@"; then
        p_handle_remote_response_host="$(cube_string_substring_after "${p_handle_remote_response_host}" "@")"
      fi

      p_host_output_color=${POSIXCUBE_COLOR_GREEN}
      p_host_output=""
      if [ "${p_handle_remote_response_result}" -ne 0 ]; then
        p_host_output_color=${POSIXCUBE_COLOR_RED}
        p_host_output="${p_handle_remote_response_context} failed with return code ${p_handle_remote_response_result}"
      else
        [ ${p_debug} -eq 1 ] && p_host_output="Commands succeeded."
      fi
      
      if [ "${p_host_output}" != "" ]; then
        if [ "${p_handle_remote_response_host}" != "" ]; then
          p_printf "[${p_host_output_color}${p_handle_remote_response_host}${POSIXCUBE_COLOR_RESET}] %s\n" "${p_host_output}"
        else
          if [ "${p_host_output_color}" = "${POSIXCUBE_COLOR_RED}" ]; then
            p_printf "[${p_host_output_color}Error${POSIXCUBE_COLOR_RESET}] %s\n" "${p_host_output}"
          else
            p_printf "%s\n" "${p_host_output}"
          fi
        fi
      fi
      
      if [ "${p_handle_remote_response_result}" -ne 0 ] && [ ${p_skip_host_errors} -eq 0 ]; then
        p_exit "${p_handle_remote_response_result}"
      fi
    }

    p_remote_ssh() {
      p_remote_ssh_host="${1}"; shift
      p_remote_ssh_user="${1}"; shift
      
      if cube_string_contains "${p_remote_ssh_host}" "@"; then
        p_remote_ssh_user="$(cube_string_substring_before "${p_remote_ssh_host}" "@")"
        p_remote_ssh_host="$(cube_string_substring_after "${p_remote_ssh_host}" "@")"
      fi
      
      [ ${p_debug} -eq 1 ] && p_printf "[${POSIXCUBE_COLOR_GREEN}${p_remote_ssh_host}${POSIXCUBE_COLOR_RESET}] Executing ssh ${p_ssh_p_option} ${p_ssh_i_option} ${p_ssh_F_option} ${p_ssh_o_options_exec} ${p_ssh_t_option} ${p_remote_ssh_user}@${p_remote_ssh_host} ${*} ...\n"
      
      if [ ${p_parallel} -gt 0 ] && [ "${p_async}" -eq 1 ]; then
        # shellcheck disable=SC2086
        # shellcheck disable=SC2029
        ssh ${p_ssh_p_option} ${p_ssh_i_option} ${p_ssh_F_option} ${p_ssh_o_options_exec} ${p_ssh_t_option} "${p_remote_ssh_user}@${p_remote_ssh_host}" "${@}" 2>&1 &
        p_wait_pids=$(cube_append_str "${p_wait_pids}" "$!")
      else
        # shellcheck disable=SC2086
        # shellcheck disable=SC2029
        ssh ${p_ssh_p_option} ${p_ssh_i_option} ${p_ssh_F_option} ${p_ssh_o_options_exec} ${p_ssh_t_option} "${p_remote_ssh_user}@${p_remote_ssh_host}" "${@}" 2>&1
        p_host_output_result=$?
        
        [ ${p_debug} -eq 1 ] && p_printf "Finished executing on ${p_remote_ssh_host}\n"
        
        p_handle_remote_response ${p_host_output_result} "${p_remote_ssh_host}" "Remote commands through SSH"
      fi
    }
    
    p_process_script() {
      read -r p_process_script_firstline < "${1}" || cube_check_return
      
      # http://pubs.opengroup.org/onlinepubs/009695399/utilities/xcu_chap02.html#tag_02_06_02
      p_process_script_firstline_trimmed="${p_process_script_firstline###!}"
      if [ "${p_process_script_firstline_trimmed}" != "/bin/sh" ] && ! cube_element_exists "${p_shells}" "${p_process_script_firstline_trimmed}"; then
        p_shells=$(cube_append_str "${p_shells}" "${p_process_script_firstline_trimmed}")
      fi
    }

    p_remote_transfer() {
      p_remote_transfer_host="${1}"; shift
      p_remote_transfer_user="${1}"; shift
      p_remote_transfer_source="${1}"; shift
      p_remote_transfer_dest="${1}"; shift
      
      if cube_string_contains "${p_remote_transfer_host}" "@"; then
        p_remote_transfer_user="$(cube_string_substring_before "${p_remote_transfer_host}" "@")"
        p_remote_transfer_host="$(cube_string_substring_after "${p_remote_transfer_host}" "@")"
      fi
      
      [ ${p_debug} -eq 1 ] && p_printf "[${POSIXCUBE_COLOR_GREEN}${p_remote_transfer_host}${POSIXCUBE_COLOR_RESET}] Executing transfer ${p_remote_transfer_source} to ${p_remote_transfer_user}@${p_remote_transfer_host}:${p_remote_transfer_dest} ...\n"
      
      if [ "${p_parallel}" -gt 0 ] && [ "${p_async}" -eq 1 ]; then
        [ ${p_debug} -eq 1 ] && p_printf "Transferring in background: ${p_remote_transfer_source} ${p_remote_transfer_user}@${p_remote_transfer_host}:${p_remote_transfer_dest}\n"

        if [ "${p_ssh_o_options_exec}" != "" ]; then
          if [ "${p_transfer_command}" = "${POSIXCUBE_TRANSFER_RSYNC}" ]; then
            # shellcheck disable=SC2086
            ${p_transfer_command} -e "ssh ${p_ssh_o_options_exec}" ${p_remote_transfer_source} "${p_remote_transfer_user}@${p_remote_transfer_host}:${p_remote_transfer_dest}" &
          else
            # shellcheck disable=SC2086
            ${p_transfer_command} ${p_ssh_o_options_exec} ${p_remote_transfer_source} "${p_remote_transfer_user}@${p_remote_transfer_host}:${p_remote_transfer_dest}" &
          fi
        else
          # shellcheck disable=SC2086
          ${p_transfer_command} ${p_remote_transfer_source} "${p_remote_transfer_user}@${p_remote_transfer_host}:${p_remote_transfer_dest}" &
        fi
        p_wait_pids=$(cube_append_str "${p_wait_pids}" "$!")
      else
        [ ${p_debug} -eq 1 ] && p_printf "Transferring in foreground: ${p_remote_transfer_source} ${p_remote_transfer_user}@${p_remote_transfer_host}:${p_remote_transfer_dest}\n"
        
        if [ "${p_ssh_o_options_exec}" != "" ]; then
          if [ "${p_transfer_command}" = "${POSIXCUBE_TRANSFER_RSYNC}" ]; then
            # shellcheck disable=SC2086
            ${p_transfer_command} -e "ssh ${p_ssh_o_options_exec}" ${p_remote_transfer_source} "${p_remote_transfer_user}@${p_remote_transfer_host}:${p_remote_transfer_dest}"
          else
            # shellcheck disable=SC2086
            ${p_transfer_command} ${p_ssh_o_options_exec} ${p_remote_transfer_source} "${p_remote_transfer_user}@${p_remote_transfer_host}:${p_remote_transfer_dest}"
          fi
        else
          # shellcheck disable=SC2086
          ${p_transfer_command} ${p_remote_transfer_source} "${p_remote_transfer_user}@${p_remote_transfer_host}:${p_remote_transfer_dest}"
        fi
        p_transfer_result=$?
        
        p_handle_remote_response ${p_transfer_result} "${p_remote_transfer_host}" "${p_transfer_command}"
      fi
    }

    p_cubedir=${p_cubedir%/}
    
    if [ ${p_local} -eq 1 ]; then
      p_user_home_dir="$(cube_user_home_dir)" || cube_check_return
      p_localcubedir="$(printf '%s' "${p_cubedir}" | sed "s@~@${p_user_home_dir}@g")"
    fi
    
    p_script_name="$(cube_current_script_name)"
    p_script_path="$(cube_current_script_abs_path)"
    
    p_remote_script="${p_cubedir}/${p_script_name}"

    # Create a script that we'll execute on the remote end
    p_script_contents="cube_initial_directory=\${PWD}"
    p_script_envar_contents=""
    
    p_envar_scripts_final=""

    for p_envar_script in ${p_envar_scripts}; do
    
      p_envar_script_remove=0
    
      p_envar_script_enc_matches=$(expr "${p_envar_script}" : '.*\.enc$')
      
      if [ "${p_envar_script_enc_matches}" -ne 0 ]; then
        if cube_command_exists gpg ; then
          [ ${p_debug} -eq 1 ] && p_printf "Decrypting ${p_envar_script}"
          
          p_envar_script_new=$(echo "${p_envar_script}" | sed 's/enc$/dec/g')
          
          if [ "${p_envar_scripts_password}" = "" ]; then
            p_printf "Enter the password for ${p_envar_script}:\n"
            gpg --output "${p_envar_script_new}" --yes --decrypt "${p_envar_script}" || cube_check_return
          else
            [ ${p_debug} -eq 1 ] && p_printf "Decrypting ${p_envar_script} ...\n"
            p_gpg_output="$(echo "${p_envar_scripts_password}" | gpg --passphrase-fd 0 --batch --yes --output "${p_envar_script_new}" --decrypt "${p_envar_script}" 2>&1)" || cube_check_return "${p_gpg_output}"
          fi
          
          p_envar_script="${p_envar_script_new}"
          p_envar_script_remove=1
        else
          p_printf_error "gpg program not found on the PATH"
          p_exit 1
        fi
      fi
      
      p_envar_scripts_final=$(cube_append_str "${p_envar_scripts_final}" "${p_envar_script}")
      
      chmod u+x "${p_envar_script}"
      
      if [ ${p_envar_script_remove} -eq 1 ]; then
      
        # We don't check the return value of the remove because that can cause errors with `-s`
      
        # shellcheck disable=SC2116
        p_script_contents="${p_script_contents}
cd ${p_cubedir}/ || cube_check_return
. $(echo "${p_cubedir}")/$(basename "${p_envar_script}")"

        # shellcheck disable=SC2116
        p_script_contents="${p_script_contents}
rm -f $(echo "${p_cubedir}")/$(basename "${p_envar_script}")"
      else
        # shellcheck disable=SC2116
        p_script_contents="${p_script_contents}
cd ${p_cubedir}/ || cube_check_return
. $(echo "${p_cubedir}")/$(basename "${p_envar_script}") || cube_check_return"
      fi
    done
    
    p_envar_scripts="${p_envar_scripts_final}"
    
    for p_cube in ${p_cubes}; do
      
      [ ${p_debug} -eq 1 ] && p_printf "Processing cube ${p_cube}\n"
    
      if [ -d "${p_cube}" ]; then
        p_cube_name=$(basename "${p_cube}")
        
        [ ${p_debug} -eq 1 ] && p_printf "Cube directory name ${p_cube_name}\n"
        
        if [ -r "${p_cube}/${p_cube_name}.sh" ]; then
        
          [ ${p_debug} -eq 1 ] && p_printf "Found cube script at ${p_cube}/${p_cube_name}.sh\n"
        
          p_process_script "${p_cube}/${p_cube_name}.sh"
          chmod u+x "${p_cube}"/*.sh
          p_cube=${p_cube%/}
          p_script_contents="${p_script_contents}
cd ${p_cubedir}/${p_cube_name}/ || cube_check_return
cube_echo \"Started cube: ${p_cube_name}\"
POSIXCUBE_CUBE_NAME=\"${p_cube_name}\" POSIXCUBE_CUBE_NAME_WITH_PREFIX=\" ${p_cube_name}.sh\" . ${p_cubedir}/${p_cube_name}/${p_cube_name}.sh || cube_check_return \"Last command in cube. Note: some posixcube APIs may return non-zero successful. If this is not checked, then consider ending the script with the statement true.\"
cube_echo \"Finished cube: ${p_cube_name}\"
"
          if [ -r "${p_cube}/envars.sh" ]; then
            p_script_envar_contents="${p_script_envar_contents}
. ${p_cubedir}/${p_cube}/envars.sh || cube_check_return \"Failed loading cube envars\"
"
          fi
        else
          p_printf_error "Could not find ${p_cube_name}.sh in cube ${p_cube} directory."
          p_exit 1
        fi
      elif [ -r "${p_cube}" ]; then
        
        [ ${p_debug} -eq 1 ] && p_printf "Cube file name ${p_cube}\n"
        
        p_process_script "${p_cube}"
        p_cube_name=$(basename "${p_cube}")
        chmod u+x "${p_cube}"
        p_script_contents="${p_script_contents}
cd ${p_cubedir}/ || cube_check_return
cube_echo \"Started cube: ${p_cube_name}\"
POSIXCUBE_CUBE_NAME=\"${p_cube_name}\" POSIXCUBE_CUBE_NAME_WITH_PREFIX=\" ${p_cube_name}\" . ${p_cubedir}/${p_cube_name} || cube_check_return \"Last command in cube\"
cube_echo \"Finished cube: ${p_cube_name}\"
"
      elif [ -r "${p_cube}.sh" ]; then
        
        [ ${p_debug} -eq 1 ] && p_printf "Cube file name with .sh ${p_cube}\n"
        
        p_process_script "${p_cube}.sh"
        p_cube_name=$(basename "${p_cube}.sh")
        chmod u+x "${p_cube}.sh"
        p_script_contents="${p_script_contents}
cd ${p_cubedir}/ || cube_check_return
cube_echo \"Started cube: ${p_cube_name}\"
POSIXCUBE_CUBE_NAME=\"${p_cube_name}\" POSIXCUBE_CUBE_NAME_WITH_PREFIX=\" ${p_cube_name}\" . ${p_cubedir}/${p_cube_name} || cube_check_return \"Last command in cube\"
cube_echo \"Finished cube: ${p_cube_name}\"
"
      else
        p_printf_error "Cube ${p_cube} could not be found as a directory or script, or you don't have read permissions."
        p_exit 1
      fi
      p_script_contents="${p_script_contents}${POSIXCUBE_NEWLINE}cd \${cube_initial_directory}"
    done
    
    for p_cube in ${p_include_cubes}; do
      if [ -d "${p_cube}" ]; then
        p_cube_name=$(basename "${p_cube}")
        if [ -r "${p_cube}/${p_cube_name}.sh" ]; then
          p_process_script "${p_cube}/${p_cube_name}.sh"
          chmod u+x "${p_cube}"/*.sh
        fi
      elif [ -r "${p_cube}" ]; then
        p_process_script "${p_cube}"
        chmod u+x "${p_cube}"
      elif [ -r "${p_cube}.sh" ]; then
        p_process_script "${p_cube}.sh"
        chmod u+x "${p_cube}.sh"
      else
        p_printf_error "Cube ${p_cube} could not be found as a directory or script, or you don't have read permissions."
        p_exit 1
      fi
    done
    
    if [ "${p_commands}" != "" ]; then
      p_script_contents="${p_script_contents}
  ${p_commands}"
    fi
    
    p_shells_count=$(cube_elements_count "${p_shells}")

    if [ "${p_shells}" != "" ] && [ "${p_shells}" != "${p_exec_shell}" ]; then
      if [ "${p_shells_count}" = "1" ]; then
        p_printf "Auto-detecting non-standard shell ${p_shells}\n"
        p_exec_shell="${p_shells}"
      else
        p_printf "Warning: Multiple shebang shells detected (${p_shells}). Everything will be sourced under ${p_exec_shell}\n"
      fi
    fi

    p_script="cube_exec.sh"
    
    cat <<HEREDOC > "${p_script}"
#!${p_exec_shell}
POSIXCUBE_APIS_ONLY=1
POSIXCUBE_COLORS="${POSIXCUBE_COLORS}"
. ${p_remote_script}
if [ \$? -ne 0 ] ; then
  echo "Could not source ${p_remote_script} script" 1>&2
  exit 1
fi

cubevar_api_debug=${p_debug}
cubevar_api_superuser="${p_superuser}"
cubevar_api_superuser_command="${p_superuser_command}"
cubevar_api_roles="${p_roles}"
${p_script_envar_contents}
${p_options}
${p_script_contents}

if [ "\${cubevar_api_post_restart}" != "" ]; then
  for p_post in \${cubevar_api_post_restart}; do
    cube_service restart "\${p_post}"
  done
fi
HEREDOC

    chmod +x "${p_script}"
            
    [ ${p_debug} -eq 1 ] && p_printf "Script ${p_script}:\n"
    
    [ ${p_debug} -eq 1 ] && cat "${p_script}"
    
    p_upload="${p_script} "

    if [ "${p_cubes}" != "" ]; then
      for p_cube in ${p_cubes}; do
        if [ -d "${p_cube}" ]; then
          p_cube_name=$(basename "${p_cube}")
          if [ -r "${p_cube}/${p_cube_name}.sh" ]; then
            p_cube=${p_cube%/}
            
            [ ${p_debug} -eq 1 ] && p_printf "Planning to upload ${p_cube}\n"
            
            p_upload="${p_upload} ${p_cube}"
          fi
        elif [ -r "${p_cube}" ]; then
          p_cube_name=$(basename "${p_cube}")
            
          [ ${p_debug} -eq 1 ] && p_printf "Planning to upload ${p_cube}\n"
          
          p_upload="${p_upload} ${p_cube}"
        elif [ -r "${p_cube}.sh" ]; then
          p_cube_name=$(basename "${p_cube}.sh")
            
          [ ${p_debug} -eq 1 ] && p_printf "Planning to upload ${p_cube}.sh\n"
          
          p_upload="${p_upload} ${p_cube}.sh"
        fi
      done
    fi

    if [ "${p_include_cubes}" != "" ]; then
      for p_cube in ${p_include_cubes}; do
        if [ -d "${p_cube}" ]; then
          p_cube_name=$(basename "${p_cube}")
          if [ -r "${p_cube}/${p_cube_name}.sh" ]; then
            p_cube=${p_cube%/}
            p_upload="${p_upload} ${p_cube}"
          fi
        elif [ -r "${p_cube}" ]; then
          p_cube_name=$(basename "${p_cube}")
          p_upload="${p_upload} ${p_cube}"
        elif [ -r "${p_cube}.sh" ]; then
          p_cube_name=$(basename "${p_cube}.sh")
          p_upload="${p_upload} ${p_cube}.sh"
        else
          p_printf_error "Could not find ${p_cube}"
          p_exit 1
        fi
      done
    fi

    p_async=1
    
    if [ ${p_skip_init} -eq 0 ]; then
    
      if [ "${p_hosts}" != "" ]; then
        if [ ${p_quiet} -eq 0 ]; then
          if [ ${p_local} -eq 1 ]; then
            p_printf "Preparing hosts: ${p_hosts} (and local) ...\n"
          else
            p_printf "Preparing hosts: ${p_hosts} ...\n"
          fi
        fi
      
        p_wait_pids=""
        for p_host in ${p_hosts}; do
          if [ "${p_transfer_command}" = "${POSIXCUBE_TRANSFER_RSYNC}" ]; then
            # Debian doesn't have rsync installed by default
            p_remote_ssh "${p_host}" "${p_user}" "[ ! -d \"${p_cubedir}\" ] && mkdir -p ${p_cubedir}; RC=\$?; command -v rsync >/dev/null 2>&1 || (command -v apt-get >/dev/null 2>&1 && ${p_superuser} apt-get -y install rsync); exit \${RC};"
          else
            p_remote_ssh "${p_host}" "${p_user}" "[ ! -d \"${p_cubedir}\" ] && mkdir -p ${p_cubedir}"
          fi
        done
        
        if [ "${p_wait_pids}" != "" ]; then
          [ ${p_debug} -eq 1 ] && p_printf "Waiting on initialization PIDs: ${p_wait_pids} ...\n"
          
          wait ${p_wait_pids}
          p_host_output_result=$?
          
          p_handle_remote_response ${p_host_output_result} "" "Remote commands through SSH"
        fi
        
        [ ${p_quiet} -eq 0 ] && p_printf "Completed preparation.\n"

        [ ${p_quiet} -eq 0 ] && p_printf "Transferring files to hosts: ${p_hosts} ...\n"
        
        # If this script is elsewhere and a symlink, then with certain transfer modes, the script won't be transferred properly,
        # so we copy it locally.
        p_created_temp_script=0
        if ! cube_file_exists "${p_script_name}"; then
          [ ${p_debug} -eq 1 ] && p_printf "Creating local script ${p_script_path} ${p_script_name} ...\n"
          cp -fL "${p_script_path}" "${p_script_name}" || cube_check_return
          p_created_temp_script=1
        fi

        p_wait_pids=""
        for p_host in ${p_hosts}; do
          p_remote_transfer "${p_host}" "${p_user}" "${p_upload} ${p_script_name} ${p_envar_scripts}" "${p_cubedir}/"
        done
        
        if [ "${p_wait_pids}" != "" ]; then
          [ ${p_debug} -eq 1 ] && p_printf "Waiting on transfer PIDs: ${p_wait_pids} ...\n"
          
          wait ${p_wait_pids}
          p_host_output_result=$?
          
          p_handle_remote_response ${p_host_output_result} "" "${p_transfer_command}"
        fi

        if [ ${p_created_temp_script} -eq 1 ]; then
          rm -f "${p_script_name}" || cube_check_return
        fi

        [ ${p_quiet} -eq 0 ] && p_printf "Completed transfers.\n"
      fi

      if [ ${p_local} -eq 1 ]; then
        if [ ! -d "${p_localcubedir}" ]; then
          mkdir -p "${p_localcubedir}" || cube_check_return
        fi
        
        [ ${p_debug} -eq 1 ] && p_printf "Preparing local execution ...\n"
        
        # shellcheck disable=SC2086
        cp -LfR ${p_upload} ${p_script_path} ${p_envar_scripts} ${p_localcubedir}/ || cube_check_return
        
        [ ${p_debug} -eq 1 ] && p_printf "Completed local preparation.\n"
      fi
    fi
    
    p_wait_pids=""
    p_async=${p_async_cubes}
    
    for p_host in ${p_hosts}; do
      if [ ${p_quiet} -eq 0 ]; then
        if cube_string_contains "${p_host}" "@"; then
          p_host_final="$(cube_string_substring_after "${p_host}" "@")"
        else
          p_host_final="${p_host}"
        fi
        
        p_display_user="${p_user}"
        if cube_string_contains "${p_host}" "@"; then
          p_display_user="$(cube_string_substring_before "${p_host}" "@")"
        fi
        
        p_printf "[${POSIXCUBE_COLOR_GREEN}${p_host_final}${POSIXCUBE_COLOR_RESET}] Executing ssh ${p_display_user}@${p_host_final} '${p_exec_shell} ${p_cubedir}/${p_script}' ...\n"
      fi
      
      p_remote_ssh "${p_host}" "${p_user}" "${p_exec_shell} ${p_cubedir}/${p_script}"
    done
    
    if [ ${p_local} -eq 1 ]; then
      cube_echo "Executing \`${p_exec_shell} ${p_localcubedir}/${p_script}\` locally ..."
      
      "${p_exec_shell}" "${p_localcubedir}/${p_script}"
    fi

    if [ "${p_wait_pids}" != "" ]; then
      [ ${p_debug} -eq 1 ] && p_printf "Waiting on cube execution PIDs: ${p_wait_pids} ...\n"
      
      wait ${p_wait_pids}
      p_host_output_result=$?
      
      p_handle_remote_response ${p_host_output_result} "" "Cube execution"
    fi

    p_exit 0
  fi
fi

# Contributors:
#   * Kevin Grigorenko (kevin@myplaceonline.com)
#   * laoshaw21
#
# Version History (using semantic versioning: http://semver.org/):
#   0.2.0
#     * Add -S option to run cube_service and cube_package APIs as superuser (Issue #12).
#     * Add cube_sudo API.
#     * Support user name in HOST specifier in addition to the -u option (Issue #8).
#     * Support bash autocompletion with user in the hostname
#     * Add new APIs cube_string_substring_before and cube_string_substring_after
#     * Breaking change: Option -p changed to -P.
#     * Add -p option which is passed to ssh (Issue #11).
#     * Breaking change: Option -i changed to -U.
#     * Add -i and -F options which are passed to ssh.
#     * Breaking change: Option -o changed to -O.
#     * Add -o option which is passed to ssh.
#   0.1.0
#     * First version
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
#   8. Use shellcheck: https://github.com/koalaman/shellcheck
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
#   8. Parameter expansion: http://pubs.opengroup.org/onlinepubs/9699919799/utilities/V3_chap02.html#tag_18_06_02
