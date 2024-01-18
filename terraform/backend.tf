terraform {
  backend "s3" {
    bucket         = "humangov-terraform-state-file" # bucket
    key            = "terraform.tfstate"             # state file of terraform
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "humangov-terraform-state-lock-table" # dynamodb table
  }
}
