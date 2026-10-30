# -----------------------------------------------------------------------------
# Which Terraform and provider versions this project works with.
# `terraform init` downloads providers matching these constraints and records
# the exact versions in .terraform.lock.hcl (commit that file).
# -----------------------------------------------------------------------------

terraform {
  required_version = ">= 1.6"

  required_providers {
    # Talks to the AWS APIs (EC2, VPC lookups, ...).
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0" # any 6.x, never 7.0
    }

    # Makes a plain HTTPS GET. Used only to discover the laptop's public IP.
    http = {
      source  = "hashicorp/http"
      version = "~> 3.0"
    }
  }
}
