#!/bin/zsh

# Initial setup on host (macOS) side

script_dir=$(dirname -- "$(readlink -nf $0)";)
parent_dir=$(dirname "$script_dir")
home_dir=$parent_dir/home
source "$script_dir/header.sh"
# Make sure that the script is run in macOS and not the Docker container
validate_macos

# Make sure permissions are right
if [[ "$current_user" == "root" ]]
then
	f_echo "Do not execute this script as root."
	exit 1
fi

# Make sure there are no previous installations in this folder
if [ -d "$home_dir/Xilinx" ]
then
	f_echo "A previous installation was found. To reinstall, use the cleanup.sh script."
	exit 1
fi

validate_internet

f_echo "Advancing with the setup requires the following:"
f_echo "- Agreeing to Xilinx'/AMD's EULAs (which can be obtained by extracting the installation binary)"
f_echo "- Enabling WebTalk data collection for version 2021.1 and agreeing to corresponding terms"
f_echo "- Installation of Rosetta 2 and agreeing to Apple's corresponding software license agreement"
f_echo "Proceed [y/n]?"
read user_consent
case $user_consent in
[yY]|[yY][eE]*)
	f_echo "Continuing setup..."
	;;
[nN]|[nN][oO]*)
	f_echo "Aborting setup."
	exit 1
	;;
*)
	f_echo "Invalid option."
	exit 1
	;;
esac

# Check if XQuartz is installed
if ! command -v xquartz &> /dev/null
then
	f_echo "XQuartz is not installed. Please install XQuartz from https://www.xquartz.org/ or with `brew cask install xquartz`."
	exit 1
fi

ensure_x11_is_running

# Check if XQuartz is configured to listen on TCP
NOLISTEM=$(defaults read org.xquartz.X11 nolisten_tcp)
if [[ "$NOLISTEM" == "1" ]]; then
	f_echo "XQuartz is not configured to listen on TCP, this will be adjusted."
	f_echo "Exit XQuartz"
	osascript -e 'quit app "XQuartz"'
	sleep 5
	XQUARTZ=$(pgrep -fl XQuartz)
	if [[ -n "$XQUARTZ" ]]; then
		f_echo "XQuartz is still running. Please quit it."
		exit 1
	fi

	f_echo "Enable XQuartz to listen on TCP"
	defaults write org.xquartz.X11 nolisten_tcp 0
	f_echo "Restart XQuartz"
	open -a XQuartz
	sleep 5
	XQUARTZ=$(pgrep -fl XQuartz)
	if [[ -z "$XQUARTZ" ]]; then
		f_echo "XQuartz is not running. Please start it."
		exit 1
	fi
else
	f_echo "XQuartz is configured to listen on TCP."
fi

# Check if the Mac is Intel or Apple Silicon
if [[ "$(uname -m)" == "x86_64" ]]; then
	f_echo "Mac is Intel-based. Rosetta installation is not required."
else
	if arch -arch x86_64 uname -m > /dev/null 2>&1; then
		f_echo "Rosetta is already installed."
	else
		f_echo "Rosetta is not installed."
		f_echo "Proceeding with Rosetta installation..."
		if ! softwareupdate --install-rosetta --agree-to-license; then
			f_echo "Error installing Rosetta."
			exit 1
		fi
	fi
fi

# Get the absolute path to the file
installation_binary=$(find "$home_dir/" -type f -name "*.bin" -exec realpath {} \; | head -n 1)
if [[ -z "$installation_binary" ]]; then
  f_echo "No installation binary found. Please put the Vivado installation file into the home folder and press Enter."
  read
	installation_binary=$(find "$home_dir/" -type f -name "*.bin" -exec realpath {} \; | head -n 1)
	if [[ -z "$installation_binary" ]]; then
    f_echo "No installation binary found. Exiting."
    exit 1
  fi
fi
f_echo "Installation binary detected: $installation_binary"

# check file hash
file_hash=$(md5 -q "$installation_binary")
set_vivado_version_from_hash "$file_hash"
if [ "$?" -eq 0 ]
then
  f_echo "Valid file provided. Detected version $vivado_version"
else
  f_echo "File corrupted or version not supported."
  exit 1
fi

# write file path to "install_bin"
install_bin_path="${installation_binary#"$home_dir"}"
install_bin_path="/home/user$install_bin_path"
echo -n "$install_bin_path" > "$script_dir/install_bin"

# Make the user own the whole folder
if ! chown -R $current_user "$home_dir"
then
	f_echo "Higher privileges are required to make the folder owned by the user."
	if ! sudo chown -R $current_user "$home_dir"
	then
		f_echo "Error setting $current_user as owner of this folder."
		exit 1
	fi
fi

# Make the scripts executable
if xattr -p com.apple.quarantine "$script_dir/xvcd/bin/xvcd" &>/dev/null
then
	if ! xattr -d com.apple.quarantine "$script_dir/xvcd/bin/xvcd"
	then
		f_echo "You need to remove the quarantine attribute from $script_dir/xvcd/bin/xvcd manually."
		wait_for_user_input
	fi
fi

if ! chmod +x "$script_dir"/*.sh "$script_dir/xvcd/bin/xvcd" "$installation_binary"
then
	f_echo "Error making the scripts executable."
	exit 1
fi

# make sure that Docker is installed
start_docker

# Attempt to enable Rosetta and set swap to at least 2GiB in Docker
eval "$script_dir/configure_docker.sh"

# Generate the Docker image
if ! eval "$script_dir/gen_image.sh"
then
	exit 1
fi

# Start container
f_echo "Now, the container is started (only terminal, no GUI) and the actual installation process begins."
docker run --init -it --rm --name vivado_container \
  --mount type=bind,source="$home_dir",target="/home/user" \
  --mount type=bind,source="$parent_dir/scripts",target="/home/user/scripts" \
  --platform linux/amd64 x64-linux sudo -H -u user bash /home/user/scripts/install_vivado.sh
