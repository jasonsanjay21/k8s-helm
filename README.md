# Kubernetes Helm-Driven Configuration Management with Rolling Updates

A production-grade demonstration of automated rolling updates in Kubernetes using Helm charts with ConfigMap-driven configuration changes and checksum-based deployment triggers.

---

## Executive Summary

This project implements a microservices deployment pattern demonstrating:

- **Zero-downtime deployments** through Kubernetes rolling update strategies
- **GitOps-ready configuration management** using Helm and ConfigMaps
- **Automated change detection** via SHA256 checksum annotations
- **Production-ready health monitoring** with liveness and readiness probes
- **Infrastructure as Code** provisioning using Terraform and kubeadm

### Objectives Met

| Requirement | Status | Implementation |
|-------------|--------|----------------|
| Kubernetes cluster via kubeadm | ✓ | Multi-node cluster with CRI-O runtime |
| HTTP application with version endpoint | ✓ | Flask-based REST API |
| Helm chart deployment | ✓ | Single Deployment + Service pattern |
| ConfigMap-driven configuration | ✓ | External configuration management |
| Health probes | ✓ | HTTP-based liveness/readiness checks |
| Automated rolling updates | ✓ | Checksum annotation trigger mechanism |

---

### Component Interaction Flow

1. **ConfigMap Update**: Helm modifies ConfigMap with new `APP_MESSAGE` value
2. **Checksum Calculation**: SHA256 hash computed on ConfigMap content
3. **Deployment Trigger**: Pod template annotation changes, triggering rolling update
4. **Progressive Rollout**: New pods created while old pods continue serving traffic
5. **Health Validation**: Readiness probes ensure new pods are healthy before receiving traffic
6. **Graceful Termination**: Old pods terminated after successful deployment

---

## Prerequisites

### Required Software

| Tool | Version | Purpose |
|------|---------|---------|
| Terraform | ≥ 1.0 | Infrastructure provisioning |
| kubectl | 1.29.0 | Kubernetes CLI |
| Helm | ≥ 3.0 | Package management |
| Docker | ≥ 20.10 | Container image building |
| AWS CLI | ≥ 2.0 | Cloud resource management |

### Infrastructure Requirements

- AWS account with appropriate IAM permissions
- SSH key pair for EC2 instance access
- Security groups configured for Kubernetes communication:
  - **Master Node**: Port 6443 (API Server), 2379-2380 (etcd), 10250-10252 (kubelet/scheduler)
  - **Worker Nodes**: Port 10250 (kubelet), 30000-32767 (NodePort range)
  - **All Nodes**: Port 179 (Calico BGP), 4789 (Calico VXLAN)

### Pre-deployment Checklist

- [ ] AWS credentials configured (`~/.aws/credentials`)
- [ ] SSH key pair created and available
- [ ] Docker Hub account for image registry
- [ ] Network security groups properly configured
- [ ] Sufficient AWS quota for EC2 instances

---

## Infrastructure Provisioning

### Terraform Deployment

**Configuration Update Required**: Modify `main.tf` with your SSH key name before deployment.

```hcl
# main.tf - Update this value
variable "key_name" {
  default = "OctKey"  # Replace with your key name
}
```

**Deployment Commands**:

```bash
# Initialize Terraform workspace
terraform init

# Review execution plan
terraform plan

# Apply infrastructure changes
terraform apply -auto-approve
```

**Expected Output**:
```
Apply complete! Resources: 5 added, 0 changed, 0 destroyed.

Outputs:
master_public_ip = "XX.XX.XX.XX"
worker_public_ip = "XX.XX.XX.XX"
```

---

## Kubernetes Cluster Setup

### Common Node Configuration

Execute on **both master and worker nodes**:

```bash
# Install kubectl binary
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl.sha256"
echo "$(cat kubectl.sha256) kubectl" | sha256sum --check
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Disable swap (required for kubelet)
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# Load required kernel modules
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
sudo modprobe overlay
sudo modprobe br_netfilter

# Configure sysctl parameters for Kubernetes networking
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sudo sysctl --system

# Install CRI-O container runtime
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

# Install Kubernetes components (kubeadm, kubelet, kubectl)
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
# Pre-pull required container images
sudo kubeadm config images pull

# Initialize control plane
sudo kubeadm init --pod-network-cidr=192.168.0.0/16

# Configure kubectl access for current user
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Verify control plane components
kubectl get nodes
kubectl get pods -n kube-system

# Deploy Calico CNI network plugin
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.0/manifests/calico.yaml

# Wait for Calico pods to be ready
kubectl wait --for=condition=ready pod -l k8s-app=calico-node -n kube-system --timeout=300s

# Generate worker node join command
kubeadm token create --print-join-command
```

