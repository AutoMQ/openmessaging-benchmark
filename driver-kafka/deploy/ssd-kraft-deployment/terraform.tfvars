public_key_path = "~/.ssh/kafka_aws.pub"
region          = "us-west-2"
az              = "us-west-2a"
ami             = "ami-03f65b8614a860c29" // Ubuntu 22.04 LTS for x86_64
// ami = "ami-08133f9f7ea98ef23" Ubuntu 22.04 LTS for arm64

instance_types = {
  "broker"     = "r6in.large"
  "controller" = "r6in.large"
  "client"     = "m5n.2xlarge"
}

num_instances = {
  "client"     = 1
  "broker"     = 3
  "controller" = 1
}

monitoring = true

ebs_volume_type = "gp3"
ebs_volume_size = 10
ebs_iops = 3000
