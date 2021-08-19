provider "aws" {
  region = "us-east-1"
  access_key = "Myaccesskey"
  secret_key = "Mysecretkey"
}

# 1- create vpc
resource "aws_vpc" "test-vpc" {
  cidr_block       = "10.0.0.0/16"


  tags = {
    Name = "test"
  }
}

# 2- create internet Gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.test-vpc.id

  tags = {
    Name = "gwt_test"
  }
}

# 3- create custom route table
resource "aws_route_table" "test-route-table" {
  vpc_id = aws_vpc.test-vpc.id


  route {
      cidr_block = "0.0.0.0/0"
      gateway_id = aws_internet_gateway.gw.id
  }

  route {
      ipv6_cidr_block    = "::/0"
      gateway_id         = aws_internet_gateway.gw.id
  }


  tags = {
    Name = "route_test"
  }
}

# 4- create a subnet
resource "aws_subnet" "test-subnet" {
  vpc_id     = aws_vpc.test-vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "test_sub"
  }
}

# 5- Associate subnet with route table
resource "aws_route_table_association" "test" {
  subnet_id      = aws_subnet.test-subnet.id
  route_table_id = aws_route_table.test-route-table.id
}

# 6- create security group to allow port 22, 80, 443
resource "aws_security_group" "allow_web" {
  name        = "allow_web_traffic"
  description = "Allow web inbound traffic"
  vpc_id      = aws_vpc.test-vpc.id

  ingress {
      description      = "https"
      from_port        = 443
      to_port          = 443
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
      description      = "http"
      from_port        = 80
      to_port          = 80
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
      description      = "sshd"
      from_port        = 22
      to_port          = 22
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
  }
  egress  {
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

# 7- create a network interface with an ip in the sbnet that was created in step 4
resource "aws_network_interface" "test" {
  subnet_id       = aws_subnet.test-subnet.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_web.id]
}

# 8- assign an elastic ip to the network interface created in step 7
resource "aws_eip" "one" {
  vpc                       = true
  network_interface         = aws_network_interface.test.id
  associate_with_private_ip = "10.0.1.50"
  depends_on                = [aws_internet_gateway.gw]

}
# 9- create ubuntu server and install/enable apache2

resource "aws_instance" "terraform-server" {
    ami         = "ami-0b70285e5215b80eb"
    instance_type = "t2.micro"
    availability_zone = "us-east-1a"
    key_name = "terraform"
    network_interface {
         device_index = 0
         network_interface_id = aws_network_interface.test.id
    }
    tags = {
        Name = "ubuntu_server"

    }
    user_data = <<-EOF
    #!/bin/bash
    echo "*** Installing apache2"
    sudo apt update -y
    sudo apt install apache2 -y
    sudo systemctl start apache2
    echo "*** Completed Installing apache2"
    EOF
}
                                                 
