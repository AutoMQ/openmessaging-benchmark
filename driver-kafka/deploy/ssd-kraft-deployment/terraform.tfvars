public_key_path = "~/.ssh/kafka_aws.pub"
region          = "us-west-2"
az              = "us-west-2a"
ami             = "ami-03f65b8614a860c29" // Ubuntu 22.04 LTS for x86_64
// ami = "ami-08133f9f7ea98ef23" Ubuntu 22.04 LTS for arm64

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
