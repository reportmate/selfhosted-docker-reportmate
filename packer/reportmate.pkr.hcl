// Packer template that bakes the ReportMate self-host stack into a VM image.
// Builds a QEMU/qcow2 image from Ubuntu cloud-init by default; add amazon-ebs
// or azure-arm builders to publish an AMI / Azure image from the same setup.sh.

packer {
  required_plugins {
    qemu = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/qemu"
    }
  }
}

variable "reportmate_tag" {
  type    = string
  default = "latest"
}

variable "iso_url" {
  type    = string
  default = "https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
}

source "qemu" "reportmate" {
  iso_url          = var.iso_url
  iso_checksum     = "none"
  disk_image       = true
  output_directory = "output-reportmate"
  disk_size        = "20G"
  format           = "qcow2"
  accelerator      = "kvm"
  ssh_username     = "ubuntu"
  ssh_password     = "ubuntu"
  ssh_timeout      = "20m"
  headless         = true
  shutdown_command = "echo 'ubuntu' | sudo -S shutdown -P now"
  vm_name          = "reportmate-appliance.qcow2"
}

build {
  sources = ["source.qemu.reportmate"]

  provisioner "file" {
    source      = "${path.root}/.."
    destination = "/tmp/reportmate"
  }

  provisioner "shell" {
    environment_vars = ["REPORTMATE_TAG=${var.reportmate_tag}"]
    script           = "${path.root}/setup.sh"
  }
}
