#!/bin/bash
export U7S_BASE_DIR=$(realpath $(dirname $0)/..)
source $U7S_BASE_DIR/common/common.inc.sh

exec $(dirname $0)/nsenter.sh kube-apiserver \
	--etcd-cafile=$XDG_CONFIG_HOME/usernetes/master/ca.pem \
	--etcd-certfile=$XDG_CONFIG_HOME/usernetes/node/node.pem \
	--etcd-keyfile=$XDG_CONFIG_HOME/usernetes/node/node-key.pem \
	--etcd-servers "$ETCD_ENDPOINTS" \
	--client-ca-file=$XDG_CONFIG_HOME/usernetes/master/ca.pem \
	--kubelet-certificate-authority=$XDG_CONFIG_HOME/usernetes/master/ca.pem \
	--kubelet-client-certificate=$XDG_CONFIG_HOME/usernetes/master/kubernetes.pem \
	--kubelet-client-key=$XDG_CONFIG_HOME/usernetes/master/kubernetes-key.pem \
	--tls-cert-file=$XDG_CONFIG_HOME/usernetes/master/kubernetes.pem \
	--tls-private-key-file=$XDG_CONFIG_HOME/usernetes/master/kubernetes-key.pem \
	--service-account-key-file=$XDG_CONFIG_HOME/usernetes/master/service-account.pem \
	--service-cluster-ip-range=10.0.0.0/24 \
	--service-account-issuer="kubernetes.default.svc" \
	--service-account-signing-key-file=$XDG_CONFIG_HOME/usernetes/master/service-account-key.pem \
	--advertise-address=$(cat $XDG_RUNTIME_DIR/usernetes/parent_ip) \
	--allow-privileged \
	--authorization-mode=Node,RBAC \
	$@

