# Terraform Mini Project

> One free-tier EC2 instance on AWS, built with Terraform and deployed through GitHub Actions running on a self-hosted runner.

## What this project does

It creates **one Amazon Linux 2023 VM** (`t3.micro`) in the AWS account's **default VPC** in `eu-north-1` (Stockholm). You log in over **SSH with your own key pair**, and only your laptop's IP can reach it. Everything stays within the AWS free plan, so it costs **$0**.

## What you learn

- **Terraform basics:** providers, variables, outputs, data sources, `locals`, validation.
- **Modules:** a reusable `modules/aws/ec2` module called from a root config.
- **State:** what it is, where it lives, and why it stays out of Git.
- **CI/CD:** `plan` on every push, and manual `apply`/`destroy`, using GitHub Actions on a self-hosted runner.
- **AWS free-tier hygiene:** guardrails in code, plus `destroy` when you're done.

## Architecture

```
 YOUR LAPTOP (macOS)
 ┌────────────────────────────────────────┐
 │ terraform CLI · GitHub self-hosted     │
 │ runner · ~/.aws (tf-mini) · SSH key    │
 │ state file (outside the repo)          │
 └───────┬───────────────────────┬────────┘
         │ AWS API (HTTPS)       │ SSH :22 as ec2-user
         ▼                       ▼
 AWS · eu-north-1 (Stockholm)
 ┌──────────────────────────────────────────────┐
 │ Default VPC 172.31.0.0/16           [exists] │
 │ ┌──────────────────────────────────────────┐ │
 │ │ Default subnet · eu-north-1a    [exists] │ │
 │ │ ┌──────────────────────────────────────┐ │ │
 │ │ │ Security group terraform-mini-ssh    │ │ │
 │ │ │ in: 22/tcp from <your IP>/32 [new]   │ │ │
 │ │ │ ┌──────────────────────────────────┐ │ │ │
 │ │ │ │ EC2 terraform-mini         [new] │ │ │ │
 │ │ │ │ t3.micro · AL2023 · 8 GB gp3     │ │ │ │
 │ │ │ │ public IPv4 · IMDSv2             │ │ │ │
 │ │ │ │ key: terraform-mini-key    [new] │ │ │ │
 │ │ │ └──────────────────────────────────┘ │ │ │
 │ │ └──────────────────────────────────────┘ │ │
 │ └──────────────────────────────────────────┘ │
 │ Route 0.0.0.0/0 → Internet Gateway  [exists] │
 └──────────────────────────────────────────────┘
```

**Already in every AWS account. Terraform only *reads* these:**
- **Default VPC** (`172.31.0.0/16`): the private network.
- **Default subnet** in `eu-north-1a`. It's public, so instances there get a public IPv4 automatically.
- **Internet Gateway** and a route `0.0.0.0/0 → IGW`, which let traffic in and out.

**Created by Terraform (3 resources):**
- **Security group** `terraform-mini-ssh`: allows port 22 from your IP only.
- **Key pair** `terraform-mini-key`: your *public* key, stored in EC2.
- **EC2 instance** `terraform-mini`: `t3.micro`, AL2023, 8 GB gp3, public IP.

## Project structure

```
Terraform_Mini_Project/
├── .github/workflows/
│   ├── ci.yml                  # push/PR: fmt → init → validate → plan
│   └── cd.yml                  # manual: apply | destroy
├── modules/
│   └── aws/
│       └── ec2/                # reusable "build one VM" module
│           ├── main.tf         #   lookups (VPC, subnet, AMI) + security group, key pair, instance
│           ├── variables.tf    #   module inputs (with free-tier validation)
│           └── outputs.tf      #   instance_id, public_ip
├── backend.tf                  # where state lives (absolute path, outside the repo)
├── versions.tf                 # Terraform + provider version constraints
├── providers.tf                # AWS region, profile, default tags
├── main.tf                     # looks up your IP, calls the ec2 module
├── variables.tf                # root inputs (all have defaults)
├── outputs.tf                  # instance_id, public_ip, ssh_allowed_cidr, ssh_command
├── terraform.tfvars.example    # sample overrides → copy to terraform.tfvars (git-ignored)
├── .terraform.lock.hcl         # exact provider versions (committed)
├── .gitignore                  # keeps state, tfvars, keys, .terraform/ out of Git
├── CLAUDE.md                   # rules for the AI assistant working in this repo
└── README.md                   # this file
```

## How it works

1. **`terraform init`** reads `backend.tf` and remembers where the state file is (in `.terraform/`). It downloads the `aws` and `http` providers and links the `ec2` module.
2. **`terraform plan`** reads the state, asks AWS what exists (default VPC, subnet, latest AL2023 AMI) and looks up your public IP. It then compares **code vs state vs AWS** and prints what it *would* change.
3. **`terraform apply`** creates the 3 resources and writes the result to the state file.
4. At first boot, **cloud-init** on the VM copies your public key (attached via `key_name`) into `/home/ec2-user/.ssh/authorized_keys`.
5. You **SSH in** with the matching private key.

**Where state lives:** `/Users/suraj_armugham/terraform_state/.terraform-state/ec2-mini/terraform.tfstate`.
It sits outside the repo for two reasons: the repo is public, and the GitHub runner wipes its checkout folder on every job. Manual runs and CI/CD all read and write this same file.

## Prerequisites and setup (one time)

1. **Install the tools:**
   ```bash
   brew tap hashicorp/tap
   brew install hashicorp/tap/terraform awscli
   ```
