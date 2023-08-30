#  _____ _ _   _           _       _____          _        _ _       _   _             
# |  __ (_) | | |         | |     |_   _|        | |      | | |     | | (_)            
# | |  \/_| |_| |     __ _| |__     | | _ __  ___| |_ __ _| | | __ _| |_ _  ___  _ __  
# | | __| | __| |    / _` | '_ \    | || '_ \/ __| __/ _` | | |/ _` | __| |/ _ \| '_ \ 
# | |_\ \ | |_| |___| (_| | |_) |  _| || | | \__ \ || (_| | | | (_| | |_| | (_) | | | |
#  \____/_|\__\_____/\__,_|_.__/   \___/_| |_|___/\__\__,_|_|_|\__,_|\__|_|\___/|_| |_|
                                                                                     
                                                                                     
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
  --set postgresql.image.tag=13.6.0 \
  --set livenessProbe.initialDelaySeconds=1220 \
  --set readinessProbe.initialDelaySeconds=1220

# will error if we didnt install gitlab runner
if [ $? -ne 0 ]; then
  echo "helm upgrade command failed. Exiting with non-zero status."
  exit 1
fi

# wait, but should be okay once webservice deployment is up
# gitlab runner will not launch because of host config which i dont seem needed to do
echo "Waiting for gitlab to finish starting pods.."
kubectl wait --for=condition=Ready deployments --all --timeout=-1s -n gitlab

# Please set your /etc/hosts
echo "REMEMBER TO SET /etc/hosts 127.0.0.1 gitlab.localhost"
echo "127.0.0.1 gitlab.localhost" >> /etc/hosts

# port forward
kubectl port-forward services/gitlab-nginx-ingress-controller 443 -n gitlab --address="0.0.0.0" 2>&1 > /var/log/gitlab-webserver.log &

# get password
echo "========================GITLAB ROOT PASSWORD IS=========================="
kubectl get secret gitlab-gitlab-initial-root-password -ojsonpath='{.data.password}' | base64 --decode ; echo

if [ $? -ne 0 ]; then
  echo "Command failed. Exiting with non-zero status."
  exit 1
fi

#   ___                  ___________   _____                             _   _             
#  / _ \                /  __ \  _  \ /  __ \                           | | (_)            
# / /_\ \_ __ __ _  ___ | /  \/ | | | | /  \/ ___  _ __  _ __   ___  ___| |_ _  ___  _ __  
# |  _  | '__/ _` |/ _ \| |   | | | | | |    / _ \| '_ \| '_ \ / _ \/ __| __| |/ _ \| '_ \ 
# | | | | | | (_| | (_) | \__/\ |/ /  | \__/\ (_) | | | | | | |  __/ (__| |_| | (_) | | | |
# \_| |_/_|  \__, |\___/ \____/___/    \____/\___/|_| |_|_| |_|\___|\___|\__|_|\___/|_| |_|
#             __/ |                                                                        
#            |___/                                                                         

# assign external ip for gitlab ingress service so the argocd server can conenct
kubectl patch svc gitlab-nginx-ingress-controller -p '{"spec":{"externalIPs":["10.43.2.138"]}}'
kubectl get pods -n argocd
echo "External IP assigned to 10.43.2.138, please enter the repository pod name.."
read repoPodName

# get container ID
containerId=$(kubectl get pod $repoPodName -o jsonpath="{.status.containerStatuses[].containerID}" -n argocd | sed 's,.*//,,')

# change /etc/hosts in argocd repo container
docker exec -it k3d-mycluster-server-0 "/bin/runc" --root /run/containerd/runc/k8s.io/ exec -t -u 0 $containerId "/bin/sh" -c 'echo "10.43.2.138 gitlab.localhost" >> /etc/hosts' 

# auth argocd
echo 'y' | argocd login localhost:8080 --username admin --password Passw0rd

# auth gitlab
gitlabPw=$(kubectl get secret gitlab-gitlab-initial-root-password -ojsonpath='{.data.password}' | base64 --decode ; echo)

# create repo
echo "Please create a public repo in gitlab.localhost and enter the repo URL (https://)"
read repoURL

# add repo
argocd repo add $repoURL --insecure-skip-server-verification --username root --password $gitlabPw

if [ $? -ne 0 ]; then
  echo "Command failed. Exiting with non-zero status."
  exit 1
fi

# change argocd /etc/hosts
# https://stackoverflow.com/questions/42793382/exec-commands-on-kubernetes-pods-with-root-access

#   ___                    _            _                                  _   
#  / _ \                  | |          | |                                | |  
# / /_\ \_ __  _ __     __| | ___ _ __ | | ___  _   _ _ __ ___   ___ _ __ | |_ 
# |  _  | '_ \| '_ \   / _` |/ _ \ '_ \| |/ _ \| | | | '_ ` _ \ / _ \ '_ \| __|
# | | | | |_) | |_) | | (_| |  __/ |_) | | (_) | |_| | | | | | |  __/ | | | |_ 
# \_| |_/ .__/| .__/   \__,_|\___| .__/|_|\___/ \__, |_| |_| |_|\___|_| |_|\__|
#       | |   | |                | |             __/ |                         
#       |_|   |_|                |_|            |___/                          
kubectl create namespace dev2
argocd app create victory-royale2 --repo https://gitlab.localhost/root/iot.git --path victory-royale --dest-server https://kubernetes.default.svc --dest-namespace dev2
sleep 10
argocd app sync victory-royale2
