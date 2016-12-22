# posixcube

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
      -v        Show version information.
      -d        Print debugging information.
      -q        Quiet; minimize output.
      -i        If using bash, install programmable tab completion for SSH hosts.
      -s        Skip remote host initialization (making ~/posixcubes, uploading
                posixcube.sh, etc.
      -k        Keep the cube_exec.sh generated script.
      COMMAND   Remote command to run on each HOST. Option may be specified
                multiple times. If no HOSTs are specified, available sub-commands:
                  edit: Decrypt, edit, and re-encrypt ENVAR file with $EDITOR.
                  show: Decrypt and print ENVAR file.

    Description:

      posixcube.sh is used to execute CUBEs and/or COMMANDs on one or more HOSTs.
      
      A CUBE is a shell script or directory containing shell scripts. The CUBE
      is rsync'ed to each HOST. If CUBE is a shell script, it's executed. If
      CUBE is a directory, a shell script of the same name in that directory
      is executed. In both cases, the directory is changed to the directory
      containing the script before execution so that you may reference files
      such as templates using relative paths.
      
      An ENVAR script is encouraged to use environment variable names of the form
      cubevar_${uniquecontext}_envar="value".
      
      Both CUBEs and COMMANDs may execute any of the functions defined in the
      "Public APIs" in the posixcube.sh script. Short descriptions of the functions
      follows. See the source comments above each function for details.
      
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

      * cube_shell
          Detect running shell and return one of the CUBE_SHELL_* values.
          Example: [ $(cube_shell) -eq ${POSIXCUBE_SHELL_BASH} ] && ...

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

    Philosophy:

      Fail hard and fast. In principle, a well written script would check ${?}
      after each command and either gracefully handle it, or report an error.
      Few people write scripts this well, so we enforce this check (using
      `cube_check_return` within all APIs) and we encourage you to do the same
      in your scripts with `some_command || cube_check_return`. We do not use
      `set -e` because some functions may handle all errors internally (with
      `cube_check_return` and use a positive return code as a "benign" result
      (e.g. `cube_set_file_contents`).

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
      conflicts, name functions cube_${cubename}_${function}

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

      ./posixcube.sh -e production.sh.enc show
      
        Decrypt and show the contents of production.sh
      
      ./posixcube.sh -e production.sh.enc edit
      
        Decrypt, edit, and re-encrypt the contents of production.sh with $EDITOR
      
    Source: https://github.com/myplaceonline/posixcube
