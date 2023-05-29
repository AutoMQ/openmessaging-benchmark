provider "aws" {
  region  = "${var.region}"
}

provider "random" {}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.0.1"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.5.1"
    }
  }
}

variable "public_key_path" {
  description = <<DESCRIPTION
Path to the SSH public key to be used for authentication.
Ensure this keypair is added to your local SSH agent so provisioners can
connect.

Example: ~/.ssh/kafka_on_es_aws.pub
DESCRIPTION
}

resource "random_id" "hash" {
  byte_length = 8
}

variable "key_name" {
  default     = "kafka_on_es_benchmark_key"
  description = "Desired name prefix for the AWS key pair"
}

variable "region" {}

variable "ami" {}

variable "az" {}

variable "instance_types" {
  type = map(string)
}

variable "num_instances" {
  type = map(string)
}

# Create a VPC to launch our instances into
resource "aws_vpc" "benchmark_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "Kafka_on_ES_Benchmark_VPC_${random_id.hash.hex}"
    Benchmark = "Kafka_on_ES"
  }
}

# Create an internet gateway to give our subnet access to the outside world
resource "aws_internet_gateway" "kafka_on_es" {
  vpc_id = "${aws_vpc.benchmark_vpc.id}"

  tags = {
    Benchmark = "Kafka_on_ES"
  }
}

# Grant the VPC internet access on its main route table
resource "aws_route" "internet_access" {
  route_table_id         = "${aws_vpc.benchmark_vpc.main_route_table_id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.kafka_on_es.id}"

  tags = {
    Benchmark = "Kafka_on_ES"
  }
}

# Create a subnet to launch our instances into
resource "aws_subnet" "benchmark_subnet" {
  vpc_id                  = "${aws_vpc.benchmark_vpc.id}"
  cidr_block              = "10.0.0.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "${var.az}"

  tags = {
    Benchmark = "Kafka_on_ES"
  }
}

resource "aws_security_group" "benchmark_security_group" {
  name   = "kafka_on_es_${random_id.hash.hex}"
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
    Name = "Kafka_on_ES_Benchmark_SecurityGroup_${random_id.hash.hex}"
    Benchmark = "Kafka_on_ES"
  }
}

resource "aws_key_pair" "auth" {
  key_name   = "${var.key_name}-${random_id.hash.hex}"
  public_key = "${file(var.public_key_path)}"

  tags = {
    Benchmark = "Kafka_on_ES"
  }
}

resource "aws_instance" "placement_manager" {
  ami                    = "${var.ami}"
  instance_type          = "${var.instance_types["placement-manager"]}"
  key_name               = "${aws_key_pair.auth.id}"
  subnet_id              = "${aws_subnet.benchmark_subnet.id}"
  vpc_security_group_ids = ["${aws_security_group.benchmark_security_group.id}"]
  count                  = "${var.num_instances["placement-manager"]}"

  root_block_device {
    volume_size = 16
    tags = {
      Name = "es_pm_${count.index}"
    }
  }

  tags = {
    Name      = "es_pm_${count.index}"
    Benchmark = "Kafka_on_ES"
  }
}

resource "aws_instance" "data_node" {
  ami                    = "${var.ami}"
  instance_type          = "${var.instance_types["data-node"]}"
  key_name               = "${aws_key_pair.auth.id}"
  subnet_id              = "${aws_subnet.benchmark_subnet.id}"
  vpc_security_group_ids = ["${aws_security_group.benchmark_security_group.id}"]
  count                  = "${var.num_instances["data-node"]}"

  root_block_device {
    volume_size = 32
    tags = {
      Name = "es_dn_${count.index}"
    }
  }

  tags = {
    Name      = "es_dn_${count.index}"
    Benchmark = "Kafka_on_ES"
  }
}

resource "aws_instance" "mixed_pm_dn" {
  ami                    = "${var.ami}"
  instance_type          = "${var.instance_types["mixed-pm-dn"]}"
  key_name               = "${aws_key_pair.auth.id}"
  subnet_id              = "${aws_subnet.benchmark_subnet.id}"
  vpc_security_group_ids = ["${aws_security_group.benchmark_security_group.id}"]
  count                  = "${var.num_instances["mixed-pm-dn"]}"

  root_block_device {
    volume_size = 32
    tags = {
      Name = "es_mixed_pm_dn_${count.index}"
    }
  }

  tags = {
    Name      = "es_mixed_pm_dn_${count.index}"
    Benchmark = "Kafka_on_ES"
  }
}

# create hosts for Kafka controllers
resource "aws_instance" "controller" {
  ami                    = "${var.ami}"
  instance_type          = "${var.instance_types["controller"]}"
  key_name               = "${aws_key_pair.auth.id}"
  subnet_id              = "${aws_subnet.benchmark_subnet.id}"
  vpc_security_group_ids = ["${aws_security_group.benchmark_security_group.id}"]
  count                  = "${var.num_instances["controller"]}"

  tags = {
    Name      = "kafka_controller_${count.index}"
    Benchmark = "Kafka_on_ES"
  }
}

# create hosts for Kafka brokers
resource "aws_instance" "broker" {
  ami                    = "${var.ami}"
  instance_type          = "${var.instance_types["broker"]}"
  key_name               = "${aws_key_pair.auth.id}"
  subnet_id              = "${aws_subnet.benchmark_subnet.id}"
  vpc_security_group_ids = ["${aws_security_group.benchmark_security_group.id}"]
  count                  = lookup(var.num_instances, "broker", 0) # (var.num_instances["broker"]")

  tags = {
    Name      = "kafka_broker_${count.index}"
    Benchmark = "Kafka_on_ES"
  }
}

# create hosts for Kafka clients
resource "aws_instance" "client" {
  ami                    = "${var.ami}"
  instance_type          = "${var.instance_types["client"]}"
  key_name               = "${aws_key_pair.auth.id}"
  subnet_id              = "${aws_subnet.benchmark_subnet.id}"
  vpc_security_group_ids = ["${aws_security_group.benchmark_security_group.id}"]
  count                  = "${var.num_instances["client"]}"

  tags = {
    Name      = "kafka_client_${count.index}"
    Benchmark = "Kafka_on_ES"
  }
}

output "pm_ssh_host" {
  value = "${aws_instance.placement_manager.0.public_ip}"
}

output "dn_ssh_host" {
  value = "${aws_instance.data_node.0.public_ip}"
}

output "kafka_ssh_host" {
  value = "${aws_instance.controller.0.public_ip}"
}

output "client_ssh_host" {
  value = "${aws_instance.client.0.public_ip}"
}
