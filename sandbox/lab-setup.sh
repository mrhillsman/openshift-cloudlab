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

# create partition(s) on sdb splitting disk in half
sudo parted -s -a opt -- /dev/sdb mklabel gpt mkpart primary ext4 1MiB 50%
sudo parted -s -a opt -- /dev/sdb mkpart primary ext4 50% 100%
sudo mkfs.ext4 /dev/sdb1
sudo mkfs.ext4 /dev/sdb2
#TODO get the UUID of /dev/sdb1 and add it to fstab
DEV_SDB1_UUID=$(sudo blkid -o value -s UUID /dev/sdb1)
DEV_SDB2_UUID=$(sudo blkid -o value -s UUID /dev/sdb2)

# mount first sdb partition for libvirt, second for nfs
cat /etc/fstab > fstab
cat << EOF >> fstab
UUID=${DEV_SDB1_UUID}    /var/lib/libvirt/images    ext4    defaults    0    0
UUID=${DEV_SDB2_UUID}    /tmp/nfs    ext4    defaults    0    0
EOF
sudo mv fstab /etc/fstab

# set virsh alias
sudo tee -a "/etc/bashrc" > /dev/null << EOF

alias virsh='virsh -c qemu:///system'
EOF

# reboot server
sudo reboot

# extend the sda1 partition
sudo resize2fs /dev/sda1

#ensure $releasever is set
echo 8 | sudo tee /etc/yum/vars/releasever

# install required packages (centos/rhel)
sudo dnf install -y qemu-kvm qemu-img libvirt virt-install libvirt-client libvirt-devel \
vim iptables-ebtables haproxy dnsmasq dnsmasq-utils jq ipmitool expect ruby-devel bind-utils \
cockpit-ws cockpit-pcp cockpit-composer cockpit-doc cockpit-session-recording podman \
cockpit-bridge cockpit-dashboard cockpit-packagekit cockpit-podman cockpit-machines tmux \
subscription-manager-cockpit cockpit-storaged cockpit-system haproxy python3-devel vim

sudo systemctl enable libvirtd
sudo systemctl start libvirtd

### edit cockpit webservice
cat << EOF > cockpit.conf
[WebService]
AllowUnencrypted = true
EOF
sudo mv cockpit.conf /etc/cockpit/cockpit.conf
sudo systemctl enable cockpit.service
sudo systemctl restart cockpit.service

# setup virsh bash completion
wget https://raw.githubusercontent.com/Bash-it/bash-it/master/completion/available/virsh.completion.bash
sudo mv virsh.completion.bash /etc/bash_completion.d/virsh

# install virtualbmc
sudo pip3 install virtualbmc

# add openlab user to libvirt group
sudo usermod -aG libvirt openlab

# add users for coredns and matchbox
sudo useradd -m -r -d /var/lib/coredns coredns
sudo useradd -m -r -d /var/lib/matchbox matchbox

# install upstream golang
#TODO check for version programmatically
wget https://dl.google.com/go/go1.14.4.linux-amd64.tar.gz
sudo tar -C /usr/local -xzf go1.14.4.linux-amd64.tar.gz
mkdir ~/go

cat << EOF >> ~/.bashrc
export GOPATH=$HOME/go
export PATH=$PATH:/usr/local/go/bin
EOF

# setup coredns
wget https://github.com/coredns/coredns/releases/download/v1.6.9/coredns_1.6.9_linux_amd64.tgz
tar xzf coredns_1.6.9_linux_amd64.tgz
sudo mv coredns /usr/local/bin

# setup matchbox
wget https://github.com/poseidon/matchbox/releases/download/v0.8.3/matchbox-v0.8.3-linux-amd64.tar.gz
tar xzf matchbox-v0.8.3-linux-amd64.tar.gz
sudo mv matchbox-v0.8.3-linux-amd64/matchbox /usr/local/bin

# setup matchbox terraform plugin
mkdir -p ~/.terraform.d/plugins
VERSION=v0.3.0
wget https://github.com/poseidon/terraform-provider-matchbox/releases/download/$VERSION/terraform-provider-matchbox-$VERSION-linux-amd64.tar.gz
tar xzf terraform-provider-matchbox-$VERSION-linux-amd64.tar.gz
cp terraform-provider-matchbox-$VERSION-linux-amd64/terraform-provider-matchbox ~/.terraform.d/plugins/terraform-provider-matchbox