**Expected Output**:
```
Your Kubernetes control-plane has initialized successfully!

To start using your cluster:
  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

Then you can join any number of worker nodes by running the following on each:
kubeadm join <MASTER-IP>:6443 --token <TOKEN> \
  --discovery-token-ca-cert-hash sha256:<HASH>
```

### Worker Node Configuration

Execute on **worker node only**:

```bash
# Reset any previous cluster configuration
sudo kubeadm reset --force

# Join the cluster using the command generated from master
sudo kubeadm join <MASTER-IP>:6443 \
  --token <TOKEN> \
  --discovery-token-ca-cert-hash sha256:<HASH> \
  --v=5
```

**Verification on Master**:
```bash
kubectl get nodes
```

**Expected Output**:
```
NAME              STATUS   ROLES           AGE   VERSION
master-node       Ready    control-plane   5m    v1.29.0
worker-node       Ready    <none>          2m    v1.29.0
```

---

## Application Architecture

### Project Structure

```
tiny-http-app/
├── app.py                      # Flask application source
├── Dockerfile                  # Container image definition
├── Chart.yaml                  # Helm chart metadata
├── values.yaml                 # Default configuration values
└── templates/
    ├── _helpers.tpl           # Template helper functions
    ├── configmap.yaml         # ConfigMap resource definition
    ├── deployment.yaml        # Deployment with rolling update strategy
    └── service.yaml           # Service resource (NodePort)
```

### Application Source Code

**Flask Application** (`app.py`):

```python
from flask import Flask, jsonify
import os

app = Flask(__name__)

@app.route('/version')
def version():
    """
    Version endpoint returning configurable message from environment.
    Returns:
        JSON response with message field
    """
    message = os.getenv('APP_MESSAGE', 'default-message')
    return jsonify({"message": message})

@app.route('/health')
def health():
    """Health check endpoint for Kubernetes probes."""
    return jsonify({"status": "healthy"}), 200

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)
```

### Container Image

**Dockerfile**:

```dockerfile
FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Install dependencies
RUN pip install --no-cache-dir flask==3.0.0

# Copy application code
COPY app.py .

# Expose application port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD python -c "import requests; requests.get('http://localhost:8080/health')"

# Run application
CMD ["python", "app.py"]
```

**Build and Publish**:

```bash
# Build container image
docker build -t jasonsanjay/tiny-http-app:latest .

# Test locally
docker run -p 8080:8080 -e APP_MESSAGE="test" jasonsanjay/tiny-http-app:latest

# Verify functionality
curl http://localhost:8080/version

# Push to Docker Hub
docker login
docker push jasonsanjay/tiny-http-app:latest
```

---

---

## Deployment Procedure

### Initial Deployment

```bash
# Validate Helm chart syntax
helm lint ./tiny-http-app

# Dry-run to preview generated manifests
helm install web ./tiny-http-app -n demo --create-namespace --dry-run --debug

# Deploy application with initial configuration
helm upgrade --install web ./tiny-http-app \
  -n demo \
  --create-namespace \
  --set appMessage="hello-world" \
  --wait \
  --timeout 5m
```

**Deployment Output**:
```
Release "web" does not exist. Installing it now.
NAME: web
LAST DEPLOYED: Thu Oct 30 18:48:18 2025
NAMESPACE: demo
STATUS: deployed
REVISION: 1
TEST SUITE: None
```

### Verification Steps

**1. Check Pod Status**:
```bash
kubectl get pods -n demo -o wide
```

**Expected Output**:
```
NAME                                 READY   STATUS    RESTARTS   AGE   IP             NODE
web-tiny-http-app-7669ff59b4-74rlc   1/1     Running   0          45s   192.168.1.10   worker-node
web-tiny-http-app-7669ff59b4-z79r2   1/1     Running   0          45s   192.168.1.11   worker-node
```

**2. Verify Service Configuration**:
```bash
kubectl get svc -n demo
```

**Expected Output**:
```
NAME                TYPE       CLUSTER-IP       EXTERNAL-IP   PORT(S)          AGE
web-tiny-http-app   NodePort   10.101.239.103   <none>        8080:30080/TCP   50s
```

**3. Validate ConfigMap Creation**:
```bash
kubectl get configmap -n demo
kubectl describe configmap web-tiny-http-app-config -n demo
```

**Expected Output**:
```
Name:         web-tiny-http-app-config
Namespace:    demo
Labels:       app.kubernetes.io/instance=web
              app.kubernetes.io/managed-by=Helm
              app.kubernetes.io/name=tiny-http-app
              helm.sh/chart=tiny-http-app-0.1.0

Data
====
APP_MESSAGE:
----
hello-world
```

**4. Test Application Endpoint**:
```bash
# Get worker node IP
export WORKER_IP=$(kubectl get nodes -o jsonpath='{.items[?(@.metadata.labels.node-role\.kubernetes\.io/control-plane!="")].status.addresses[?(@.type=="ExternalIP")].address}')

# Test version endpoint
curl http://${WORKER_IP}:30080/version
```

