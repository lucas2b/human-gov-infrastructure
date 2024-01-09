# setting the backend configuration pointing to AWS infrastructure
# S3 bucket will handle tfstate file
# Dynamodb will handle the terraform lock file
terraform {
  backend "s3" {
    bucket         = "humangov-terraform-state-file"
    key            = "terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "humangov-terraform-state-lock-table"
  }
}
