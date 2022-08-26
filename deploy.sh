#!/bin/bash -eux

function ensure_kind_cluster() {

  if ! kind get clusters | grep -q kind; then
    cat <<EOF | kind create cluster --name kind --wait 5m --image=kindest/node:v1.23.4 --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
containerdConfigPatches:
- |-
  [plugins."io.containerd.grpc.v1.cri".registry]
    [plugins."io.containerd.grpc.v1.cri".registry.mirrors]
      [plugins."io.containerd.grpc.v1.cri".registry.mirrors."localregistry-docker-registry.default.svc.cluster.local:30050"]
        endpoint = ["http://127.0.0.1:30050"]
    [plugins."io.containerd.grpc.v1.cri".registry.configs]
      [plugins."io.containerd.grpc.v1.cri".registry.configs."127.0.0.1:30050".tls]
        insecure_skip_verify = true
featureGates:
  EphemeralContainers: true
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
  - containerPort: 30050
    hostPort: 30050
    protocol: TCP
  - containerPort: 30051
    hostPort: 30051
    protocol: TCP
  - containerPort: 30052
    hostPort: 30052
    protocol: TCP
EOF
  fi

  kind export kubeconfig --name kind
}

function ensure_local_registry() {
  helm repo add twuni https://helm.twun.io
  # the htpasswd value below is username: user, password: password encoded using `htpasswd` binary
  # e.g. `docker run --entrypoint htpasswd httpd:2 -Bbn user password`
  helm upgrade --install localregistry twuni/docker-registry \
    --set service.type=NodePort,service.nodePort=30050,service.port=30050 \
    --set persistence.enabled=true \
    --set secrets.htpasswd='user:$2y$05$Ue5dboOfmqk6Say31Sin9uVbHWTl8J1Sgq9QyAEmFQRnq1TPfP1n2'
}

function install_cert_manager() {
  kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.9.1/cert-manager.yaml
}

function install_cartographer() {
  kubectl create namespace cartographer-system || true
  kapp deploy --yes -a cartographer -f https://github.com/vmware-tanzu/cartographer/releases/latest/download/cartographer.yaml
}

function install_kpack() {
  kubectl apply -f https://github.com/pivotal/kpack/releases/download/v0.6.1/release-0.6.1.yaml
}

function install_source_controller() {
  if ! flux -v; then
    curl -s https://fluxcd.io/install.sh | sudo bash
  fi
  flux check --pre
  flux install \
  --namespace=flux-system \
  --network-policy=false \
  --components=source-controller
}

function install_carto_example() {
  pushd carto-example/basic-sc
    kapp deploy --yes -a example -f <(ytt --ignore-unknown-comments -f .) -f <(ytt --ignore-unknown-comments -f ../shared/ -f ./values.yaml)
  popd
}

ensure_kind_cluster
ensure_local_registry
install_cert_manager
install_cartographer
install_kpack
install_source_controller
install_carto_example