**Expected Response**:
```json
{"message":"hello-world"}
```

---

## Rolling Update Demonstration

### Triggering Configuration Update

```bash
# Update ConfigMap value via Helm
helm upgrade web ./tiny-http-app \
  -n demo \
  --set appMessage="hola" \
  --wait \
  --timeout 5m
```

**Update Output**:
```
Release "web" has been upgraded. Happy Helming!
NAME: web
LAST DEPLOYED: Thu Oct 30 18:52:15 2025
NAMESPACE: demo
STATUS: deployed
REVISION: 2
```

### Monitoring Rolling Update Progress

```bash
# Watch deployment rollout status
kubectl rollout status deployment/web-tiny-http-app -n demo
```

**Rollout Output**:
```
Waiting for deployment "web-tiny-http-app" rollout to finish: 1 out of 2 new replicas have been updated...
Waiting for deployment "web-tiny-http-app" rollout to finish: 1 out of 2 new replicas have been updated...
Waiting for deployment "web-tiny-http-app" rollout to finish: 1 old replicas are pending termination...
Waiting for deployment "web-tiny-http-app" rollout to finish: 1 old replicas are pending termination...
deployment "web-tiny-http-app" successfully rolled out
```

### Post-Update Verification

**1. Verify New Pod Generation**:
```bash
kubectl get pods -n demo -o wide
```

**Expected Output** (note different pod hash):
```
NAME                                 READY   STATUS    RESTARTS   AGE   IP             NODE
web-tiny-http-app-8a7b9c6d5f-abc12   1/1     Running   0          90s   192.168.1.12   worker-node
web-tiny-http-app-8a7b9c6d5f-xyz89   1/1     Running   0          87s   192.168.1.13   worker-node
```

**Key Observation**: Pod hash changed from `7669ff59b4` to `8a7b9c6d5f`, confirming new pod template deployment.

**2. Validate Updated Configuration**:
```bash
curl http://${WORKER_IP}:30080/version
```

**Expected Response**:
```json
{"message":"hola"}
```

**3. Examine ReplicaSet History**:
```bash
kubectl get replicasets -n demo
```

**Expected Output**:
```
NAME                           DESIRED   CURRENT   READY   AGE
web-tiny-http-app-7669ff59b4   0         0         0       5m
web-tiny-http-app-8a7b9c6d5f   2         2         2       2m
```

**Analysis**: Old ReplicaSet scaled to 0 replicas, new ReplicaSet managing 2 active pods.

---

## Verification and Validation

### Checksum Validation

**Verify Checksum Annotation**:
```bash
kubectl get deployment web-tiny-http-app -n demo -o jsonpath='{.spec.template.metadata.annotations.checksum/config}'
```

**Compare ConfigMap Content**:
```bash
# Get ConfigMap hash
kubectl get configmap web-tiny-http-app-config -n demo -o yaml | sha256sum

# Get deployment annotation
kubectl get deployment web-tiny-http-app -n demo -o yaml | grep "checksum/config"
```

### Rollout History Analysis

```bash
# View deployment revision history
kubectl rollout history deployment/web-tiny-http-app -n demo
```

**Expected Output**:
```
REVISION  CHANGE-CAUSE
1         <none>
2         <none>
```

**Detailed Revision Comparison**:
```bash
# Compare revision 1 and 2
kubectl rollout history deployment/web-tiny-http-app -n demo --revision=1
kubectl rollout history deployment/web-tiny-http-app -n demo --revision=2
```

### Pod Environment Validation

```bash
# Inspect pod environment variables
POD_NAME=$(kubectl get pods -n demo -l app.kubernetes.io/name=tiny-http-app -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n demo ${POD_NAME} -- env | grep APP_MESSAGE
```

**Expected Output**:
```
APP_MESSAGE=hola
```

### Health Probe Status

```bash
# Check probe configuration and status
kubectl describe pod ${POD_NAME} -n demo | grep -A 10 "Liveness\|Readiness"
```

**Expected Output**:
```
    Liveness:   http-get http://:http/version delay=10s timeout=2s period=10s #success=1 #failure=3
    Readiness:  http-get http://:http/version delay=5s timeout=2s period=5s #success=1 #failure=3
```

### Event Timeline

```bash
# View recent events in namespace
kubectl get events -n demo --sort-by='.lastTimestamp' | tail -20
```

---

## Troubleshooting Guide

### Issue: Pods Not Updating

**Symptoms**:
- Pod names remain unchanged after Helm upgrade
- ConfigMap updated but deployment not triggered

**Diagnosis**:
```bash
# Check deployment annotations
kubectl get deployment web-tiny-http-app -n demo -o yaml | grep checksum

# Verify ConfigMap exists
kubectl get configmap -n demo

# Check Helm release status
helm status web -n demo
```

