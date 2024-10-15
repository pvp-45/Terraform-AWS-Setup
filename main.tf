# Project - Create an EC2 instance, deploy it on a custom VPC and a custom sub-net and assign it a public ip address
# This will help to SSH into the EC2 instance, connect to it and make changes on it, also can automatically set 
# a web server to run on it in order to handle web traffic. 

provider "aws" {
    region = "us-east-1"
    access_key = var.AWS_ACCESS_KEY_ID  
    secret_key = var.AWS_SECRET_ACCESS_KEY
}

# 1. Create VPC

resource "aws_vpc" "prod-vpc" {
    cidr_block = "10.0.0.0/16"
    tags = {
        Name = "production"
    }
}

# 2. Create Internet Gateway

resource "aws_internet_gateway" "gw" {
    vpc_id = aws_vpc.prod-vpc.id

}

# 3. Create a Custom Route Table 
resource "aws_route_table" "prod-route-table" {
  vpc_id = aws_vpc.prod-vpc.id

  route {
    cidr_block = "0.0.0.0/0"  #default route -> all traffic is going to get sent to the internet gateway
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

# 4. Create a Subnet
resource "aws_subnet""subnet-1" {
    vpc_id = aws_vpc.prod-vpc.id
    cidr_block = "10.0.1.0/24"
    availability_zone = "us-east-1a"

    tags = {
        Name = "prod-subnet"
    }
}  

# 5. Associate subnet with Route Table
resource "aws_route_table_association" "a" {
    subnet_id = aws_subnet.subnet-1.id
    route_table_id = aws_route_table.prod-route-table.id

}

# 6. Create Security Group to allow 22, 80 and 443 (web traffic)
resource "aws_security_group" "allow_web" {
  name        = "allow_web_traffic"
  description = "Allow web inbound traffic and all outbound traffic"
  vpc_id      = aws_vpc.prod-vpc.id

ingress {
  description = "HTTPS"
  from_port         = 443
  protocol       = "tcp"
  to_port           = 443
  cidr_blocks = ["0.0.0.0/0"]
}

ingress {
  description = "HTTP"
  from_port         = 80
  protocol       = "tcp"
  to_port           = 80
  cidr_blocks = ["0.0.0.0/0"]
}

ingress {
  description = "SSH"
  from_port         = 22
  protocol       = "tcp"
  to_port           = 22
  cidr_blocks = ["0.0.0.0/0"]
}
# The egress rule allows all outbound traffic (all protocols and ports) to any destination.
egress { 
  from_port = 0
  to_port = 0
  protocol = "-1"
  cidr_blocks = ["0.0.0.0/0"]

}

tags = {
    Name = "allow web"
}

}



# 7. Create a network interface with an ip in the subnet that was created in step 4

resource "aws_network_interface" "web-server-nic" {
  subnet_id       = aws_subnet.subnet-1.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_web.id]

}

# 8. Assign an elastic IP to the network interface created in step 7
resource "aws_eip" "one" {
  vpc                       = true
  network_interface         = aws_network_interface.web-server-nic.id
  associate_with_private_ip = "10.0.1.50"
  depends_on = [aws_internet_gateway.gw]
}
# AWS EIP relies on the deployment of the internet gateway


# 9. Create Ubuntu server and install/enable apache2
resource "aws_instance" "web-server-instance" {
  ami = "ami-0866a3c8686eaeeba"
  instance_type = "t2.micro"
  availability_zone = "us-east-1a"
  key_name = "main-key" # to connect to EC2 instances you'll need key
  network_interface  {
    device_index = 0
    network_interface_id = aws_network_interface.web-server-nic.id
  }

# Now will tell terraform that on deployment of the server, run a few commands so that we can automaticaly install apache

  user_data = <<-EOF
              #!/bin/bash
              sudo apt update -y
              sudo apt install apache2 -y
              sudo systemct1 start apache2
              sudo bash -c 'echo your very first web server > /var/www/html/index.html'
              EOF
  
  tags = {
    Name = "web-server"
  }

}
