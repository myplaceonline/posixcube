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
      COMMAND   Remote commands to run on each HOST. Option may be specified
                multiple times.

    Description:

      posixcube.sh is used to execute COMMANDs and/or CUBEs on one or more HOSTs.
      
      A CUBE is a shell script or directory containing shell scripts. The CUBE
      is rsync'ed to each HOST. If CUBE is a shell script, it's executed. If
      CUBE is a directory, a shell script of the same name in that directory
      is executed.

    Examples:
    
      ./posixcube.sh -u root -h socrates -h seneca uptime
      
        Run the `uptime` command on hosts `socrates` and `seneca`
        as the user `root`.
      
      ./posixcube.sh -h socrates -c server_check.sh
      
        Run the `server_check.sh` cube (script) on the `socrates` host.
      
      ./posixcube.sh -h web*.test.com uptime
      
        Run the `uptime` command on all hosts matching the regular expression
        web.*.test.com in the SSH configuration files.
      
      sudo ./posixcube.sh -i && . /etc/bash_completion.d/posixcube_completion.sh
      
        For Bash users, install a programmable completion script to support tab
        auto-completion of hosts from SSH configuration files.
