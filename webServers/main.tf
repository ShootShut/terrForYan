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

data "yandex_dns_zone" "web" {}

data "yandex_compute_image" "latest_ubuntu_linux" {
  family   = "ubuntu-*-lts"
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

resource "yandex_compute_instance" "default" {
  name        = "test"
  platform_id = "standard-v1"
  zone        = "ru-central1-b"

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      image_id = "image_id"
    }
  }
  
  network_interface {
    subnet_id = "${yandex_vpc_network.lab-net.id}"
  }

  metadata = {
    foo      = "bar"
    ssh-keys = "ubuntu:${file("~/sandbox/terrForYan/key.pub")}"
  }
}

/*
  resource "yandex_autoscaling_group" "web" {
    name = "WebServer-ASG"
    launch_configuration = yandex_launch_configuration.web.name
    min_size             = 2
    max_size             = 2
    min_elb_campacity    = 2
    health_check_type    = "ELB"
    vpc_zone_identifier  = [yandex_vpc_network.default_yc1.id, yandex_vpc_network.default_yc2.id]
    load_balancers       = [yandex_alb_load_balancer.web.name] 

    dynamic "tag" {
      for_each = {
        Name   = "WebServer in ASG"
        Owner  = "Vladimir Makrevich"
        TAGKEY = "TAGVALUE"
      }
      content {
        key                 = tag.key
        value               = tag.value
        propagate_at_launch = true
      }
    }
    lifecycle {
      create_before_destroy = true
    }
  }
*/
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
  

 