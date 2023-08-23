# make namespsace
kubectl create namespace gitlab
kubectl config set-context --current --namespace=gitlab

# download and configure gitlab
helm repo add gitlab https://charts.gitlab.io
helm search repo -l gitlab/gitlab
helm upgrade --install gitlab gitlab/gitlab \
  --timeout 600s \
  --set global.hosts.domain=localhost \
  --set global.hosts.externalIP=127.0.0.1 \
  --set certmanager-issuer.email=me@example.com \
  --set postgresql.image.tag=13.6.0

# get password
kubectl get secret gitlab-gitlab-initial-root-password -ojsonpath='{.data.password}' | base64 --decode ; echo

# wait
kubectl wait --for=condition=Ready pods --all --timeout=-1s -n gitlab

# Please set your /etc/hosts
echo "REMEMBER TO SET /etc/hosts 127.0.0.1 gitlab.localhost"

# port forward
kubectl port-forward services/gitlab-webservice-default 443 -n gitlab --address="0.0.0.0" 2>&1 > /var/log/gitlab-webserver.log &


