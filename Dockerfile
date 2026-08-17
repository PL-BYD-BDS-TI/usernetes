# this dockerfile can be translated to `docker/dockerfile:1-experimental` syntax for enabling cache mounts:
# $ ./hack/translate-dockerfile-runopt-directive.sh < Dockerfile  | DOCKER_BUILDKIT=1 docker build  -f -  .

### Version definitions
# use ./hack/show-latest-commits.sh to get the latest commits

ARG ROOTLESSKIT_COMMIT=v3.1.0
ARG CONTAINERD_COMMIT=v2.3.4
ARG CRIO_COMMIT=v1.36.3

ARG KUBE_NODE_COMMIT=v1.36.3

# Version definitions (cont.)
ARG SLIRP4NETNS_RELEASE=v1.3.4
ARG CONMON_RELEASE=v2.2.1
ARG CRUN_RELEASE=1.29.1
ARG FUSE_OVERLAYFS_RELEASE=v1.17
ARG CONTAINERD_FUSE_OVERLAYFS_RELEASE=2.1.7
ARG KUBE_MASTER_RELEASE=v1.36.3
# Kube's build script requires KUBE_GIT_VERSION to be set to a semver string
ARG KUBE_GIT_VERSION=v1.36.3
ARG CNI_PLUGINS_RELEASE=v1.9.1
# ARG CILIUM_RELEASE=v1.20.0
# ARG CALICO_RELEASE=v3.32.0
ARG FLANNEL_CNI_PLUGIN_RELEASE=v1.9.1-flannel3
ARG FLANNEL_RELEASE=v0.28.9
ARG ETCD_RELEASE=v3.7.1
ARG CFSSL_RELEASE=1.6.5

ARG ALPINE_RELEASE=3.24
ARG GO_RELEASE=1.26.6
ARG UBUNTU_RELEASE=resolute

### Common base images (common-*)
FROM docker.io/alpine:${ALPINE_RELEASE} AS common-alpine
RUN apk add -q --no-cache git build-base autoconf automake libtool wget

FROM docker.io/golang:${GO_RELEASE}-alpine${ALPINE_RELEASE} AS common-golang-alpine
RUN apk add -q --no-cache git

FROM common-golang-alpine AS common-golang-alpine-heavy
RUN apk -q --no-cache add bash build-base linux-headers libseccomp-dev libseccomp-static gcc

### RootlessKit (rootlesskit-build)
FROM common-golang-alpine AS rootlesskit-build
RUN git clone -q https://github.com/rootless-containers/rootlesskit.git /go/src/github.com/rootless-containers/rootlesskit
WORKDIR /go/src/github.com/rootless-containers/rootlesskit
ARG ROOTLESSKIT_COMMIT
RUN git pull && git checkout ${ROOTLESSKIT_COMMIT}
ENV CGO_ENABLED=0
RUN mkdir /out && \
  go build -o /out/rootlesskit /go/src/github.com/rootless-containers/rootlesskit/cmd/rootlesskit && \
  go build -o /out/rootlessctl /go/src/github.com/rootless-containers/rootlesskit/cmd/rootlessctl

#### slirp4netns (slirp4netns-build)
FROM common-alpine AS slirp4netns-build
ARG SLIRP4NETNS_RELEASE
ADD https://github.com/rootless-containers/slirp4netns/releases/download/${SLIRP4NETNS_RELEASE}/slirp4netns-x86_64 /out/slirp4netns
RUN chmod +x /out/slirp4netns

### fuse-overlayfs (fuse-overlayfs-build)
FROM common-alpine AS fuse-overlayfs-build
ARG FUSE_OVERLAYFS_RELEASE
ADD https://github.com/containers/fuse-overlayfs/releases/download/${FUSE_OVERLAYFS_RELEASE}/fuse-overlayfs-x86_64 /out/fuse-overlayfs
RUN chmod +x /out/fuse-overlayfs

### containerd-fuse-overlayfs (containerd-fuse-overlayfs-build)
FROM common-alpine AS containerd-fuse-overlayfs-build
ARG CONTAINERD_FUSE_OVERLAYFS_RELEASE
RUN mkdir -p /out && \
 wget -q -O - https://github.com/containerd/fuse-overlayfs-snapshotter/releases/download/v${CONTAINERD_FUSE_OVERLAYFS_RELEASE}/containerd-fuse-overlayfs-${CONTAINERD_FUSE_OVERLAYFS_RELEASE}-linux-amd64.tar.gz | tar xz -C /out

### crun (crun-build)
FROM common-alpine AS crun-build
ARG CRUN_RELEASE
ADD https://github.com/containers/crun/releases/download/${CRUN_RELEASE}/crun-${CRUN_RELEASE}-linux-amd64 /out/crun
RUN chmod +x /out/crun