# setup terraform
wget https://releases.hashicorp.com/terraform/0.12.26/terraform_0.12.26_linux_amd64.zip
unzip terraform_0.12.26_linux_amd64.zip
sudo mv terraform /usr/local/bin

# install upstream vagrant and vagrant-libvirt (centos/rhel)
#TODO check for version programmatically
wget https://releases.hashicorp.com/vagrant/2.2.9/vagrant_2.2.9_x86_64.rpm
sudo rpm -i vagrant_2.2.9_x86_64.rpm
vagrant plugin install vagrant-libvirt

sudo mkdir /etc/coredns
sudo chown coredns: /etc/coredns
sudo mkdir /etc/matchbox
sudo -u matchbox mkdir /var/lib/matchbox/assets
sudo mv matchbox-v0.8.3-linux-amd64/scripts/tls /etc/matchbox/
sudo chown -R matchbox: /etc/matchbox

git clone https://github.com/mrhillsman/baremetal-upi-sandbox
git clone https://github.com/mrhillsman/upi-rt
git clone https://github.com/mrhillsman/openshift-lab
mkdir install-dir

wget https://mirror.openshift.com/pub/openshift-v4/clients/oc/latest/linux/oc.tar.gz
sudo tar -C /usr/local/bin -xzf oc.tar.gz

# setup nfs (centos/rhel)
sudo dnf install -y nfs-utils
sudo systemctl enable --now nfs-server
sudo mkdir -p /tmp/nfs
echo '/tmp/nfs 192.168.0.0/24(rw,sync,no_subtree_check,no_root_squash)' | sudo tee -a /etc/exports
sudo exportfs -ra
sudo systemctl restart nfs-server

# get the latest rhcos files
sudo -u matchbox mkdir -p /var/lib/matchbox/assets
for f in `curl -sk https://mirror.openshift.com/pub/openshift-v4/dependencies/rhcos/latest/latest/sha256sum.txt|awk '/installer|metal|qemu/ {print $2}'`; do sudo -u matchbox wget https://mirror.openshift.com/pub/openshift-v4/dependencies/rhcos/latest/latest/$f -O /var/lib/matchbox/assets/$f; done;

cat << EOF >> pxe_network.xml
<network>
  <name>pxe_network</name>
  <forward mode='nat'>
    <nat>
      <port start='1024' end='65535'/>
    </nat>
  </forward>
  <bridge name='virbr1' stp='on' delay='0'/>
  <dns enable='no'/>
  <ip address='192.168.0.1' netmask='255.255.255.0'>
  </ip>
</network>
EOF

virsh net-define pxe_network.xml  
virsh net-autostart pxe_network  
virsh net-start pxe_network  

#### create the default storage pool
virsh pool-define-as default dir - - - - "/var/lib/libvirt/images"  
virsh pool-build default  
virsh pool-start default  
virsh pool-autostart default  

sudo mv /etc/haproxy/haproxy.cfg{,.bkup}
sudo cp openshift-lab/sandbox/haproxy.cfg /etc/haproxy/

sudo cp /etc/dnsmasq.conf{,.bkup}
sudo mkdir -p /var/lib/tftpboot

sudo tee "/etc/dnsmasq.conf" > /dev/null << EOF
port=0
dhcp-range=192.168.0.2,192.168.0.253
dhcp-option=3,192.168.0.2
dhcp-option=6,192.168.0.2
dhcp-match=set:bios,option:client-arch,0
dhcp-boot=tag:bios,undionly.kpxe
dhcp-match=set:efi32,option:client-arch,6
dhcp-boot=tag:efi32,ipxe.efi
dhcp-match=set:efibc,option:client-arch,7
dhcp-boot=tag:efibc,ipxe.efi
dhcp-match=set:efi64,option:client-arch,9
dhcp-boot=tag:efi64,ipxe.efi
log-queries
log-dhcp
dhcp-userclass=set:ipxe,iPXE
dhcp-boot=tag:ipxe,http://192.168.0.1:8080/boot.ipxe
enable-tftp
tftp-root=/var/lib/tftpboot
tftp-no-blocksize
dhcp-boot=pxelinux.0
dhcp-host=08:00:27:3d:80:00,192.168.0.2,bootstrap
dhcp-host=08:00:27:3d:80:32,192.168.0.50,master1
dhcp-host=08:00:27:3d:80:33,192.168.0.51,master2
dhcp-host=08:00:27:3d:80:34,192.168.0.52,master3
dhcp-host=08:00:27:3d:90:32,192.168.0.100,worker1
dhcp-host=08:00:27:3d:90:33,192.168.0.101,worker2
dhcp-host=08:00:27:3d:90:34,192.168.0.102,worker3
bind-interfaces
listen-address=192.168.0.1
EOF

