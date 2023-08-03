public_key_path = "~/.ssh/kafka_on_es_aws.pub"
region          = "us-west-2"
az              = "us-west-2a"

ami             = "ami-0744bdf45532dfd8e" // Debian 11 (HVM) 20221003 Release x86_64
# ami             = "ami-052c97e98f1d8d870" // Debian 11 (HVM) 20221003 Release arm64
user            = "admin"
// ami             = "ami-03f65b8614a860c29" // Ubuntu 22.04 LTS 20230516 Release
// user            = "ubuntu"

instance_type = {
  "placement-dirver"    = "i4i.2xlarge"
  "controller"          = "i4i.2xlarge"
  "mixed-pd-ctrl"       = "i4i.2xlarge"

  "range-server"        = "i4i.4xlarge"
  "broker"              = "i4i.4xlarge"
  "mixed-rs-bkr"        = "i4i.4xlarge"

  "client"              = "m5n.8xlarge"
}

instance_cnt = {
  "placement-dirver"    = 0
  "controller"          = 0
  "mixed-pd-ctrl"       = 3

  "range-server"        = 0
  "broker"              = 0
  "mixed-rs-bkr"        = 3

  "client"              = 4
}
