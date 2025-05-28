// ────────────────────────────────────────────────────────────────────────────
// main.tf — configure Terraform and the AWS provider
// ────────────────────────────────────────────────────────────────────────────

terraform {
  // Tell Terraform which providers and versions we need
  required_providers {
    aws = {
      source  = "hashicorp/aws" // official AWS provider
      version = "~> 5.0"        // any 5.x release
    }
  }

  // (Optional) enforce a minimum Terraform CLI version
  required_version = ">= 1.0.0"
}

provider "aws" {
  region  = "af-south-1" // Cape Town region
  profile = "terraform"  // AWS CLI profile to use for credentials
}

// Lookup the default VPC so we can build subnets and SGs
data "aws_vpc" "default" {
  default = true // returns the one default VPC in the account
}
