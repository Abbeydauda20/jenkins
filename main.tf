provider "aws" {
  region     = "us-east-1"
  access_key = ""
  secret_key = ""
}

terraform {
  required_version = ">=1.3.0"
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "4.59.0"
    }
  }
}

# VPC
resource "aws_vpc" "prod-vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
      Name = "production"
  }
}

# create internet gateway 
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.prod-vpc.id
  tags = {
    Name : "Prod gateway"
  }
}

# create custom route table 

resource "aws_route_table" "prod-route-table" {
  vpc_id = aws_vpc.prod-vpc.id

  route {
      cidr_block = "0.0.0.0/0"
      gateway_id = aws_internet_gateway.gw.id
  }

  route {
      ipv6_cidr_block        = "::/0"
      gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "Prod"
  }
}

# Create a subnet 

resource "aws_subnet" "subnet-1" {
    vpc_id = aws_vpc.prod-vpc.id
    cidr_block = "10.0.1.0/24"
    availability_zone = "us-east-1a"
    map_public_ip_on_launch = true

    tags = {
        Name = "prod-subnet"
    }
}

# Associate subnet with Route Table 

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.subnet-1.id
  route_table_id = aws_route_table.prod-route-table.id
}

# Create Security Group to allow port 22, 8080, 443

resource "aws_security_group" "allow_web" {
  name        = "allow_web_traffic"
  description = "Allow Web traffic"
  vpc_id      = aws_vpc.prod-vpc.id

  ingress {
      description      = "HTTPS"
      from_port        = 443
      to_port          = 443
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
    }

  ingress {
      description      = "HTTP"
      from_port        = 80
      to_port          = 80
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
    }
  ingress {
      description      = "SSH"
      from_port        = 22
      to_port          = 22
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
    }

  egress {
      from_port        = 0
      to_port          = 0
      protocol         = "-1"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    }

  tags = {
    Name = "allow_web"
  }
}

# Create a network interface with an ip in the subnet that was created earlier 

resource "aws_network_interface" "web-server-nic" {
  subnet_id       = aws_subnet.subnet-1.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_web.id]

  tags = {
    Name : "prod-network-interface"
  }
}

# Assign an elastic ip to the network interface created in previous step

resource "aws_eip" "one" {
  vpc                       = true
  network_interface         = aws_network_interface.web-server-nic.id
  associate_with_private_ip = "10.0.1.50"
  #depends_on = [aws_internet_gateway.gw, aws_instance.jenkins]

  tags = {
    Name : "Prod-Elastic-ip"
  }
}

# Create Ubuntu server and install/jenkins

resource "aws_instance" "jenkins" {
    ami = "ami-0557a15b87f6559cf"
    instance_type = "t3.micro"
    availability_zone = "us-east-1a"
    key_name = "Novakeypair"

    network_interface {
        device_index = 0
        network_interface_id = aws_network_interface.web-server-nic.id
    }
     user_data = <<-EOF
              #!/bin/bashdestroy

              sudo yum update -y
              sudo yum install -y java-1.8.0-openjdk-devel
              sudo wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
              sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io.key
              sudo yum install -y jenkins
              sudo systemctl enable jenkins
              sudo systemctl start jenkins
              EOF

      tags = {
      Name : "Web-Server"
    }    
}

    

    resource "aws_instance" "apache" {
    ami = "ami-0557a15b87f6559cf"
    instance_type = "t3.micro"
    availability_zone = "us-east-1a"
    key_name = "Novakeypair"

    network_interface {
        device_index = 0
        network_interface_id = aws_network_interface.web-server-nic.id
    }
     user_data = <<-EOF
        #! /bin/bash
        sudo apt update -y 
        sudo apt install apache2
        sudo bash -c 'echo your very first web server > /var/www/html/index.html'
        EOF

    tags = {
      Name : "Web-Server"
    }    
}