# setup matchbox systemd
sudo tee /etc/systemd/system/matchbox.service > /dev/null << EOF
[Unit]
Description=CoreOS matchbox Server
Documentation=https://github.com/coreos/matchbox

[Service]
User=matchbox
Group=matchbox
ExecStart=/usr/local/bin/matchbox

ProtectHome=yes
ProtectSystem=full

[Install]
WantedBy=multi-user.target
EOF

# setup coredns systemd
sudo mkdir /etc/systemd/system/matchbox.service.d
sudo tee /etc/systemd/system/matchbox.service.d/override.conf > /dev/null << EOF
[Service]
User=matchbox
Group=matchbox
Environment="MATCHBOX_ADDRESS=192.168.0.1:8080"
Environment="MATCHBOX_RPC_ADDRESS=192.168.0.1:8081"
Environment="MATCHBOX_CA_FILE=/etc/matchbox/tls/ca.crt"
Environment="MATCHBOX_CERT_FILE=/etc/matchbox/tls/server.crt"
Environment="MATCHBOX_KEY_FILE=/etc/matchbox/tls/server.key"
Environment="MATCHBOX_WEB_SSL=false"
Environment="MATCHBOX_WEB_CERT_FILE=/etc/matchbox/tls/server.crt"
Environment="MATCHBOX_WEB_KEY_FILE=/etc/matchbox/tls/server.key"
Environment="MATCHBOX_LOG_LEVEL=debug"
EOF

sudo tee /etc/systemd/system/coredns.service > /dev/null << EOF
[Unit]
Description=CoreDNS DNS server
Documentation=https://coredns.io
After=network.target

[Service]
PermissionsStartOnly=true
LimitNOFILE=1048576
LimitNPROC=512
CapabilityBoundingSet=CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_BIND_SERVICE
NoNewPrivileges=true
User=coredns
WorkingDirectory=~
ExecStart=/usr/local/bin/coredns -conf=/etc/coredns/Corefile
ExecReload=/bin/kill -SIGUSR1 $MAINPID
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

# reload systemd units
sudo systemctl daemon-reload

# create SSL certs for matchbox
sudo mkdir -p /etc/matchbox/tls
sudo cp -R ${HOME}/matchbox-v0.8.3-linux-amd64/scripts/tls /etc/matchbox
sudo chown -R matchbox: /etc/matchbox
cd /etc/matchbox/tls  
sudo -u matchbox SAN=DNS.1:matchbox.cloud.lab,IP.1:130.127.133.42,IP.2:192.168.0.1,IP.3:192.168.122.1 ./cert-gen

# setup lab DNS file
sudo mkdir /etc/coredns
sudo chown coredns: /etc/coredns
sudo -u coredns tee /etc/coredns/db.sky00.lab > /dev/null << EOF
\$ORIGIN sky00.lab.
\$TTL 10800      ; 3 hours
@       3600 IN SOA sns.dns.icann.org. noc.dns.icann.org. (
                                2019010110 ; serial
                                7200       ; refresh (2 hours)
                                3600       ; retry (1 hour)
                                1209600    ; expire (2 weeks)
                                3600       ; minimum (1 hour)
                                )

_etcd-server-ssl._tcp.os.sky00.lab. 8640 IN    SRV 0 10 2380 etcd-0.os.sky00.lab.
_etcd-server-ssl._tcp.os.sky00.lab. 8640 IN    SRV 0 10 2380 etcd-1.os.sky00.lab.
_etcd-server-ssl._tcp.os.sky00.lab. 8640 IN    SRV 0 10 2380 etcd-2.os.sky00.lab.

