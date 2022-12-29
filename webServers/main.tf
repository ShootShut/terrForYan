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

data "yandex_dns_zone" "web" {
  dns_zone_id = "zone1"
}

data "yandex_compute_image" "ubuntu" {
  family   = "ubuntu-2004-lts"
  /*image_id = ["fd8ingbofbh3j5h7i8ll"]*/
}

resource "yandex_vpc_network" "lab-net" {
  name = "lab-network"
}

resource "yandex_vpc_default_security_group" "web" {
  network_id      = "${yandex_vpc_network.lab-net.id}"
  
  dynamic "ingress" {
    for_each         = ["80", "443", "8080", "22"]
    content {
      from_port      = ingress.value
      to_port        = ingress.value
      protocol       = "tcp"
      v4_cidr_blocks = ["0.0.0.0/0"]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "yandex_compute_instance_group" "web" {
  name                = "test-ig"
  folder_id           = "${data.yandex_resourcemanager_folder.test_folder.id}"
  service_account_id  = "${yandex_iam_service_account.test_account.id}"
  deletion_protection = true
  instance_template {
    platform_id = "standard-v1"
    resources {
      memory = 2
      cores  = 2
    }
    boot_disk {
      mode = "READ_WRITE"
      initialize_params {
        image_id = "${data.yandex_compute_image.ubuntu.id}"
        size     = 4
      }
    }
    network_interface {
      network_id = "${yandex_vpc_network.my-inst-group-network.id}"
      subnet_ids = ["${yandex_vpc_subnet.my-inst-group-subnet.id}"]
    }
    labels = {
      label1 = "label1-value"
      label2 = "label2-value"
    }
    metadata = {
      foo      = "bar"
      ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
    }
    network_settings {
      type = "STANDARD"
    }
  }

  variables = {
    test_key1 = "test_value1"
    test_key2 = "test_value2"
  }

  scale_policy {
    fixed_scale {
      size = 3
    }
  }

  allocation_policy {
    zones = ["ru-central1-a"]
  }

  deploy_policy {
    max_unavailable = 2
    max_creating    = 2
    max_expansion   = 2
    max_deleting    = 2
  }
}

resource "yandex_alb_load_balancer" "web" {
  network_id         = "${yandex_vpc_network.lab-net.id}"
  name               = "WebServer in ASG"
  //availability_zones = [data.yandex_dns_zone.available.names[0], data.yandex_dns_zone.names[1]]
  //security_group    = [yandex_vpc_security_group.web.id]

  allocation_policy {
  location {
    zone_id   = "ru-central1-b"
    subnet_id = yandex_vpc_network.lab-net.id 
    }
  }      

  listener {
    name = "my-listener"
    endpoint {
      address {
        external_ipv4_address {}
      }
      ports = [ 80 ]
    }    
    http {
      handler {
        //http_router_id = yandex_alb_http_router.test-router.id
      }
    }
  }
  /*
    health_check {
      healthy_threshold   = 2
      unhealthy_threshold = 2
      timeout             = 3
      target              = "HTTP:80/"
      interval            = 10
    }
  */
}

  resource "yandex_vpc_network" "default_yc1" {
    name = "network1"
  }
  resource "yandex_vpc_network" "default_yc2" {
    name = "network1"
  }

  output "zone" {
    value = data.yandex_dns_zone.web.zone
  }
  

 