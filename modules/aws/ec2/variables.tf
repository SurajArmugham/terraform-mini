# -----------------------------------------------------------------------------
# Module inputs. The caller (root main.tf) passes these in the `module "ec2"`
# block. Variables without a default MUST be provided by the caller.
# -----------------------------------------------------------------------------

variable "project_name" {
  description = "Name prefix for every resource (security group, key pair, instance Name tag)."
  type        = string
}

variable "instance_type" {
  description = "EC2 size. Restricted to free-tier, x86 types so the AMI always matches and cost stays $0."
  type        = string
  default     = "t3.micro"

  # Guardrail: `plan` fails early if someone sets a paid or ARM instance type.
  validation {
    condition     = contains(["t2.micro", "t3.micro"], var.instance_type)
    error_message = "instance_type must be t2.micro or t3.micro (free tier, x86)."
  }
}

variable "availability_zone" {
  description = "AZ whose default subnet hosts the instance. Must be in the provider's region (eu-north-1)."
  type        = string
  default     = "eu-north-1a"
}

variable "ssh_cidr" {
  description = "The only CIDR allowed to SSH in, e.g. \"203.0.113.10/32\" (your laptop's public IP)."
  type        = string
  sensitive   = true # hides your home IP in plan output (GitHub Actions logs are public)

  validation {
    condition     = can(cidrhost(var.ssh_cidr, 0))
    error_message = "ssh_cidr must be a valid CIDR such as 203.0.113.10/32."
  }
}

variable "public_key" {
  description = "Contents of your SSH PUBLIC key (the .pub file). AWS puts it on the VM at first boot."
  type        = string
}
