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
  type    = bool
  default = true
}

# Create a VPC to launch our instances into
resource "aws_vpc" "benchmark_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name      = "Kafka_on_ES_Benchmark_VPC_${random_id.hash.hex}"
    Benchmark = "Kafka_on_ES"
  }
}

# Create an internet gateway to give our subnet access to the outside world
resource "aws_internet_gateway" "kafka_on_es" {
  vpc_id = aws_vpc.benchmark_vpc.id

  tags = {
    Benchmark = "Kafka_on_ES"
  }
}

# Grant the VPC internet access on its main route table
resource "aws_route" "internet_access" {
  route_table_id         = aws_vpc.benchmark_vpc.main_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.kafka_on_es.id
}

# Create a subnet to launch our instances into
resource "aws_subnet" "benchmark_subnet" {
  vpc_id                  = aws_vpc.benchmark_vpc.id
  cidr_block              = "10.0.0.0/24"
  map_public_ip_on_launch = true
  availability_zone       = var.az

  tags = {
    Benchmark = "Kafka_on_ES"
  }
}

resource "aws_security_group" "benchmark_security_group" {
  name   = "kafka_on_es_${random_id.hash.hex}"
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
    Name      = "Kafka_on_ES_Benchmark_SecurityGroup_${random_id.hash.hex}"
    Benchmark = "Kafka_on_ES"
  }
}

resource "aws_key_pair" "auth" {
  key_name   = "${var.key_name}-${random_id.hash.hex}"
  public_key = file(var.public_key_path)

  tags = {
    Benchmark = "Kafka_on_ES"
  }
}

resource "aws_instance" "placement_driver" {
  ami                    = var.ami
  instance_type          = var.instance_type["placement-driver"]
  key_name               = aws_key_pair.auth.id
  subnet_id              = aws_subnet.benchmark_subnet.id
  vpc_security_group_ids = [aws_security_group.benchmark_security_group.id]
  count                  = var.instance_cnt["placement-driver"]

  root_block_device {
    volume_size = 64
    tags = {
      Name = "pd_${count.index}"
    }
  }

  monitoring = var.monitoring
  tags = {
    Name      = "pd_${count.index}"
    Benchmark = "Kafka_on_ES"
  }
}

resource "aws_instance" "controller" {
  ami                    = var.ami
  instance_type          = var.instance_type["controller"]
  key_name               = aws_key_pair.auth.id
  subnet_id              = aws_subnet.benchmark_subnet.id
  vpc_security_group_ids = [aws_security_group.benchmark_security_group.id]
  count                  = var.instance_cnt["controller"]

  root_block_device {
    volume_size = 64
    tags = {
      Name = "ctrl_${count.index}"
    }
  }

  monitoring = var.monitoring
  tags = {
    Name      = "ctrl_${count.index}"
    Benchmark = "Kafka_on_ES"
  }
}

resource "aws_instance" "mixed_pd_ctrl" {
  ami                    = var.ami
  instance_type          = var.instance_type["mixed-pd-ctrl"]
  key_name               = aws_key_pair.auth.id
  subnet_id              = aws_subnet.benchmark_subnet.id
  vpc_security_group_ids = [aws_security_group.benchmark_security_group.id]
  count                  = var.instance_cnt["mixed-pd-ctrl"]

  root_block_device {
    volume_size = 64
    tags = {
      Name = "mixed_pd_ctrl_${count.index}"
    }
  }

  monitoring = var.monitoring
  tags = {
    Name      = "mixed_pd_ctrl_${count.index}"
    Benchmark = "Kafka_on_ES"
  }
}

resource "aws_instance" "range_server" {
  ami                    = var.ami
  instance_type          = var.instance_type["range-server"]
  key_name               = aws_key_pair.auth.id
  subnet_id              = aws_subnet.benchmark_subnet.id
  vpc_security_group_ids = [aws_security_group.benchmark_security_group.id]
  count                  = var.instance_cnt["range-server"]

  root_block_device {
    volume_size = 64
    tags = {
      Name = "rs_${count.index}"
    }
  }

  monitoring = var.monitoring
  tags = {
    Name      = "rs_${count.index}"
    Benchmark = "Kafka_on_ES"
  }
}

