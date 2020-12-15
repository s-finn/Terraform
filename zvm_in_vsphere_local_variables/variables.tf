variable "vsphere_user" {
    type = string
    description = "vSphere Administrator service account for Zerto"
    default = "entervCaccount"
}

variable "vsphere_password" {
    type = string
    description = "vSphere Administrator service account pass for Zerto"
    default = "entervCpassword"
}

variable "vsphere_server" {
    type = string
    description = "vCenter IP address"
    default = "entervCip"
}

variable "vsphere_datacenter" {
    type = string
    description = "vCenter Datacenter Name"
    default = "entervCdatacenter"
}

variable "zvm_windows_password" {
    description = "Password for ZVM"
    type       = string
    default    = "enterZVMospassword"
}

variable "zvm_ip" {
    description = "ZVM IP Address"
    type = string
    default = "enterZVMip"
}