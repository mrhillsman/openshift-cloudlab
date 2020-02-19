#resource "null_resource" "ipmi_master" {
#    count = var.master_count
#    provisioner "local-exec" {
#        command = <<EOT
#          ipmitool -I lanplus -H ${var.master_nodes[count.index]["ipmi_host"]} -p ${var.master_nodes[count.index]["ipmi_port"]} -U ${var.master_nodes[count.index]["ipmi_user"]} -P ${var.master_nodes[count.index]["ipmi_pass"]} chassis bootdev pxe;
#          ipmitool -I lanplus -H ${var.master_nodes[count.index]["ipmi_host"]} -p ${var.master_nodes[count.index]["ipmi_port"]} -U ${var.master_nodes[count.index]["ipmi_user"]} -P ${var.master_nodes[count.index]["ipmi_pass"]} power reset || ipmitool -I lanplus -H ${var.master_nodes[count.index]["ipmi_host"]} -p ${var.master_nodes[count.index]["ipmi_port"]} -U ${var.master_nodes[count.index]["ipmi_user"]} -P ${var.master_nodes[count.index]["ipmi_pass"]} power on;
#EOT
#    }
#}
#
#resource "null_resource" "ipmi_master_cleanup" {
#    count = var.master_count
#    provisioner "local-exec" {
#        when = "destroy"
#        command = <<EOT
#          ipmitool -I lanplus -H ${var.master_nodes[count.index]["ipmi_host"]} -p ${var.master_nodes[count.index]["ipmi_port"]} -U ${var.master_nodes[count.index]["ipmi_user"]} -P ${var.master_nodes[count.index]["ipmi_pass"]} power off;
#EOT
#    }
#}
