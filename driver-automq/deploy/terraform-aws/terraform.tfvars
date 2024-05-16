public_key_path = "~/.ssh/automq_aws.pub"
region          = "us-west-2"
az              = "us-west-2a"

ami             = "ami-03f65b8614a860c29" // Ubuntu 22.04 LTS for x86_64
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

monitoring = true
spot = false

ebs_volume_type = "gp3"
ebs_volume_size = 10
ebs_iops = 3000

access_key = "${AUTOMQ_ACCESS_KEY}"
secret_key = "${AUTOMQ_SECRET_KEY}"

aws_cn = false
