provider "aws" {
  region = var.region
}

provider "random" {}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.26.0"
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

Example: ~/.ssh/automq_for_kafka.pub
DESCRIPTION
}

resource "random_id" "hash" {
  byte_length = 8
}

variable "key_name" {
  default     = "automq_for_kafka_benchmark_key"
  description = "Desired name prefix for the AWS key pair"
}

variable "region" {}

variable "az" {
  type = list(string)
}

variable "ami" {}

variable "user" {}

variable "instance_type" {
  type = map(string)
}

variable "instance_cnt" {
  type = map(string)
}

variable "instance_bandwidth_Gbps" {
  type = number
}

# if true, enable CloudWatch monitoring on the instances
variable "monitoring" {
  type = bool
}

# if true, use spot instances
variable "spot" {
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

variable "aws_cn" {
  type = bool
}

variable "s3_wal_enabled" {
  type = bool
  default = false
}

variable "access_key" {}

variable "secret_key" {}

locals {
  cluster_id       = "M_benchmark_aws______A"
  server_kafka_ids = { for i in range(var.instance_cnt["server"]) : i => i + 1 }
  broker_kafka_ids = { for i in range(var.instance_cnt["broker"]) : i => var.instance_cnt["server"] + i + 1 }
}

# Create a VPC to launch our instances into
resource "aws_vpc" "benchmark_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name      = "automq_for_kafka_benchmark_vpc_${random_id.hash.hex}"
    Benchmark = "automq_for_kafka_${random_id.hash.hex}"
  }
}

# Create an internet gateway to give our subnet access to the outside world
resource "aws_internet_gateway" "automq_for_kafka" {
  vpc_id = aws_vpc.benchmark_vpc.id

  tags = {
    Benchmark = "automq_for_kafka_${random_id.hash.hex}"
  }
}

# Grant the VPC internet access on its main route table
resource "aws_route" "internet_access" {
  route_table_id         = aws_vpc.benchmark_vpc.main_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.automq_for_kafka.id
}

# Create a subnet to launch our instances into
resource "aws_subnet" "benchmark_subnet" {
  count                   = length(var.az)
  vpc_id                  = aws_vpc.benchmark_vpc.id
  cidr_block              = cidrsubnet(aws_vpc.benchmark_vpc.cidr_block, 8, count.index)
  map_public_ip_on_launch = true
  availability_zone       = element(var.az, count.index)

  tags = {
    Benchmark = "automq_for_kafka_${random_id.hash.hex}"
  }
}

resource "aws_security_group" "benchmark_security_group" {
  name   = "automq_for_kafka_${random_id.hash.hex}"
  vpc_id = aws_vpc.benchmark_vpc.id

  # SSH access from anywhere
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Grafana access from anywhere
  ingress {
    from_port   = 3000
    to_port     = 3000
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
    Name      = "automq_for_kafka_benchmark_security_group_${random_id.hash.hex}"
    Benchmark = "automq_for_kafka_${random_id.hash.hex}"
  }
}

resource "aws_key_pair" "auth" {
  key_name   = "${var.key_name}-${random_id.hash.hex}"
  public_key = file(var.public_key_path)

  tags = {
    Benchmark = "automq_for_kafka_${random_id.hash.hex}"
  }
}

resource "aws_iam_role" "benchmark_role_s3" {
  name = "automq_for_kafka_benchmark_role_s3_${random_id.hash.hex}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = var.aws_cn ? "ec2.amazonaws.com.cn" : "ec2.amazonaws.com"
        }
      }
    ]
  })

  inline_policy {
    name = "automq_for_kafka_benchmark_policy_${random_id.hash.hex}"

    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Action = [
            "s3:ListBucket",
            "s3:GetObject",
            "s3:PutObject",
            "s3:DeleteObject",
            "s3:AbortMultipartUpload",
          ]
          Effect = "Allow"
          Resource = var.aws_cn ? [
            "arn:aws-cn:s3:::${aws_s3_bucket.benchmark_bucket.id}",
            "arn:aws-cn:s3:::${aws_s3_bucket.benchmark_bucket.id}/*",
            ] : [
            "arn:aws:s3:::${aws_s3_bucket.benchmark_bucket.id}",
            "arn:aws:s3:::${aws_s3_bucket.benchmark_bucket.id}/*",
          ]
        }
      ]
    })
  }

  tags = {
    Name      = "automq_for_kafka_benchmark_iam_role_${random_id.hash.hex}"
    Benchmark = "automq_for_kafka_${random_id.hash.hex}"
  }
}

