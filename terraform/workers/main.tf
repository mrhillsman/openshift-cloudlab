# ================MATCHBOX=====================

locals {
  kernel_args = [
    "console=tty0",
    "console=ttyS0,115200n8",
    "console=ttyS1,115200n8",
    "rd.neednet=1",

    # "rd.break=initqueue"
    "coreos.inst=yes",

    "coreos.inst.image_url=${var.pxe_os_image_url}",
    "coreos.inst.install_dev=vda",
  ]

  pxe_kernel = var.pxe_kernel_url
  pxe_initrd = var.pxe_initrd_url

  #worker_public_ipv4 = var.worker_public_ipv4
}

provider "matchbox" {
  endpoint    = var.matchbox_rpc_endpoint
  client_cert = file(var.matchbox_client_cert)
  client_key  = file(var.matchbox_client_key)
  ca          = file(var.matchbox_trusted_ca_cert)
}

resource "matchbox_profile" "default" {
  name = var.cluster_id
}

resource "matchbox_group" "default" {
  name    = var.cluster_id
  profile = matchbox_profile.default.name
}

resource "matchbox_profile" "worker" {
  count = var.worker_count
  name   = "${var.cluster_id}-${var.worker_nodes[count.index]["name"]}"
  kernel = local.pxe_kernel

  initrd = [
    local.pxe_initrd,
  ]

  args = flatten([
    local.kernel_args,
    "coreos.inst.ignition_url=${var.matchbox_http_endpoint}/ignition?mac=${var.worker_nodes[count.index]["worker_mac_address"]}",
  ])

  raw_ignition = file(var.worker_nodes[count.index]["worker_ign_file"])
}


resource "matchbox_group" "worker" {
  count = var.worker_count
  name   = var.worker_nodes[count.index]["name"]
  profile = "${var.cluster_id}-${var.worker_nodes[count.index]["name"]}"

  selector = {
    mac = var.worker_nodes[count.index]["worker_mac_address"]
  }
}
