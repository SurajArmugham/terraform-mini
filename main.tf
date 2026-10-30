# -----------------------------------------------------------------------------
# Root module: the entry point Terraform runs. It gathers inputs and calls
# the reusable ec2 module, which does the actual work.
# -----------------------------------------------------------------------------

# Ask a public service for this laptop's public IP (a plain-text reply such as
# "203.0.113.10\n"). Because CI also runs on this laptop, it gets the same IP.
data "http" "my_ip" {
  url = "https://checkip.amazonaws.com"

  lifecycle {
    postcondition {
      condition     = self.status_code == 200
      error_message = "Could not look up the public IP from checkip.amazonaws.com."
    }
  }
}

locals {
  # "203.0.113.10\n" → "203.0.113.10/32" (/32 = exactly this one address)
  ssh_cidr = "${trimspace(data.http.my_ip.response_body)}/32"
}

module "ec2" {
  source = "./modules/aws/ec2" # path to the module folder

  # Each argument here fills a variable in modules/aws/ec2/variables.tf.
  project_name      = var.project_name
  instance_type     = var.instance_type
  availability_zone = var.availability_zone
  ssh_cidr          = local.ssh_cidr
  public_key        = file(pathexpand(var.ssh_public_key_path)) # pathexpand turns ~ into /Users/<you>
}
