#!/bin/bash
export U7S_BASE_DIR=$(realpath $(dirname $0)/..)
source $U7S_BASE_DIR/common/common.inc.sh
nsenter::main $0 $@

: ${U7S_FLANNEL=}
if [[ $U7S_FLANNEL != 1 ]]; then
	log::error "U7S_FLANNEL needs to be 1"
	exit 1
fi

export NODE_NAME="$(hostname -s)"

exec flanneld \
	--iface-can-reach "$U7S_PARENT_IP" \
	--ip-masq \
	--public-ip "$U7S_PARENT_IP" \
	--kube-subnet-mgr \
	--kube-api-url "https://$(cat $XDG_CONFIG_HOME/usernetes/node/master):6443" \
	--kube-annotation-prefix "flannel.io" \
	--kubeconfig-file "$XDG_CONFIG_HOME/usernetes/node/kube-subnet-mgr.kubeconfig" \
	--net-config-path="$U7S_BASE_DIR/config/flannel/etcd/coreos.com_network_config" \
	$@
