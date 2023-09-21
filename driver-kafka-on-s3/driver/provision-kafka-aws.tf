provider "aws" {
  region = var.region
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

Example: ~/.ssh/kafka_on_s3_aws.pub
DESCRIPTION
}

resource "random_id" "hash" {
  byte_length = 8
}

variable "key_name" {
  default     = "kafka_on_s3_benchmark_key"
  description = "Desired name prefix for the AWS key pair"
}

variable "region" {}

variable "az" {}

variable "ami" {}

variable "user" {}

variable "instance_type" {
  type = map(string)
}

variable "instance_cnt" {
  type = map(string)
}

# if true, enable CloudWatch monitoring on the instances
variable "monitoring" {
  type = bool
}

variable "ebs_volume_type" {
  type = string
}

variable "ebs_volume_size" {
  type = number
}

variable "ebs_iops" {
  type = number
}

# Create a VPC to launch our instances into
resource "aws_vpc" "benchmark_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name      = "Kafka_on_S3_Benchmark_VPC_${random_id.hash.hex}"
    Benchmark = "Kafka_on_S3_${random_id.hash.hex}"
  }
}

# Create an internet gateway to give our subnet access to the outside world
resource "aws_internet_gateway" "kafka_on_s3" {
  vpc_id = aws_vpc.benchmark_vpc.id

  tags = {
    Benchmark = "Kafka_on_S3_${random_id.hash.hex}"
  }
}

# Grant the VPC internet access on its main route table
resource "aws_route" "internet_access" {
  route_table_id         = aws_vpc.benchmark_vpc.main_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.kafka_on_s3.id
}

# Create a subnet to launch our instances into
resource "aws_subnet" "benchmark_subnet" {
  vpc_id                  = aws_vpc.benchmark_vpc.id
  cidr_block              = "10.0.0.0/24"
  map_public_ip_on_launch = true
  availability_zone       = var.az

  tags = {
    Benchmark = "Kafka_on_S3_${random_id.hash.hex}"
  }
}

resource "aws_security_group" "benchmark_security_group" {
  name   = "kafka_on_s3_${random_id.hash.hex}"
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

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name      = "Kafka_on_S3_Benchmark_SecurityGroup_${random_id.hash.hex}"
    Benchmark = "Kafka_on_S3_${random_id.hash.hex}"
  }
}

resource "aws_key_pair" "auth" {
  key_name   = "${var.key_name}-${random_id.hash.hex}"
  public_key = file(var.public_key_path)

  tags = {
    Benchmark = "Kafka_on_S3_${random_id.hash.hex}"
  }
}

resource "aws_instance" "server" {
  ami                    = var.ami
  instance_type          = var.instance_type["server"]
  key_name               = aws_key_pair.auth.id
  subnet_id              = aws_subnet.benchmark_subnet.id
  vpc_security_group_ids = [aws_security_group.benchmark_security_group.id]
  count                  = var.instance_cnt["server"]

  root_block_device {
    volume_size = 16
    tags = {
      Name      = "Kafka_on_S3_Benchmark_EBS_root_server_${count.index}"
      Benchmark = "Kafka_on_S3_${random_id.hash.hex}"
    }
  }

  ebs_block_device {
    device_name = "/dev/sdf"
    volume_type = var.ebs_volume_type
    volume_size = var.ebs_volume_size
    iops        = var.ebs_iops
    tags = {
      Name      = "Kafka_on_S3_Benchmark_EBS_data_server_${count.index}"
      Benchmark = "Kafka_on_S3_${random_id.hash.hex}"
    }
  }

  monitoring = var.monitoring
  tags = {
    Name      = "Kafka_on_S3_Benchmark_EC2_server_${count.index}"
    Benchmark = "Kafka_on_S3_${random_id.hash.hex}"
  }
}

resource "aws_instance" "client" {
  ami                    = var.ami
  instance_type          = var.instance_type["client"]
  key_name               = aws_key_pair.auth.id
  subnet_id              = aws_subnet.benchmark_subnet.id
  vpc_security_group_ids = [aws_security_group.benchmark_security_group.id]
  count                  = var.instance_cnt["client"]

  root_block_device {
    volume_size = 16
    tags = {
      Name      = "Kafla_on_S3_Benchmark_EBS_root_client_${count.index}"
      Benchmark = "Kafka_on_S3_${random_id.hash.hex}"
    }
  }

  monitoring = var.monitoring
  tags = {
    Name      = "Kafka_on_S3_Benchmark_EC2_client_${count.index}"
    Benchmark = "Kafka_on_S3_${random_id.hash.hex}"
  }
}

output "user" {
  value = var.user
}

output "server_ssh_host" {
  value = var.instance_cnt["server"] > 0 ? aws_instance.server[0].public_ip : null
}

output "client_ssh_host" {
  value = var.instance_cnt["client"] > 0 ? aws_instance.client[0].public_ip : null
}

resource "local_file" "hosts_ini" {
  content = templatefile("${path.module}/hosts.ini.tpl",
    {
      server = aws_instance.server,
      client = aws_instance.client,

      ssh_user = var.user,
    }
  )
  filename = "${path.module}/hosts.ini"
}
