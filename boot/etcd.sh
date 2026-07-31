#!/bin/bash
export U7S_BASE_DIR=$(realpath $(dirname $0)/..)
source $U7S_BASE_DIR/common/common.inc.sh

exec etcd \
	--data-dir $XDG_DATA_HOME/usernetes/etcd \
	--name $(hostname -s) \
	--cert-file=$XDG_CONFIG_HOME/usernetes/peer/peer.pem \
	--key-file=$XDG_CONFIG_HOME/usernetes/peer/peer-key.pem \
	--peer-cert-file=$XDG_CONFIG_HOME/usernetes/peer/peer.pem \
	--peer-key-file=$XDG_CONFIG_HOME/usernetes/peer/peer-key.pem \
	--trusted-ca-file=$XDG_CONFIG_HOME/usernetes/node/ca.pem \
	--peer-trusted-ca-file=$XDG_CONFIG_HOME/usernetes/peer/ca.pem \
	--peer-client-cert-auth \
	--client-cert-auth \
	--listen-client-urls https://0.0.0.0:2379 \
	--listen-peer-urls https://0.0.0.0:2380 \
	--advertise-client-urls https://$U7S_PARENT_IP:2379 \
	--initial-advertise-peer-urls https://$U7S_PARENT_IP:2380 \
	$@
