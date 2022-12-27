terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
  required_version = ">= 0.13"
}

provider "yandex" {
  zone = "ru-central1-b"
}

resource "yandex_compute_instance" "master" {
  name = "master"

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      image_id = "fd8g5c4veh7l0m27sv1k"
    }
  }

  network_interface {
    subnet_id = "e2lrd6h5la4p4md3f42m"
    nat       = true
  }

  metadata = {
    ssh-keys  = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
    user-data = "ubuntu:${file("~/sandbox/terrForYan/testKuber/user_data.sh")}"
  }
}

resource "yandex_compute_instance" "worker" {
  count = 2
  //name  = "worker"

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      image_id = "fd8g5c4veh7l0m27sv1k"
    }
  }

  network_interface {
    subnet_id = "e2lrd6h5la4p4md3f42m"
    nat       = true
  }

  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
  }
}


output "internal_ip_address_vm_1" {
  value = yandex_compute_instance.master.network_interface.0.ip_address
}
/*
output "internal_ip_address_vm_2" {
  value = yandex_compute_instance.vm-2[count.index].network_interface.0.ip_address
}
*/

output "external_ip_address_vm_1" {
  value = yandex_compute_instance.master.network_interface.0.nat_ip_address
}
/*
output "external_ip_address_vm_2" {
  value = yandex_compute_instance.vm-2.network_interface.0.nat_ip_address
}
*/