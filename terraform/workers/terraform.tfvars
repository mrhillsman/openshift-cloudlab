cluster_domain = "sky00.lab"
cluster_id= "os"

matchbox_client_cert = "/etc/matchbox/tls/client.crt"
matchbox_client_key = "/etc/matchbox/tls/client.key"
matchbox_http_endpoint = "http://192.168.0.1:8080"
matchbox_rpc_endpoint = "192.168.0.1:8081"
matchbox_trusted_ca_cert = "/etc/matchbox/tls/ca.crt"

pxe_initrd_url = "assets/rhcos-4.3.8-x86_64-installer-initramfs.x86_64.img"
pxe_kernel_url = "assets/rhcos-4.3.8-x86_64-installer-kernel-x86_64"
pxe_os_image_url = "http://192.168.0.1:8080/assets/rhcos-4.3.8-x86_64-metal.x86_64.raw.gz"

worker_nodes = [
  {
    name = "worker0",
    worker_public_ipv4 = "192.168.0.100",
    worker_mac_address = "08:00:27:3d:90:32",
    worker_ipmi_host = "192.168.0.1",
    worker_ipmi_user = "admin",
    worker_ipmi_pass = "password",
    worker_ipmi_port = "10100",
    worker_ign_file = "/tmp/baremetal/worker.ign"
  },
  {
    name = "worker1",
    worker_public_ipv4 = "192.168.0.101",
    worker_mac_address = "08:00:27:3d:90:33",
    worker_ipmi_host = "192.168.0.1",
    worker_ipmi_user = "admin",
    worker_ipmi_pass = "password",
    worker_ipmi_port = "10101",
    worker_ign_file = "/tmp/baremetal/worker.ign"
  },
  {
    name = "worker2",
    worker_public_ipv4 = "192.168.0.102",
    worker_mac_address = "08:00:27:3d:90:34",
    worker_ipmi_host = "192.168.0.1",
    worker_ipmi_user = "admin",
    worker_ipmi_pass = "password",
    worker_ipmi_port = "10102",
    worker_ign_file = "/tmp/baremetal/worker.ign"
  },
]

worker_count = 3