resource "aws_instance" "broker" {
  ami                    = var.ami
  instance_type          = var.instance_type["broker"]
  key_name               = aws_key_pair.auth.id
  subnet_id              = aws_subnet.benchmark_subnet.id
  vpc_security_group_ids = [aws_security_group.benchmark_security_group.id]
  count                  = var.instance_cnt["broker"]

  root_block_device {
    volume_size = 64
    tags = {
      Name = "bkr_${count.index}"
    }
  }

  monitoring = var.monitoring
  tags = {
    Name      = "bkr_${count.index}"
    Benchmark = "Kafka_on_ES"
  }
}

resource "aws_instance" "mixed_rs_bkr" {
  ami                    = var.ami
  instance_type          = var.instance_type["mixed-rs-bkr"]
  key_name               = aws_key_pair.auth.id
  subnet_id              = aws_subnet.benchmark_subnet.id
  vpc_security_group_ids = [aws_security_group.benchmark_security_group.id]
  count                  = var.instance_cnt["mixed-rs-bkr"]

  root_block_device {
    volume_size = 64
    tags = {
      Name = "mixed_rs_bkr_${count.index}"
    }
  }

  monitoring = var.monitoring
  tags = {
    Name      = "mixed_rs_bkr_${count.index}"
    Benchmark = "Kafka_on_ES"
  }
}

# create hosts for Kafka clients
resource "aws_instance" "client" {
  ami                    = var.ami
  instance_type          = var.instance_type["client"]
  key_name               = aws_key_pair.auth.id
  subnet_id              = aws_subnet.benchmark_subnet.id
  vpc_security_group_ids = [aws_security_group.benchmark_security_group.id]
  count                  = var.instance_cnt["client"]

  root_block_device {
    volume_size = 64
    tags = {
      Name = "client_${count.index}"
    }
  }

  monitoring = var.monitoring
  tags = {
    Name      = "clt_${count.index}"
    Benchmark = "Kafka_on_ES"
  }
}

output "user" {
  value = var.user
}

output "pd_ssh_host" {
  value = var.instance_cnt["placement-driver"] + var.instance_cnt["mixed-pd-ctrl"] > 0 ? concat(aws_instance.placement_driver, aws_instance.mixed_pd_ctrl)[0].public_ip : null
}

output "rs_ssh_host" {
  value = var.instance_cnt["range-server"] + var.instance_cnt["mixed-rs-bkr"] > 0 ? concat(aws_instance.range_server, aws_instance.mixed_rs_bkr)[0].public_ip : null
}

output "controller_ssh_host" {
  value = var.instance_cnt["controller"] + var.instance_cnt["mixed-pd-ctrl"] > 0 ? concat(aws_instance.controller, aws_instance.mixed_pd_ctrl)[0].public_ip : null
}

output "broker_ssh_host" {
  value = var.instance_cnt["broker"] + var.instance_cnt["mixed-rs-bkr"] > 0 ? concat(aws_instance.broker, aws_instance.mixed_rs_bkr)[0].public_ip : null
}

output "client_ssh_host" {
  value = var.instance_cnt["client"] > 0 ? aws_instance.client[0].public_ip : null
}

resource "local_file" "hosts_ini" {
  content = templatefile("${path.module}/hosts.ini.tpl",
    {
      pd            = aws_instance.placement_driver,
      ctrl          = aws_instance.controller,
      mixed_pd_ctrl = aws_instance.mixed_pd_ctrl,

      rs           = aws_instance.range_server,
      bkr          = aws_instance.broker,
      mixed_rs_bkr = aws_instance.mixed_rs_bkr,

      client = aws_instance.client,

      ssh_user = var.user,
    }
  )
  filename = "${path.module}/hosts.ini"
}
