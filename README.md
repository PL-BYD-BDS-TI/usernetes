# Usernetes: Kubernetes without the root privileges

Usernetes aims to provide a reference distribution of Kubernetes that can be installed under a user's `$HOME` and does not require the root privileges.

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->


- [Included components](#included-components)
- [Adoption](#adoption)
- [How it works](#how-it-works)
- [Restrictions](#restrictions)
- [Requirements](#requirements)
  - [cgroup v2](#cgroup-v2)
    - [Enable cpu controller](#enable-cpu-controller)
- [Quick start](#quick-start)
  - [Download](#download)
  - [Install](#install)
  - [Use `kubectl`](#use-kubectl)
  - [Uninstall](#uninstall)
- [Run Usernetes in Docker](#run-usernetes-in-docker)
  - [Single node](#single-node)
  - [Multi node (Docker Compose)](#multi-node-docker-compose)
- [Advanced guide](#advanced-guide)
  - [Expose netns ports to the host](#expose-netns-ports-to-the-host)
  - [Routing ping packets](#routing-ping-packets)
  - [IP addresses](#ip-addresses)
  - [Install Usernetes from source](#install-usernetes-from-source)
- [License](#license)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

## Included components

* Installer scripts
* Rootless Containers infrastructure
  * [RootlessKit](https://github.com/rootless-containers/rootlesskit)
  * [fuse-overlayfs](https://github.com/containers/fuse-overlayfs)
* Master components (`etcd`, `kube-apiserver`, ...)
* Node components (`kubelet` and `kube-proxy`)
* CRI runtime
  * CRI-O
* OCI runtime
  * crun
* Multi-node CNI
  * Flannel (lxc-user-nic and Wireguard)
* CoreDNS

Installer scripts are in POC status.

## How it works

Usernetes executes Kubernetes and CRI runtimes without the root privileges by using unprivileged [`user_namespaces(7)`](http://man7.org/linux/man-pages/man7/user_namespaces.7.html), [`mount_namespaces(7)`](http://man7.org/linux/man-pages/man7/mount_namespaces.7.html), and [`network_namespaces(7)`](http://man7.org/linux/man-pages/man7/network_namespaces.7.html).

To set up NAT across the host and the network namespace without the root privilege, Usernetes uses a separated in-kernel network stack as regular user ([`lxc-user-nic(1)`](https://www.man7.org/linux/man-pages/man1/lxc-user-nic.1.html) mode in rootlesskit).

No SETUID/SETCAP binary is needed, except [`newuidmap(1)`](http://man7.org/linux/man-pages/man1/newuidmap.1.html) and [`newgidmap(1)`](http://man7.org/linux/man-pages/man1/newgidmap.1.html), which are used for setting up [`user_namespaces(7)`](http://man7.org/linux/man-pages/man7/user_namespaces.7.html) with multiple sub-UIDs and sub-GIDs, and [`lxc-user-nic(1)`](https://www.man7.org/linux/man-pages/man1/lxc-user-nic.1.html) for setting up the network stack.

## Restrictions

* [fuse-overlayfs](https://github.com/containers/fuse-overlayfs) is used instead of kernel-mode overlayfs.
* Node ports are network-namespaced
* Apparmor is unsupported

## Requirements

Recommended host distribution is Ubuntu 26.04.

The following requirements have to be satisfied:

* Kernel >= 4.18.

* cgroup v2.

* Recent version of systemd. Known to work with systemd >= 242.

* `mount.fuse3` binary. Provided by `fuse3` package on most distros.

* `iptables` binary. Provided by `iptables` package on most distros.

* `conntrack` binary. Provided by `conntrack` package on most distros.

* `lxc-user-nic` binary. Provided by `lxc` package.

* `newuidmap` and `newgidmap` binaries. Provided by `uidmap` package on most distros.

* `/etc/subuid` and `/etc/subgid` should contain more than 65536 sub-IDs. e.g. `exampleuser:231072:65536`. These files are automatically configured on most distros.

```console
$ id -u
1001
$ whoami
exampleuser
$ grep "^$(whoami):" /etc/subuid
exampleuser:231072:65536
$ grep "^$(whoami):" /etc/subgid
exampleuser:231072:65536
```

* The following kernel modules to be loaded:
```
fuse
tun
tap
bridge
br_netfilter
veth
ip_tables
ip6_tables
iptable_nat
ip6table_nat
iptable_filter
ip6table_filter
nf_tables
x_tables
xt_MASQUERADE
xt_addrtype
xt_comment
xt_conntrack
xt_mark
xt_multiport
xt_nat
xt_tcpudp
vxlan
```

### cgroup v2

The host needs to be running with cgroup v2.

If `/sys/fs/cgroup/cgroup.controllers` is present on your system, you are using v2, otherwise you are using v1.

To enable cgroup v2, add `systemd.unified_cgroup_hierarchy=1` to the `GRUB_CMDLINE_LINUX` line in `/etc/default/grub` and run `sudo update-grub`.

If `grubby` command is available on your system, this step can be also accomplished with `sudo grubby --update-kernel=ALL --args="systemd.unified_cgroup_hierarchy=1"`.


#### Enable cpu controller
Typically, only `memory` and `pids` controllers are delegated to non-root users by default.
```console
$ cat /sys/fs/cgroup/user.slice/user-$(id -u).slice/user@$(id -u).service/cgroup.subtree_control
memory pids
```


To  allow delegation of all controllers, you need to change the systemd configuration as follows:

```console
# mkdir -p /etc/systemd/system/user@.service.d
# cat > /etc/systemd/system/user@.service.d/delegate.conf << EOF
[Service]
Delegate=yes
EOF
# systemctl daemon-reload
```

You have to re-login or reboot the host after changing the systemd configuration. Rebooting is recommended.

## Quick start

### Download

Download the latest `usernetes-x86_64.tbz` from [Releases](https://github.com/rootless-containers/usernetes/releases).

```console
$ tar xjvf usernetes-x86_64.tbz
$ cd usernetes
```

### Install

`install.sh` installs Usernetes systemd units to `$HOME/.config/systemd/user`.

To use etcd as the underlying database (default):
```console
$ ./install.sh --db=etcd
[INFO] Base dir: /home/exampleuser/gopath/src/github.com/rootless-containers/usernetes
[INFO] Installing /home/exampleuser/.config/systemd/user/u7s.target
[INFO] Installing /home/exampleuser/.config/systemd/user/u7s-rootlesskit.service
[INFO] Installing /home/exampleuser/.config/systemd/user/u7s-netsy.service
[INFO] Installing /home/exampleuser/.config/systemd/user/u7s-master.target
[INFO] Installing /home/exampleuser/.config/systemd/user/u7s-kube-apiserver.service
[INFO] Installing /home/exampleuser/.config/systemd/user/u7s-kube-controller-manager.service
[INFO] Installing /home/exampleuser/.config/systemd/user/u7s-kube-scheduler.service
[INFO] Installing /home/exampleuser/.config/systemd/user/u7s-node.target
[INFO] Installing /home/exampleuser/.config/systemd/user/u7s-kubelet-crio.service
[INFO] Installing /home/exampleuser/.config/systemd/user/u7s-kube-proxy.service
[INFO] Installing /home/exampleuser/.config/systemd/user/u7s-flanneld.service
[INFO] Enabling u7s.target
+ systemctl --user -T enable u7s.target
Created symlink /home/exampleuser/.config/systemd/user/default.target.wants/u7s.target → /home/exampleuser/.config/systemd/user/u7s.target.
+ set +x
[INFO] Starting u7s-master.target
+ systemctl --user start -T u7s-master.target
Enqueued anchor job 25324 u7s-master.target/start.
Enqueued auxiliary job 25346 u7s-kube-scheduler.service/start.
Enqueued auxiliary job 25326 u7s-rootlesskit.service/start.
Enqueued auxiliary job 25325 u7s-kube-controller-manager.service/start.
Enqueued auxiliary job 25345 u7s-netsy.service/start.
Enqueued auxiliary job 25344 u7s-kube-apiserver.service/start.

real	0m13.481s
user	0m0.000s
sys	0m0.004s
+ set +x
[INFO] Setting up ClusterRole and ClusterRoleBinding for 'system:kube-subnet-mgr' (flannel)
+ kubectl apply -f /home/exampleuser/gopath/src/github.com/rootless-containers/usernetes/manifests/kube-subnet-mgr.yaml
clusterrole.rbac.authorization.k8s.io/kube-subnet-mgr unchanged
clusterrolebinding.rbac.authorization.k8s.io/kube-subnet-mgr unchanged
+ set +x
[INFO] Setting up ClusterRoleBinding between user 'kubernetes' and cluster role 'system:kubelet-api-admin'
+ kubectl apply -f /home/exampleuser/gopath/src/github.com/rootless-containers/usernetes/manifests/apiserver-kubelet-admin.yaml
Warning: resource clusterrolebindings/apiserver-kubelet-admin is missing the kubectl.kubernetes.io/last-applied-configuration annotation which is required by kubectl apply. kubectl apply should only be used on resources created declaratively by either kubectl create --save-config or kubectl apply. The missing annotation will be patched automatically.
clusterrolebinding.rbac.authorization.k8s.io/apiserver-kubelet-admin configured
+ set +x
[INFO] Installing CoreDNS
+ kubectl apply -f /home/exampleuser/gopath/src/github.com/rootless-containers/usernetes/manifests/coredns.yaml
serviceaccount/coredns unchanged
clusterrole.rbac.authorization.k8s.io/u7s-coredns unchanged
clusterrolebinding.rbac.authorization.k8s.io/u7s-coredns unchanged
configmap/coredns unchanged
deployment.apps/coredns unchanged
service/kube-dns unchanged
+ set +x
[INFO] Starting u7s.target
+ systemctl --user start -T u7s.target
Enqueued anchor job 25347 u7s.target/start.
Enqueued auxiliary job 25372 u7s-flanneld.service/start.
Enqueued auxiliary job 25371 u7s-node.target/start.
Enqueued auxiliary job 25374 u7s-kube-proxy.service/start.
Enqueued auxiliary job 25373 u7s-kubelet-crio.service/start.

real	0m1.095s
user	0m0.002s
sys	0m0.002s
+ set +x
[INFO] Installation complete.
[INFO] Hint: `sudo loginctl enable-linger` to start user services automatically on the system start up.
[INFO] Hint: export KUBECONFIG=/home/exampleuser/.config/usernetes/master/admin.kubeconfig
```

To use netsy as the underlying database:
```console
$ ./install.sh --db=netsy
```

### Use `kubectl`

```console
$ export KUBECONFIG="$HOME/.config/usernetes/master/admin.kubeconfig"
$ kubectl get nodes -o wide
```

### Uninstall

```console
$ ./uninstall.sh
```

To remove data files:
```console
$ ./show-cleanup-command.sh
$ eval $(./show-cleanup-command.sh)
```

## Run Usernetes in Docker

All-in-one Docker image is available as [`ghcr.io/rootless-containers/usernetes`](https://ghcr.io/rootless-containers/usernetes) on GHCR.

To build the image manually:

```console
$ docker build -t ghcr.io/rootless-containers/usernetes .
```

The image is based on Ubuntu.

### Single node

```console
$ docker run -td --name usernetes-node -p 127.0.0.1:6443:6443 --privileged ghcr.io/rootless-containers/usernetes --db=etcd
```

Wait until `docker ps` shows "healty" as the status of `usernetes-node` container.

```console
$ docker cp usernetes-node:/home/user/.config/usernetes/master/admin.kubeconfig docker.kubeconfig
$ export KUBECONFIG=./docker.kubeconfig
$ kubectl run -it --rm --image busybox foo
/ #
```

### Multi node (Docker Compose)

```console
$ make up
$ export KUBECONFIG=$HOME/.config/usernetes/docker-compose.kubeconfig
```

Flannel virtual network (Wireguard) `10.5.0.0/16` is configured by default.

```console
$ kubectl get nodes -o wide
NAME           STATUS   ROLES    AGE     VERSION           INTERNAL-IP    EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION      CONTAINER-RUNTIME
967e81e90e1f   Ready    <none>   3m42s   v1.14-usernetes   10.0.101.100   <none>        Ubuntu 18.04.1 LTS   4.15.0-43-generic   docker://Unknown
b2204f192e5c   Ready    <none>   3m42s   v1.14-usernetes   10.0.102.100   <none>        Ubuntu 18.04.1 LTS   4.15.0-43-generic   cri-o://1.14.0-dev
ba0133c68378   Ready    <none>   3m42s   v1.14-usernetes   10.0.103.100   <none>        Ubuntu 18.04.1 LTS   4.15.0-43-generic   cri-o://1.14.0-dev
$ kubectl run --replicas=3 --image=nginx:alpine nginx
$ kubectl get pods -o wide
NAME                     READY   STATUS    RESTARTS   AGE   IP          NODE           NOMINATED NODE   READINESS GATES
nginx-6b4b85b77b-7hqrk   1/1     Running   0          3s    10.5.13.3   b2204f192e5c   <none>           <none>
nginx-6b4b85b77b-8rknj   1/1     Running   0          3s    10.5.79.3   967e81e90e1f   <none>           <none>
nginx-6b4b85b77b-r466s   1/1     Running   0          3s    10.5.7.3    ba0133c68378   <none>           <none>
$ kubectl exec -it nginx-6b4b85b77b-7hqrk -- wget -O - http://10.5.79.3
Connecting to 10.5.79.3 (10.5.79.3:80)
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
...
$ kubectl exec -it nginx-6b4b85b77b-7hqrk -- wget -O - http://10.5.7.3
Connecting to 10.5.7.3 (10.5.7.3:80)
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
...
```

## Advanced guide

### Expose netns ports to the host

As Usernetes runs in a network namespace, you can't expose container ports to the host
by just running `kubectl expose --type=NodePort`.

In addition, you need to expose Usernetes netns ports to the host:

```console
$ ./rootlessctl.sh add-ports 0.0.0.0:30080:30080/tcp
```

You can also manually expose Usernetes netns ports manually with `socat`:

```console
$ pid=$(cat $XDG_RUNTIME_DIR/usernetes/rootlesskit/child_pid)
$ socat -t -- TCP-LISTEN:30080,reuseaddr,fork EXEC:"nsenter -U -n -t $pid socat -t -- STDIN TCP4\:127.0.0.1\:30080"
```

Alternatively, you can manually create relevant NAT in NFTables.

### Routing ping packets

To route ping packets, you may need to set up `net.ipv4.ping_group_range` properly as the root.

```console
$ sudo sh -c "echo 0   2147483647  > /proc/sys/net/ipv4/ping_group_range"
```

### IP addresses

* 10.0.0.0/24: The CIDR for the Kubernetes ClusterIP services
  * 10.0.0.1: The kube-apiserver ClusterIP
  * 10.0.0.53: The CoreDNS ClusterIP

* 10.0.100.0/24: The CIDR used instead of 10.0.42.0/24 in Docker Compose master
* 10.0.102.0/24: The CIDR used instead of 10.0.42.0/24 in Docker Compose CRI-O node

* 10.5.0.0/16: The CIDR for Flannel

### Install Usernetes from source

Docker 17.05+ is required for building Usernetes from the source.
Docker 18.09+ with `DOCKER_BUILDKIT=1` is recommended.
Build is also proven as working with Podman 5.8+.

```console
$ make
```

Binaries are generated under `./bin` directory.

## License

Usernetes is licensed under the terms of  [Apache License Version 2.0](LICENSE).

The binary releases of Usernetes contain files that are licensed under the terms of different licenses:

* `bin/crun`:  [GNU GENERAL PUBLIC LICENSE Version 2](docs/binary-release-license/LICENSE-crun), see https://github.com/containers/crun
* `bin/fuse-overlayfs`:  [GNU GENERAL PUBLIC LICENSE Version 2](docs/binary-release-license/LICENSE-fuse-overlayfs), see https://github.com/containers/fuse-overlayfs
* `bin/{cfssl,cfssljson}`: [2-Clause BSD License](docs/binary-release-license/LICENSE-cfssl), see https://github.com/cloudflare/cfssl
