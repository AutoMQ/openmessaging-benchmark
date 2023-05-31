public_key_path = "~/.ssh/kafka_on_es_aws.pub"
region          = "us-west-2"
az              = "us-west-2a"
ami             = "ami-03f65b8614a860c29" // Ubuntu 22.04 LTS 20230516 Release

instance_type = {
  "placement-manager" = "m5n.large"    // TODO
  "data-node"         = "i4i.2xlarge"  // TODO
  "mixed-pm-dn"       = "i4i.2xlarge"  // TODO

  "broker"            = "i4i.4xlarge"
  "controller"        = "i3en.2xlarge"
  "client"            = "m5n.8xlarge"
}

instance_cnt = {
  "placement-manager" = 1
  "data-node"         = 2
  "mixed-pm-dn"       = 0

  "client"            = 4
  "broker"            = 0
  "controller"        = 1
}
