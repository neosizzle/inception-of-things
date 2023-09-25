# inception-of-things
A project which involves setting up and managing sample k3s clusters with k3d, emulated using virtual machines on vagrant and a CI/CD implementation using Agro CD

# /dev/log for inception-of-things

[Toc]

# Week 1
## Kubernetes reading and VM setup
I have found this [book](https://eddiejackson.net/azure/Kubernetes_book.pdf) book online that explains the kubernetes ecosystem, and I will be reading it as my primary resource from now

Docker installation 
` apt-get install ca-certificates curl gnupg lsb-release`

`mkdir -p /etc/apt/keyrings`

`curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
`

`echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
`



I also set up a Debian VM to go with the practical examples, which I have docker and k3d installed. To install k3d, I need to install kubectl

```
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
 
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
```

and then k3d itself

`wget -q -O - https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
`

From my understanding so far, kubernetes is an orchestrator to run and deploy multiple docker (or not) containers and k3d and minikube are tools that acts wrappers around the k8s architecture. 

Run `k3d cluster create mycluster` to create a sample cluster and `kubectl cluster-info` to verify the cluster creation

![](https://i.imgur.com/AW5Yqse.png)

## Installation of dashboard
I wanted to set up the dashboard so I can see visually whats going on, so here are the installation steps

Deploy dashboard
```kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml```

get auth token to login to dashboard for the default user (remember the token)
`kubectl create token default`

Serve the api
``` kubectl proxy --address='0.0.0.0'```

Should head to http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/, it should appear. You will log in as admin-user and you should paste the token you have earlier to login.

![](https://i.imgur.com/ZXiWS5s.png)

## AgroCD installation
AgroCD will be our gitOPs CD tool, install it with the commands below

```
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
rm argocd-linux-amd64
```

To add agrocd to an exising cluster, one needs to create a namespace for it 

`kubectl create namespace argocd`

then change the state of the cluster with the manifest from their repo, which will create service accounts, custom resources, services, deployments and roles alike

`kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
`

## Cluster creation
We will be using k3d to create the cluster and initial namespaces

```bash
# create a cluster
k3d cluster create mycluster

# create dev namespace
kubectl create namespace dev

# install agrocd in cluster
kubectl create namespace argocd
```

We will now install argo3d in our cluster and launch it
```bash
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'

# expose agrocd
echo "waiting for argocd pods to start.."
kubectl wait --for=condition=Ready pods --all --timeout=69420s -n argocd
kubectl port-forward svc/argocd-server -n argocd 8080:443 --address="0.0.0.0" 2>&1 > /var/log/argocd-log &
```

Once that runs, you can head to localhost:8080 to access the argocd admin dashboard. This will be our gitOPS tool, so we will visit here often

![](https://i.imgur.com/Mt3FA2R.png)

To set the initial password for argocd, run the script

```bash
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
```

This will set your password to `Passw0rd`. You will log in using this password with username `admin`

## Setting up CI/CD pipeline
Create an app to deploy by creating a directory as the repos root, and create a build directory where your manifest files live.

```
root
|
|-- victory_royale
    |
    |-- build.yaml
    |
    |-- service.yaml
```

in `build.yaml`, you will create the manifest file for your pods / deployment
```yaml

apiVersion: apps/v1
kind: Deployment
metadata:
  name: victory-royale
spec:
  replicas: 1
  selector:
    matchLabels:
      app: victory-royale
  template:
    metadata:
      labels:
        app: victory-royale
    spec:
      containers:
        - image: wil42/playground:v1
          name: victory-royale
      ports:
        - containerPort: 8888
          name: http
          protocol: TCP
```
In your `service.yaml`, you will create your service resource, which exposes your containers to entexternal clusters

```yaml
apiVersion: v1
kind: Service
metadata:
  name: victory-royale
spec:
  ports:
  - port: 8888
    targetPort: 8888
  selector:
    app: victory-royale
```

Make sure to push these, `victory-royale` is the application name, you can change to whichever name you see fit.

Use ArgoCD to track the app you created

```bash
# change context namespace
kubectl config set-context --current --namespace=argocd

# create app in agrocd
argocd app create victory-royale --repo https://github.com/neosizzle/what-is-sports-in-malay-jng.git --path victory-royale --dest-server https://kubernetes.default.svc --dest-namespace dev
sleep 10

```
> Of course, change the repo link and the names as you see fit

You can use 
```bash
argocd app get victory-royale
```
to view the app that you created.

Run the following commands to build and deploy the app
```bash
# toggle app autosync
argocd app set victory-royale --sync-policy automated
sleep 10

# sync the app (deploy)
argocd app sync victory-royale

# expose the app via port forwarding (unclean, should do ingress instead)
 while true; do
      echo "waiting for dev pods to start..."
      kubectl wait --for=condition=Ready pods --all --timeout=6969s -n dev  2>&1 > /var/log/dev-wait.log && echo "done, use curl localhost:8888 to check.."
      kubectl port-forward services/victory-royale 8888 -n dev --address="0.0.0.0" 2>&1 > /var/log/dev-server.log 
      sleep 10  # Add a small delay to prevent excessive CPU usage
done &

```

Now try changing the app and pushing a change, the app ArgoCD should pick that up and redeploy the app automatically.

# Week 2

## Helm installation
```bash=
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

## Gitlab install via helm
1. Create the gitlab namespace
    `kubectl create namespace gitlab`

2. Set the current namespace to gitlab for convinience
    `kubectl config set-context --current --namespace=gitlab`

3. Download and install gitlab to the cluster via the helm chart
`helm repo add gitlab https://charts.gitlab.io`
`helm search repo -l gitlab/gitlab`

    ```bash
    helm upgrade --install gitlab gitlab/gitlab \
      --timeout 600s \
      --set global.hosts.domain=localhost \
      --set global.hosts.externalIP=127.0.0.1 \
      --set certmanager-issuer.email=me@example.com \
      --set postgresql.image.tag=13.6.0 \
      --set livenessProbe.initialDelaySeconds=220 \
      --set readinessProbe.initialDelaySeconds=220
      ```
 4. Expose the gitlab frontend
      ```bash
      kubectl port-forward services/gitlab-nginx-ingress-controller 8082:443 -n gitlab --address="0.0.0.0" 2>&1 > /var/log/gitlab-webserver.log &
      ```
  
 5. Obtain the root password for login
      ```bash
      kubectl get secret gitlab-gitlab-initial-root-password -ojsonpath='{.data.password}' | base64 --decode ; echo
      ```

## Connecting argoCD with gitlab
https://stackoverflow.com/questions/42793382/exec-commands-on-kubernetes-pods-with-root-access

> If you want to run a command in a k3d node, you should first understand that k3d nodes are essentially Docker containers. Therefore, you can use Docker commands to interact with these nodes, including running commands inside them.

1. Assign external ip for gitlab ingress service so the argocd server can conenct
    `kubectl patch svc gitlab-nginx-ingress-controller -p '{"spec":{"externalIPs":["10.43.2.138"]}}'`

2. List out all the pods and look for the pod name for the argocd repo server (this pod is responsoble for the cloning action)
    `kubectl get pods -n argocd`

3. Get the containerID of the said pod, we will use this ID later to manually change the hosts file
    `kubectl get pod $repoPodName -o jsonpath="{.status.containerStatuses[].containerID}" | sed 's,.*//,,'`

4. Change /etc/hosts in argocd repo container
    - `docker exec -it  k3d-mycluster-server-0 /bin/sh`
    - `runc --root /run/containerd/runc/k8s.io/ exec -t -u 0 $containerID sh`
    - `echo "10.43.2.138 gitlab.localhost" >> /etc/hosts`

5. Register gitlab repo to argo CD
    `argocd repo add https://gitlab.localhost/root/iot.git --insecure-skip-server-verification`

If done right, there should be no errors. 
:::warning
Since these changes are **Manual**, this needs to be done again if the pod restarts.
:::

## GitLab app deployment

1. Create namespace for the app
    `kubectl create namespace dev2`

2. Create the app object in ArgoCD
    ```bash
    argocd app create victory-royale2 --repo https://gitlab.localhost/root/iot.git --path victory-royale --dest-server https://kubernetes.default.svc --dest-namespace dev2
    ```

3. Sync the app
    `argocd app sync victory-royale2`
---

![image alt](https://media.discordapp.net/attachments/1140585468149387344/1144151559408721950/image.png?width=1336&height=610)

# Week 3
## Install setup on VM (If using VM)
Install non-graphical debian-bullseye (11.6)
  
```bash
#setup script

#download dependencies for vbox
sudo apt-get update && sudo apt-get upgrade
sudo apt install linux-headers-amd64 linux-headers-5.10.0-25-amd64 gcc perl make -y

#download virtualbox
wget https://download.virtualbox.org/virtualbox/7.0.10/virtualbox-7.0_7.0.10-158379~Debian~bullseye_amd64.deb

# manual installation of virtualbox
# might need to add ldconfig or start-stop daemon to path
# export PATH="$PATH:/sbin"
sudo apt-get update
mv virtualbox-7.0_7.0.10-158379~Debian~bullseye_amd64.deb vb.deb
sudo dpkg -i vb.deb
sudo apt --fix-broken install -y
sudo apt-get upgrade

#fix symbolic link issue
touch /sbin/vboxconfig
sudo ln -s /usr/lib/virtualbox/postint-common.sh /sbin/vboxconfig

#run to fix vbox config issue
sudo /sbin/vboxconfig

#download and install vagrant
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg

#add link to sources apt sources lit
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list

# install dependencies for vagrant
sudo apt install qemu qemu-kvm libvirt-clients libvirt-daemon-system virtinst bridge-utils -y
chmod 666 /dev/kvm

#install vagrant from hashicorp repository
sudo apt install vagrant -y

# create a ssh key used by vagrant
ssh-keygen

# load kvm module needed by vagratn
sudo modprobe kvm

```

## Disable hypervisor on host
On windows, type the command `bcdedit /set hypervisorlaunchtype off` in an **admin powershell** to disable the hosts hypervisor, so it wont clash with the VMs one.

To enable it, type the command `bcdedit /set hypervisorlaunchtype auto` in the same shell.

The machine needs to be restarted to apply the changes. Virtualization dependant applications like docker and WSL will cease to function if this is done correctly.

## Setting up machines in Vagrantfile

Below is how to setup a very basic machine on vagrant named "Server".
```ruby
BOX_IMAGE = "generic/debian11"
Vagrant.configure("2") do |config|
	#Server config
	config.vm.define "Server" do |s|
		s.vm.box = BOX_IMAGE
		s.vm.network "private_network", ip: vagrant_config['server_ip']
		s.vm.hostname = "nfernandS"
	end
end
```


:::info
> ##### Setting IP
> ```ruby
> s.vm.network "private_network", ip: vagrant_config['server_ip']
> ```
> This sets the private network en1 to whatever is specified.
> This machine can be connected from host or from another machine within the same vagrant network using the same "server_ip".
:::

### Provider settings Vagrant
Each individual machine can have its own provider specific settings, or they can all share one shared setting
#### Individual Provider
```ruby
config.vm.define "Server" do |s|
	s.vm.box = BOX_IMAGE
	s.vm.network "private_network", ip: vagrant_config['server_ip']
	s.vm.hostname = "nfernandS"
	
	# Provider settings
	s.vm.provider "virtualbox" do |vb|
	  vb.memory = "1024"
	  vb.cpus = 1
	end
end
```

#### Shared Provider
```ruby
config.vm.define "Server" do |s|
	s.vm.box = BOX_IMAGE
	s.vm.network "private_network", ip: vagrant_config['server_ip']
	s.vm.hostname = "nfernandS"
end

config.vm.define "ServerWorker" do |sw|
	sw.vm.box = BOX_IMAGE
	sw.vm.network "private_network", ip: vagrant_config['server_ip']
	sw.vm.hostname = "nfernandSW"
end

# Provider settings
config.vm.provider "virtualbox" do |vb|
  vb.memory = "1024"
  vb.cpus = 1
end
```

:::info
 ##### Specifying Virtual Machine specific settings 
 ```ruby
 vb.memory = "1024"
 vb.cpus = 1
 ```
:::warning
These settings are specific to the provider so check the provider documentation page
:::


### Connecting to Vagrant via ssh
After setting up the private network in the Vagrantfile and starting up vagrant with `vagrant up`.
There are a few ways to connect to vagrant 

:::info
> ##### Method 1
> This method involves using the vagrant-ssh settings as a ssh config
> ```bash
> vagrant ssh-config > vagrant-ssh
> ssh -F vagrant-ssh vagrant@machine-ip
> ssh -F vagrant-ssh machine-name
> ```
> 
> OR 
> 
> You can add it directly to your user ssh config
> ```bash
> vagrant ssh-config >> ~/.ssh/config
> ssh machine-name
> ssh vagrant@machine-ip
> ```
> 
> ##### Method 2
> Connect via vagrant's inbuilt ssh feature
> ```bash
> vagrant ssh machine-name
> ```
:::

#### How to remove password for ssh
You can achieve by generating a ssh-key and passing the public key to the authorized_keys for each machine
```bash
ssh-keygen
ssh-copy-id vagrant@<dedicatedip>
```
or it can automated in the Vagrant file script
```ruby
s.vm.provision "file", source: PATH_TO_PUBLIC_KEY , destination: "~/.ssh/me.pub"
```
> This has to be done for each machine

## Setting up k3s
k3s has to be installed on each machine once.
Both server and agent have slightly different installation methods.

::: info
> - A server node is defined as a host running the `k3s server` command, with control-plane and datastore components managed by K3s.
> - An agent node is defined as a host running the `k3s agent` command, without any datastore or control-plane components.
> [More info about design architecture](https://docs.k3s.io/architecture)
:::

### k3s as server
#### Basic Installation Method
```bash
curl -sfL https://get.k3s.io | sh -s 
```
##### Useful flags
`--node-external-ip=value`
IPv4/IPv6 external IP addresses to advertise for node

`--advertise-address=value`
Port that api-server uses to advertise to members of the cluster
This sets the default IP to use when agents try to connect

`--node-ip=value`
IPv4/IPv6 addresses to advertise for node
This sets the internal server IP for the node when `kubectl get nodes -o wide is called`

`--write-kubeconfig-mode=value`
Write kubeconfig with this mode specified
Mode needs to be set to `644` if some configs are specified 

`--agent-token=value`
Shared secret used to join agents to the cluster, but not servers
Custom tokens can be set with this for easier testing

:::info
> If token value is not specified a token will be generated automatically in the file
> `/var/lib/rancher/k3s/server/node-token`
> in the server host machine
:::
[More info about server flags](https://docs.k3s.io/cli/server)

#### Full Install Method
```bash 
curl -sfL https://get.k3s.io | sh -s - --write-kubeconfig-mode 644 --node-ip=$SERVER_IP
```


### k3s as agent
#### Basic Installation Method
```bash
curl -sfL https://get.k3s.io | sh -s - --token=$TOKEN --server=$SERVER_IP
```

##### Useful flags
`--server=value`
Server to connect to
If `--node-ip` or `--advertise-value` is used in server setup use the value specified in there

`--token=value`
Token to use for authentication

`--node-ip=value`
IP address to advertise for node
This sets the internal server IP for the node when `kubectl get nodes -o wide is called`

[More info about agent flags](https://docs.k3s.io/cli/agent)

#### Full Install Method
```bash
curl -sfL https://get.k3s.io | sh -s - agent --server https://$SERVER_IP:6443 --token=$TOKEN --node-ip=192.168.56.111
```

:::info
> If token is automatically generated it is possible to ssh / scp to copy the file in 
> `/var/lib/rancher/k3s/server/node-token` of the servers host machine to acquire the token
:::

# Week 4 
## Setting up vagrant and ingress
The part vagrant setup is similar to part 1, Create a vagrantfile with the contents
```ruby
# -*- mode: ruby -*-
# vi: set ft=ruby :

# https://docs.vagrantup.com.
BOX_IMAGE = "generic/debian11"
PATH_TO_PUBLIC_KEY="~/.ssh/id_rsa.pub"
PATH_TO_SERVER_SCRIPT="./server_setup.sh"
PATH_TO_AGENT_SCRIPT="./agent_setup.sh"

require 'yaml'

current_dir    = File.dirname(File.expand_path(__FILE__))
configs        = YAML.load_file("#{current_dir}/config.yaml")
vagrant_config = configs['configs'][configs['configs']['use']]

Vagrant.configure("2") do |config|

	#Server config
  config.vm.define "Server" do |s|
    s.vm.box = BOX_IMAGE
    s.vm.network "private_network", ip: vagrant_config['server_ip']
    s.vm.hostname = "nfernandS"
		
		# Provider settings
    s.vm.provider "virtualbox" do |vb|
      vb.memory = "1024"
      vb.cpus = 1
    end

	#Copies the publickey in id_rsa.pub into machine
	s.vm.provision "file", source: PATH_TO_PUBLIC_KEY , destination: "~/.ssh/me.pub"
    
    # Copies k3s config files into machine
    s.vm.provision "file", source: ./configmap.yaml , destination: "~/.configmap.yaml
    s.vm.provision "file", source: ./deployment.yaml , destination: "~/.deployment.yaml
    s.vm.provision "file", source: ./ingress.yaml , destination: "~/.ingress.yaml
    s.vm.provision "file", source: ./services.yaml , destination: "~/.services.yaml
	
	#Server start script
	s.vm.provision "shell", path: PATH_TO_SERVER_SCRIPT,
		env: {"SERVER_IP" => vagrant_config['server_ip'], "TOKEN" => vagrant_config['token']}, run: 'always'
  end

end
```

And change the server startup script to 
```bash=
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
# curl -sfL https://get.k3s.io | sh -s - --node-external-ip=$SERVER_IP --agent-token=$TOKEN

#Without external_ip (advertise-address defaults to node-ip might be able to remove)
curl -sfL https://get.k3s.io | sh -s - --write-kubeconfig-mode 644 --advertise-address=$SERVER_IP --node-ip=$SERVER_IP --agent-token=$TOKEN

# WAIT for k3s to start

sudo kubectl apply -f .
```

### configmap.yaml 
```
data.index.html - a file defined for each app. We later use these ConfigMaps to mount the file under the Nginx default server file system location /usr/share/nginx/html
```

```
metadata.name - a name we later use to select this configmap
```

### deployment.yaml
```
metadata.labels.app - a common convention used to label resources with an application name. It is not a predefined field, but it is a label key that is frequently used in practice for this purpose
```

```
spec.replicas - a number of pods that will be deployed
```

```
spec.selector.matchLabels.app - the rules that the deployment controller uses to match the pods
```

```
template.metadata.labels.app - a label used by the selector for the Deployment controller
```

```
spec.template.spec.image - just a simple nginx image with minimal changes that i pushed to my own docker account, think we can still use a normal nginx image. UPDATE: normal image used
```

```
spec.template.spec.volumes - we use the configmap here and define a name for it
```

```
spec.template.spec.containers.volumeMoutns - we mount the volume that we derrived from the configmap onto the default server file location
```

### ingress.yaml

```
spec.ingressClassName - spent fucking hours wondering why my ingress never worked, turns out this is used by an ingress controller (default on k3s is Traefik) to select a rule that it should apply. Useful when running multiple ingress controllers in the same cluster
```

```
spec.rules - the rules that this ingress resource will define
```

```
spec.rules.host - string that should match the request header field 'Host'
```

```
spec.rules.http.paths.backend.service.name - the service that the request will be redirected to
```

### services.yaml
```
spec.selector.app - a rule used to select the deployment to which the service should bind
```

```
spec.ports.port - a port of the container to which the requests will be sent
```

## Load balancer implementation
The current configuration works on the app1 and app3 hosts, however for app2s replica set, there is not garentee that the traffic is distributed to each replica. If the traffic is not distributed, the purpose of having a replicaSet is not justified.

To make the changes, we will need to change `ingress.yaml` to the following

```yaml=
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: app-ingress
spec:
  ingressClassName: "traefik"
  rules:
    - host: app1.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: service-app-1
                port:
                  number: 81
    - host: app2.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: service-app-2
                port:
                  number: 81
    - host: app3.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: service-app-3
                port:
                  number: 81
```

We also need to change `services.yaml` to the following

```yaml=
apiVersion: v1
kind: Service
metadata:
  name: service-app-1
spec:
  selector:
    app: nginx-app-1
  ports:
    - protocol: TCP
      port: 81
      targetPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: service-app-2
spec:
  selector:
    app: nginx-app-2
  ports:
    - protocol: TCP
      port: 81
      targetPort: 80
  type: LoadBalancer
---
apiVersion: v1
kind: Service
metadata:
  name: service-app-3
spec:
  selector:
    app: nginx-app-3
  ports:
    - protocol: TCP
      port: 81
      targetPort: 80
```

To initiate the balancing feature, we will first and foremost change the service type for app2 to a load balancer. This spawns a LoadBalancer Service in the node level **that listens to port 80 and 443 by default**. It will try to find a free host in the cluster for port 80. If no host with that port is available, the service remains pending.

You know what else listens to port 80 on the node level? K3s built in **traefik controller**. This will create a port conflict with the load balancer service, hence some changes are needed.

We can't change the traefik controller listen port, however we are able to change the port the loadBalancer service is listening on. 

So our first change will be on the loadBalancer service to listen to port 81 instead. We can now change the traefil controller to forward whatever coming from port 80 (default) to the loadBalancer at port 81 for . 

The load balacer will then distribute the traffic to the pods in the app2 replicaSet through port 80.

For app1 and app3 however, there will be no load balancers, so it can be remain inchanged. However for the sake of readability, we will change the service lister and the traefik rule to port 81 as well.

![](https://hackmd.io/_uploads/r1lkQglk6.png)


> Since the loadBalancer service listens to the port at node level, means that it is also exposed outside the cluster. If you make any request on port 81, you will hit the load balancer and you will get served app2.
