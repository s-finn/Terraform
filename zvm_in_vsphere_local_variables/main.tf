provider "vsphere" {
  user                 = var.vsphere_user
  password             = var.vsphere_password
  vsphere_server       = var.vsphere_server
  allow_unverified_ssl = true
}


data "vsphere_datacenter" "dc" {
  name = var.vsphere_datacenter
}

data "vsphere_datastore" "datastore" {
  name          = "enterDatastoreName"
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_network" "network" {
  name          = "enterVMnetwork"
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_resource_pool" "pool" {
  name          = "enterResourcePool"
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_virtual_machine" "template" {
  name          = "enterTemplateName"
  datacenter_id = data.vsphere_datacenter.dc.id
}



resource "vsphere_virtual_machine" "vm" {
  name             = "enterVMname"
  resource_pool_id = data.vsphere_resource_pool.pool.id
  datastore_id     = data.vsphere_datastore.datastore.id
  firmware         = "bios"
  scsi_type        = "lsilogic-sas"

  num_cpus = 2
  memory   = 4096
  guest_id = "windows9Server64Guest"

  network_interface {
    network_id = data.vsphere_network.network.id
  }

  disk {
    label            = "enterdisklabel"
    size             = "enterdisksize"
    thin_provisioned = false
  }

  clone {
    template_uuid = data.vsphere_virtual_machine.template.id

    customize {
      windows_options {
        computer_name  = "enterWindowsPCname"
        admin_password = var.zvm_windows_password
      }

      network_interface {
        ipv4_address = var.zvm_ip
        ipv4_netmask = 24
      }

      ipv4_gateway    = "enterIPgateway"
      dns_server_list = list("enterDNS1", "enterDNS2ifapplicable")
    }
  }
  provisioner "remote-exec" {
    inline = [
      "\"C:\\Program Files\\Zerto Virtual Replication VMware Installer.exe\" -s VCenterHostName=${var.vsphere_server} VCenterUserName=${var.vsphere_user} VCenterPassword=${var.vsphere_password}"
    ]
    connection {
      type     = "winrm"
      user     = "Administrator"
      password = var.zvm_windows_password
      host     = var.zvm_ip
      https    = false
      insecure = false
    }
  }
}