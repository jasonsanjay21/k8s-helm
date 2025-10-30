ls
# disable swap
sudo swapoff -a
# Create the .conf file to load the modules at bootup
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter
# sysctl params required by setup, params persist across reboots
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

# Apply sysctl params without reboot
sudo sysctl --system
## Install CRIO Runtime
sudo apt-get update -y
sudo apt-get install -y software-properties-common curl apt-transport-https ca-certificates gpg
sudo curl -fsSL https://pkgs.k8s.io/addons:/cri-o:/prerelease:/main/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/cri-o-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/cri-o-apt-keyring.gpg] https://pkgs.k8s.io/addons:/cri-o:/prerelease:/main/deb/ /" | sudo tee /etc/apt/sources.list.d/cri-o.list
sudo apt-get update -y
sudo apt-get install -y cri-o
sudo systemctl daemon-reload
sudo systemctl enable crio --now
sudo systemctl start crio.service
echo "CRI runtime installed successfully"
# Add Kubernetes APT repository and install required packages
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update -y
sudo apt-get install -y kubelet="1.29.0-*" kubectl="1.29.0-*" kubeadm="1.29.0-*"
sudo apt-get update -y
sudo apt-get install -y jq
sudo systemctl enable --now kubelet
sudo systemctl start kubelet
kubectl get nodes
vi app.yaml
kubectl apply -f app.yaml 
kubectl get pods
kubectl get pods -o wide
kubectl get svc tiny-http-app-service
kubectl get pods -o wide
kubectl get nodes
kubectl describe nodes
kubectl get nodes
kubeadm token create --print-join-command
kubectl get nodes
kubectl apply -f app.yaml 
kubectl get pods
kubectl logs -f tiny-http-app-686947f98f-hnklq
curl http://13.60.219.39:30080/version
vi app.yaml 
ls
vi app.yaml 
kubectl apply -f app.yaml 
kubectl get svc tiny-http-app-service
vi app.yaml 
kubectl apply -f app.yaml 
kubectl get svc tiny-http-app-service
kubectl get pods
kubectl logs -f tiny-http-app-686947f98f-hnklq
curl http://13.60.219.39:30080/version
helm create web
curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
sudo apt-get install apt-transport-https --yes
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
sudo apt-get update
sudo apt-get install helm
helm version
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh
helm version
helm create web
ls -lrth
cd web/
ls
cd.
cd ..
kls
ls
cat app.yaml 
ls
vi helm_script.sh
chmod +x helm_script.sh 
./helm_script.sh 
ls
cd tiny-http-app/
ls
helm init
helm lint .
helm template my-app .
helm install tiny-http-app .
cd
ls -lrth
rm -rf app.yaml 
kubectl delete -f app.yaml
kubectl delete deployment tiny-http-app
kubectl delete service tiny-http-app-service
kubectl get pods
kubectl get pods -o wide
kubectl get pods
kubectl get pods -o wide
cd tiny-http-app/
helm install tiny-http-app .
helm list
kubectl get pods
kubectl get svc
curl http://10.100.57.71:8080/version
curl http://13.60.219.39:30080/version
cd
kubectl get pods -l app.kubernetes.io/name=tiny-http-app
helm upgrade --install web ./chart -n demo --create-namespace --set appMessage="hello-world"
ls
cd tiny-http-app/
ls
helm upgrade --install web ./chart -n demo --create-namespace --set appMessage="hello-world"
cd ..
helm upgrade --install web ./tiny-http-app -n demo --create-namespace --set appMessage="hello-world"
sudo apt update
sudo apt install -y git
echo "# k8s-helm" >> README.md
git init
git add README.md
git commit -m "first commit"
git branch -M main
git remote add origin https://github.com/jasonsanjay21/k8s-helm.git
git push -u origin main
echo "# k8s-helm" >> README.md
git init
git add README.md
git commit -m "first commit"
git branch -M main
git remote add origin https://github.com/jasonsanjay21/k8s-helm.git
git push -u origin main
echo "# k8s-helm" >> README.md
git init
git add README.md
git commit -m "first commit"
git branch -M main
git remote add origin https://github.com/jasonsanjay21/k8s-helm.git
git push -u origin main
git config --global user.name "Jason"
