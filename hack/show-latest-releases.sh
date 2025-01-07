#!/bin/bash
set -eu -o pipefail

x() {
	NAME=$1
	REPO=$2
	echo "$NAME=$(curl -s "https://api.github.com/repos/$REPO/releases/latest" | jq -r '.tag_name')"
}

x ROOTLESSKIT_COMMIT rootless-containers/rootlesskit
x CONTAINERD_COMMIT containerd/containerd
x CRIO_COMMIT cri-o/cri-o

x KUBE_NODE_COMMIT kubernetes/kubernetes

x SLIRP4NETNS_RELEASE rootless-containers/slirp4netns
x CONMON_RELEASE containers/conmon
x CRUN_RELEASE containers/crun
x FUSE_OVERLAYFS_RELEASE containers/fuse-overlayfs
x CONTAINERD_FUSE_OVERLAYFS_RELEASE containerd/fuse-overlayfs-snapshotter
x KUBE_MASTER_RELEASE kubernetes/kubernetes
x KUBE_GIT_VERSION kubernetes/kubernetes
x CNI_PLUGINS_RELEASE containernetworking/plugins
x FLANNEL_CNI_PLUGIN_RELEASE flannel-io/cni-plugin
x FLANNEL_RELEASE flannel-io/flannel
x ETCD_RELEASE etcd-io/etcd
x CFSSL_RELEASE cloudflare/cfssl

# echo ALPINE_RELEASE=
# echo GO_RELEASE=
# echo FEDORA_RELEASE=
