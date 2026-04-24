terraform {
  backend "s3" {
    bucket = "my-terraform-state-bucket6"
    key    = "dev/terraform.tfstate"
    region = "us-east-1"
  }
}