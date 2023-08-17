# expose agrocd
echo "waiting for argocd pods to start.."
kubectl wait --for=condition=Ready pods --all --timeout=69420s -n argocd
kubectl port-forward svc/argocd-server -n argocd 8080:443 --address="0.0.0.0" 2>&1 > /var/log/argocd-log &


# expose the app via port forwarding (unclean, should do ingress instead)
 while true; do
      echo "waiting for dev pods to start..."
      kubectl wait --for=condition=Ready pods --all --timeout=6969s -n dev  2>&1 > /var/log/dev-wait.log && echo "done, use curl localhost:8888 to check.."
      # kubectl port-forward services/victory-royale 8888 -n dev --address="0.0.0.0" 2>&1 > /var/log/dev-server.log &
      kubectl port-forward services/victory-royale 8888 -n dev --address="0.0.0.0" 2>&1 > /var/log/dev-server.log 
      sleep 10  # Add a small delay to prevent excessive CPU usage
done &
