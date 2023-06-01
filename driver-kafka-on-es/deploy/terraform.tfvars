public_key_path = "~/.ssh/kafka_on_es_aws.pub"
region          = "us-west-2"
az              = "us-west-2a"
ami             = "ami-03f65b8614a860c29" // Ubuntu 22.04 LTS 20230516 Release

instance_type = {
  "placement-manager"   = "i4i.2xlarge"
  "controller"          = "i4i.2xlarge"
  "mixed-pm-ctrl"       = "i4i.2xlarge"

  "data-node"           = "i4i.2xlarge"
  "broker"              = "i4i.2xlarge"
  "mixed-dn-bkr"        = "i4i.2xlarge"

  "client"              = "m5n.xlarge"
}

instance_cnt = {
  "placement-manager"   = 1
  "controller"          = 1
  "mixed-pm-ctrl"       = 2

  "data-node"           = 1
  "broker"              = 1
  "mixed-dn-bkr"        = 1

  "client"              = 1
}
