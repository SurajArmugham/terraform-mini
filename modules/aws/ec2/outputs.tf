# -----------------------------------------------------------------------------
# Module outputs: values handed back to the caller as module.ec2.<name>.
# -----------------------------------------------------------------------------

output "instance_id" {
  description = "ID of the EC2 instance (e.g. i-0abc123...)."
  value       = aws_instance.this.id
}

output "public_ip" {
  description = "Public IPv4 address used for SSH."
  value       = aws_instance.this.public_ip
}
