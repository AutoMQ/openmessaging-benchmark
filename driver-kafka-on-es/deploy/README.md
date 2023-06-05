# AutoMQ for Apache Kafka Deployments

## Requirements

- [Terraform](https://www.terraform.io/downloads.html)
  - [Plugin: terraform-inventory](https://github.com/adammck/terraform-inventory)
- [Ansible](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html)
- [AWS CLI Tool](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
  - [Configure AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-quickstart.html)

## Deployments

### Generate SSH Keys

Once you're all set up with AWS and have the necessary tools installed locally, you'll need to create both a public and a private SSH key at `~/.ssh/kafka_on_es_aws` (private) and `~/.ssh/kafka_on_es_aws.pub` (public), respectively. You can do this by running the following command:

```bash
ssh-keygen -f ~/.ssh/kafka_on_es_aws
```

When prompted to enter a passphrase, simply hit `Enter` twice. Then, make sure that the keys have been created:

```bash
ls ~/.ssh/kafka_on_es_aws*
```

Note: `~/.ssh/kafka_on_es_aws` is the default key name used in the `terraform.tfvars` file. If you want to use a different key name, you will need to update the `terraform.tfvars` file accordingly.

### Create Resource Using Terraform

You can create the necessary AWS resources using just a few Terraform commands:

```bash
terraform init
terraform apply
```

When you run `terraform apply`, you will be prompted to type `yes`. Type `yes` to continue with the installation or anything else to quit.

Once the installation is complete, you will see a confirmation message listing the resources that have been installed.

#### Terraform Variables

The `terraform.tfvars` file contains the following variables:

- `public_key_path`: The path to the public key that will be used to access the EC2 instances.
- `region`: The AWS region where the resources will be created.
- `az`: The AWS availability zone where the resources will be created.
- `ami`: The [AMI](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/AMIs.html) ID to use for the EC2 instances.
- `user`: The default user to use when SSHing into the EC2 instances.
- `instance_type`: The EC2 instance type used by the various components
- `instance_cnt`: The number of EC2 instances to create for each component

### Run Ansible Playbook

Once the Terraform installation is complete, you can run the Ansible playbook to install the necessary software and start the **AutoMQ for Apache Kafka** on the EC2 instances:

```bash
ansible-playbook deploy.yaml -i hosts.ini
```

#### SSH into EC2 Instances

You can SSH into the EC2 instances using the following command:

```bash
ssh -i ~/.ssh/kafka_on_es_aws ubuntu@$(terraform output --raw pm_ssh_host)
ssh -i ~/.ssh/kafka_on_es_aws ubuntu@$(terraform output --raw dn_ssh_host)
ssh -i ~/.ssh/kafka_on_es_aws ubuntu@$(terraform output --raw controller_ssh_host)
ssh -i ~/.ssh/kafka_on_es_aws ubuntu@$(terraform output --raw broker_ssh_host)
ssh -i ~/.ssh/kafka_on_es_aws ubuntu@$(terraform output --raw client_ssh_host)
```

### Tear Down

To tear down the resources created by Terraform, run the following command:

```bash
terraform destroy
```

When you run `terraform destroy`, you will be prompted to type `yes`. Type `yes` to continue with the installation or anything else to quit.

Make sure to let the process run to completion (it could take several minutes). Once the tear down is complete, all AWS resources that you created for the Kafka benchmarking suite will have been removed.
