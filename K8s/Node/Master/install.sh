#!/bin/bash

# Cập nhật danh sách package
sudo apt-get update

# Cài đặt các package cần thiết
sudo apt-get install -y ca-certificates curl gnupg

# Thêm kho lưu trữ Docker và khóa GPG
sudo mkdir -m 0755 -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Cài đặt Docker
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Thêm người dùng vào nhóm docker
sudo usermod -aG docker $(whoami)

# Tạo cấu hình cho Docker
sudo mkdir -p /etc/docker
cat | sudo tee /etc/docker/daemon.json <<EOF
{
    "exec-opts": ["native.cgroupdriver=systemd"],
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "100m"
    },
    "storage-driver": "overlay2",
    "storage-opts": [
        "overlay2.override_kernel_check=true"
    ]
}
EOF

# Tạo thư mục cho cấu hình dịch vụ Docker
sudo mkdir -p /etc/systemd/system/docker.service.d

# Khởi động lại dịch vụ Docker
sudo systemctl enable docker.service
sudo systemctl daemon-reload
sudo systemctl restart docker

# Tắt SELinux
sudo setenforce 0
sudo sed -i --follow-symlinks 's/^SELINUX=enforcing/SELINUX=disabled/' /etc/sysconfig/selinux

# Tắt Firewall
sudo systemctl disable firewalld >/dev/null 2>&1
sudo systemctl stop firewalld

# Cấu hình sysctl
cat | sudo tee /etc/sysctl.d/kubernetes.conf <<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sudo sysctl --system >/dev/null 2>&1

# Tắt swap
sudo sed -i '/swap/d' /etc/fstab
sudo swapoff -a

sudo apt-get update
# apt-transport-https may be a dummy package; if so, you can skip that package
sudo apt-get install -y apt-transport-https ca-certificates curl gpg
# If the directory `/etc/apt/keyrings` does not exist, it should be created before the curl command, read the note below.
# sudo mkdir -p -m 755 /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.31/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
# This overwrites any existing configuration in /etc/apt/sources.list.d/kubernetes.list
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
