# posixcube

    usage: posixcube.sh -h HOST... [OPTION]... COMMAND...

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
      
      * cube_log:
          Print $1 to stdout prefixed with ([`date`] [`hostname`]) and
          suffixed with a newline (with optional printf arguments in $@).
          Example: cube_log "Hello World"

      * cube_error:
          Same as cube_log except output to stderr and include a red "Error: "
          message prefix.
          Example: cube_error "Goodbye World"

      * cube_throw:
          Same as cube_error but also print a stack of functions and processes
          (if available) and then call `exit 1`.
          Example: cube_throw "Expected some_file."

      * cube_check_numargs:
          Call cube_throw if there are less than $1 arguments in $@
          Example: cube_check_numargs 2 "${@}"

      * cube_service:
          Run the $1 action on the $2 service.
          Example: cube_service start crond

      * cube_check_command_exists:
          Check if $1 command or function exists in the current context.
          Example: cube_check_command_exists systemctl

      * cube_check_dir_exists:
          Check if $1 exists as a directory.
          Example: cube_check_dir_exists /etc/cron.d/

      * cube_check_file_exists:
          Check if $1 exists as a file with read access.
          Example: cube_check_file_exists /etc/cron.d/0hourly

      * cube_operating_system:
          Detect operating system and return one of the CUBE_OS_* values.
          Example: [ $(cube_operating_system) -eq ${POSIXCUBE_OS_LINUX} ] && ...

    Philosophy:

      Fail hard and fast.

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
