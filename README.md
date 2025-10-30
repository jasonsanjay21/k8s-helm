# Kubernetes Helm-Driven Config Change with Rolling Updates

This project demonstrates a Kubernetes deployment using **Helm** with automatic rolling updates triggered by **ConfigMap changes**.

---

## Overview

- **Application**: Simple HTTP service that returns a JSON response with a configurable message  
- **Endpoint**: `/version` → `{"message": "<value>"}` (value comes from `APP_MESSAGE` environment variable)  
- **Infrastructure**: Kubernetes cluster provisioned via **kubeadm**  
- **Key Feature**: Rolling updates triggered automatically when ConfigMap changes (via checksum annotation)

---

## Prerequisites

- Kubernetes cluster (kubeadm setup)  
- Helm 3.x installed  
- `kubectl` configured  
- Docker image built and pushed to a registry  

> ⚠️ Before Terraform deployment, update your `main.tf` with your key (`OctKey`) for SSH access.  

---

## Terraform Setup (AWS)

1. Initialize Terraform:

```bash
terraform init
terraform apply

Master & Worker Node Preparation

Run the following on both master and worker nodes:


# Download kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl.sha256"
echo "$(cat kubectl.sha256) kubectl" | sha256sum --check
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
chmod +x kubectl
mkdir -p ~/.local/bin
mv ./kubectl ~/.local/bin/kubectl
# Ensure ~/.local/bin is in $PATH
kubectl version --client

# Disable swap
sudo swapoff -a

# Load kernel modules
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
sudo modprobe overlay
sudo modprobe br_netfilter

# Sysctl params required by Kubernetes
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sudo sysctl --system

# Install CRI-O runtime
sudo apt-get update -y
sudo apt-get install -y software-properties-common curl apt-transport-https ca-certificates gpg
sudo curl -fsSL https://pkgs.k8s.io/addons:/cri-o:/prerelease:/main/deb/Release.key \
  | sudo gpg --dearmor -o /etc/apt/keyrings/cri-o-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/cri-o-apt-keyring.gpg] \
  https://pkgs.k8s.io/addons:/cri-o:/prerelease:/main/deb/ /" \
  | sudo tee /etc/apt/sources.list.d/cri-o.list
sudo apt-get update -y
sudo apt-get install -y cri-o
sudo systemctl daemon-reload
sudo systemctl enable --now crio

# Install Kubernetes components
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key \
  | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /' \
  | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update -y
sudo apt-get install -y kubelet="1.29.0-*" kubeadm="1.29.0-*" kubectl="1.29.0-*"
sudo apt-get install -y jq
sudo systemctl enable --now kubelet
sudo systemctl start kubelet

Master Node Only:
# Initialize Kubernetes master
sudo kubeadm config images pull
sudo kubeadm init

# Configure kubectl for the current user
mkdir -p "$HOME"/.kube
sudo cp -i /etc/kubernetes/admin.conf "$HOME"/.kube/config
sudo chown "$(id -u)":"$(id -g)" "$HOME"/.kube/config

# Install Calico network plugin
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.0/manifests/calico.yaml

# Generate token for worker nodes
kubeadm token create --print-join-command
Make sure port 6443 is open in the master security group for workers to connect.

Worker Node Only
# Reset any previous cluster configuration
sudo kubeadm reset --preflight-checks

# Join the cluster using the command generated from master node
sudo kubeadm join <MASTER_IP>:6443 --token <TOKEN> --discovery-token-ca-cert-hash sha256:<HASH> --v=5

Project Structure
.
├── app.py                   # Flask application
├── Dockerfile               # Container image definition
├── chart/
│   ├── Chart.yaml           # Helm chart metadata
│   ├── values.yaml          # Default configuration values
│   └── templates/
│       ├── _helpers.tpl     # Template helpers
│       ├── configmap.yaml   # ConfigMap for APP_MESSAGE
│       ├── deployment.yaml  # Deployment with checksum annotation
│       └── service.yaml     # Service (NodePort)
└── README.md



Key Helm Chart Features

ConfigMap Management: Stores APP_MESSAGE

Checksum Annotation: Pod template checksum triggers rolling updates

Rolling Updates: Automatic recreation of pods when ConfigMap changes

Health Checks: Liveness and readiness probes on /version

Service Discovery: NodePort service for external access

Docker Image

Build and push your Docker image:

docker build -t jasonsanjay/tiny-http-app:latest .
docker push jasonsanjay/tiny-http-app:latest


Update chart/values.yaml:

image:
  repository: jasonsanjay/tiny-http-app
  tag: "latest"

Deployment & Rolling Updates
Initial Deployment
helm upgrade --install web ./chart -n demo --create-namespace --set appMessage="hello-world"
kubectl get pods -n demo


Test endpoint:

kubectl get svc -n demo
curl http://<NODE_IP>:30080/version
# Output: {"message":"hello-world"}

Trigger Rolling Update
helm upgrade web ./chart -n demo --set appMessage="hola"
kubectl rollout status deployment/web -n demo


Test updated endpoint:

curl http://<NODE_IP>:30080/version
# Output: {"message":"hola"}

Verification

Check pods:

kubectl get pods -n demo


Check deployment annotation (checksum):

kubectl get deployment web -n demo -o yaml | grep checksum


Rollout history:

kubectl rollout history deployment/web -n demo
kubectl rollout history deployment/web -n demo --revision=1
kubectl rollout history deployment/web -n demo --revision=2

Cleanup
helm uninstall web -n demo
kubectl delete namespace demo
terraform destroy

Technologies Used

Kubernetes

Helm

kubeadm

Flask

Docker

Author

Jason Sanjay
