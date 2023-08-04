terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.1"
    }
  }
}

variable "public_key_path" {
  description = <<DESCRIPTION
Path to the SSH public key to be used for authentication.
Ensure this keypair is added to your local SSH agent so provisioners can
connect.

Example: ~/.ssh/pulsar_aws.pub
DESCRIPTION
}

resource "random_id" "hash" {
  byte_length = 8
}

variable "key_name" {
  default     = "pulsar_benchmark_key"
  description = "Desired name prefix for the AWS key pair"
}

variable "region" {}
variable "az" {}
variable "ami" {}
variable "instance_types" {}
variable "num_instances" {}

provider "aws" {
  region = var.region
}

# Create a VPC to launch our instances into
resource "aws_vpc" "benchmark_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "Pulsar_Benchmark_VPC_${random_id.hash.hex}"
  }
}

# Create an internet gateway to give our subnet access to the outside world
resource "aws_internet_gateway" "pulsar" {
  vpc_id = aws_vpc.benchmark_vpc.id
}

# Grant the VPC internet access on its main route table
resource "aws_route" "internet_access" {
  route_table_id         = aws_vpc.benchmark_vpc.main_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.pulsar.id
}

# Create a subnet to launch our instances into
resource "aws_subnet" "benchmark_subnet" {
  vpc_id                  = aws_vpc.benchmark_vpc.id
  cidr_block              = "10.0.0.0/24"
  map_public_ip_on_launch = true
  availability_zone       = var.az
}

resource "aws_security_group" "benchmark_security_group" {
  name   = "terraform_pulsar_${random_id.hash.hex}"
  vpc_id = aws_vpc.benchmark_vpc.id

  # SSH access from anywhere
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # All ports open within the VPC
  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  # Prometheus/Dashboard access
  ingress {
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Benchmark_Security_Group_${random_id.hash.hex}"
  }
}

resource "aws_key_pair" "auth" {
  key_name   = "${var.key_name}_${random_id.hash.hex}"
  public_key = file(var.public_key_path)
}

resource "aws_instance" "zookeeper" {
  ami           = var.ami
  instance_type = var.instance_types["zookeeper"]
  key_name      = aws_key_pair.auth.id
  subnet_id     = aws_subnet.benchmark_subnet.id
  vpc_security_group_ids = [
  aws_security_group.benchmark_security_group.id]
  count = var.num_instances["zookeeper"]

  tags = {
    Name = "zk_${count.index}"
  }
}

resource "aws_instance" "pulsar" {
  ami           = var.ami
  instance_type = var.instance_types["pulsar"]
  key_name      = aws_key_pair.auth.id
  subnet_id     = aws_subnet.benchmark_subnet.id
  vpc_security_group_ids = [
  aws_security_group.benchmark_security_group.id]
  count = var.num_instances["pulsar"]

  tags = {
    Name = "pulsar_${count.index}"
  }
}

resource "aws_instance" "client" {
  ami           = var.ami
  instance_type = var.instance_types["client"]
  key_name      = aws_key_pair.auth.id
  subnet_id     = aws_subnet.benchmark_subnet.id
  vpc_security_group_ids = [
  aws_security_group.benchmark_security_group.id]
  count = var.num_instances["client"]

  tags = {
    Name = "pulsar_client_${count.index}"
  }
}

resource "aws_instance" "prometheus" {
  ami           = var.ami
  instance_type = var.instance_types["prometheus"]
  key_name      = aws_key_pair.auth.id
  subnet_id     = aws_subnet.benchmark_subnet.id
  vpc_security_group_ids = [
  aws_security_group.benchmark_security_group.id]
  count = var.num_instances["prometheus"]

  tags = {
    Name = "prometheus_${count.index}"
  }
}

output "zookeeper" {
  value = {
    for instance in aws_instance.zookeeper :
    instance.public_ip => instance.private_ip
  }
}

output "pulsar" {
  value = {
    for instance in aws_instance.pulsar :
    instance.public_ip => instance.private_ip
  }
}

output "client" {
  value = {
    for instance in aws_instance.client :
    instance.public_ip => instance.private_ip
  }
}

output "prometheus" {
  value = {
    for instance in aws_instance.prometheus :
    instance.public_ip => instance.private_ip
  }
}

output "client_ssh_host" {
  value = aws_instance.client.0.public_ip
}

output "prometheus_host" {
  value = var.num_instances["prometheus"] > 0 ? aws_instance.prometheus.0.public_ip: null
}
