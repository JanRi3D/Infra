# Infra


## Prerequisites

- A Brain

## Network Configuration

First, configure the hosts file to ensure all nodes can communicate with each other by hostname:

```bash
nano /etc/hosts
```

Add the following entries (replace with your actual node IPs and names):

```
37.27.15.24 k8s-01
37.27.35.203 k8s-02
65.108.90.40 k8s-03
```

## System Preparation

### Disable Swap

Kubernetes requires swap to be disabled:

```bash
swapoff -a
```

To make this permanent, edit `/etc/fstab` and comment out any swap lines.

### Configure Required Kernel Modules

Load necessary kernel modules:

```bash
modprobe overlay
modprobe br_netfilter
```

Make these modules load on boot:

```bash
tee /etc/modules-load.d/k8s.conf <<EOF
overlay
br_netfilter
EOF
```

### Configure Kernel Parameters

Set required kernel parameters:

```bash
nano /etc/sysctl.d/k8s.conf
```

Add the following parameters:

```
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward   = 1
```

Apply the changes:

```bash
sysctl --system
```

## Container Runtime Installation

### Install and Configure Containerd

```bash
apt install containerd -y
mkdir -p /etc/containerd
containerd config default | tee /etc/containerd/config.toml
```

Configure containerd to use systemd cgroup driver:

```bash
sed -i 's/ SystemdCgroup = false/ SystemdCgroup = true/' /etc/containerd/config.toml
```

Start and enable containerd:

```bash
systemctl restart containerd.service
systemctl enable containerd.service
```

## Kubernetes Components Installation

### Install Required Dependencies

```bash
apt-get install curl ca-certificates apt-transport-https -y
```

### Add Kubernetes Repository

```bash
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.31/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list
```

### Install Kubernetes Components

```bash
apt update -y
apt install kubelet kubeadm kubectl -y
```

## Initialize Kubernetes Master Node

Run the following command on the master node only:

```bash
kubeadm init --pod-network-cidr=10.0.0.0/16
```

### Set Up kubeconfig

Configure kubectl to work for your user:

```bash
mkdir -p $HOME/.kube
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config
```

## Network Plugin Installation (Calico)

Install the Calico operator:

```bash
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.29.3/manifests/tigera-operator.yaml
```

Download and modify the Calico custom resources:

```bash
curl -O https://raw.githubusercontent.com/projectcalico/calico/v3.29.3/manifests/custom-resources.yaml
sed -i 's/cidr: 192\.168\.0\.0\/16/cidr: 10.0.0.0\/16/g' custom-resources.yaml
kubectl create -f custom-resources.yaml
```

## Join Worker Nodes

After initializing the master node, you'll receive a command to join worker nodes to the cluster. It will look something like:

```bash
kubeadm join <master-ip>:6443 --token <token> --discovery-token-ca-cert-hash sha256:<hash>
```

Run this command on each worker node.

## Verify Cluster Status

Check node status:

```bash
kubectl get nodes
```

All nodes should eventually show `Ready` status.

## Troubleshooting

If you encounter issues with the cluster setup:

1. Check system logs: `journalctl -xeu kubelet`
2. Ensure all required ports are open between nodes
3. Verify that containerd is running properly: `systemctl status containerd`

## Next Steps

- Deploy applications to your cluster
- Set up persistent storage
- Configure network policies
- Implement monitoring and logging solutions