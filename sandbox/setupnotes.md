# Setting up UPI Sandbox via CloudLab
__#TODO automation of cloudlab experiment deployment and server hostname returned for Ansible initial setup__

## Prerequisites

We are going to use an Ansible playbook for ease of use and organization. We need to install Ansible then download and run the playbook.

#### Perform as openlab user:

```
# re-partition sda to use all space
sed -e 's/\s*\([\+0-9a-zA-Z]*\).*/\1/' << EOF | sudo fdisk /dev/sda
  o # clear the in memory partition table
  n # new partition
  p # primary partition
  1 # partition number 1
    # default - start at beginning of disk
    # default - use all of the disk
  a # make a partition bootable
  w # write the partition table
  q # and we're done
EOF

# create partition on sdb
sudo parted -s -a opt -- /dev/sdb mklabel gpt mkpart primary ext4 1MiB 50%
sudo parted -s -a opt -- /dev/sdb mkpart primary ext4 50% 100%
sudo mkfs.ext4 /dev/sdb1
sudo mkfs.ext4 /dev/sdb2
#TODO get the UUID of /dev/sdb1 and add it to fstab
DEV_SDB1_UUID=$(sudo blkid -o value -s UUID /dev/sdb1)
DEV_SDB2_UUID=$(sudo blkid -o value -s UUID /dev/sdb2)
cat /etc/fstab > fstab
cat << EOF >> fstab
UUID=${DEV_SDB1_UUID}    /var/lib/libvirt/images    ext4    defaults    0    0
UUID=${DEV_SDB2_UUID}    /tmp/nfs    ext4    defaults    0    0
EOF
sudo mv fstab /etc/fstab

# add policy for libvirt allowing regular users
sudo mkdir -p /etc/polkit-1/rules.d/
cat << EOF >> 49-org.libvirt.unix.manager.rules
/* Allow users in kvm group to manage the libvirt
daemon without authentication */
polkit.addRule(function(action, subject) {
    if (action.id == "org.libvirt.unix.manage" &&
        subject.isInGroup("libvirt")) {
            return polkit.Result.YES;
    }
});
EOF
sudo mv 49-org.libvirt.unix.manager.rules /etc/polkit-1/rules.d/

# fix issue with NetworkManager and Libvirt bridging
cat << EOF >> 99-bridge.rules
ACTION=="add", SUBSYSTEM=="module", KERNEL=="br_netfilter", RUN+="/lib/systemd/systemd-sysctl --prefix=/net/bridge"
EOF
sudo mv 99-bridge.rules /etc/udev/rules.d/

#cat << EOF >> 99-bridge.conf
#net.bridge.bridge-nf-call-ip6tables = 0
#net.bridge.bridge-nf-call-iptables = 0
#net.bridge.bridge-nf-call-arptables = 0
#EOF
#sudo mv 99-bridge.conf /etc/sysctl.d/
#sudo sysctl -p /etc/sysctl.d/99-bridge.conf

echo "net.ipv4.ip_forward = 1" | sudo tee /etc/sysctl.d/99-ipforward.conf
sudo sysctl -p /etc/sysctl.d/99-ipforward.conf

# reboot the server
sudo reboot

# extend the sda1 partition
sudo resize2fs /dev/sda1

# install required packages
sudo add-apt-repository -y ppa:vbernat/haproxy-2.1
sudo add-apt-repository -y ppa:projectatomic/ppa
sudo apt update
## pip
sudo apt install -y python-dev python3-dev
sudo bash -c 'python <(curl -sk https://bootstrap.pypa.io/get-pip.py)'
## virtualization
sudo apt install -y qemu-kvm libvirt-daemon libvirt-daemon-system network-manager \
qemu libvirt-clients ebtables dnsmasq-base haproxy expect software-properties-common \
libxslt-dev libxml2-dev libvirt-dev zlib1g-dev ruby-dev jq ipmitool ipmiutil \
cockpit cockpit-docker cockpit-packagekit cockpit-machines dnsmasq uidmap

cat << EOF > cockpit.conf
[WebService]
AllowUnencrypted = true
EOF

sudo mv cockpit.conf /etc/cockpit/cockpit.conf
sudo systemctl restart cockpit.service

## virtualbmc
sudo pip install virtualbmc

# add openlab user to libvirt group
sudo usermod -aG libvirt openlab

# install upstream golang
#TODO check for version programmatically
wget https://dl.google.com/go/go1.13.7.linux-amd64.tar.gz
sudo tar -C /usr/local -xzf go1.13.7.linux-amd64.tar.gz
mkdir ~/go
# add these so they are set on login
export GOPATH=$HOME/go
export PATH=$PATH:/usr/local/go/bin

# get coredns binaries
wget https://github.com/coredns/coredns/releases/download/v1.6.7/coredns_1.6.7_linux_amd64.tgz
tar xzf coredns_1.6.7_linux_amd64.tgz
sudo mv coredns /usr/local/bin

# get matchbox binaries
wget https://github.com/poseidon/matchbox/releases/download/v0.8.3/matchbox-v0.8.3-linux-amd64.tar.gz
tar xzf matchbox-v0.8.3-linux-amd64.tar.gz
sudo mv matchbox-v0.8.3-linux-amd64/matchbox /usr/local/bin

# get terraform binaries
wget https://releases.hashicorp.com/terraform/0.12.20/terraform_0.12.20_linux_amd64.zip
unzip terraform_0.12.20_linux_amd64.zip
sudo mv terraform /usr/local/bin

wget https://raw.githubusercontent.com/Bash-it/bash-it/master/completion/available/virsh.completion.bash
sudo mv virsh.completion.bash /etc/bash_completion.d/virsh

# install upstream vagrant and vagrant-libvirt
#TODO check for version programmatically
sudo wget -v https://releases.hashicorp.com/vagrant/2.2.7/vagrant_2.2.7_x86_64.deb
sudo dpkg -i vagrant_2.2.7_x86_64.deb
sudo vagrant plugin install vagrant-libvirt

# get openshift binaries (this should be relevant to the version of openshift you want to install)
#TODO check for version programmatically
wget https://mirror.openshift.com/pub/openshift-v4/clients/ocp-dev-preview/latest/openshift-install-linux-4.4.0-0.nightly-2019-12-20-210709.tar.gz
wget https://mirror.openshift.com/pub/openshift-v4/clients/ocp-dev-preview/latest/openshift-client-linux-4.4.0-0.nightly-2019-12-20-210709.tar.gz

tar xzf openshift-client-*
tar xzf openshift-install-*
sudo mv kubectl oc openshift-install /usr/local/bin
```

