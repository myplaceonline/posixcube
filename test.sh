#!/bin/sh
# Some contrived examples

cube_echo "Hello World"

cube_package install atop
cube_service enable atop
cube_service start atop

if cube_command_exists dnf ; then
  dnf check-update || cube_check_return
fi

cube_ensure_directory ~/test/

cube_read_heredoc <<'HEREDOC'; cubevar_app_myconfig="${cube_read_heredoc_result}"
[app]
name=${cubevar_app_name}
test=${cubevar_app_test}
HEREDOC

cubevar_app_name="Hello World"
cubevar_app_test="{ host: $(cube_hostname), random: $(cube_random_number 10), memory: $(cube_total_memory), ip: $(cube_interface_ipv4_address eth0) }"

if cube_set_file_contents_string ~/test/test.cfg "${cubevar_app_myconfig}" ; then
  chmod 600 ~/test/test.cfg || cube_check_return
fi

# cube_set_file_contents ~/test/test.cfg templates/test.cfg.template

if cube_has_role "production" && cube_file_contains ~/test/test.cfg "ip: 10" ; then
  cube_throw "Production role on test box"
fi
