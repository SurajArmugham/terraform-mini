# -----------------------------------------------------------------------------
# Provider configuration: HOW Terraform connects to AWS.
# -----------------------------------------------------------------------------

provider "aws" {
  region  = var.region      # every resource is created in this region
  profile = var.aws_profile # reads the access key from ~/.aws/credentials

  # Added to EVERY resource this provider creates, so they're easy to find
  # in the console (Resource Groups & Tag Editor → filter Project = terraform-mini).
  default_tags {
    tags = {
      Project   = var.project_name
      ManagedBy = "terraform"
    }
  }
}

# The http provider needs no configuration.
