public_key_path = "~/.ssh/elasticstream_aws.pub"
region          = "us-east-1"
az              = "us-east-1c"
ami             = "ami-053b0d53c279acc90" // Ubuntu 22.04 LTS 20230516 Release

instance_type = {
  "placement-manager" = "m5n.large"    // TODO
  "data-node"         = "i4i.2xlarge"  // TODO
  "client"            = "i3en.2xlarge" // TODO
}

instance_cnt = {
  "placement-manager" = 3
  "data-node"         = 3
  "client"            = 0 // TODO
}
