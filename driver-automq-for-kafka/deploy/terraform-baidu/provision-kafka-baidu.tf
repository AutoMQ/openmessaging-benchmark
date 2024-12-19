provider "baiducloud" {
  region     = var.region
  access_key = var.access_key
  secret_key = var.secret_key
}

provider "random" {}

terraform {
  required_providers {
    baiducloud = {
      source  = "baidubce/baiducloud"
      version = "1.21.10"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.5.1"
    }
  }
}

resource "random_id" "hash" {
  byte_length = 8
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

variable "spot" {
  type = bool
}

variable "cds_disk_type" {
  type = string
}

variable "cds_disk_size" {
  type = number
}

variable "access_key" {}

variable "secret_key" {}

locals {
  tags = {
    Benchmark    = "automq_for_kafka_${random_id.hash.hex}"
    automqVendor = "automq"
  }
  cluster_id       = "M_benchmark_baidu____A"
  server_kafka_ids = { for i in range(var.instance_cnt["server"]) : i => i + 1 }
  broker_kafka_ids = { for i in range(var.instance_cnt["broker"]) : i => var.instance_cnt["server"] + i + 1 }
}

resource "baiducloud_vpc" "benchmark_vpc" {
  cidr = "10.0.0.0/16"

  name = "automq_for_kafka_benchmark_vpc_${random_id.hash.hex}"
  tags = local.tags
}

resource "baiducloud_subnet" "benchmark_subnet" {
  count     = length(var.az)
  vpc_id    = baiducloud_vpc.benchmark_vpc.id
  cidr      = cidrsubnet(baiducloud_vpc.benchmark_vpc.cidr, 8, count.index)
  zone_name = element(var.az, count.index)

  name = "automq_for_kafka_benchmark_subnet_${count.index}_${random_id.hash.hex}"
  tags = local.tags
}

resource "baiducloud_security_group" "benchmark_security_group" {
  vpc_id = baiducloud_vpc.benchmark_vpc.id

  name = "automq_for_kafka_benchmark_security_group_${random_id.hash.hex}"
  tags = local.tags
}

resource "baiducloud_security_group_rule" "benchmark_security_group_rule_ssh" {
  security_group_id = baiducloud_security_group.benchmark_security_group.id

  direction  = "ingress"
  ether_type = "IPv4"
  protocol   = "tcp"
  port_range = "22"
  source_ip  = "0.0.0.0/0"

  remark = "Allow SSH"
}

resource "baiducloud_security_group_rule" "benchmark_security_group_rule_grafana" {
  security_group_id = baiducloud_security_group.benchmark_security_group.id

  direction  = "ingress"
  ether_type = "IPv4"
  protocol   = "tcp"
  port_range = "3000"
  source_ip  = "0.0.0.0/0"

  remark = "Allow Grafana"
}

resource "baiducloud_security_group_rule" "benchmark_security_group_rule_within_vpc" {
  security_group_id = baiducloud_security_group.benchmark_security_group.id

  direction  = "ingress"
  ether_type = "IPv4"
  protocol   = "tcp"
  port_range = "1-65535"
  source_ip  = baiducloud_vpc.benchmark_vpc.cidr

  remark = "Allow within VPC"
}

resource "baiducloud_security_group_rule" "benchmark_security_group_rule_outbound" {
  security_group_id = baiducloud_security_group.benchmark_security_group.id

  direction  = "egress"
  ether_type = "IPv4"

  remark = "Allow all outbound traffic"
}

resource "baiducloud_bcc_key_pair" "benchmark_key_pair" {
  name       = "automq_for_kafka_benchmark_key_pair_${random_id.hash.hex}"
  public_key = file(var.public_key_path)
}

# resource "baiducloud_iam_group" "benchmark_iam_group" {
#   name          = "automq_for_kafka_benchmark_iam_group_${random_id.hash.hex}"
#   force_destroy = true
# }

# resource "baiducloud_iam_policy" "benchmark_iam_policy" {
#   name     = "automq_for_kafka_benchmark_iam_policy_${random_id.hash.hex}"
#   document = <<EOF
# {
#   "accessControlList": [
#     {
#       "service": "bce:bos",
#       "region": "${var.region}",
#       "effect": "Allow",
#       "permission": [
#         "WRITE",
#         "READ",
#         "DeleteObject"
#       ],
#       "resource": [
#         "${baiducloud_bos_bucket.benchmark_bucket.bucket}/*"
#       ]
#     },
#     {
#       "service": "bce:bos",
#       "region": "${var.region}",
#       "effect": "Allow",
#       "permission": [
#         "ListBuckets"
#       ],
#       "resource": [
#         "${baiducloud_bos_bucket.benchmark_bucket.bucket}"
#       ]
#     }
#   ]
# }
# EOF
# }

# resource "baiducloud_iam_group_policy_attachment" "benchmark_iam_group_policy_attachment" {
#   group  = baiducloud_iam_group.benchmark_iam_group.name
#   policy = baiducloud_iam_policy.benchmark_iam_policy.name
# }

resource "baiducloud_instance" "server" {
  image_id          = var.ami
  instance_spec     = var.instance_type["server"]
  keypair_id        = baiducloud_bcc_key_pair.benchmark_key_pair.id
  availability_zone = element(var.az, count.index % length(var.az))
  subnet_id         = element(baiducloud_subnet.benchmark_subnet.*.id, count.index % length(var.az))
  security_groups   = [baiducloud_security_group.benchmark_security_group.id]
  count             = var.instance_cnt["server"]

  root_disk_storage_type = "cloud_hp1"
  root_disk_size_in_gb   = 40

  cds_disks {
    storage_type   = var.cds_disk_type
    cds_size_in_gb = var.cds_disk_size
  }
  related_release_flag = true

  # TODO: bind IAM role

  name = "automq_for_kafka_benchmark_server_${count.index}_${random_id.hash.hex}"
  tags = merge(local.tags, {
    nodeID          = local.server_kafka_ids[count.index],
    automqClusterID = local.cluster_id,
  })
}

resource "baiducloud_eip" "server_eip" {
  count = var.instance_cnt["server"]

  payment_timing    = "Postpaid"
  billing_method    = "ByTraffic"
  bandwidth_in_mbps = 32

  name = "automq_for_kafka_benchmark_server_eip_${count.index}_${random_id.hash.hex}"
  tags = local.tags
}

resource "baiducloud_eip_association" "server_eip_association" {
  count = var.instance_cnt["server"]

  eip           = baiducloud_eip.server_eip[count.index].eip
  instance_id   = baiducloud_instance.server[count.index].id
  instance_type = "BCC"
}

resource "baiducloud_instance" "broker" {
  image_id          = var.ami
  instance_spec     = var.instance_type["broker"]
  keypair_id        = baiducloud_bcc_key_pair.benchmark_key_pair.id
  availability_zone = element(var.az, count.index % length(var.az))
  subnet_id         = element(baiducloud_subnet.benchmark_subnet.*.id, count.index % length(var.az))
  security_groups   = [baiducloud_security_group.benchmark_security_group.id]
  count             = var.instance_cnt["broker"]

  root_disk_storage_type = "cloud_hp1"
  root_disk_size_in_gb   = 40

  cds_disks {
    storage_type   = var.cds_disk_type
    cds_size_in_gb = var.cds_disk_size
  }
  related_release_flag = true

  # TODO: bind IAM role

  name = "automq_for_kafka_benchmark_broker_${count.index}_${random_id.hash.hex}"
  tags = merge(local.tags, {
    nodeID          = local.broker_kafka_ids[count.index],
    automqClusterID = local.cluster_id,
  })
}

resource "baiducloud_eip" "broker_eip" {
  count = var.instance_cnt["broker"]

  payment_timing    = "Postpaid"
  billing_method    = "ByTraffic"
  bandwidth_in_mbps = 32

  name = "automq_for_kafka_benchmark_broker_eip_${count.index}_${random_id.hash.hex}"
  tags = local.tags
}

resource "baiducloud_eip_association" "broker_eip_association" {
  count = var.instance_cnt["broker"]

  eip           = baiducloud_eip.broker_eip[count.index].eip
  instance_id   = baiducloud_instance.broker[count.index].id
  instance_type = "BCC"
}

resource "baiducloud_instance" "client" {
  image_id          = var.ami
  instance_spec     = var.instance_type["client"]
  keypair_id        = baiducloud_bcc_key_pair.benchmark_key_pair.id
  availability_zone = element(var.az, count.index % length(var.az))
  subnet_id         = element(baiducloud_subnet.benchmark_subnet.*.id, count.index % length(var.az))
  security_groups   = [baiducloud_security_group.benchmark_security_group.id]
  count             = var.instance_cnt["client"]

  root_disk_storage_type = "cloud_hp1"
  root_disk_size_in_gb   = 40

  related_release_flag = true

  # TODO: bind IAM role

  name = "automq_for_kafka_benchmark_client_${count.index}_${random_id.hash.hex}"
  tags = local.tags
}

resource "baiducloud_eip" "client_eip" {
  count = var.instance_cnt["client"]

  payment_timing    = "Postpaid"
  billing_method    = "ByTraffic"
  bandwidth_in_mbps = 32

  name = "automq_for_kafka_benchmark_client_eip_${count.index}_${random_id.hash.hex}"
  tags = local.tags
}

resource "baiducloud_eip_association" "client_eip_association" {
  count = var.instance_cnt["client"]

  eip           = baiducloud_eip.client_eip[count.index].eip
  instance_id   = baiducloud_instance.client[count.index].id
  instance_type = "BCC"
}

resource "baiducloud_bos_bucket" "benchmark_bucket" {
  bucket        = "automq-for-kafka-benchmark-${random_id.hash.hex}"
  acl           = "private"
  force_destroy = true

  tags = local.tags
}

output "user" {
  value = var.user
}

output "server_ssh_host" {
  value = var.instance_cnt["server"] > 0 ? baiducloud_eip.server_eip[0].eip : null
}

output "server_ssh_hosts" {
  value = baiducloud_eip.server_eip[*].eip
}

output "broker_ssh_host" {
  value = var.instance_cnt["broker"] > 0 ? baiducloud_eip.broker_eip[0].eip : null
}

output "broker_ssh_hosts" {
  value = baiducloud_eip.broker_eip[*].eip
}

output "client_ssh_host" {
  value = var.instance_cnt["client"] > 0 ? baiducloud_eip.client_eip[0].eip : null
}

output "client_ssh_hosts" {
  value = baiducloud_eip.client_eip[*].eip
}

resource "local_file" "hosts_ini" {
  content = templatefile("${path.module}/hosts.ini.tpl",
    {
      server            = baiducloud_instance.server,
      server_public_ips = baiducloud_eip.server_eip[*].eip,
      server_kafka_ids  = local.server_kafka_ids,
      broker            = baiducloud_instance.broker,
      broker_public_ips = baiducloud_eip.broker_eip[*].eip,
      broker_kafka_ids  = local.broker_kafka_ids,
      client            = baiducloud_instance.client,
      client_public_ips = baiducloud_eip.client_eip[*].eip,
      # use the first client (if exist) for telemetry
      telemetry = var.instance_cnt["client"] > 0 ? slice(baiducloud_instance.client, 0, 1) : [],
      telemetry_public_ips = var.instance_cnt["client"] > 0 ? slice(baiducloud_eip.client_eip[*].eip, 0, 1) : [],

      ssh_user = var.user,

      bos_region = var.region,
      bos_bucket = baiducloud_bos_bucket.benchmark_bucket.bucket,
      cluster_id = local.cluster_id,

      access_key = var.access_key,
      secret_key = var.secret_key,
      role_name  = "none", # TODO: bind IAM role

      # convert Gbps to Bps
      network_bandwidth = format("%.0f", var.instance_bandwidth_Gbps * 1024 * 1024 * 1024 / 8),
    }
  )
  filename = "${path.module}/hosts.ini"
}
