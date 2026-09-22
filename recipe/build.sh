#!/usr/bin/env bash

set -exuo pipefail

module='github.com/containers/podman'
export GOPATH="$( pwd )"
LICENSE_DIR="$( pwd )/license-files"

if [[ "$target_platform" == "osx-arm64" || "$target_platform" == "osx-64" ]]; then
  make -C "src/${module}" podman-remote
  make -C "src/${module}" podman-remote-darwin-docs
  # install.remote also tries to install podman-mac-helper which is not built;
  # install the remote binary manually and use separate targets for the rest.
  install -d -m 755 "${PREFIX}/bin"
  install -m 755 "src/${module}/bin/darwin/podman" "${PREFIX}/bin/podman"
  make -C "src/${module}" \
    install.man install.completions \
    ETCDIR="${PREFIX}/etc"
else
  make -C "src/${module}" all
  make -C "src/${module}" \
    install install.completions \
    ETCDIR="${PREFIX}/etc"
  # podman is built with the `systemd` build tag (for healthcheck timers). On a
  # host with a systemd journal that would also switch the default log driver
  # and events backend to journald -- but conda-forge's conmon is built without
  # journald support ("Include journald in compilation path to log to systemd
  # journal"), so keep the non-systemd defaults for those two.
  mkdir -p "${PREFIX}/etc/containers/containers.conf.d"
  cat > "${PREFIX}/etc/containers/containers.conf.d/10-conda-forge.conf" <<EOF
[containers]
log_driver = "k8s-file"

[engine]
events_logger = "file"
EOF
fi

cd "./src/${module}"
if [[ "$target_platform" == "osx-arm64" || "$target_platform" == "osx-64" ]]; then
  GOFLAGS="-tags=remote,exclude_graphdriver_btrfs,containers_image_openpgp" \
    go-licenses save ./cmd/podman/ --save_path="$LICENSE_DIR"
else
  go-licenses save ./cmd/podman/ --save_path="$LICENSE_DIR"
fi
