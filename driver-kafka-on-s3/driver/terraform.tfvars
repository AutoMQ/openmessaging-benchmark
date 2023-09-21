public_key_path = "~/.ssh/kafka_on_s3_aws.pub"
region          = "cn-northwest-1"
az              = "cn-northwest-1a"

# ami             = "ami-0744bdf45532dfd8e" // Debian 11 (HVM) 20221003 Release x86_64
# ami             = "ami-052c97e98f1d8d870" // Debian 11 (HVM) 20221003 Release arm64
# user            = "admin"
ami             = "ami-04c77a27ae5156100" // Canonical, Ubuntu, 22.04 LTS, amd64 jammy image build on 2023-03-03
user            = "ubuntu"

instance_type = {
  "server"              = "r6i.large"
  "client"              = "m6i.xlarge"
}

instance_cnt = {
  "server"              = 3
  "client"              = 4
}

monitoring = true

ebs_volume_type = "gp3"
ebs_volume_size = 10
ebs_iops = 3000
