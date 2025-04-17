public_key_path = "~/.ssh/automq_for_kafka.pub"
region          = "us-east-1"
az              = ["us-east-1a"]

ami             = "ami-0f9de6e2d2f067fca" // Ubuntu 22.04 LTS for x86_64
user            = "ubuntu"

instance_type = {
  "server"              = "r6in.large"
  "broker"              = "r6in.large"
  "client"              = "m6in.xlarge"
}

instance_cnt = {
  "server"              = 0
  "broker"              = 0
  "client"              = 8
}

instance_bandwidth_Gbps = 3.125

monitoring = true
spot = true

ebs_volume_type = "gp3"
ebs_volume_size = 10
ebs_iops = 3000

access_key = "your_access_key"
secret_key = "your_secret_key"

aws_cn = false
