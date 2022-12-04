#!/bin/bash

set -e

# You can set this variable whatever you want in shell session right before running this script by issuing:
# export DATA_PATH='/usr/local/etc/nginx-ui'
DataPath=${DATA_PATH:-/etc/nginx-ui}

# Font color
FontBlack="\033[30m";
FontRed="\033[31m";
FontGreen="\033[32m";
FontYellow="\033[33m";
FontBlue="\033[34m";
FontPurple="\033[35m";
FontSkyBlue="\033[36m";
FontWhite="\033[37m";
FontSuffix="\033[0m";

cat_file_with_name() {
  while [[ "$#" -gt '0' ]]; do
    echo -e "${FontSkyBlue}# $1${FontSuffix}\n"
    cat "$1"
    echo ''
    shift
  done
}

curl() {
  $(type -P curl) -L -q --retry 5 --retry-delay 10 --retry-max-time 60 "$@"
}

identify_the_operating_system_and_architecture() {
  if [[ "$(uname)" == 'Linux' ]]; then
    case "$(uname -m)" in
    'i386' | 'i686')
      MACHINE='32'
      ;;
    'amd64' | 'x86_64')
      MACHINE='64'
      ;;
    'armv5tel')
      MACHINE='arm32-v5'
      ;;
    'armv6l')
      MACHINE='arm32-v6'
      grep Features /proc/cpuinfo | grep -qw 'vfp' || MACHINE='arm32-v5'
      ;;
    'armv7' | 'armv7l')
      MACHINE='arm32-v7a'
      grep Features /proc/cpuinfo | grep -qw 'vfp' || MACHINE='arm32-v5'
      ;;
    'armv8' | 'aarch64')
      MACHINE='arm64-v8a'
      ;;
    *)
      echo -e "${FontRed}error: The architecture is not supported.${FontSuffix}"
      exit 1
      ;;
    esac
    if [[ ! -f '/etc/os-release' ]]; then
      echo -e "${FontRed}error: Don't use outdated Linux distributions.${FontSuffix}"
      exit 1
    fi
  else
    echo -e "${FontRed}error: This operating system is not supported.${FontSuffix}"
    exit 1
  fi
}

get_latest_version() {
  # Get latest release version number
  local latest_release
  if ! latest_release=$(curl -sS -H "Accept: application/vnd.github.v3+json" "https://api.github.com/repos/0xJacky/nginx-ui/releases/latest"); then
    echo -e "${FontRed}error: Failed to get release list, please check your network.${FontSuffix}"
    exit 1
  fi

  RELEASE_LATEST="$(echo "$latest_release" | sed 'y/,/\n/' | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')"
  if [[ -z "$RELEASE_LATEST" ]]; then
    if echo "$latest_release" | grep -q "API rate limit exceeded"; then
      echo -e "${FontRed}error: github API rate limit exceeded${FontSuffix}"
    else
      echo -e "${FontRed}error: Failed to get the latest release version.${FontSuffix}"
      echo "Welcome bug report: https://github.com/0xJacky/nginx-ui/issues"
    fi
    exit 1
  fi
  RELEASE_LATEST="v${RELEASE_LATEST#v}"
}

download_nginx_ui() {
  local download_link
  download_link="https://github.com/0xJacky/nginx-ui/releases/download/$RELEASE_LATEST/nginx-ui-linux-$MACHINE.tar.gz"

  echo "Downloading Nginx UI archive: $download_link"
  if ! curl -R -H 'Cache-Control: no-cache' -L -o "$TAR_FILE" "$download_link"; then
    echo 'error: Download failed! Please check your network or try again.'
    return 1
  fi
  return 0
}

decompression() {
  echo "$1"
  if ! tar -zxf "$1" -C "$TMP_DIRECTORY"; then
    echo -e "${FontRed}error: Nginx UI decompression failed.${FontSuffix}"
    "rm" -r "$TMP_DIRECTORY"
    echo "removed: $TMP_DIRECTORY"
    exit 1
  fi
  echo "info: Extract the Nginx UI package to $TMP_DIRECTORY and prepare it for installation."
}

install_bin() {
  NAME="nginx-ui"
  install -m 755 "${TMP_DIRECTORY}/$NAME" "/usr/local/bin/$NAME"
}

install_config() {
  mkdir -p "$DataPath"
  if [[ ! -f "$DataPath/app.ini" ]]; then
cat > "$DataPath/app.ini" << EOF
[server]
RunMode = release
HttpPort = 9000
HTTPChallengePort = 9180
EOF
    echo "info: The default configuration file was installed to '$DataPath/app.ini' successfully!"
  fi

  echo -e "${FontGreen}note: The following are the current configuration for the nginx-ui."
  echo -e "${FontGreen}note: Please change the information if needed.${FontSuffix}"
  cat_file_with_name "$DataPath/app.ini"
}

main() {
  identify_the_operating_system_and_architecture

  # Important Variables
  TMP_DIRECTORY="$(mktemp -d)"
  TAR_FILE="${TMP_DIRECTORY}/nginx-ui-linux-$MACHINE.tar.gz"

  get_latest_version
  echo "info: Installing Nginx UI $RELEASE_LATEST for $(uname -m)"
  if ! download_nginx_ui; then
    "rm" -r "$TMP_DIRECTORY"
    echo "removed: $TMP_DIRECTORY"
    exit 1
  fi
  decompression "$TAR_FILE"

  install_bin
  echo 'installed: /usr/local/bin/nginx-ui'
  "rm" -r "$TMP_DIRECTORY"

  install_config
}

main "$@"
