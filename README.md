# Kubernetes Helm-Driven Configuration Management with Rolling Updates


---

## Prerequisites

### Required Software

| Tool | Version | Purpose |
|------|---------|---------|
| Terraform | ≥ 1.0 | Infrastructure provisioning |
| kubectl | 1.29.0 | Kubernetes CLI |
| Helm | ≥ 3.0 | Package management |
| Docker | ≥ 20.10 | Container image building |

### Infrastructure Requirements

- AWS account with appropriate IAM permissions
- SSH key pair for EC2 instance access
- Security groups configured:
  - **Master Node**: Port 6443 (API Server)
  - **Worker Nodes**: Port 10250 (kubelet), 30000-32767 (NodePort)
  - **All Nodes**: Port 179 (Calico BGP)

---

## Infrastructure Provisioning

### Terraform Deployment

**Update `main.tf` with your SSH key name**:

```hcl
variable "key_name" {
  default = "OctKey"  # Replace with your key
}
```

**Deploy Infrastructure**:

```bash
terraform init
terraform plan
terraform apply -auto-approve
```

---

## Kubernetes Cluster Setup

### Common Node Configuration

Execute on **both master and worker nodes**:

```bash
# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Disable swap
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# Load kernel modules
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
sudo modprobe overlay
sudo modprobe br_netfilter

# Configure sysctl
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sudo sysctl --system

# Install CRI-O
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
sudo systemctl enable crio --now

# Install Kubernetes components
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key \
  | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] \
  https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /' \
  | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update -y
sudo apt-get install -y kubelet="1.29.0-*" kubeadm="1.29.0-*" kubectl="1.29.0-*" jq
sudo apt-mark hold kubelet kubeadm kubectl
sudo systemctl enable kubelet --now
```

### Master Node Initialization

Execute on **master node only**:

```bash
# Initialize control plane
sudo kubeadm config images pull
sudo kubeadm init --pod-network-cidr=192.168.0.0/16

# Configure kubectl
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Deploy Calico CNI
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.0/manifests/calico.yaml

# Generate join command
kubeadm token create --print-join-command
```

### Worker Node Join

Execute on **worker node only**:

```bash
# Join cluster (use command from master)
sudo kubeadm reset --force
sudo kubeadm join <MASTER-IP>:6443 --token <TOKEN> \
  --discovery-token-ca-cert-hash sha256:<HASH>
```

**Verify on Master**:
```bash
kubectl get nodes
```

---

### Project Structure

```
tiny-http-app/
├── app.py                      # Flask application
├── Dockerfile                  # Container image
├── Chart.yaml                  # Helm metadata
├── values.yaml                 # Configuration
└── templates/
    ├── _helpers.tpl           # Helper functions
    ├── configmap.yaml         # ConfigMap definition
    ├── deployment.yaml        # Deployment with checksum
    └── service.yaml           # NodePort service
```

### Application Code

**Flask Application** (`app.py`):

```python
from flask import Flask, jsonify
import os

app = Flask(__name__)

@app.route('/version')
def version():
    message = os.getenv('APP_MESSAGE', 'default-message')
    return jsonify({"message": message})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)
```

**Dockerfile**:

```dockerfile
FROM python:3.9-alpine
WORKDIR /app
RUN pip install flask
COPY app.py .
EXPOSE 8080
CMD ["python", "app.py"]
```

**Build and Push**:

```bash
docker build -t jasonsanjay/tiny-http-app:latest .
docker push jasonsanjay/tiny-http-app:latest
```

---

## Deployment Procedure

### Initial Deployment

```bash
# Validate chart
helm lint ./tiny-http-app

# Deploy with initial configuration
helm upgrade --install web ./tiny-http-app \
  -n demo \
  --create-namespace \
  --set appMessage="hello-world" \
  --wait
```

**Output**:
```
Release "web" does not exist. Installing it now.
NAME: web
LAST DEPLOYED: Thu Oct 30 18:48:18 2025
NAMESPACE: demo
STATUS: deployed
REVISION: 1
```

### Verification

**Check Pods**:
```bash
kubectl get pods -n demo
```

**Output**:
```
NAME                                 READY   STATUS    RESTARTS   AGE
web-tiny-http-app-7669ff59b4-74rlc   1/1     Running   0          45s
web-tiny-http-app-7669ff59b4-z79r2   1/1     Running   0          45s
```

**Check Service**:
```bash
kubectl get svc -n demo
```

**Output**:
```
NAME                TYPE       CLUSTER-IP       EXTERNAL-IP   PORT(S)          AGE
web-tiny-http-app   NodePort   10.101.239.103   <none>        8080:30080/TCP   50s
```

