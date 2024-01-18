provider "aws" {
  region = "us-east-1"
}


# chamada do módulo em loop à partir do array de variáveis
module "aws_humangov_infrastructure" {
  source     = "./modules/aws_humangov_infrastructure"
  for_each   = toset(var.states)
  state_name = each.value
}