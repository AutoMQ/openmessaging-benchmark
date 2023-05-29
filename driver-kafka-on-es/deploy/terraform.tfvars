public_key_path = "~/.ssh/kafka_on_es_aws.pub"
region          = "us-west-2"
az              = "us-west-2a"
ami             = "ami-053b0d53c279acc90" // Ubuntu 22.04 LTS 20230516 Release

instance_type = {
  "placement-manager" = "m5n.large"    // TODO
  "data-node"         = "i4i.2xlarge"  // TODO
  "broker"            = "i3en.6xlarge"
  "controller"        = "i3en.2xlarge"
  "client"            = "m5n.8xlarge"
}

instance_cnt = {
  "placement-manager" = 3
  "data-node"         = 3
  "client"            = 2
  "broker"            = 0
  "controller"        = 3
}
