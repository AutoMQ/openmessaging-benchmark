public_key_path = "~/.ssh/automq_for_kafka.pub"
region          = "cn-hangzhou"
az              = ["cn-hangzhou-j", "cn-hangzhou-k"]

ami             = "ubuntu_22_04_x64_20G_alibase_20231221.vhd"
user            = "root"

instance_type = {
  "server"              = "ecs.r7.large"
  "broker"              = "ecs.r7.large"
  "client"              = "ecs.g7.xlarge"
}

instance_cnt = {
  "server"              = 1
  "broker"              = 2
  "client"              = 2
}

instance_bandwidth_Gbps = 2.0

spot = true

ebs_category = "cloud_essd"
ebs_performance_level = "PL1"
ebs_volume_size = 20

access_key = "your_access_key"
secret_key = "your_secret_key"
