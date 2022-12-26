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

data "yandex_availability_zones" "available" {}
data "yandex_ami" "latest_ubuntu_linux" {
  image_id    = ["fd8ingbofbh3j5h7i8ll"]
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu-*-lts-*"]
  }
}

resource "yandex_vpc_security_group" "web" {
  
  dynamic "ingress" {
    for_each      = ["80", "443", "8080", "22"]
    content {
      from_port   = ingress.values
      to_port     = ingress.values
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

 }

 resource "yandex_launch_configuration" "web" {
  name            = "WebServer-HA"
  image_id        = data.yandex_ami.latest_ubuntu_linux.id
  instance_type   = "t3.micro"
  security_groups = [yandex_vpc_security_group.id]
  user_data       = file("user_data.sh")

  lifecycle {
    create_before_destroy = true
  }
 }

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

  resource "yandex_alb_load_balancer" "web" {
    name               = "WebServer in ASG"
    availability_zones = [data.yandex_availability_zones.available.names[0], data.yandex_availability_zones.names[1]]
    security_groups    = [yandex_vpc_security_group.web.id]
    

    listener {
      lb_port           = 80
      lb_protocol       = "http"
      instance_port     = 80
      instance_protocol = "http"
    }
    health_check {
      healthy_threshold   = 2
      unhealthy_threshold = 2
      timeout             = 3
      target              = "HTTP:80/"
      interval            = 10
    }
  
  }

  resource "yandex_vpc_network" "default_yc1" {
    availability_zone = data.yandex_availability_zones.available.names[0]
  }
  resource "yandex_vpc_network" "default_yc2" {
    availability_zone = data.yandex_availability_zones.names[1]
  }

  output "web_loadbalancer_url" {
    value = yandex_alb_load_balancer.web.dns_name 
  }
  

 