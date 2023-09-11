#setup script
# root check
if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi


#download dependencies for vbox
apt-get update -y && apt-get upgrade -y
apt install linux-headers-amd64 linux-headers-5.10.0-25-amd64 gcc perl make -y

#download virtualbox
wget https://download.virtualbox.org/virtualbox/7.0.10/virtualbox-7.0_7.0.10-158379~Debian~bullseye_amd64.deb

# manual installation of virtualbox
# might need to add ldconfig or start-stop daemon to path
# export PATH="$PATH:/sbin"
apt-get update
dpkg -i  virtualbox-7.0_7.0.10-158379~Debian~bullseye_amd64.deb
apt --fix-broken install -y
apt-get upgrade

#fix symbolic link issue
touch /sbin/vboxconfig
ln -s /usr/lib/virtualbox/postint-common.sh /sbin/vboxconfig

#run to fix vbox config issue
/sbin/vboxconfig

#download and install vagrant
wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg

#add link to sources apt sources lit
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list

# install dependencies for vagrant
apt install qemu qemu-kvm libvirt-clients libvirt-daemon-system virtinst bridge-utils -y
chmod 666 /dev/kvm

#install vagrant from hashicorp repository
apt install vagrant -y

# create a ssh key used by vagrant
ssh-keygen

# load kvm module needed by vagratn
modprobe kvm