**Resolution**:
```bash
# Force deployment recreation
kubectl rollout restart deployment/web-tiny-http-app -n demo

# Or delete and redeploy
helm uninstall web -n demo
helm install web ./tiny-http-app -n demo --set appMessage="value"
```

### Issue: Service Not Accessible

**Symptoms**:
- Connection timeout when accessing NodePort
- Endpoint returns no response

**Diagnosis**:
```bash
# Check service endpoints
kubectl get endpoints -n demo

# Verify pod readiness
kubectl get pods -n demo

# Check service configuration
kubectl describe svc web-tiny-http-app -n demo

# Verify security group rules
aws ec2 describe-security-groups --group-ids <SG_ID>
```

**Resolution**:
```bash
# Test from within cluster
kubectl run -it --rm debug --image=busybox --restart=Never -- wget -O- http://web-tiny-http-app.demo:8080/version

# Verify NodePort binding
sudo netstat -tulpn | grep 30080

# Check firewall rules
sudo iptables -L -n | grep 30080
```

### Issue: Probe Failures

**Symptoms**:
- Pods in CrashLoopBackOff state
- Readiness probe failures in events

**Diagnosis**:
```bash
# Check pod logs
kubectl logs ${POD_NAME} -n demo

# Describe pod for events
kubectl describe pod ${POD_NAME} -n demo

# Test probe endpoint manually
kubectl exec ${POD_NAME} -n demo -- wget -O- http://localhost:8080/version
```

**Resolution**:
```bash
# Adjust probe timings in values.yaml
# Increase initialDelaySeconds or periodSeconds

# Verify application starts correctly
kubectl logs ${POD_NAME} -n demo --previous
```

### Issue: Image Pull Errors

**Symptoms**:
- ImagePullBackOff or ErrImagePull status
- Unable to pull image from registry

**Diagnosis**:
```bash
# Check image pull status
kubectl describe pod ${POD_NAME} -n demo | grep -A 5 "Events"

# Verify image exists
docker pull jasonsanjay/tiny-http-app:latest
```

**Resolution**:
```bash
# Create image pull secret if using private registry
kubectl create secret docker-registry regcred \
  --docker-server=https://index.docker.io/v1/ \
  --docker-username=<username> \
  --docker-password=<password> \
  --docker-email=<email> \
  -n demo

# Update deployment to use secret
# Add to values.yaml:
# imagePullSecrets:
#   - name: regcred
```

---

## Cleanup Procedures

### Application Cleanup

```bash
# Uninstall Helm release
helm uninstall web -n demo

# Verify resources removed
kubectl get all -n demo

# Delete namespace
kubectl delete namespace demo
```

### Cluster Cleanup

```bash
# On worker nodes
sudo kubeadm reset --force
sudo rm -rf /etc/cni/net.d
sudo rm -rf /var/lib/etcd

# On master node
sudo kubeadm reset --force
sudo rm -rf /etc/kubernetes/
sudo rm -rf /var/lib/etcd
```

### Infrastructure Cleanup

```bash
# Destroy Terraform-managed resources
terraform destroy -auto-approve

# Verify resources deleted
aws ec2 describe-instances --filters "Name=tag:Project,Values=kubernetes-helm"
```

---

## Technical Stack

### Core Technologies

| Component | Version | Purpose |
|-----------|---------|---------|
| **Kubernetes** | 1.29.0 | Container orchestration platform |
| **Helm** | 3.x | Kubernetes package manager |
| **kubeadm** | 1.29.0 | Cluster bootstrapping tool |
| **CRI-O** | Latest | OCI-compliant container runtime |
| **Calico** | 3.26.0 | Network policy and CNI plugin |
| **Flask** | 3.0.0 | Python web framework |
| **Docker** | 20.10+ | Container image builder |
| **Terraform** | 1.0+ | Infrastructure as Code tool |

### Design Patterns Implemented

- **Rolling Update Strategy**: Zero-downtime deployments
- **Immutable Infrastructure**: Pods replaced rather than updated
- **External Configuration**: ConfigMaps for environment-specific values
- **Health Monitoring**: Liveness and readiness probes
- **Resource Management**: CPU and memory limits/requests
- **GitOps Ready**: Declarative configuration management

---

## Key Learnings and Best Practices

### Achieved Competencies

1. **Infrastructure Automation**: Provisioned production-grade Kubernetes cluster using kubeadm
2. **Configuration Management**: Implemented external configuration via ConfigMaps
3. **Deployment Strategies**: Executed zero-downtime rolling updates with health checks
4. **Observability**: Integrated health probes for automated failure detection
5. **Package Management**: Created reusable, parameterized Helm charts
6. **Change Detection**: Implemented checksum-based automatic deployment triggers

