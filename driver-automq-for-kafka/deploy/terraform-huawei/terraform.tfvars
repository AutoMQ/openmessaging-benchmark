public_key_path = "~/.ssh/automq_for_kafka.pub"
region          = "cn-north-4"
az              = ["cn-north-4a", "cn-north-4g"]

ami             = "89ac6e18-d938-4b0d-b038-bcdb03a1b87f" // Ubuntu 22.04 server 64bit
user            = "root"

instance_type = {
  "server"              = "c6.xlarge.4"
  "broker"              = "c6.xlarge.4"
  "client"              = "c6.xlarge.4"
}

instance_cnt = {
  "server"              = 1
  "broker"              = 0
  "client"              = 1
}

instance_bandwidth_Gbps = 2.4

evs_volume_type = "SSD"
evs_volume_size = 20

access_key = "your_access_key"
secret_key = "your_secret_key"
