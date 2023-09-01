# root check
if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

# create a cluster
k3d cluster create mycluster

# create dev namespace
kubectl create namespace dev

# install agrocd in cluster
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'

# install ingress controller in cluster
# kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/cloud/deploy.yaml
# kubectl create ingress demo-localhost --class=nginx  -n default

# expose agrocd
echo "waiting for argocd pods to start.."
kubectl wait --for=condition=Ready pods --all --timeout=69420s -n argocd
kubectl port-forward svc/argocd-server -n argocd 8080:443 --address="0.0.0.0" 2>&1 > /var/log/argocd-log &
sleep 5

# get agrocd initial password
init_pw=$(argocd admin initial-password -n argocd | head -n 1)
echo y >> init_creds
echo admin >> init_creds
echo ${init_pw} >> init_creds

# tell user his creds
echo "Your username is admin"
echo "Your initial password is ${init_pw}, will be changed to Passw0rd"

# login agrocd
# argocd login localhost:8080 < init_creds
echo y | argocd login localhost:8080 --username admin --password ${init_pw} 

# change password
argocd account update-password --current-password $init_pw --new-password Passw0rd
rm init_creds

# change context namespace
kubectl config set-context --current --namespace=argocd

# create app in agrocd
argocd app create victory-royale --repo https://github.com/neosizzle/what-is-sports-in-malay-jng.git --path victory-royale --dest-server https://kubernetes.default.svc --dest-namespace dev
sleep 10

# toggle app autosync
argocd app set victory-royale --sync-policy automated
sleep 10

# sync the app (deploy)
argocd app sync victory-royale

# expose the app via port forwarding (unclean, should do ingress instead)
 while true; do
      echo "waiting for dev pods to start..."
      kubectl wait --for=condition=Ready pods --all --timeout=6969s -n dev  2>&1 > /var/log/dev-wait.log && echo "done, use curl localhost:8888 to check.."
      # kubectl port-forward services/victory-royale 8888 -n dev --address="0.0.0.0" 2>&1 > /var/log/dev-server.log &
      kubectl port-forward services/victory-royale 8888 -n dev --address="0.0.0.0" 2>&1 > /var/log/dev-server.log 
      sleep 10  # Add a small delay to prevent excessive CPU usage
done &
