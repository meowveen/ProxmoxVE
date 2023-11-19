#!/usr/bin/env bash

# Copyright (c) 2021-2023 tteck
# Author: tteck (tteckster)
# License: MIT
# https://github.com/tteck/Proxmox/raw/main/LICENSE

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies"
$STD apt-get install -y curl
$STD apt-get install -y sudo
$STD apt-get install -y mc
msg_ok "Installed Dependencies"

get_latest_release() {
  curl -sL https://api.github.com/repos/$1/releases/latest | grep '"tag_name":' | cut -d'"' -f4
}

DOCKER_LATEST_VERSION=$(get_latest_release "moby/moby")
DOCKER_COMPOSE_LATEST_VERSION=$(get_latest_release "docker/compose")

msg_info "Installing Docker $DOCKER_LATEST_VERSION"
DOCKER_CONFIG_PATH='/etc/docker/daemon.json'
mkdir -p $(dirname $DOCKER_CONFIG_PATH)
echo -e '{\n  "log-driver": "journald"\n}' >/etc/docker/daemon.json
$STD sh <(curl -sSL https://get.docker.com)
msg_ok "Installed Docker $DOCKER_LATEST_VERSION"

msg_info "Installing Docker Compose $DOCKER_COMPOSE_LATEST_VERSION"
DOCKER_CONFIG=${DOCKER_CONFIG:-$HOME/.docker}
mkdir -p $DOCKER_CONFIG/cli-plugins
curl -sSL https://github.com/docker/compose/releases/download/$DOCKER_COMPOSE_LATEST_VERSION/docker-compose-linux-x86_64 -o ~/.docker/cli-plugins/docker-compose
chmod +x $DOCKER_CONFIG/cli-plugins/docker-compose
msg_ok "Installed Docker Compose $DOCKER_COMPOSE_LATEST_VERSION"

msg_info "Installing Dockge"
mkdir -p /opt/stacks /opt/dockge
cd /opt/dockge
$STD curl https://raw.githubusercontent.com/louislam/dockge/master/compose.yaml --output compose.yaml
$STD docker compose up -d
msg_ok "Installed Dockge"

read -r -p "Would you like to add Home Assistant? <y/N> " prompt
if [[ ${prompt,,} =~ ^(y|yes)$ ]]; then
  msg_info "Adding Home Assistant compose.yaml"
  mkdir -p /opt/stacks/homeassistant
  cat <<EOF >/opt/stacks/homeassistant/compose.yaml
version: "3.3"
services:
  home-assistant:
    container_name: homeassistant
    privileged: true
    restart: unless-stopped
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - /dev:/dev
      - ha_config:/config
    network_mode: host
    image: ghcr.io/home-assistant/home-assistant:stable
volumes:
  ha_config: {}
networks: {}
EOF
msg_ok "Added Home Assistant compose.yaml"
fi

motd_ssh
customize

msg_info "Cleaning up"
$STD apt-get autoremove
$STD apt-get autoclean
msg_ok "Cleaned"
