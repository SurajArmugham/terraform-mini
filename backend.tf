# -----------------------------------------------------------------------------
# WHERE Terraform keeps its state (the record of what it created).
#
# "local" = a file on this laptop. It lives OUTSIDE the repo so that:
#   - it is never committed (the repo is public), and
#   - the GitHub runner's checkout folder, wiped every job, can't delete it.
#
# Backend blocks can't use variables, ~ or $HOME, so the path is absolute.
# After changing it, run `terraform init -migrate-state`.
# -----------------------------------------------------------------------------

terraform {
  backend "local" {
    path = "/Users/suraj_armugham/terraform_state/.terraform-state/ec2-mini/terraform.tfstate"
  }
}
