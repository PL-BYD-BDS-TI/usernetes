#!/bin/bash
set -eu -o pipefail

y() {
	NAME=$1
	REPO=$2
	echo "$NAME=$(curl -s "https://api.github.com/repos/$REPO/releases/latest" | jq -r '.tag_name')"
}

x() {
	NAME=$1
	REPO=$2
	echo $NAME=$(curl -s "https://api.github.com/repos/$REPO/releases" | jq -r '.[].tag_name' | python3 -c '
import fileinput
from packaging.version import Version
versions = list()
for line in fileinput.input():
    versions.append(line.strip())
versions.sort(key=Version)
print(versions[-1])
')
}

z() {
	NAME=$1
	REPO=$2
	echo $NAME=$(curl -s "https://api.github.com/repos/$REPO/releases" | jq -r '.[].tag_name' | python3 -c '
import fileinput
import re
from packaging.version import Version
versions = list()
for line in fileinput.input():
    line = line.strip()
    if (re.match(r"^v?\d+\.\d+\.\d+$", line)):
        versions.append(line)
versions.sort(key=Version)
print(versions[-1])
')
}

g() {
	NAME=$1
	REPO=$2
	echo $NAME=$(git -c 'versionsort.suffix=-' ls-remote --refs --tags --sort='v:refname' "$REPO" | tail --lines=1 | cut --delimiter='/' --fields=3)
}

y ROOTLESSKIT_COMMIT rootless-containers/rootlesskit
x CRIO_COMMIT cri-o/cri-o
echo
y KUBE_NODE_COMMIT kubernetes/kubernetes
echo
x CONMON_RELEASE containers/conmon
x CRUN_RELEASE containers/crun
x FUSE_OVERLAYFS_RELEASE containers/fuse-overlayfs
y KUBE_MASTER_RELEASE kubernetes/kubernetes
y KUBE_GIT_VERSION kubernetes/kubernetes
x CNI_PLUGINS_RELEASE containernetworking/plugins
y FLANNEL_CNI_PLUGIN_RELEASE flannel-io/cni-plugin
x FLANNEL_RELEASE flannel-io/flannel
x KUBE_NETWORK_POLICIES_RELEASE kubernetes-sigs/kube-network-policies
z ETCD_RELEASE etcd-io/etcd
x CFSSL_RELEASE cloudflare/cfssl
g WG_TOOLS_RELEASE https://git.zx2c4.com/wireguard-tools.git
x CRI_TOOLS_RELEASE kubernetes-sigs/cri-tools
echo
IFS=' ' read -r -a goalpine <<< $(curl -s https://hub.docker.com/_/golang | grep -Po '[0-9]+\.[0-9]+\.[0-9]+\-alpine[0-9]+\.[0-9]+' | head -1 | sed -e 's/\-alpine/ /')
echo ALPINE_RELEASE="${goalpine[1]}"
echo GO_RELEASE="${goalpine[0]}"
