provider "aws" {
  region  = "${var.region}"
}

provider "random" {}

variable "public_key_path" {
  description = <<DESCRIPTION
Path to the SSH public key to be used for authentication.
Ensure this keypair is added to your local SSH agent so provisioners can
connect.

Example: ~/.ssh/elasticstream_aws.pub
DESCRIPTION
}

resource "random_id" "hash" {
  byte_length = 8
}

variable "key_name" {
  default     = "elasticstream-benchmark-key"
  description = "Desired name prefix for the AWS key pair"
}

variable "region" {}

variable "ami" {}

variable "az" {}

variable "instance_type" {
  type = map(string)
}

variable "instance_cnt" {
  type = map(string)
}

# Create a VPC to launch our instances into
resource "aws_vpc" "benchmark_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "ElasticStream_Benchmark_VPC_${random_id.hash.hex}"
  }
}

# Create an internet gateway to give our subnet access to the outside world
resource "aws_internet_gateway" "elasticstream" {
  vpc_id = "${aws_vpc.benchmark_vpc.id}"
}

# Grant the VPC internet access on its main route table
resource "aws_route" "internet_access" {
  route_table_id         = "${aws_vpc.benchmark_vpc.main_route_table_id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.elasticstream.id}"
}

# Create a subnet to launch our instances into
resource "aws_subnet" "benchmark_subnet" {
  vpc_id                  = "${aws_vpc.benchmark_vpc.id}"
  cidr_block              = "10.0.0.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "${var.az}"
}

resource "aws_security_group" "benchmark_security_group" {
  name   = "terraform-elasticstream-${random_id.hash.hex}"
  vpc_id = "${aws_vpc.benchmark_vpc.id}"

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

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ElasticStream_Benchmark_SecurityGroup_${random_id.hash.hex}"
  }
}

resource "aws_key_pair" "auth" {
  key_name   = "${var.key_name}-${random_id.hash.hex}"
  public_key = "${file(var.public_key_path)}"
}

resource "aws_instance" "placement_manager" {
  ami                    = "${var.ami}"
  instance_type          = "${var.instance_type["placement-manager"]}"
  key_name               = "${aws_key_pair.auth.id}"
  subnet_id              = "${aws_subnet.benchmark_subnet.id}"
  vpc_security_group_ids = ["${aws_security_group.benchmark_security_group.id}"]
  count                  = "${var.instance_cnt["placement-manager"]}"

  root_block_device {
    volume_size = 16
    tags = {
      Name = "pm_${count.index}"
    }
  }

  tags = {
    Name      = "pm_${count.index}"
    Benchmark = "ElasticStream"
  }
}

resource "aws_instance" "data_node" {
  ami                    = "${var.ami}"
  instance_type          = "${var.instance_type["data-node"]}"
  key_name               = "${aws_key_pair.auth.id}"
  subnet_id              = "${aws_subnet.benchmark_subnet.id}"
  vpc_security_group_ids = ["${aws_security_group.benchmark_security_group.id}"]
  count                  = "${var.instance_cnt["data-node"]}"

  root_block_device {
    volume_size = 32
    tags = {
      Name = "dn_${count.index}"
    }
  }

  tags = {
    Name      = "dn_${count.index}"
    Benchmark = "ElasticStream"
  }
}

resource "aws_instance" "client" {
  ami                    = "${var.ami}"
  instance_type          = "${var.instance_type["client"]}"
  key_name               = "${aws_key_pair.auth.id}"
  subnet_id              = "${aws_subnet.benchmark_subnet.id}"
  vpc_security_group_ids = ["${aws_security_group.benchmark_security_group.id}"]
  count                  = "${var.instance_cnt["client"]}"

  root_block_device {
    volume_size = 32
    tags = {
      Name = "client_${count.index}"
    }
  }

  tags = {
    Name      = "client_${count.index}"
    Benchmark = "ElasticStream"
  }
}

output "pm_ssh_host" {
  value = "${aws_instance.placement_manager.0.public_ip}"
}

output "dn_ssh_host" {
  value = "${aws_instance.data_node.0.public_ip}"
}