2. **Create an AWS account** on the **Free plan** (it comes with credits and never charges your card unless you upgrade). Turn on MFA for root.
3. **Create an IAM user** `tf-mini` with no console access. Attach `AmazonEC2FullAccess`, then create an access key for the "Command Line Interface".
4. **Save the credentials on the laptop** (stored in `~/.aws`, never in this repo):
   ```bash
   aws configure --profile tf-mini      # region: eu-north-1, output: json
   aws sts get-caller-identity --profile tf-mini
   ```
5. **Create the SSH key pair:**
   ```bash
   ssh-keygen -t ed25519 -f ~/.ssh/tf-mini-ec2 -C "tf-mini-ec2"
   ```
6. **Create the state folder:**
   ```bash
   mkdir -p /Users/suraj_armugham/terraform_state/.terraform-state/ec2-mini
   ```
7. **Variables (optional):** every variable has a default. To change one, copy `terraform.tfvars.example` to `terraform.tfvars` and edit it.

## Run it locally

Run each command from the project root and read its output before moving on.

```bash
# 1. INIT: prepare the working folder (run again after changing backend/providers/modules)
#    - reads backend.tf → records the state location in .terraform/
#    - downloads the aws + http providers into .terraform/providers/
#    - writes .terraform.lock.hcl (exact provider versions; commit it)
terraform init

# 2. FMT: rewrite .tf files in the standard style (whitespace only, never logic)
terraform fmt -recursive

# 3. VALIDATE: offline check for typos, wrong arguments, bad references
terraform validate

# 4. PLAN: dry run, nothing changes
#    symbols:  + create   ~ update in place   - destroy   -/+ replace
#    first run ends with:  Plan: 3 to add, 0 to change, 0 to destroy.
terraform plan

# 5. APPLY: shows the plan again, then asks for "yes"
#    creates the resources, writes state, prints the outputs
terraform apply

# 6. SSH: wait about a minute for boot, then use the printed ssh_command
ssh -i ~/.ssh/tf-mini-ec2 ec2-user@$(terraform output -raw public_ip)
#    inside the VM:  whoami → ec2-user ;  sudo su - → root ;  exit

# 7. INSPECT STATE (read-only)
terraform state list     # resources Terraform tracks
terraform output         # print outputs again
terraform show           # full details

# 8. PLAN AGAIN: should say "No changes." This proves the state is being read.
terraform plan

# 9. DESTROY: asks for "yes", removes all 3 resources, cost back to $0
terraform destroy
```

## CI/CD (GitHub Actions on a self-hosted runner)

Both workflows run on **this laptop** (`runs-on: [self-hosted, macOS]`). That way they use the local Terraform, `~/.aws` credentials and state file, and **no AWS secrets are stored in GitHub**.

| Workflow | Trigger | Steps |
|---|---|---|
| `ci.yml` | push to `main`, pull request | `fmt -check` → `init` → `validate` → `plan` |
| `cd.yml` | manual (**Actions → cd → Run workflow**), choose `apply` or `destroy` | `init` → `apply`/`destroy -auto-approve` → `output` |

Triggering `cd.yml` by hand, after reading the CI plan, is the approval step. Both workflows use `concurrency: terraform`, so only one run touches the state at a time.

**Runner setup:**
1. Repo → Settings → Actions → Runners → **New self-hosted runner** → macOS. Run the commands it shows in `~/actions-runner`.
2. Install it as a background service: `./svc.sh install && ./svc.sh start`. Check it with `./svc.sh status`.
3. The runner shows as **Idle** in repo settings. Jobs only run while the laptop is on and the runner is started.

**Public-repo safety:** turn on Settings → Actions → General → **"Require approval for all external contributors"**. Otherwise, a fork's pull request could change a workflow and run code on your laptop.
Actions logs on a public repo are public too, so your home IP (`ssh_cidr`) is marked `sensitive` and shows as `(sensitive value)` in plans.

## Cost ($0) notes

Guardrails built into the code:
- `instance_type` can only be `t2.micro` or `t3.micro`. In `eu-north-1`, only `t3.micro` is offered.
- `cpu_credits = "standard"`: no surprise charges for CPU bursting.
- 8 GB gp3 root disk (the free tier allows 30 GB), deleted together with the instance.
- No detailed monitoring, NAT Gateway, Elastic IP, load balancer or extra volumes.
- A public IPv4 address costs about $0.005/hour, which the free plan's credits cover. It's the one line to watch in Billing.

**Habit:** run `terraform destroy` (or `cd.yml` → `destroy`) when you finish practising.

## Troubleshooting

| Symptom | Likely cause and fix |
|---|---|
| `ssh` times out | Your public IP changed. Compare `terraform output -raw ssh_allowed_cidr` (it's hidden in normal output) with your current IP, then run `plan`/`apply` again to update the rule. |
| `AccessDenied` / `UnauthorizedOperation` | The `tf-mini` user is missing `AmazonEC2FullAccess`, or the wrong profile is in use. Run `aws sts get-caller-identity --profile tf-mini`. |
| `Permission denied (publickey)` | Wrong key or user. Use `-i ~/.ssh/tf-mini-ec2` and `ec2-user`. |
| GitHub job stuck at "Queued" | The runner isn't running. In `~/actions-runner`, run `./svc.sh status` and `./svc.sh start`. |
| `Error acquiring the state lock` | Another run is in progress. Wait for it to finish. Use `terraform force-unlock <ID>` only if you're sure nothing is running. |
| `Unsupported instance type` | That type isn't offered in this region or AZ. Keep `t3.micro` in `eu-north-1`. |

## Next steps

- **CD approval gate:** `plan -out=tfplan` → a GitHub Environment with a required reviewer → `apply tfplan`.
- **Custom `network` module:** your own VPC, subnet and internet gateway, still free (but avoid NAT Gateways).
- **`user_data`:** install nginx at boot and open port 80 to serve a web page.
