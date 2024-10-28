#!/bin/zsh

# starts the Docker container and xvcd for USB forwarding

script_dir=$(dirname -- "$(readlink -nf $0)";)
parent_dir=$(dirname "$script_dir")
home_dir=$parent_dir/home
source "$script_dir/header.sh"
validate_macos

# this is called when the container stops or ctrl+c is hit
function stop_container {
    docker kill vivado_container > /dev/null 2>&1
    f_echo "Stopped Docker container"
    killall xvcd > /dev/null 2>&1
    f_echo "Stopped xvcd"
    exit 0
}
trap 'stop_container' INT

# Make sure everything is setup to run the container
start_docker
if [[ $(docker ps) == *vivado_container* ]]
then
    f_echo "There is already an instance of the container running."
    exit 1
fi
killall xvcd > /dev/null 2>&1

ensure_x11_is_running
XAUTH_COOKIE=$(xauth list :0 | awk '{print $3}')

if false; then
    docker run -it --init --rm --name vivado_container \
    --mount type=bind,source="$home_dir",target="/home/user" \
    --mount type=bind,source="$script_dir",target="/home/user/scripts" \
    --mount type=bind,source="$HOME/.Xauthority",target="/root/.Xauthority" \
    -e DISPLAY=host.docker.internal:0 \
     -e XAUTH_COOKIE=$XAUTH_COOKIE \
    --platform linux/amd64 \
    x64-linux sudo -E -H -u user bash
    exit 0
fi

# run container
docker run --init --rm --name vivado_container \
  --mount type=bind,source="$home_dir",target="/home/user" \
  --mount type=bind,source="$script_dir",target="/home/user/scripts" \
  --mount type=bind,source="$HOME/.Xauthority",target="/root/.Xauthority" \
  -e DISPLAY=host.docker.internal:0 \
  -e XAUTH_COOKIE=$XAUTH_COOKIE \
  --platform linux/amd64 \
  x64-linux sudo -E -H -u user bash /home/user/scripts/linux_start.sh &
sleep 7

f_echo "Running xvcd for USB forwarding..."
# while vivado_container is running
while [[ $(docker ps) == *vivado_container* ]]
do
    # if there is a running instance of xvcd
    if pgrep -x "xvcd" > /dev/null
    then
        :
    else
        eval "$script_dir/xvcd/bin/xvcd > /dev/null 2>&1 &"
        sleep 2
    fi
done
stop_container
