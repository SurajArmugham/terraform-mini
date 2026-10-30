# -----------------------------------------------------------------------------
# Module: aws/ec2
# Creates ONE free-tier EC2 instance inside the account's DEFAULT VPC.
#
#   Reads   (data sources): default VPC, default subnet in one AZ, latest AL2023 AMI
#   Creates (resources)   : security group, key pair, EC2 instance
# -----------------------------------------------------------------------------

# ---- Data sources: look up things that already exist. Nothing is created. ----

# The default VPC that AWS creates in every region of every account.
data "aws_vpc" "default" {
  default = true
}

# The default (public) subnet of that VPC in our chosen AZ.
# Instances here automatically get a public IPv4 and a route to the internet.
data "aws_subnet" "default" {
  vpc_id            = data.aws_vpc.default.id
  availability_zone = var.availability_zone
  default_for_az    = true
}

# Latest Amazon Linux 2023 image for x86_64, published by Amazon itself.
# Needs only ec2:DescribeImages (covered by AmazonEC2FullAccess).
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

# ---- Resources: the 3 things Terraform creates (and later destroys). ----

# Firewall around the VM: SSH (port 22) only from var.ssh_cidr, all outbound allowed.
resource "aws_security_group" "this" {
  name        = "${var.project_name}-ssh"
  description = "SSH from my IP only"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH from my laptop"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_cidr]
  }

  egress {
    description = "All outbound (package updates, etc.)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # -1 = all protocols
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-ssh"
  }
}

# Uploads your PUBLIC key to EC2. The private key never leaves your laptop.
resource "aws_key_pair" "this" {
  key_name   = "${var.project_name}-key"
  public_key = var.public_key
}

# The VM itself. Every cost-related setting is pinned to free-tier values.
resource "aws_instance" "this" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = var.instance_type
  subnet_id                   = data.aws_subnet.default.id
  vpc_security_group_ids      = [aws_security_group.this.id]
  key_name                    = aws_key_pair.this.key_name # cloud-init copies this key to ec2-user at boot
  associate_public_ip_address = true                       # needed to SSH from the internet
  monitoring                  = false                      # detailed CloudWatch monitoring costs extra

  # t3 defaults to "unlimited" CPU bursting, which can bill for extra CPU.
  # "standard" = throttle instead of charging.
  credit_specification {
    cpu_credits = "standard"
  }

  # IMDSv2 only: the secure way for the VM to read its own metadata (incl. your SSH key).
  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  # 8 GB gp3 disk (free tier allows 30 GB). Deleted with the instance so nothing lingers.
  root_block_device {
    volume_type           = "gp3"
    volume_size           = 8
    encrypted             = true # uses the free AWS-managed key
    delete_on_termination = true
  }

  tags = {
    Name = var.project_name
  }

  # Amazon publishes new AL2023 AMIs often. Without this, every new AMI would
  # make `plan` want to REPLACE the running VM. Ignore AMI drift after creation.
  lifecycle {
    ignore_changes = [ami]
  }
}
