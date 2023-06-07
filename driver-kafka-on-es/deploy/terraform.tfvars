public_key_path = "~/.ssh/kafka_on_es_aws.pub"
region          = "us-west-2"
az              = "us-west-2a"

ami             = "ami-0744bdf45532dfd8e" // Debian 11 (HVM) 20221003 Release
user            = "admin"
// ami             = "ami-03f65b8614a860c29" // Ubuntu 22.04 LTS 20230516 Release
// user            = "ubuntu"

instance_type = {
  "placement-manager"   = "i4i.2xlarge"
  "controller"          = "i4i.2xlarge"
  "mixed-pm-ctrl"       = "i4i.2xlarge"

  "data-node"           = "i4i.4xlarge"
  "broker"              = "i4i.4xlarge"
  "mixed-dn-bkr"        = "i4i.4xlarge"

  "client"              = "m5n.8xlarge"
}

instance_cnt = {
  "placement-manager"   = 0
  "controller"          = 0
  "mixed-pm-ctrl"       = 3

  "data-node"           = 0
  "broker"              = 0
  "mixed-dn-bkr"        = 3

  "client"              = 4
}
