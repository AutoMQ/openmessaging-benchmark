public_key_path = "~/.ssh/automq_for_kafka.pub"
region          = "bj"
az              = ["cn-bj-d", "cn-bj-f"]

ami             = "m-UxUl63JI" // Ubuntu 22.04 LTS (64bit)
user            = "root"

instance_type = {
  "server"              = "bcc.m5.c2m16"
  "broker"              = "bcc.m5.c2m16"
  "client"              = "bcc.g5.c4m16"
}

instance_cnt = {
  "server"              = 1
  "broker"              = 0
  "client"              = 1
}

instance_bandwidth_Gbps = 1.5

# Note: Spot instance is not supported by Terraform in Baidu Cloud, this parameter is ignored.
spot = true

cds_disk_type = "enhanced_ssd_pl1"
cds_disk_size = 20

access_key = "your_access_key"
secret_key = "your_secret_key"