### containerd (containerd-build)
FROM common-golang-alpine-heavy AS containerd-build
RUN git clone https://github.com/containerd/containerd.git /go/src/github.com/containerd/containerd
WORKDIR /go/src/github.com/containerd/containerd
ARG CONTAINERD_COMMIT
RUN git pull && git checkout ${CONTAINERD_COMMIT}
RUN SHIM_CGO_ENABLED=1 make --quiet EXTRA_FLAGS="-buildmode pie" EXTRA_LDFLAGS='-linkmode external -extldflags "-fno-PIC -static"' BUILDTAGS="netgo osusergo static_build no_devmapper no_btrfs no_aufs no_zfs" \
  bin/containerd bin/containerd-shim-runc-v2 bin/ctr && \
  mkdir /out && cp bin/containerd bin/containerd-shim-runc-v2 bin/ctr /out

### CRI-O (crio-build)
FROM common-golang-alpine-heavy AS crio-build
RUN apk add -q --no-cache gpgme gpgme-dev
RUN git clone -q https://github.com/cri-o/cri-o.git /go/src/github.com/cri-o/cri-o
WORKDIR /go/src/github.com/cri-o/cri-o
ARG CRIO_COMMIT
RUN git pull && git checkout ${CRIO_COMMIT} && sed -i 's/g\.SetLinuxCgroupsPath("")//' server/rootless_linux.go
RUN EXTRA_LDFLAGS='-linkmode external -extldflags "-static"' make binaries && \
  mkdir /out && cp bin/crio bin/pinns /out

### conmon (conmon-build)
FROM common-golang-alpine-heavy AS conmon-build
RUN apk add -q --no-cache glib-dev glib-static libseccomp-dev libseccomp-static pcre2-static
RUN git clone -q https://github.com/containers/conmon.git /go/src/github.com/containers/conmon
WORKDIR /go/src/github.com/containers/conmon
ARG CONMON_RELEASE
RUN git pull && git checkout ${CONMON_RELEASE}
RUN make PKG_CONFIG='pkg-config --static' CFLAGS='-static' LDFLAGS='-s -w -static' && \
  mkdir /out && cp bin/conmon /out

### CNI Plugins (cniplugins-build)
FROM common-alpine AS cniplugins-build
ARG CNI_PLUGINS_RELEASE
RUN mkdir -p /out/cni && \
 wget -q -O - https://github.com/containernetworking/plugins/releases/download/${CNI_PLUGINS_RELEASE}/cni-plugins-linux-amd64-${CNI_PLUGINS_RELEASE}.tgz | tar xz -C /out/cni && \
 cd /out/cni && ls | egrep -vx "(host-local|loopback|bridge|portmap)" | xargs rm -f
ARG FLANNEL_CNI_PLUGIN_RELEASE
RUN wget -q -O /out/cni/flannel https://github.com/flannel-io/cni-plugin/releases/download/${FLANNEL_CNI_PLUGIN_RELEASE}/flannel-amd64 && \
  chmod +x /out/cni/flannel

# ### cilium (cilium-build)
# FROM common-golang-alpine-heavy AS cilium-build
# RUN git clone -q https://github.com/cilium/cilium.git /go/src/github.com/cilium/cilium
# WORKDIR /go/src/github.com/cilium/cilium
# RUN git pull && git checkout ${CILIUM_RELEASE} && mkdir /out
# ARG CILIUM_RELEASE
# WORKDIR /go/src/github.com/cilium/cilium/plugins/cilium-cni
# RUN CGO_ENABLED=1 GOARCH=amd64 go build -mod=vendor -ldflags '-s -w -linkmode external -extldflags "-static"' -tags=osusergo -o /out/cilium-cni
# WORKDIR /go/src/github.com/cilium/cilium/daemon
# RUN CGO_ENABLED=1 GOARCH=amd64 go build -mod=vendor -ldflags '-s -w -linkmode external -extldflags "-static"' -tags=osusergo -o /out/cilium-agent

### Kubernetes master (kube-master-build)
FROM common-alpine AS kube-master-build
ARG KUBE_MASTER_RELEASE
RUN mkdir /out && \
  wget -q -O - https://dl.k8s.io/${KUBE_MASTER_RELEASE}/kubernetes-server-linux-amd64.tar.gz | tar xz -C / && \
  cd /kubernetes/server/bin && \
  cp kube-apiserver kube-controller-manager kube-scheduler kubectl /out

### Kubernetes node (kube-node-build)
FROM common-golang-alpine-heavy AS kube-node-build
RUN apk add -q --no-cache rsync
RUN git clone -q https://github.com/kubernetes/kubernetes.git /kubernetes
WORKDIR /kubernetes
ARG KUBE_NODE_COMMIT
RUN git pull && git checkout ${KUBE_NODE_COMMIT}
ARG KUBE_GIT_VERSION
# runopt = --mount=type=cache,id=u7s-k8s-build-cache,target=/root
RUN KUBE_STATIC_OVERRIDES=kubelet \
  make --quiet kube-proxy kubelet && \
  mkdir /out && cp _output/bin/kube* /out

