#!/bin/zsh

# Cleans up the folder, removing any Vivado installation

script_dir=$(dirname -- "$(readlink -nf $0)";)
source $script_dir/header.sh
validate_macos

cd $script_dir/..home/
to_remove=(".cache" ".dbus" ".local" "Xilinx" ".Xilinx"
"Desktop" "installer" ".bash_history" ".lesshst" ".sudo_as_admin_successful"
".Xauthority" ".xsession-errors" ".XIC.lock" ".mozilla" ".java" ".config"
".fontconfig" )
for file in ${to_remove[@]}
do
    rm -rf $file
done