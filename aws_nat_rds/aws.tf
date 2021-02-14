provider "aws" {
  region = "eu-central-1"
  profile = "gentoo"
}

resource "aws_vpc" "vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support = true
  tags = {
    "Name" = "zlogene_vpc"
  }
}

data "aws_availability_zones" "available" {}

resource "aws_subnet" "instance" {
  availability_zone = data.aws_availability_zones.available.names[0]
  cidr_block = "10.0.1.0/24"
  vpc_id = aws_vpc.vpc.id
  tags = {
    "Name" = "zlogene_subnet"
  }
}

resource "aws_subnet" "instance2" {
  availability_zone = data.aws_availability_zones.available.names[1]
  cidr_block = "10.0.3.0/24"
  vpc_id = aws_vpc.vpc.id
  tags = {
    "Name" = "zlogene_subnet2"
  }
}
resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "ssh" {
  key_name = "zlogene_machine"
  public_key = tls_private_key.ssh.public_key_openssh
}

output "ssh_private_key_pem" {
  value = tls_private_key.ssh.private_key_pem
}

output "ssh_public_key_pem" {
  value = tls_private_key.ssh.public_key_pem
}

resource "aws_security_group" "securitygroup" {
  name = "zlogene_sg"
  description = "zlogene owns this"
  vpc_id = aws_vpc.vpc.id
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port = 22
    to_port = 22
    protocol = "tcp"
  }
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port = 80
    to_port = 80
    protocol = "tcp"
  }
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port = -1
    to_port = -1
    protocol = "icmp"
  }
  ingress {
     cidr_blocks = ["0.0.0.0/0"]
     from_port = 2049
     to_port = 2049
     protocol = "tcp"
  }
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port = 3306
    to_port = 3306
    protocol = "tcp"
  }
  egress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port = 0
    to_port = 0
    protocol = "-1"
  }
  tags = {
    "Name" = "zlogene-sg"
  }
}

resource "aws_instance" "ec2instance" {
  instance_type = "t2.micro"
  ami = "ami-03d8059563982d7b0" # https://cloud-images.ubuntu.com/locator/ec2/ (Ubuntu)
  subnet_id = aws_subnet.instance.id
  security_groups = [aws_security_group.securitygroup.id]
  key_name = aws_key_pair.ssh.key_name
  disable_api_termination = false
  ebs_optimized = false
  root_block_device {
    volume_size = "10"
  }
  tags = {
    "Name" = "zlogene-machine"
  }
}

output "instance_private_ip" {
  value = aws_instance.ec2instance.private_ip
}
resource "aws_subnet" "nat_gateway" {
  availability_zone = data.aws_availability_zones.available.names[0]
  cidr_block = "10.0.2.0/24"
  vpc_id = aws_vpc.vpc.id
  tags = {
    "Name" = "zlogene-nat"
  }
}

resource "aws_internet_gateway" "nat_gateway" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    "Name" = "zlogene-nat-gw"
  }
}

resource "aws_route_table" "nat_gateway" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.nat_gateway.id
  }
}

resource "aws_route_table_association" "nat_gateway" {
  subnet_id = aws_subnet.nat_gateway.id
  route_table_id = aws_route_table.nat_gateway.id
}
resource "aws_eip" "nat_gateway" {
  vpc = true
}

resource "aws_nat_gateway" "nat_gateway" {
  allocation_id = aws_eip.nat_gateway.id
  subnet_id = aws_subnet.nat_gateway.id
  tags = {
    "Name" = "zlogene-nat-gw"
  }
}

output "nat_gateway_ip" {
  value = aws_eip.nat_gateway.public_ip
}

resource "aws_route_table" "instance" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gateway.id
  }
}

resource "aws_route_table_association" "instance" {
  subnet_id = aws_subnet.instance.id
  route_table_id = aws_route_table.instance.id
}
resource "aws_instance" "ec2jumphost" {
  instance_type = "t2.micro"
  ami = "ami-03d8059563982d7b0" # https://cloud-images.ubuntu.com/locator/ec2/ (Ubuntu)
  subnet_id = aws_subnet.nat_gateway.id
  security_groups = [aws_security_group.securitygroup.id]
  key_name = aws_key_pair.ssh.key_name
  disable_api_termination = false
  ebs_optimized = false
  root_block_device {
    volume_size = "10"
  }
  tags = {
    "Name" = "zlogene-jump-machine"
  }
}

resource "aws_eip" "jumphost" {
  instance = aws_instance.ec2jumphost.id
  vpc = true
}

output "jumphost_ip" {
  value = aws_eip.jumphost.public_ip
}


# EFS madness starts here:

resource "aws_efs_file_system" "efs-zlogene" {
   creation_token = "efs-zlogene"
   performance_mode = "generalPurpose"
   throughput_mode = "bursting"
   encrypted = "true"
 tags = {
     Name = "zlogene-efs"
   }
 }

resource "aws_efs_mount_target" "efs-mt-zlogene" {
   file_system_id  = aws_efs_file_system.efs-zlogene.id
   subnet_id = aws_subnet.instance.id
   security_groups = [aws_security_group.securitygroup.id]
 }

 # RDS goes here:

resource "aws_db_subnet_group" "db_subnet" {
   name = "zlogene_db_subnet"
   subnet_ids = [aws_subnet.instance.id, aws_subnet.instance2.id]
 }
 

 resource "aws_db_instance" "zlogene_instance" {
  allocated_storage = 20
  identifier = "testinstance"
  storage_type = "gp2"
  engine = "mysql"
  engine_version = "5.7"
  instance_class = "db.t2.small"
  vpc_security_group_ids = [aws_security_group.securitygroup.id] 
  name = "test"
  username = "admin"
  password = "****"
  parameter_group_name = "default.mysql5.7"
  skip_final_snapshot = "true"
  db_subnet_group_name = aws_db_subnet_group.db_subnet.name
 }
