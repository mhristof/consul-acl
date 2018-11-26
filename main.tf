provider "aws" {
  region = "eu-west-1"
}

resource "aws_key_pair" "user" {
  key_name   = "user"
  public_key = "${file("~/.ssh/id_rsa.key.pub")}"
}

data "aws_ami" "ubuntu" {
    most_recent = true

    filter {
        name   = "name"
        values = ["ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-amd64-server-*"]
    }

    filter {
        name   = "virtualization-type"
        values = ["hvm"]
    }

    owners = ["099720109477"] # Canonical
}


module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "my-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
  public_subnets  = ["10.0.101.0/24"]

  enable_nat_gateway = true

  tags = {
    Terraform = "true"
    Environment = "dev"
  }
}

resource "aws_security_group_rule" "allow_all" {
  type            = "ingress"
  from_port       = 22
  to_port         = 22
  protocol        = "tcp"
  cidr_blocks     = ["0.0.0.0/0"]

  security_group_id = "${module.vpc.default_security_group_id}"
}

# Create an IAM role for the auto-join
resource "aws_iam_role" "consul-join" {
  name               = "consul-join"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_policy" "consul-join" {
  name        = "consul-join"
  description = "Allows Consul nodes to describe instances for joining."
  policy      = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "ec2:DescribeInstances",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_policy_attachment" "consul-join" {
  name       = "consul-join"
  roles      = ["${aws_iam_role.consul-join.name}"]
  policy_arn = "${aws_iam_policy.consul-join.arn}"
}

resource "aws_iam_instance_profile" "consul-join" {
  name  = "consul-join"
  role = "${aws_iam_role.consul-join.name}"
}

module "ec2_cluster_leader" {
  source                 = "terraform-aws-modules/ec2-instance/aws"
  version                = "1.12.0"
  associate_public_ip_address   =  true

  name                   = "consul_leaders"
  instance_count         = 3

  ami                    = "${data.aws_ami.ubuntu.id}"
  instance_type          = "t2.micro"
  key_name               = "${aws_key_pair.user.id}"
  monitoring             = false
  vpc_security_group_ids = ["${module.vpc.default_security_group_id}"]
  subnet_id              = "${module.vpc.public_subnets[0]}"
  iam_instance_profile = "${aws_iam_instance_profile.consul-join.name}"


  tags = {
    Terraform = "true"
    Environment = "dev"
    ansible_group = "consul-leaders"
    leader = "true"
  }
}

module "ec2_cluster" {
  source                 = "terraform-aws-modules/ec2-instance/aws"
  version                = "1.12.0"
  associate_public_ip_address   =  true

  name                   = "consul"
  instance_count         = 2

  ami                    = "${data.aws_ami.ubuntu.id}"
  instance_type          = "t2.micro"
  key_name               = "${aws_key_pair.user.id}"
  monitoring             = false
  vpc_security_group_ids = ["${module.vpc.default_security_group_id}"]
  subnet_id              = "${module.vpc.public_subnets[0]}"
  iam_instance_profile = "${aws_iam_instance_profile.consul-join.name}"


  tags = {
    Terraform = "true"
    Environment = "dev"
    ansible_group = "consul"
    leader = "false"
  }
}
