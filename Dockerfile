ARG ARGOCD_VERSION=v1.7.6
ARG KUSTOMIZE_VERSION=2.1.0
ARG JQ_VERSION=1.6
ARG YQ_VERSION=3
ARG OC_VERSION="v3.11.0"
ARG OC_RELEASE="openshift-origin-client-tools-v3.11.0-0cbc58b-linux-64bit"
ARG HELM_VERSION=3.4.0
ARG GOLANG_VERSION=1.15.3-alpine3.12
FROM scratch

LABEL maintainer="devops@croz.net"

FROM alpine:3.12.1 as alpine

FROM mikefarah/yq:${YQ_VERSION} as yq

FROM alpine as jq
ARG JQ_VERSION
ADD https://github.com/stedolan/jq/releases/download/jq-${JQ_VERSION}/jq-linux64 /usr/local/bin/jq
RUN chmod 755 /usr/local/bin/jq

FROM alpine as oc
ARG OC_VERSION
ARG OC_RELEASE
RUN wget -O release.tar.gz https://github.com/openshift/origin/releases/download/$OC_VERSION/$OC_RELEASE.tar.gz && \
    mkdir /openshift && \
    tar --strip-components=1 -xzvf release.tar.gz -C /openshift/ && \
    chmod 755 /openshift/oc && \
    chmod 755 /openshift/kubectl && \
    rm -rf /opt/ocq

FROM alpine as kustomize
ARG KUSTOMIZE_VERSION
RUN wget -O /usr/local/bin/kustomize https://github.com/kubernetes-sigs/kustomize/releases/download/v${KUSTOMIZE_VERSION}/kustomize_${KUSTOMIZE_VERSION}_linux_amd64 && \
  chmod +x /usr/local/bin/kustomize

FROM alpine as argocd
ARG ARGOCD_VERSION
RUN wget -O /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/download/${ARGOCD_VERSION}/argocd-linux-amd64 && \
  chmod +x /usr/local/bin/argocd

FROM alpine as kubeval
RUN wget https://github.com/instrumenta/kubeval/releases/latest/download/kubeval-linux-amd64.tar.gz && \
    tar xf kubeval-linux-amd64.tar.gz && \
    cp kubeval /usr/local/bin

FROM alpine as helm
ARG HELM_VERSION
RUN wget https://get.helm.sh/helm-v${HELM_VERSION}-linux-amd64.tar.gz && \
  tar -zxvf helm-v${HELM_VERSION}-linux-amd64.tar.gz && \
  mv linux-amd64/helm /usr/local/bin/helm && \
  chmod 755 /usr/local/bin/helm

FROM golang:${GOLANG_VERSION} as golang

FROM buildah/buildah:959e6da7f52b27f8d7a6e39c884f700bce7ab5cb as buildah

FROM alpine as oc-clients
RUN apk add dpkg

ENV OC_VERSION "v3.11.0"
ENV OC_RELEASE "openshift-origin-client-tools-v3.11.0-0cbc58b-linux-64bit"

ADD https://github.com/openshift/origin/releases/download/$OC_VERSION/$OC_RELEASE.tar.gz /opt/oc/release.tar.gz
RUN apk add --no-cache ca-certificates openssl git bash gettext
RUN tar --strip-components=1 -xzvf  /opt/oc/release.tar.gz -C /opt/oc/ && \
    mv /opt/oc/oc /usr/local/bin/oc311 && \
    rm -rf /opt/oc
ADD https://mirror.openshift.com/pub/openshift-v4/clients/oc/latest/linux/oc.tar.gz /opt/oc/oc.tar.gz
RUN tar -xzvf /opt/oc/oc.tar.gz && rm /opt/oc/oc.tar.gz && mv oc /usr/local/bin/oc4

FROM frolvlad/alpine-glibc:latest
ARG GOSU_VERSION=1.11
RUN apk add --no-cache dpkg bash ca-certificates openssl git gettext
RUN mv /bin/sh /bin/_sh && ln -s /bin/bash /bin/sh

RUN set -eux; \
	wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-amd64"; \
	chmod +x /usr/local/bin/gosu; \
	gosu nobody true

ENV OC_VERSION "v3.11.0"
ENV OC_RELEASE "openshift-origin-client-tools-v3.11.0-0cbc58b-linux-64bit"

