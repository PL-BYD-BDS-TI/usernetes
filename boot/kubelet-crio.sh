#!/bin/bash
export U7S_BASE_DIR=$(realpath $(dirname $0)/..)
source $U7S_BASE_DIR/common/common.inc.sh

PROBES=3
while [[ PROBES -gt 0 ]] && (! crictl -t 7s -r unix://$XDG_RUNTIME_DIR/usernetes/crio/crio.sock info 2>/dev/null); do
  sleep 3
  PROBES=$((PROBES-1))
done

if [[ PROBES -le 0 ]]; then
  echo 'CRI-O is not ready'
  exit 1
fi

exec $(dirname $0)/kubelet.sh --container-runtime-endpoint unix://$XDG_RUNTIME_DIR/usernetes/crio/crio.sock $@