### Extra Notes
#### setup the pxe_network
```
cat << EOF >> pxe_network.xml
<network>
  <name>pxe_network</name>
  <forward mode='nat' />
  <ip address='192.168.0.1' netmask='255.255.255.0' />
</network>
EOF
virsh net-define pxe_network.xml
virsh net-autostart pxe_network
virsh net-start pxe_network
```

#### create Vagrantfile
```
# matchbox domain
# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  config.vm.define :matchbox do |matchbox|

    matchbox.vm.box = "fedora/31-cloud-base"
    matchbox.vm.hostname = "matchbox"
    matchbox.vm.network "private_network", :ip => "192.168.0.254", :libvirt__network_name => "pxe_network"

    matchbox.vm.provider :libvirt do |vb|
      vb.management_network_name = "default"
      vb.management_network_address = "192.168.122.0/24"
      vb.memory = "2048"
      vb.cpus = "2"
    end

    matchbox.vm.provision "shell", path: "config/setup.sh"
  end
end

# working Vagrantfile for PXE
# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  config.vm.define :bootstrap do |bootstrap|

    bootstrap.vm.provider :libvirt do |lv|
      lv.mgmt_attach = false
      lv.memory = "2048"
      lv.cpus = "2"
      lv.storage :file, :device => 'vda', :size => '40G', :type => 'qcow2'
    end

    bootstrap.vm.hostname = "bootstrap"
    bootstrap.vm.network :private_network,
      :ip => "192.168.0.2",
      :mac => "08:00:27:3d:80:e2",
      :libvirt__netmask => "255.255.255.0",
      :libvirt__network_name => "pxe_network"
  end
end
```

#### get github repos
git clone https://github.com/mrhillsman/baremetal-upi-sandbox  
git clone https://github.com/mrhillsman/upi-rt  

#### change CLUSTER_DOMAIN, CLUSTER_NAME, PULL_SECRET, and SSH_KEY

### NOTES
we need to be able to get the first IP of the pxe_network to set it in resolv.conf for matchbox node
for libvirt, no box pxe is ideal, quicker, less disk usage however network config does not work...so how does it pxe?


#### haproxy on the host /etc/haproxy/haproxy.cfg
```
global
        debug

defaults
        log global
        mode    http
        timeout connect 5000
        timeout client 5000
        timeout server 5000

frontend apps
    bind 128.105.144.132:80
    bind 128.105.144.132:443
    option tcplog
    mode tcp
    default_backend apps

backend apps
    mode tcp
    balance roundrobin
    option ssl-hello-chk
    server master0 192.168.0.100 check

frontend api
    bind 128.105.144.132:6443
    option tcplog
    mode tcp
    default_backend api

backend api
    mode tcp
    balance roundrobin
    option ssl-hello-chk
    server master0 192.168.0.50:6443 check
    
    
#### should we create an NFS server for image registry
```

```
cat /etc/containers/registries.conf
# This is a system-wide configuration file used to
# keep track of registries for various container backends.
# It adheres to TOML format and does not support recursive
# lists of registries.

# The default location for this configuration file is /etc/containers/registries.conf.

# The only valid categories are: 'registries.search', 'registries.insecure',
# and 'registries.block'.

[registries.search]
registries = ['docker.io', 'registry.fedoraproject.org', 'quay.io', 'registry.access.redhat.com', 'registry.centos.org']

# If you need to access insecure registries, add the registry's fully-qualified name.
# An insecure registry is one that does not have a valid SSL certificate or only does HTTP.
[registries.insecure]
registries = []


# If you need to block pull access from a registry, uncomment the section below
# and add the registries fully-qualified name.
#
[registries.block]
registries = []
```

#### create the default storage pool

virsh pool-define-as guest_images dir - - - - "/guest_images"
virsh pool-build guest_images
virsh pool-start guest_images
virsh pool-autostart guest_images

### ...
