provider "aws" {
  region = "us-east-1"
}

# will create resourced based on this module
module "aws_humangov_infrastructure" {
  source     = "./modules/aws_humangov_infrastructure"
  for_each   = toset(var.states)
  state_name = each.value #module will receive this variable with the same name
}