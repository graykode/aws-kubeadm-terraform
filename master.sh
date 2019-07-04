#!/bin/bash -ve
tourch /home/ubuntu/master.log

curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
touch /etc/apt/sources.list.d/kubernetes.list

su -c "echo 'deb http://apt.kubernetes.io/ kubernetes-xenial main' >> \
    /etc/apt/sources.list.d/kubernetes.list"

# Install kubelet kubeadm kubectl kubernetes-cni docker
apt-get update
apt-get install -y kubelet kubeadm kubectl kubernetes-cni
curl -sSL https://get.docker.com/ | sh
systemctl start docker
echo '[Finished] Installing kubelet kubeadm kubectl kubernetes-cni docker' > /home/ubuntu/master.log

systemctl stop docker
mkdir /mnt/docker
chmod 711 /mnt/docker
cat <<EOF > /etc/docker/daemon.json
{
    "data-root": "/mnt/docker",
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "10m",
        "max-file": "5"
    }
}
EOF
systemctl start docker
systemctl enable docker
echo '[Finished] docker configure' > /home/ubuntu/master.log

# Point kubelet at big ephemeral drive
mkdir /mnt/kubelet
echo 'KUBELET_EXTRA_ARGS="--root-dir=/mnt/kubelet --cloud-provider=aws"' > /etc/default/kubelet
echo '[Finished] kubelet configure' > /home/ubuntu/master.log

# ----------------- from here same with worker.sh

cat >init-config.yaml <<EOF
apiVersion: kubeadm.k8s.io/v1beta1
kind: InitConfiguration
bootstrapTokens:
- groups:
  - system:bootstrappers:kubeadm:default-node-token
  token: "${k8stoken}"
  ttl: "0"
nodeRegistration:
  name: "$(hostname -f)"
  taints: []
---
apiVersion: kubeadm.k8s.io/v1beta1
kind: ClusterConfiguration
apiServerExtraArgs:
  cloud-provider: aws
controllerManagerExtraArgs:
  cloud-provider: aws
networking:
  podSubnet: 10.244.0.0/16
EOF

kubeadm init --config=/init-config.yaml --ignore-preflight-errors=NumCPU
touch /tmp/fresh-cluster
echo '[Finished] created kubeadm cluster' > /home/ubuntu/master.log

# Pass bridged IPv4 traffic to iptables chains (required by Flannel like the above cidr setting)
echo "net.bridge.bridge-nf-call-iptables = 1" > /etc/sysctl.d/60-flannel.conf
service procps start

# Set up kubectl for the ubuntu user
mkdir -p /home/ubuntu/.kube && cp -i /etc/kubernetes/admin.conf /home/ubuntu/.kube/config && chown -R ubuntu. /home/ubuntu/.kube
echo 'source <(kubectl completion bash)' >> /home/ubuntu/.bashrc
echo '[Finished] Now you can use kubectl, try : kubectl get nodes' > /home/ubuntu/master.log

if [ -f /tmp/fresh-cluster ]; then
  su -c 'kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/13a990bb716c82a118b8e825b78189dcfbfb2f1e/Documentation/kube-flannel.yml' ubuntu
  echo '[Finished] All nodes are ready' > /home/ubuntu/master.log
  su -c 'kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/static/mandatory.yaml' ubuntu
  su -c 'kubectl apply -f https://raw.githubusercontent.com/graykode/aws-kubeadm-terraform/master/service-l7.yaml' ubuntu
  su -c 'kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/static/provider/aws/patch-configmap-l4.yaml' ubuntu
fi