**Test Endpoint**:
```bash
curl http://<WORKER-NODE-IP>:30080/version
```

**Response**:
```json
{"message":"hello-world"}
```

---

## Rolling Update Demonstration

### Trigger Configuration Update

```bash
helm upgrade web ./tiny-http-app \
  -n demo \
  --set appMessage="hola" \
  --wait
```

**Output**:
```
Release "web" has been upgraded. Happy Helming!
NAME: web
LAST DEPLOYED: Thu Oct 30 18:52:15 2025
NAMESPACE: demo
STATUS: deployed
REVISION: 2
```

### Monitor Rollout

```bash
kubectl rollout status deployment/web-tiny-http-app -n demo
```

**Output**:
```
Waiting for deployment "web-tiny-http-app" rollout to finish: 1 out of 2 new replicas have been updated...
Waiting for deployment "web-tiny-http-app" rollout to finish: 1 old replicas are pending termination...
deployment "web-tiny-http-app" successfully rolled out
```

### Verify Update

**Check New Pods**:
```bash
kubectl get pods -n demo
```

**Output** (note changed pod hash):
```
NAME                                 READY   STATUS    RESTARTS   AGE
web-tiny-http-app-8a7b9c6d5f-abc12   1/1     Running   0          90s
web-tiny-http-app-8a7b9c6d5f-xyz89   1/1     Running   0          87s
```

**Key Observation**: Pod hash changed from `7669ff59b4` → `8a7b9c6d5f` ✓

**Test Updated Endpoint**:
```bash
curl http://<WORKER-NODE-IP>:30080/version
```

**Response**:
```json
{"message":"hola"}
```

**Check ReplicaSets**:
```bash
kubectl get rs -n demo
```

**Output**:
```
NAME                           DESIRED   CURRENT   READY   AGE
web-tiny-http-app-7669ff59b4   0         0         0       5m
web-tiny-http-app-8a7b9c6d5f   2         2         2       2m
```

---

## Verification and Validation

### Checksum Validation

```bash
# View deployment checksum annotation
kubectl get deployment web-tiny-http-app -n demo \
  -o jsonpath='{.spec.template.metadata.annotations.checksum/config}'
```

### Rollout History

```bash
# View revision history
kubectl rollout history deployment/web-tiny-http-app -n demo
```

**Output**:
```
REVISION  CHANGE-CAUSE
1         <none>
2         <none>
```

### ConfigMap Content

```bash
kubectl describe configmap web-tiny-http-app-config -n demo
```

**Output**:
```
Name:         web-tiny-http-app-config
Namespace:    demo
Data
====
APP_MESSAGE:
----
hola
```

### Environment Variable Check

```bash
POD_NAME=$(kubectl get pods -n demo -l app.kubernetes.io/name=tiny-http-app -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n demo ${POD_NAME} -- env | grep APP_MESSAGE
```

**Output**:
```
APP_MESSAGE=hola
```

---

## Troubleshooting Guide

### Pods Not Updating

**Diagnosis**:
```bash
kubectl get deployment web-tiny-http-app -n demo -o yaml | grep checksum
kubectl get configmap -n demo
helm status web -n demo
```

**Resolution**:
```bash
kubectl rollout restart deployment/web-tiny-http-app -n demo
```

### Service Not Accessible

**Diagnosis**:
```bash
kubectl get endpoints -n demo
kubectl describe svc web-tiny-http-app -n demo
kubectl get pods -n demo
```

**Resolution**:
```bash
# Test from within cluster
kubectl run -it --rm debug --image=busybox --restart=Never -- \
  wget -O- http://web-tiny-http-app.demo:8080/version
```

### Image Pull Errors

**Diagnosis**:
```bash
kubectl describe pod ${POD_NAME} -n demo | grep -A 5 "Events"
```

**Resolution**:
```bash
# Verify image exists
docker pull jasonsanjay/tiny-http-app:latest

# Check image name in values.yaml
cat tiny-http-app/values.yaml | grep repository
```

---

## Cleanup

```bash
# Uninstall application
helm uninstall web -n demo

# Delete namespace
kubectl delete namespace demo

# Destroy infrastructure
terraform destroy -auto-approve
```

---

## Technical Stack

| Component | Version | Purpose |
|-----------|---------|---------|
| **Kubernetes** | 1.29.0 | Container orchestration |
| **Helm** | 3.x | Package manager |
| **kubeadm** | 1.29.0 | Cluster bootstrapping |
| **CRI-O** | Latest | Container runtime |
| **Calico** | 3.26.0 | Network plugin |
| **Flask** | 3.0.0 | Web framework |
| **Docker** | 20.10+ | Image builder |
| **Terraform** | 1.0+ | Infrastructure as Code |

---

## License

MIT
