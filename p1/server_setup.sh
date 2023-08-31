#get .env
#set -o allexport
#source .env set
#set +o allexport

echo "Running server setup..."
echo "ip = $SERVER_IP"
echo "token = $TOKEN"

echo "Copying host machine publickey into machine..."
cat /home/vagrant/.ssh/me.pub >> /home/vagrant/.ssh/authorized_keys

#Installing the k3s binary (can change this to the fast install method later on after figuring out how to do it)
#wget -P /usr/local/bin https://github.com/k3s-io/k3s/releases/download/v1.26.5+k3s1/k3s; chmod a+x /usr/local/bin/k3s

#Starting k3s server 
#	[--node-external-ip] = Sets up the server over local network
# [--agent-token] = Custom token
echo "Starting k3s server..."
curl -sfL https://get.k3s.io | sh -s - --node-external-ip=$SERVER_IP --agent-token=$TOKEN

#Without external_ip (advertise-address defaults to node-ip might be able to remove)
curl -sfL https://get.k3s.io | sh -s - --write-kubeconfig-mode 644 --advertise-address=$SERVER_IP --node-ip=$SERVER_IP --agent-token=$TOKEN
