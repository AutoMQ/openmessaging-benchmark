public_key_path = "~/.ssh/automq_for_kafka.pub"
region          = "ap-beijing"
az              = ["ap-beijing-6", "ap-beijing-7", "ap-beijing-8"]

ami             = "img-487zeit5" # Ubuntu Server 22.04 LTS 64bit
user            = "ubuntu"

instance_type = {
  "server"              = "SA5.LARGE16"
  "broker"              = "SA5.LARGE16"
  "client"              = "SA5.LARGE16"
}

instance_cnt = {
  "server"              = 1
  "broker"              = 0
  "client"              = 1
}

instance_bandwidth_Gbps = 1.5

cbs_disk_type = "CLOUD_HSSD"
cbs_disk_size = 20

secret_id = "your_access_key"
secret_key = "your_secret_key"
