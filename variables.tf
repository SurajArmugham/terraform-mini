# -----------------------------------------------------------------------------
# Root inputs. Every one has a default, so `terraform plan` works with no
# extra input. Override in terraform.tfvars (git-ignored) or with
# TF_VAR_<name> environment variables.
# -----------------------------------------------------------------------------

variable "region" {
  description = "AWS region for all resources."
  type        = string
  default     = "eu-north-1" # Stockholm
}

variable "aws_profile" {
  description = "Profile name in ~/.aws/credentials (created with `aws configure --profile`)."
  type        = string
  default     = "tf-mini"
}

variable "project_name" {
  description = "Name prefix and Project tag for every resource."
  type        = string
  default     = "terraform-mini" # matches the AWS project name
}

variable "instance_type" {
  description = "EC2 size. The module only allows free-tier types (t3.micro in eu-north-1)."
  type        = string
  default     = "t3.micro"
}

variable "availability_zone" {
  description = "AZ inside var.region whose default subnet hosts the instance."
  type        = string
  default     = "eu-north-1a"
}

variable "ssh_public_key_path" {
  description = "Path to your SSH PUBLIC key. Its private half stays on this laptop."
  type        = string
  default     = "~/.ssh/tf-mini-ec2.pub"
}