sky00.lab.		       A 192.168.0.1
api.os.sky00.lab.              A 192.168.0.1
api-int.os.sky00.lab.          A 192.168.0.1
os-bootstrap.sky00.lab.        A 192.168.0.2

os-master0.sky00.lab.    A 192.168.0.50
etcd-0.os.sky00.lab.      IN  CNAME os-master0.sky00.lab.
os-master1.sky00.lab.    A 192.168.0.51
etcd-1.os.sky00.lab.      IN  CNAME os-master1.sky00.lab.
os-master2.sky00.lab.    A 192.168.0.52
etcd-2.os.sky00.lab.      IN  CNAME os-master2.sky00.lab.
os-worker0.sky00.lab.    A 192.168.0.100
os-worker1.sky00.lab.    A 192.168.0.101
os-worker2.sky00.lab.    A 192.168.0.102

\$ORIGIN apps.os.sky00.lab.
*    A    192.168.0.1
EOF

# setup CoreDNS Corefile
sudo -u coredns tee /etc/coredns/Corefile > /dev/null << EOF
.:53 {
    bind 127.0.0.1
    bind 192.168.0.1
    log
    errors
    forward . 130.127.132.51
}

sky00.lab:53 {
    bind 127.0.0.1
    bind 192.168.0.1
    log
    errors
    file /etc/coredns/db.sky00.lab
    debug
}
EOF

# copy Vagrantfile to install directory
cp ~/openshift-lab/sandbox/Vagrantfile ~/install-dir/Vagrantfile

Login to https://api.ci.openshift.org/
Click on username in top-right and then click on "Copy Login Command"
Run login command in the terminal (copy/paste or if you have the token use the following:)
  oc login https://api.ci.openshift.org --token=<token>
oc registry login --to=api.json
Get your pull secret from https://cloud.redhat.com/openshift/install/metal/user-provisioned and copy it to pull.json
jq -c -s '.[0] * .[1]' api.json pull.json > registries.json
Pick a green release from https://openshift-release.svc.ci.openshift.org/
oc adm release extract -a ./registries.json --tools registry.svc.ci.openshift.org/ocp/release:4.4.0-0.ci-2020-06-04-112804

# extract and setup oc and openshift-install binaries
sudo tar --overwrite -C /usr/local/bin -xzf openshift-client-linux-4.4* oc
sudo tar --overwrite -C /usr/local/bin -xzf openshift-install-linux-4.4* openshift-install

# copy terraform files to install directory
cp -R ~/openshift-lab/terraform ~/install-dir/terraform

# verify the RHCOS versions
sudo ls /var/lib/matchbox/assets
grep -iRl rhcos ~/install-dir/terraform/*
# if the versions do not match update/change the terraform.tfvars files

# create ssh key if it does not exist
ssh-keygen -t rsa -N ''

# copy install-config.yaml to install directory
cp ~/openshift-lab/sandbox/install-config.yaml ~/install-dir/install-config.yaml
# copy the ssh key and registries.json to the install-config.yaml
# create copy of install-config.yaml
cp install-dir/install-config.yaml install-config.yaml.bkup

# make directory for openshift-install files
mkdir /tmp/baremetal

# create openshift install manifest
openshift-install create manifests --log-level debug --dir /tmp/baremetal

# set master nodes to unschedulable
# vim manifests/cluster-scheduler-02-config.yml
apiVersion: config.openshift.io/v1
kind: Scheduler
metadata:
  creationTimestamp: null
  name: cluster
spec:
  mastersSchedulable: false # change from true to false
  policy:
    name: ""
status: {}

# create ignition configs
openshift-install create ignition-configs --log-level debug --dir /tmp/baremetal


# Notes
comment out the default resolv.conf settings and add nameserver 127.0.0.1






























Automatic image pruning is not enabled. Regular pruning of images no longer referenced by ImageStreams is strongly recommended to ensure your cluster remains healthy. To remove this warning, install the image pruner by creating an imagepruner.imageregistry.operator.openshift.io resource with the name `cluster`. Ensure that the `suspend` field is set to `false`.
