provider "huaweicloud" {
  region     = var.region
  access_key = var.access_key
  secret_key = var.secret_key
}

provider "random" {}

terraform {
  required_providers {
    huaweicloud = {
      source  = "huaweicloud/huaweicloud"
      version = "1.70.1"
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

variable "evs_volume_type" {
  type = string
}

variable "evs_volume_size" {
  type = number
}

variable "access_key" {}

variable "secret_key" {}

locals {
  tags = {
    Benchmark    = "automq_for_kafka_${random_id.hash.hex}"
    automqVendor = "automq"
  }
  cluster_id       = "M_benchmark_huawei___A"
  server_kafka_ids = { for i in range(var.instance_cnt["server"]) : i => i + 1 }
  broker_kafka_ids = { for i in range(var.instance_cnt["broker"]) : i => var.instance_cnt["server"] + i + 1 }
}

resource "huaweicloud_vpc" "benchmark_vpc" {
  cidr = "10.0.0.0/16"

  name = "automq_for_kafka_benchmark_vpc_${random_id.hash.hex}"
  tags = local.tags
}

resource "huaweicloud_vpc_subnet" "benchmark_subnet" {
  count             = length(var.az)
  vpc_id            = huaweicloud_vpc.benchmark_vpc.id
  cidr              = cidrsubnet(huaweicloud_vpc.benchmark_vpc.cidr, 8, count.index)
  gateway_ip        = cidrhost(cidrsubnet(huaweicloud_vpc.benchmark_vpc.cidr, 8, count.index), 1)
  availability_zone = element(var.az, count.index)
  dns_list          = ["100.125.1.250", "100.125.129.250"]

  name = "automq_for_kafka_benchmark_subnet_${count.index}_${random_id.hash.hex}"
  tags = local.tags
}

resource "huaweicloud_networking_secgroup" "benchmark_secgroup" {
  delete_default_rules = true

  name = "automq_for_kafka_benchmark_secgroup_${random_id.hash.hex}"
  tags = local.tags
}

resource "huaweicloud_networking_secgroup_rule" "benchmark_secgroup_rule_ssh" {
  security_group_id = huaweicloud_networking_secgroup.benchmark_secgroup.id
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = "0.0.0.0/0"
}

resource "huaweicloud_networking_secgroup_rule" "benchmark_secgroup_rule_grafana" {
  security_group_id = huaweicloud_networking_secgroup.benchmark_secgroup.id
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 3000
  port_range_max    = 3000
  remote_ip_prefix  = "0.0.0.0/0"
}

resource "huaweicloud_networking_secgroup_rule" "benchmark_secgroup_rule_within_vpc" {
  security_group_id = huaweicloud_networking_secgroup.benchmark_secgroup.id
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 1
  port_range_max    = 65535
  remote_ip_prefix  = huaweicloud_vpc.benchmark_vpc.cidr
}

resource "huaweicloud_networking_secgroup_rule" "benchmark_secgroup_rule_outbound" {
  security_group_id = huaweicloud_networking_secgroup.benchmark_secgroup.id
  direction         = "egress"
  ethertype         = "IPv4"
}

resource "huaweicloud_kps_keypair" "benchmark_keypair" {
  name       = "automq_for_kafka_benchmark_keypair_${random_id.hash.hex}"
  public_key = file(var.public_key_path)
}

resource "huaweicloud_identity_role" "benchmark_policy" {
  name        = "automq_for_kafka_benchmark_policy_${random_id.hash.hex}"
  description = "AutoMQ for Kafka Benchmark Policy"
  type        = "AX"
  policy      = <<EOF
{
  "Version": "1.1",
  "Statement": [
    {
      "Action": [
        "obs:object:PutObject",
        "obs:object:AbortMultipartUpload",
        "obs:object:GetObject",
        "obs:object:DeleteObject"
      ],
      "Effect": "Allow",
      "Resource": [
        "obs:*:*:object:${huaweicloud_obs_bucket.benchmark_bucket.bucket}/*"
      ]
    },
    {
      "Action": [
        "obs:bucket:ListBucket"
      ],
      "Effect": "Allow",
      "Resource": [
        "obs:*:*:bucket:${huaweicloud_obs_bucket.benchmark_bucket.bucket}"
      ]
    }
  ]
}
EOF
}

resource "huaweicloud_identity_agency" "benchmark_agency" {
  name                   = "automq_for_kafka_benchmark_agency_${random_id.hash.hex}"
  delegated_service_name = "op_svc_ecs"

  all_resources_roles = [
    huaweicloud_identity_role.benchmark_policy.name,
  ]
}

resource "huaweicloud_compute_instance" "server" {
  image_id  = var.ami
  flavor_id = var.instance_type["server"]
  key_pair  = huaweicloud_kps_keypair.benchmark_keypair.name
  network {
    uuid = element(huaweicloud_vpc_subnet.benchmark_subnet.*.id, count.index % length(var.az))
  }
  security_group_ids = [huaweicloud_networking_secgroup.benchmark_secgroup.id]
  count              = var.instance_cnt["server"]

  eip_type = "5_bgp"
  bandwidth {
    share_type  = "PER"
    size        = 64
    charge_mode = "traffic"
  }

  charging_mode = var.spot ? "spot" : "postPaid"
  spot_duration = 6
  spot_duration_count = 2

  system_disk_type = "SSD"
  system_disk_size = 20

  data_disks {
    type = var.evs_volume_type
    size = var.evs_volume_size
  }
  delete_disks_on_termination = true

  agency_name = huaweicloud_identity_agency.benchmark_agency.name

  name = "automq_for_kafka_benchmark_server_${count.index}_${random_id.hash.hex}"
  tags = merge(local.tags, {
    nodeID          = local.server_kafka_ids[count.index],
    automqClusterID = local.cluster_id,
  })
}

resource "huaweicloud_compute_instance" "broker" {
  image_id  = var.ami
  flavor_id = var.instance_type["broker"]
  key_pair  = huaweicloud_kps_keypair.benchmark_keypair.name
  network {
    uuid = element(huaweicloud_vpc_subnet.benchmark_subnet.*.id, count.index % length(var.az))
  }
  security_group_ids = [huaweicloud_networking_secgroup.benchmark_secgroup.id]
  count              = var.instance_cnt["broker"]

  eip_type = "5_bgp"
  bandwidth {
    share_type  = "PER"
    size        = 64
    charge_mode = "traffic"
  }

  charging_mode = var.spot ? "spot" : "postPaid"
  spot_duration = 6
  spot_duration_count = 2

  system_disk_type = "SSD"
  system_disk_size = 20

  data_disks {
    type = var.evs_volume_type
    size = var.evs_volume_size
  }
  delete_disks_on_termination = true

  agency_name = huaweicloud_identity_agency.benchmark_agency.name

  name = "automq_for_kafka_benchmark_broker_${count.index}_${random_id.hash.hex}"
  tags = merge(local.tags, {
    nodeID          = local.broker_kafka_ids[count.index],
    automqClusterID = local.cluster_id,
  })
}

resource "huaweicloud_compute_instance" "client" {
  image_id  = var.ami
  flavor_id = var.instance_type["client"]
  key_pair  = huaweicloud_kps_keypair.benchmark_keypair.name
  network {
    uuid = element(huaweicloud_vpc_subnet.benchmark_subnet.*.id, count.index % length(var.az))
  }
  security_group_ids = [huaweicloud_networking_secgroup.benchmark_secgroup.id]
  count              = var.instance_cnt["client"]

  eip_type = "5_bgp"
  bandwidth {
    share_type  = "PER"
    size        = 64
    charge_mode = "traffic"
  }

  charging_mode = var.spot ? "spot" : "postPaid"
  spot_duration = 6
  spot_duration_count = 2

  system_disk_type = "SSD"
  system_disk_size = 20

  agency_name = huaweicloud_identity_agency.benchmark_agency.name

  name = "automq_for_kafka_benchmark_client_${count.index}_${random_id.hash.hex}"
  tags = local.tags
}

resource "huaweicloud_obs_bucket" "benchmark_bucket" {
  bucket        = "automq-for-kafka-benchmark-${random_id.hash.hex}"
  acl           = "private"
  force_destroy = true

  tags = local.tags
}

output "user" {
  value = var.user
}

output "server_ssh_host" {
  value = var.instance_cnt["server"] > 0 ? huaweicloud_compute_instance.server[0].public_ip : null
}

output "server_ssh_hosts" {
  value = huaweicloud_compute_instance.server[*].public_ip
}

output "broker_ssh_host" {
  value = var.instance_cnt["broker"] > 0 ? huaweicloud_compute_instance.broker[0].public_ip : null
}

output "broker_ssh_hosts" {
  value = huaweicloud_compute_instance.broker[*].public_ip
}

output "client_ssh_host" {
  value = var.instance_cnt["client"] > 0 ? huaweicloud_compute_instance.client[0].public_ip : null
}

output "client_ssh_hosts" {
  value = huaweicloud_compute_instance.client[*].public_ip
}

resource "local_file" "hosts_ini" {
  content = templatefile("${path.module}/hosts.ini.tpl",
    {
      server           = huaweicloud_compute_instance.server,
      server_kafka_ids = local.server_kafka_ids,
      broker           = huaweicloud_compute_instance.broker,
      broker_kafka_ids = local.broker_kafka_ids,
      client           = huaweicloud_compute_instance.client,
      # use the first client (if exist) for telemetry
      telemetry = var.instance_cnt["client"] > 0 ? slice(huaweicloud_compute_instance.client, 0, 1) : [],

      ssh_user = var.user,

      obs_region = var.region,
      obs_bucket = huaweicloud_obs_bucket.benchmark_bucket.bucket,
      cluster_id = local.cluster_id,

      access_key = var.access_key,
      secret_key = var.secret_key,
      role_name  = huaweicloud_identity_role.benchmark_policy.name,

      # convert Gbps to Bps
      network_bandwidth = format("%.0f", var.instance_bandwidth_Gbps * 1024 * 1024 * 1024 / 8),
    }
  )
  filename = "${path.module}/hosts.ini"
}
