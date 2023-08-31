#get .env
#set -o allexport
#source .env set
#set +o allexport

echo "Running agent setup..."
echo "ip = $SERVER_IP"
echo "token = $TOKEN"

echo "Copying host machine publickey into machine..."
cat /home/vagrant/.ssh/me.pub >> /home/vagrant/.ssh/authorized_keys

#Installing the k3s binary (can change this to the fast install method later on after figuring out how to do it)
#wget -P /usr/local/bin https://github.com/k3s-io/k3s/releases/download/v1.26.5+k3s1/k3s; chmod a+x /usr/local/bin/k3s

#connect to server with k3s binary
#k3s agent --server https://192.168.56.110:6443/cacerts --token node_token

#TODO: use scp to copy token instead of hard value token

#connect to server
echo "Joining cluster as agent..."
curl -sfL https://get.k3s.io | K3S_URL=https://$SERVER_IP:6443 K3S_TOKEN=$TOKEN sh -

#Without external_ip (can try to pass in node-ip dynamically with args in Vagrant file)
curl -sfL https://get.k3s.io | sh -s - agent --server https://$SERVER_IP:6443 --token=$TOKEN --node-ip=192.168.56.111