resource "aws_iam_instance_profile" "benchmark_instance_profile_s3" {
  name = "automq_for_kafka_benchmark_instance_profile_s3_${random_id.hash.hex}"

  role = aws_iam_role.benchmark_role_s3.name

  tags = {
    Name      = "automq_for_kafka_benchmark_iam_instanceprofile_${random_id.hash.hex}"
    Benchmark = "automq_for_kafka_${random_id.hash.hex}"
  }
}

resource "aws_instance" "server" {
  ami                    = var.ami
  instance_type          = var.instance_type["server"]
  key_name               = aws_key_pair.auth.id
  subnet_id              = element(aws_subnet.benchmark_subnet.*.id, count.index % length(var.az))
  vpc_security_group_ids = [aws_security_group.benchmark_security_group.id]
  count                  = var.instance_cnt["server"]

  dynamic "instance_market_options" {
    for_each = var.spot ? [1] : []
    content {
      market_type = "spot"
      spot_options {
        instance_interruption_behavior = "stop"
        spot_instance_type             = "persistent"
      }
    }
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = 16
    tags = {
      Name            = "automq_for_kafka_benchmark_ebs_root_server_${count.index}_${random_id.hash.hex}"
      Benchmark       = "automq_for_kafka_${random_id.hash.hex}"
      automqVendor    = "automq"
      automqClusterID = local.cluster_id
    }
  }

  dynamic "ebs_block_device" {
    for_each = var.s3_wal_enabled ? [] : [1]
    content {
      device_name = "/dev/sdf"
      volume_type = var.ebs_volume_type
      volume_size = var.ebs_volume_size
      iops        = var.ebs_iops
      tags = {
        Name            = "automq_for_kafka_benchmark_ebs_data_server_${count.index}_${random_id.hash.hex}"
        Benchmark       = "automq_for_kafka_${random_id.hash.hex}"
        automqNodeID    = local.server_kafka_ids[count.index]
        automqVendor    = "automq"
        automqClusterID = local.cluster_id
      }
    }
  }

  iam_instance_profile = aws_iam_instance_profile.benchmark_instance_profile_s3.name

  monitoring = var.monitoring
  tags = {
    Name            = "automq_for_kafka_benchmark_ec2_server_${count.index}_${random_id.hash.hex}"
    Benchmark       = "automq_for_kafka_${random_id.hash.hex}"
    nodeID          = local.server_kafka_ids[count.index]
    automqVendor    = "automq"
    automqClusterID = local.cluster_id
  }
}

resource "aws_instance" "broker" {
  ami                    = var.ami
  instance_type          = var.instance_type["broker"]
  key_name               = aws_key_pair.auth.id
  subnet_id              = element(aws_subnet.benchmark_subnet.*.id, count.index % length(var.az))
  vpc_security_group_ids = [aws_security_group.benchmark_security_group.id]
  count                  = var.instance_cnt["broker"]

  dynamic "instance_market_options" {
    for_each = var.spot ? [1] : []
    content {
      market_type = "spot"
      spot_options {
        instance_interruption_behavior = "stop"
        spot_instance_type             = "persistent"
      }
    }
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = 16
    tags = {
      Name            = "automq_for_kafka_benchmark_ebs_root_broker_${count.index}_${random_id.hash.hex}"
      Benchmark       = "automq_for_kafka_${random_id.hash.hex}"
      automqVendor    = "automq"
      automqClusterID = local.cluster_id
    }
  }

  dynamic "ebs_block_device" {
    for_each = var.s3_wal_enabled ? [] : [1]
    content {
      device_name = "/dev/sdf"
      volume_type = var.ebs_volume_type
      volume_size = var.ebs_volume_size
      iops        = var.ebs_iops
      tags = {
        Name            = "automq_for_kafka_benchmark_ebs_data_broker_${count.index}_${random_id.hash.hex}"
        Benchmark       = "automq_for_kafka_${random_id.hash.hex}"
        automqNodeID    = local.broker_kafka_ids[count.index]
        automqVendor    = "automq"
        automqClusterID = local.cluster_id
      }
    }
  }

  iam_instance_profile = aws_iam_instance_profile.benchmark_instance_profile_s3.name

  monitoring = var.monitoring
  tags = {
    Name            = "automq_for_kafka_benchmark_ec2_broker_${count.index}_${random_id.hash.hex}"
    Benchmark       = "automq_for_kafka_${random_id.hash.hex}"
    nodeID          = local.broker_kafka_ids[count.index]
    automqVendor    = "automq"
    automqClusterID = local.cluster_id
  }
}

