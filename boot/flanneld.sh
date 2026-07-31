#!/bin/bash
export U7S_BASE_DIR=$(realpath $(dirname $0)/..)
source $U7S_BASE_DIR/common/common.inc.sh
nsenter::main $0 $@

: ${U7S_FLANNEL=}
if [[ $U7S_FLANNEL != 1 ]]; then
	log::error "U7S_FLANNEL needs to be 1"
	exit 1
fi

exec flanneld \
	--iface-can-reach "$U7S_PARENT_IP" \
	--ip-masq \
	--public-ip "$U7S_PARENT_IP" \
	--etcd-endpoints "$ETCD_ENDPOINTS" \
	--etcd-cafile "$XDG_CONFIG_HOME/usernetes/node/ca.pem" \
	--etcd-certfile "$XDG_CONFIG_HOME/usernetes/node/node.pem" \
	--etcd-keyfile "$XDG_CONFIG_HOME/usernetes/node/node-key.pem" \
	$@
