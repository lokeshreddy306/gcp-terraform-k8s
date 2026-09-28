#!/bin/bash

set -e
#If a command fails, stop the script.
echo "====================================="
echo " Kubernetes Node Bootstrap Starting"
echo "====================================="
#installing the packages
apt-get update
apt-get install -y containerd ca-certificates curl gpg apt-transport-https

#disabling the swap memory for effective resource management by kubernetes
swapoff -a
sed -i '/ swap/ s/^/#/' /etc/fstab

#Configure containerd
mkdir -p /etc/containerd

containerd config default > /etc/containerd/config.toml

sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

#systemctl restart containerd
systemctl enable --now containerd

#Kubernetes kernel modules
cat <<EOF > /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter

#Kubernetes networking settings
cat <<EOF > /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOF

sysctl --system
#Reload/apply the system's sysctl configuration.

#Kubernetes repository
mkdir -p -m 755 /etc/apt/keyrings

curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.35/deb/Release.key \
| gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.35/deb/ /' \
> /etc/apt/sources.list.d/kubernetes.list

#Install Kubernetes components
apt-get update
apt-get install -y kubelet kubeadm kubectl

apt-mark hold kubelet kubeadm kubectl

systemctl enable kubelet

echo "====================================="
echo " Kubernetes Node Bootstrap Completed"
echo "====================================="