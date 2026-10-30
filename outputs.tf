# -----------------------------------------------------------------------------
# Printed after `terraform apply`. Re-print any time with `terraform output`.
# -----------------------------------------------------------------------------

output "instance_id" {
  description = "EC2 instance ID (find it in the console: EC2 → Instances)."
  value       = module.ec2.instance_id
}

output "public_ip" {
  description = "Public IPv4 address of the VM."
  value       = module.ec2.public_ip
}

output "ssh_allowed_cidr" {
  description = "The only address allowed to SSH in. If SSH times out, check this still matches your IP."
  value       = local.ssh_cidr
  sensitive   = true # hidden in logs; view with: terraform output -raw ssh_allowed_cidr
}

output "ssh_command" {
  description = "Copy-paste this to log in."
  value       = "ssh -i ${trimsuffix(var.ssh_public_key_path, ".pub")} ec2-user@${module.ec2.public_ip}"
}
