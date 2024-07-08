
provider "aws" {
  access_key = ""
  secret_key = ""
  region     = "us-west-2"
}
/*
resource "aws_instance" "test-instance" {
	ami = "ami-0aff18ec83b712f05"
	instance_type = "t2.micro"
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  name = "dev-vpc"

  cidr = "10.0.0.0/16"

  azs             = ["us-west-2a"]
  private_subnets = ["10.0.1.0/24"]
  public_subnets  = ["10.0.101.0/24"]

  enable_nat_gateway = true
  enable_vpn_gateway = false

  tags = {
    Terraform = "true"
    Environment = "dev"
  }
}

output "vpc_id" {
  value = module.vpc.vpc_id
}


output "private_subnet_ids" {
  value = module.vpc.private_subnets
}

output "public_subnet_ids" {
  value = module.vpc.public_subnets
}
*/