# install the oc client tools
COPY --from=oc-clients /usr/local/bin/oc311 /usr/local/bin/oc311
COPY --from=oc-clients /usr/local/bin/oc4 /usr/local/bin/oc4
RUN mkdir -p /.local/etc/alternatives /.local/var/lib/alternatives && \
    echo -e '#!/bin/bash\nupdate-alternatives --altdir /.local/etc/alternatives --admindir /.local/var/lib/alternatives "$@"' > /usr/bin/uma && chmod +x /usr/bin/uma && \
    echo -e '#!/bin/bash\necho 1 | uma --config oc' > /usr/bin/use_oc311 && chmod +x /usr/bin/use_oc311 && \
    echo -e '#!/bin/bash\necho 2 | uma --config oc' > /usr/bin/use_oc4 && chmod +x /usr/bin/use_oc4
RUN uma --install /usr/local/bin/oc oc /usr/local/bin/oc311 2 && \
    uma --install /usr/local/bin/oc oc /usr/local/bin/oc4 1

COPY --from=yq /usr/bin/yq /usr/local/bin/yq
COPY --from=jq /usr/local/bin/jq /usr/local/bin/jq
COPY --from=kustomize /usr/local/bin/kustomize /usr/local/bin/kustomize
COPY --from=argocd /usr/local/bin/argocd /usr/local/bin/argocd
COPY --from=kubeval /usr/local/bin/kubeval /usr/local/bin/kubeval
COPY --from=helm /usr/local/bin/helm /usr/local/bin/helm

COPY --from=golang /usr/local/go/bin/go /usr/local/go/bin/go
RUN ln -s /usr/local/go/bin/go /usr/local/bin/go

COPY --from=buildah /usr/local/bin/runc   /usr/local/bin/runc
COPY --from=buildah /usr/local/bin/podman /usr/local/bin/podman
COPY --from=buildah /usr/libexec/podman/conmon /usr/libexec/podman/conmon
COPY --from=buildah /usr/libexec/cni /usr/libexec/cni
COPY --from=buildah /usr/local/bin/skopeo /usr/local/bin/skopeo
COPY --from=buildah /usr/local/bin/fuse-overlayfs /usr/local/bin/fuse-overlayfs
COPY --from=buildah /usr/local/bin/slirp4netns /usr/local/bin/slirp4netns
COPY --from=buildah /usr/local/bin/buildah /usr/local/bin/buildah
RUN set -eux; \
	adduser -D podman -h /podman -u 9000; \
	echo 'podman:900000:65536' > /etc/subuid; \
	echo 'podman:900000:65536' > /etc/subgid; \
	ln -s /usr/local/bin/podman /usr/bin/docker; \
	mkdir -pm 775 /etc/containers /podman/.config/containers /etc/cni/net.d /podman/.local/share/containers/storage/libpod; \
	chown -R root:podman /podman; \
	wget -O /etc/containers/registries.conf https://raw.githubusercontent.com/projectatomic/registries/master/registries.fedora; \
	wget -O /etc/containers/policy.json     https://raw.githubusercontent.com/containers/skopeo/master/default-policy.json; \
	wget -O /etc/cni/net.d/99-bridge.conflist https://raw.githubusercontent.com/containers/libpod/master/cni/87-podman-bridge.conflist; \
	runc --help >/dev/null; \
	podman --help >/dev/null; \
	/usr/libexec/podman/conmon --help >/dev/null; \
	slirp4netns --help >/dev/null; \
	fuse-overlayfs --help >/dev/null;

VOLUME /podman/.local/share/containers/storage

ADD https://raw.githubusercontent.com/containers/podman/master/vendor/github.com/containers/storage/storage.conf /etc/containers/storage.conf
RUN sed -i 's/metacopy=on/metacopy=off/' /etc/containers/storage.conf
ADD https://raw.githubusercontent.com/containers/libpod/master/contrib/podmanimage/stable/containers.conf /usr/share/containers/
RUN sed -i 's/# events_logger = "journald"/events_logger = "none"/' /usr/share/containers/containers.conf

WORKDIR /work

# Setup certificate trust
COPY trust* ./
RUN chmod +x ./trustcerts.sh && ./trustcerts.sh

CMD yq --version && \
  jq --version && \
  buildah --version && \
  helm version && \
  skopeo --version && \
  argocd version --client && \
  kustomize version && \
  kubeval --version && \
  go version && \
  oc version
