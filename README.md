# posixcube

    usage: posixcube.sh -h HOST... [OPTION]... COMMANDS
    posixcube.sh version 0.1
    POSIX.1-2008-standard automation scripting.

      -?        Help.
      -h HOST   Target host. Option may be specified multiple times. If a host has
                a wildcard ('*'), then HOST is interpeted as a regular expression,
                with '*' replaced with '.*' and any matching hosts in the following
                files are added to the HOST list: /etc/ssh_config,
                /etc/ssh/ssh_config, ~/.ssh/config, /etc/ssh_known_hosts,
                /etc/ssh/ssh_known_hosts, ~/.ssh/known_hosts, and /etc/hosts.
      -u USER   SSH user. Defaults to \${USER}.
      -v        Show version information.
      -d        Print debugging information.
      -q        Quiet; minimize output.
      -i        If using bash, install programmable tab completion for SSH hosts.
      COMMANDS  Remote commands to run on each HOST.

    Examples:
    
      ./posixcube.sh -u root -h socrates -h seneca uptime
      
        Run the \`uptime\` command on hosts \`socrates\` and \`seneca\`
        as the user \`root\`.
      
      ./posixcube.sh -h web*.test.com uptime
      
        Run the \`uptime\` command on all hosts matching the regular expression
        web.*.test.com in the SSH configuration files.
      
      sudo ./posixcube.sh -i && source \
        /etc/bash_completion.d/posixcube_completion.sh
      
        For Bash users, install a programmable completion script to support tab
        auto-completion of hosts from SSH configuration files.