#### flannel (flannel-build)
# TODO: use upstream binary when https://github.com/coreos/flannel/issues/1365 gets resolved
FROM common-golang-alpine-heavy AS flannel-build
RUN git clone -q https://github.com/coreos/flannel.git /go/src/github.com/coreos/flannel
WORKDIR /go/src/github.com/coreos/flannel
ARG FLANNEL_RELEASE
RUN git pull && git checkout ${FLANNEL_RELEASE}
ENV CGO_ENABLED=0
RUN make dist/flanneld && \
  mkdir /out && cp dist/flanneld /out

#### etcd (etcd-build)
FROM common-alpine AS etcd-build
ARG ETCD_RELEASE
RUN mkdir /tmp-etcd /out && \
  wget -q -O - https://github.com/etcd-io/etcd/releases/download/${ETCD_RELEASE}/etcd-${ETCD_RELEASE}-linux-amd64.tar.gz | tar xz -C /tmp-etcd && \
  cp /tmp-etcd/etcd-${ETCD_RELEASE}-linux-amd64/etcd /tmp-etcd/etcd-${ETCD_RELEASE}-linux-amd64/etcdctl /tmp-etcd/etcd-${ETCD_RELEASE}-linux-amd64/etcdutl /out

#### cfssl (cfssl-build)
FROM common-alpine AS cfssl-build
ARG CFSSL_RELEASE
RUN mkdir -p /out && \
  wget -q -O /out/cfssl https://github.com/cloudflare/cfssl/releases/download/v${CFSSL_RELEASE}/cfssl_${CFSSL_RELEASE}_linux_amd64 && \
  chmod +x /out/cfssl && \
  wget -q -O /out/cfssljson https://github.com/cloudflare/cfssl/releases/download/v${CFSSL_RELEASE}/cfssljson_${CFSSL_RELEASE}_linux_amd64 && \
  chmod +x /out/cfssljson

# #### calico
# FROM docker.io/calico/node:${CALICO_RELEASE} AS calico

### Binaries (bin-main)
FROM scratch AS bin-main
COPY --from=rootlesskit-build /out/* /
COPY --from=slirp4netns-build /out/* /
COPY --from=fuse-overlayfs-build /out/* /
COPY --from=crun-build /out/* /
COPY --from=containerd-build /out/* /
COPY --from=containerd-fuse-overlayfs-build /out/* /
COPY --from=crio-build /out/* /
COPY --from=conmon-build /out/* /
# can't use wildcard here: https://github.com/rootless-containers/usernetes/issues/78
COPY --from=cniplugins-build /out/cni /cni
# COPY --from=cilium-build /out/cilium-agent /cilium-agent
# COPY --from=cilium-build /out/cilium-cni /cni/cilium-cni
COPY --from=kube-master-build /out/* /
COPY --from=kube-node-build /out/* /
COPY --from=flannel-build /out/* /
COPY --from=etcd-build /out/* /
COPY --from=cfssl-build /out/* /
# COPY --from=calico /bin/calico-node /calico-node

#### Test (test-main)
FROM docker.io/ubuntu:${UBUNTU_RELEASE} AS test-main
ADD https://raw.githubusercontent.com/AkihiroSuda/containerized-systemd/6ced78a9df65c13399ef1ce41c0bedc194d7cff6/docker-entrypoint.sh /docker-entrypoint.sh
COPY hack/etc_systemd_system_user@.service.d_delegate.conf /etc/systemd/system/user@.service.d/delegate.conf
RUN chmod +x /docker-entrypoint.sh && \
  apt-get update -y && \
  apt-get install -q -y conntrack fuse3 git iptables nftables time which \
  systemd-container && \
  userdel ubuntu && \
  useradd --create-home --home-dir /home/user --uid 1000 -G systemd-journal user && \
  mkdir -p /home/user/.local /home/user/.config/usernetes && \
  chown -R user:user /home/user && \
  rm -rf /tmp/*
COPY --chown=user:user . /home/user/usernetes
COPY --from=bin-main --chown=user:user / /home/user/usernetes/bin
RUN ln -sf /home/user/usernetes/boot/docker-unsudo.sh /usr/local/bin/unsudo
VOLUME /home/user/.local
VOLUME /home/user/.config
HEALTHCHECK --interval=30s --timeout=10s --start-period=90s --retries=5 \
  CMD ["unsudo", "systemctl", "--user", "is-system-running"]
ENTRYPOINT ["/docker-entrypoint.sh", "unsudo", "/home/user/usernetes/boot/docker-2ndboot.sh"]
