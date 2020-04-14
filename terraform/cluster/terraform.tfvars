cluster_domain = "centos.lab"
cluster_id= "os"

matchbox_client_cert = "/etc/matchbox/tls/client.crt"
matchbox_client_key = "/etc/matchbox/tls/lclient.key"
matchbox_http_endpoint = "http://192.168.0.1:8080"
matchbox_rpc_endpoint = "192.168.0.1:8081"
matchbox_trusted_ca_cert = "/etc/matchbox/tls/ca.crt"

pxe_initrd_url = "assets/rhcos-4.3.8-x86_64-installer-initramfs.x86_64.img"
pxe_kernel_url = "assets/rhcos-4.3.8-x86_64-installer-kernel-x86_64"
pxe_os_image_url = "http://192.168.0.1:8080/assets/rhcos-4.3.8-x86_64-metal.x86_64.raw.gz"

bootstrap_public_ipv4 = "192.168.0.2"
bootstrap_mac_address = "08:00:27:3d:80:00"
bootstrap_ipmi_host = "192.168.0.1"
bootstrap_ipmi_user = "admin"
bootstrap_ipmi_pass = "password"
bootstrap_ipmi_port = "10000"
bootstrap_ign_file = "/tmp/baremetal/bootstrap.ign"

master_nodes = [
  {
    name = "master0",
    master_public_ipv4 = "192.168.0.50",
    master_mac_address = "08:00:27:3d:80:32",
    master_ipmi_host = "192.168.0.1",
    master_ipmi_user = "admin",
    master_ipmi_pass = "password",
    master_ipmi_port = "10050",
    master_ign_file = "/tmp/baremetal/master.ign"
  },
  {
    name = "master1",
    master_public_ipv4 = "192.168.0.51",
    master_mac_address = "08:00:27:3d:80:33",
    master_ipmi_host = "192.168.0.1",
    master_ipmi_user = "admin",
    master_ipmi_pass = "password",
    master_ipmi_port = "10051",
    master_ign_file = "/tmp/baremetal/master.ign"
  },
  {
    name = "master2",
    master_public_ipv4 = "192.168.0.52",
    master_mac_address = "08:00:27:3d:80:34",
    master_ipmi_host = "192.168.0.1",
    master_ipmi_user = "admin",
    master_ipmi_pass = "password",
    master_ipmi_port = "10052",
    master_ign_file = "/tmp/baremetal/master.ign"
  },
]

master_count = 3