resource "aws_instance" "client" {
  ami                    = var.ami
  instance_type          = var.instance_type["client"]
  key_name               = aws_key_pair.auth.id
  subnet_id              = element(aws_subnet.benchmark_subnet.*.id, count.index % length(var.az))
  vpc_security_group_ids = [aws_security_group.benchmark_security_group.id]
  count                  = var.instance_cnt["client"]

  dynamic "instance_market_options" {
    for_each = var.spot ? [1] : []
    content {
      market_type = "spot"
      spot_options {
        instance_interruption_behavior = "stop"
        spot_instance_type             = "persistent"
      }
    }
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = 64
    tags = {
      Name      = "automq_for_kafka_benchmark_ebs_root_client_${count.index}_${random_id.hash.hex}"
      Benchmark = "automq_for_kafka_${random_id.hash.hex}_client"
    }
  }

  monitoring = var.monitoring
  tags = {
    Name      = "automq_for_kafka_benchmark_ec2_client_${count.index}_${random_id.hash.hex}"
    Benchmark = "automq_for_kafka_${random_id.hash.hex}_client"
  }
}

resource "aws_s3_bucket" "benchmark_bucket" {
  bucket        = "automq-for-kafka-benchmark-${random_id.hash.hex}"
  force_destroy = true

  tags = {
    Name      = "automq_for_kafka_benchmark_s3_${random_id.hash.hex}"
    Benchmark = "automq_for_kafka_${random_id.hash.hex}"
  }
}

output "user" {
  value = var.user
}

output "server_ssh_host" {
  value = var.instance_cnt["server"] > 0 ? aws_instance.server[0].public_ip : null
}

output "server_ssh_hosts" {
  value = aws_instance.server[*].public_ip
}

output "broker_ssh_host" {
  value = var.instance_cnt["broker"] > 0 ? aws_instance.broker[0].public_ip : null
}

output "broker_ssh_hosts" {
  value = aws_instance.broker[*].public_ip
}

output "client_ssh_host" {
  value = var.instance_cnt["client"] > 0 ? aws_instance.client[0].public_ip : null
}

output "client_ssh_hosts" {
  value = aws_instance.client[*].public_ip
}

output "client_ids" {
  value = [for i in aws_instance.client : i.id]
}

output "env_id" {
  value = random_id.hash.hex
}

output "vpc_id" {
  value = aws_vpc.benchmark_vpc.id
}

output "ssh_key_name" {
  value = aws_key_pair.auth.key_name
}

resource "local_file" "hosts_ini" {
  content = templatefile("${path.module}/hosts.ini.tpl",
    {
      server           = aws_instance.server,
      server_kafka_ids = local.server_kafka_ids,
      broker           = aws_instance.broker,
      broker_kafka_ids = local.broker_kafka_ids,
      client           = aws_instance.client,
      # use the first client (if exist) for telemetry
      telemetry = var.instance_cnt["client"] > 0 ? slice(aws_instance.client, 0, 1) : [],

      ssh_user = var.user,

      cloud_provider = var.aws_cn ? "aws-cn" : "aws",
      s3_region      = var.region,
      s3_bucket      = aws_s3_bucket.benchmark_bucket.id,
      aws_domain     = var.aws_cn ? "amazonaws.com.cn" : "amazonaws.com",
      cluster_id     = local.cluster_id,

      access_key = var.access_key,
      secret_key = var.secret_key,
      role_name  = aws_iam_role.benchmark_role_s3.name,

      # convert Gbps to Bps
      network_bandwidth = format("%.0f", var.instance_bandwidth_Gbps * 1024 * 1024 * 1024 / 8),

      s3_wal_enabled = var.s3_wal_enabled,
    }
  )
  filename = "${path.module}/hosts.ini"
}
