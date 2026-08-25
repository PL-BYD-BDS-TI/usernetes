#!/bin/bash
export U7S_BASE_DIR=$(realpath $(dirname $0)/..)
source $U7S_BASE_DIR/common/common.inc.sh
source $U7S_BASE_DIR/config/netsy/netsy.inc.sh

# Running netsy as child process
(
netsy \
	--config=$XDG_CONFIG_HOME/usernetes/netsy/config.jsonc \
	$@
) &
CHILD=$!

PROBES=30
while [[ PROBES -gt 0 ]] && (! etcdctl --endpoints https://$(hostname):2379 --cacert=$XDG_CONFIG_HOME/usernetes/node/ca.pem --cert=$XDG_CONFIG_HOME/usernetes/node/node.pem --key=$XDG_CONFIG_HOME/usernetes/node/node-key.pem endpoint health 2>/dev/null); do
	PROBES=$((PROBES-1))
done

if [[ PROBES -le 0 ]]; then
	echo 'Netsy server unhealthy'
	kill $CHILD
	exit 1
fi

systemd-notify --ready

trap "systemd-notify --stopping; kill $CHILD" SIGINT

wait
