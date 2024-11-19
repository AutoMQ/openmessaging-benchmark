provider "tencentcloud" {
  region     = var.region
  secret_id  = var.secret_id
  secret_key = var.secret_key
}

provider "random" {}

terraform {
  required_providers {
    tencentcloud = {
      source  = "tencentcloudstack/tencentcloud"
      version = "1.81.140"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.5.1"
    }
  }
}

data "tencentcloud_user_info" "user_info" {}

resource "random_id" "hash" {
  byte_length = 2
}

variable "public_key_path" {
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

variable "cbs_disk_type" {
  type = string
}

variable "cbs_disk_size" {
  type = number
}

variable "secret_id" {}

variable "secret_key" {}

locals {
  tags = {
    Benchmark    = "automq_for_kafka_${random_id.hash.hex}"
    automqVendor = "automq"
  }
  cluster_id       = "M_benchmark_tencent__A"
  server_kafka_ids = { for i in range(var.instance_cnt["server"]) : i => i + 1 }
  broker_kafka_ids = { for i in range(var.instance_cnt["broker"]) : i => var.instance_cnt["server"] + i + 1 }
}

resource "tencentcloud_vpc" "benchmark_vpc" {
  cidr_block = "10.0.0.0/16"

  name = "automq_for_kafka_benchmark_vpc_${random_id.hash.hex}"
  tags = local.tags
}

resource "tencentcloud_subnet" "benchmark_subnet" {
  count             = length(var.az)
  vpc_id            = tencentcloud_vpc.benchmark_vpc.id
  cidr_block        = cidrsubnet(tencentcloud_vpc.benchmark_vpc.cidr_block, 8, count.index)
  availability_zone = element(var.az, count.index)

  name = "automq_for_kafka_benchmark_subnet_${random_id.hash.hex}"
  tags = local.tags
}

resource "tencentcloud_security_group" "benchmark_security_group" {
  name = "automq_for_kafka_benchmark_security_group_${random_id.hash.hex}"
  tags = local.tags
}

resource "tencentcloud_security_group_rule_set" "benchmark_security_group_rule_set" {
  security_group_id = tencentcloud_security_group.benchmark_security_group.id

  # SSH access from anywhere
  ingress {
    action     = "ACCEPT"
    protocol   = "TCP"
    port       = "22"
    cidr_block = "0.0.0.0/0"
  }

  # Grafana access from anywhere
  ingress {
    action     = "ACCEPT"
    protocol   = "TCP"
    port       = "3000"
    cidr_block = "0.0.0.0/0"
  }

  # All ports open within the VPC
  ingress {
    action     = "ACCEPT"
    protocol   = "TCP"
    cidr_block = tencentcloud_vpc.benchmark_vpc.cidr_block
  }

  # outbound internet access
  egress {
    action     = "ACCEPT"
    cidr_block = "0.0.0.0/0"
  }
}

resource "tencentcloud_key_pair" "benchmark_key_pair" {
  public_key = file(var.public_key_path)

  key_name = "benchmark_key_pair_${random_id.hash.hex}"
  tags     = local.tags
}

resource "tencentcloud_cam_role" "benchmark_role" {
  document = <<EOF
{
  "version": "2.0",
  "statement": [
    {
      "action": [
        "name/sts:AssumeRole"
      ],
      "effect": "allow",
      "principal": {
        "service": [
          "cvm.qcloud.com"
        ]
      }
    }
  ]
}
EOF

  name = "automq_for_kafka_benchmark_role_${random_id.hash.hex}"
  tags = local.tags
}

resource "tencentcloud_cam_policy" "benchmark_policy" {
  document = <<EOF
{
  "version": "2.0",
  "statement": [
    {
      "action": [
        "cos:AbortMultipartUpload",
        "cos:GetObject",
        "cos:HeadObject",
        "cos:CompleteMultipartUpload",
        "cos:InitiateMultipartUpload",
        "cos:UploadPart",
        "cos:DeleteMultipleObjects",
        "cos:DeleteObject",
        "cos:PutObject",
        "cos:UploadPartCopy"
     ],
      "effect": "allow",
      "resource": [
        "qcs::cos:${var.region}:*:${tencentcloud_cos_bucket.benchmark_bucket.bucket}/*"
      ]
    },
    {
      "action": [
        "cos:HeadBucket",
        "cos:GetBucket"
      ],
      "effect": "allow",
      "resource": [
        "qcs::cos:${var.region}:*:${tencentcloud_cos_bucket.benchmark_bucket.bucket}"
      ]
    }
  ]
}
EOF

  name = "automq_for_kafka_benchmark_policy_${random_id.hash.hex}"
}

resource "tencentcloud_cam_role_policy_attachment" "benchmark_role_policy_attachment" {
  role_id   = tencentcloud_cam_role.benchmark_role.id
  policy_id = tencentcloud_cam_policy.benchmark_policy.id
}

resource "tencentcloud_instance" "server" {
  image_id                = var.ami
  availability_zone       = element(var.az, count.index % length(var.az))
  instance_type           = var.instance_type["server"]
  key_ids                 = [tencentcloud_key_pair.benchmark_key_pair.id]
  vpc_id                  = tencentcloud_vpc.benchmark_vpc.id
  subnet_id               = element(tencentcloud_subnet.benchmark_subnet.*.id, count.index % length(var.az))
  orderly_security_groups = [tencentcloud_security_group.benchmark_security_group.id]
  count                   = var.instance_cnt["server"]

  allocate_public_ip         = true
  internet_charge_type       = "TRAFFIC_POSTPAID_BY_HOUR"
  internet_max_bandwidth_out = 64

  system_disk_type = "CLOUD_BSSD"
  system_disk_size = 20

  data_disks {
    data_disk_type       = var.cbs_disk_type
    data_disk_size       = var.cbs_disk_size
    delete_with_instance = true
  }

  cam_role_name = tencentcloud_cam_role.benchmark_role.name

  instance_name = "automq_for_kafka_benchmark_server_${count.index}_${random_id.hash.hex}"
  tags = merge(local.tags, {
    nodeID          = local.server_kafka_ids[count.index],
    automqClusterID = local.cluster_id,
  })
}

resource "tencentcloud_instance" "broker" {
  image_id                = var.ami
  availability_zone       = element(var.az, count.index % length(var.az))
  instance_type           = var.instance_type["broker"]
  key_ids                 = [tencentcloud_key_pair.benchmark_key_pair.id]
  vpc_id                  = tencentcloud_vpc.benchmark_vpc.id
  subnet_id               = element(tencentcloud_subnet.benchmark_subnet.*.id, count.index % length(var.az))
  orderly_security_groups = [tencentcloud_security_group.benchmark_security_group.id]
  count                   = var.instance_cnt["broker"]

  allocate_public_ip         = true
  internet_charge_type       = "TRAFFIC_POSTPAID_BY_HOUR"
  internet_max_bandwidth_out = 64

  system_disk_type = "CLOUD_BSSD"
  system_disk_size = 20

  data_disks {
    data_disk_type       = var.cbs_disk_type
    data_disk_size       = var.cbs_disk_size
    delete_with_instance = true
  }

  cam_role_name = tencentcloud_cam_role.benchmark_role.name

  instance_name = "automq_for_kafka_benchmark_broker_${count.index}_${random_id.hash.hex}"
  tags = merge(local.tags, {
    nodeID          = local.broker_kafka_ids[count.index],
    automqClusterID = local.cluster_id,
  })
}

resource "tencentcloud_instance" "client" {
  image_id                = var.ami
  availability_zone       = element(var.az, count.index % length(var.az))
  instance_type           = var.instance_type["client"]
  key_ids                 = [tencentcloud_key_pair.benchmark_key_pair.id]
  vpc_id                  = tencentcloud_vpc.benchmark_vpc.id
  subnet_id               = element(tencentcloud_subnet.benchmark_subnet.*.id, count.index % length(var.az))
  orderly_security_groups = [tencentcloud_security_group.benchmark_security_group.id]
  count                   = var.instance_cnt["client"]

  allocate_public_ip         = true
  internet_charge_type       = "TRAFFIC_POSTPAID_BY_HOUR"
  internet_max_bandwidth_out = 64

  system_disk_type = "CLOUD_BSSD"
  system_disk_size = 20

  cam_role_name = tencentcloud_cam_role.benchmark_role.name

  instance_name = "automq_for_kafka_benchmark_client_${count.index}_${random_id.hash.hex}"
  tags          = local.tags
}

resource "tencentcloud_cos_bucket" "benchmark_bucket" {
  bucket      = "benchmark-${random_id.hash.hex}-${data.tencentcloud_user_info.user_info.app_id}"
  acl         = "private"
  force_clean = true

  tags = local.tags
}

output "user" {
  value = var.user
}

output "server_ssh_host" {
  value = var.instance_cnt["server"] > 0 ? tencentcloud_instance.server[0].public_ip : null
}

output "broker_ssh_host" {
  value = var.instance_cnt["broker"] > 0 ? tencentcloud_instance.broker[0].public_ip : null
}

output "client_ssh_host" {
  value = var.instance_cnt["client"] > 0 ? tencentcloud_instance.client[0].public_ip : null
}

resource "local_file" "hosts_ini" {
  content = templatefile("${path.module}/hosts.ini.tpl",
    {
      server           = tencentcloud_instance.server,
      server_kafka_ids = local.server_kafka_ids,
      broker           = tencentcloud_instance.broker,
      broker_kafka_ids = local.broker_kafka_ids,
      client           = tencentcloud_instance.client,
      # use the first client (if exist) for telemetry
      telemetry = var.instance_cnt["client"] > 0 ? slice(tencentcloud_instance.client, 0, 1) : [],

      ssh_user = var.user,

      cos_region   = var.region,
      cos_bucket   = tencentcloud_cos_bucket.benchmark_bucket.bucket,
      cluster_id   = local.cluster_id,

      secret_id  = var.secret_id,
      secret_key = var.secret_key,
      role_name  = tencentcloud_cam_role.benchmark_role.name,

      # convert Gbps to Bps
      network_bandwidth = format("%.0f", var.instance_bandwidth_Gbps * 1024 * 1024 * 1024 / 8),
    }
  )
  filename = "${path.module}/hosts.ini"
}
