public_key_path = "~/.ssh/kafka_aws.pub"
region          = "us-west-2"
az              = "us-west-2a"
ami             = "ami-03f65b8614a860c29" // Ubuntu 22.04 LTS 20230516 Release

instance_types = {
  "broker"     = "i4i.4xlarge"
  "controller" = "i4i.2xlarge"
  "client"     = "m5n.8xlarge"
}

num_instances = {
  "client"     = 4
  "broker"     = 3
  "controller" = 3
}
