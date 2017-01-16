# posixcube

## Usage

    usage: posixcube.sh -h HOST... [OPTION]... COMMAND...

      A POSIX compliant, shell script-based server automation framework.

      -?        Help.
      -h HOST   Target host. Option may be specified multiple times. The HOST may
                be preceded with USER@ to specify the remote user. If a host has
                a wildcard ('*'), then HOST is interpeted as a regular expression,
                with '*' replaced with '.*' and any matching hosts in the following
                files are added to the HOST list: /etc/ssh_config,
                /etc/ssh/ssh_config, ~/.ssh/config, /etc/ssh_known_hosts,
                /etc/ssh/ssh_known_hosts, ~/.ssh/known_hosts, and /etc/hosts.
      -c CUBE   Execute a cube. Option may be specified multiple times. If COMMANDS
                are also specified, cubes are run first.
      -u USER   SSH user. Defaults to ${USER}. This may also be specified in HOST.
      -e ENVAR  Shell script with environment variable assignments which is
                uploaded and sourced on each HOST. Option may be specified
                multiple times. Files ending with .enc will be decrypted
                temporarily. If not specified, defaults to envars*sh envars*sh.enc
      -P PWD    Password for decrypting .enc ENVAR files.
      -w PWDF   File that contains the password for decrypting .enc ENVAR files.
                Defaults to ~/.posixcube.pwd
      -r ROLE   Role name. Option may be specified multiple times.
      -O P=V    Set the specified variable P with the value V. Option may be
                specified multiple times. Do not put double quotes around V. If
                V contains *, replace with matching hosts per the -h algorithm.
      -U CUBE   Upload a CUBE but do not execute it. This is needed when one CUBE
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
      -S        Run cube_package and cube_service APIs as superuser.
      -i FILE   SSH `-i` option for identity file.
      -p PORT   SSH `-p` option.
      -o K=V    SSH `-o` option. Option may be specified multiple times. Defaults
                to `-o ConnectTimeout=5`.
      -F FILE   SSH `-F` option.
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
      
      sudo ${PATH_TO}/posixcube.sh -b && . /etc/bash_completion.d/posixcube_completion.sh
      
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
      
      2. We don't use `set -e` because some functions may handle all errors
      internally (with `cube_check_return`) and use a positive return code as a
      "benign" result (e.g. `cube_set_file_contents`). We don't use `set -u`
      because we source in the user's scripts and they may not want this behavior.
      
      3. Recent versions of many distributions encourage running most commands
      as a non-superuser, and then using `sudo` if needed, with some distributions
      disallowing remote SSH using the `root` account by default. First, the `sudo`
      command is not standardized (see http://unix.stackexchange.com/a/48553).
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
        the script first loops through every host and ensures that ~/posixcubes/
        exists, then it transfers itself to the remote host. These two actions
        may be skipped with the `-s` parameter if you've already run the script
        at least once and your version of this script hasn't been updated. Next,
        the script loops through every host and transfers any CUBEs and a script
        containing the CUBEs and COMMANDs to run (`cube_exec.sh`). If the shell
        is detected to be `bash`, then the above occur asynchronously across the
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
          Print $1 to stdout with $2 appended after a space if $1 was not blank.
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
          Ensure directory $1 exists. Return true if the file is created; otherwise, false.
          Example: cube_ensure_directory ~/.ssh/

      * cube_ensure_file
          Ensure file $1 exists. Return true if the file is created; otherwise, false.
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
          Print to stdout the IPv4 address of interface $1
          Example: cube_interface_ipv4_address eth0

      * cube_interface_ipv6_address
          Print to stdout the IPv6 address of interface $1
          Example: cube_interface_ipv6_address eth0

      * cube_prompt
          Prompt the question $1 followed by " (y/N)" and prompt for an answer.
          A blank string answer is equivalent to No. Return true if yes, false otherwise.
          Example: cube_prompt "Are you sure?"

      * cube_hostname
          Print to stdout the full hostname.
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
      
      * cube_string_contains
          Return true if $1 contains $2; otherwise, false.
          Example: cube_string_contains "${cubevar_app_str}" "@" && ...
      
      * cube_string_substring_before
          Print to stdout a substring of $1 strictly before the first match of the
          regular expression $2.
          Example: cubevar_app_str="$(cube_string_substring_before "${cubevar_app_str}" "@")"

      * cube_string_substring_after
          Print to stdout a substring of $1 strictly after the first match of the
          regular expression $2.
          Example: cubevar_app_str="$(cube_string_substring_after "${cubevar_app_str}" "@")"
      
      * cube_sudo
          Execute $* as superuser with all posixcube APIs available (see Philosophy #3).
          Example: cube_sudo cube_ensure_file /etc/app.txt

    Public Variables:

      * POSIXCUBE_APIS_ONLY
          Set this to any value to only source the public APIs in posixcube.sh.
          Example: POSIXCUBE_APIS_ONLY=true . posixcube.sh && cube_echo $(cube_random_number 10)
      
      * POSIXCUBE_SOURCED
          Set this to any value to only run a sub-COMMAND, most commonly `source`,
          to source in all ENVAR files, but skip actual execution of posixcube.
          Example: POSIXCUBE_SOURCED=true . posixcube.sh source; POSIXCUBE_SOURCED= ; cube_echo Test

    Source: https://github.com/myplaceonline/posixcube

## Examples

* [https://github.com/myplaceonline/myplaceonline_posixcubes](https://github.com/myplaceonline/myplaceonline_posixcubes):
  Cubes that build a full Ruby on Rails stack with haproxy load balancer (frontend), nginx+passenger Rails
  servers (web), postgresql database (database) and more (elasticsearch, database backup, rsyslog server, etc.).
