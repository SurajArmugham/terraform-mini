# CLAUDE.md

Context and rules for Claude when working in this repository.

## Purpose
A learning project: one free-tier EC2 instance (`t3.micro`, Amazon Linux 2023) in the AWS default VPC, reached by SSH key, with a target cost of **$0**. The user is learning Terraform, so explain what you do.

## Hard rules
- **Never run `terraform apply` or `terraform destroy`, and never trigger `cd.yml`**, without the user's explicit OK in chat for that run.
  These are safe to run any time: `init`, `fmt`, `validate`, `plan`, `state list`, `output`, `show`.
- **Never remove or loosen the zero-cost guardrails:** the `instance_type` validation, `cpu_credits = "standard"`, the 8 GB gp3 root disk, `monitoring = false`. Never add a NAT Gateway, Elastic IP, load balancer or extra volume.
- **The repo is public.** Never commit state, `*.tfvars` (except `terraform.tfvars.example`), SSH keys, AWS credentials or the account ID.
- **Never read or print AWS credentials** (`~/.aws/credentials`, or terminal output from `aws configure`). Use `aws sts get-caller-identity --profile tf-mini` to check access.
- **Never edit the state file by hand.** Use `terraform state` commands only with the user's OK.
- Only commit or push when the user asks.

## Facts
- **State:** `/Users/suraj_armugham/terraform_state/.terraform-state/ec2-mini/terraform.tfstate` (local backend, absolute path in `backend.tf`, outside the repo).
- **AWS:** profile `tf-mini` (IAM user with `AmazonEC2FullAccess`), region `eu-north-1`, AZ `eu-north-1a`, AWS project `terraform-mini` (Free plan).
- **Resource names:** prefix `terraform-mini`. Every resource is tagged `Project = terraform-mini`, `ManagedBy = terraform`.
- **SSH:** key `~/.ssh/tf-mini-ec2`, user `ec2-user`. Port 22 is open only to the laptop's IP, which the `http` data source looks up.
- **CI/CD:** GitHub Actions on a **self-hosted runner on this laptop** (`runs-on: [self-hosted, macOS]`). It uses the local Terraform, `~/.aws` and state; no AWS secrets are stored in GitHub.
- **Lifecycle:** `ignore_changes = [ami]` on the instance stops new AMI releases from forcing a replacement.

## Conventions
- Run `terraform fmt -recursive` and `terraform validate` before every commit.
- Every variable has a `type` and a `description`. Root variables all have defaults.
- Modules live under `modules/aws/<name>/` with `main.tf`, `variables.tf` and `outputs.tf`.
- Code carries short explanatory comments, since this is a learning project.
- Keep README.md in sync when behavior, names or setup steps change.

## Commands
```bash
terraform init
terraform fmt -recursive && terraform validate
terraform plan
terraform output
ssh -i ~/.ssh/tf-mini-ec2 ec2-user@$(terraform output -raw public_ip)
```
