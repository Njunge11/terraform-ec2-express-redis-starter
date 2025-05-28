// ────────────────────────────────────────────────────────────────────────────
// express.tf — EC2 instance for your Express API & its Elastic IP
// ────────────────────────────────────────────────────────────────────────────

# 1) Lookup your single public subnet
data "aws_subnet" "public" {
  id = aws_subnet.public.id
}

# 2) Find the latest Amazon Linux 2023 Arm64 AMI
data "aws_ami" "al2023_arm" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-*-arm64"]
  }
}

# 3) Extract the ECR registry URI (e.g. 123456789012.dkr.ecr.af-south-1.amazonaws.com)
locals {
  registry_uri = regex(
    "^([^.]+\\.dkr\\.ecr\\.[^.]+\\.amazonaws\\.com)",
    var.express_image
  )[0]
}
# 4) EC2 instance running your Express container
resource "aws_instance" "app" {
  ami                         = data.aws_ami.al2023_arm.id                // Amazon Linux 2023 ARM AMI
  instance_type               = "t4g.nano"                                // smallest, cost-effective ARM instance
  subnet_id                   = data.aws_subnet.public.id                 // our public-only subnet
  vpc_security_group_ids      = [aws_security_group.api.id]               // allows SSH & HTTP
  associate_public_ip_address = true                                      // assigns a public IP
  key_name                    = var.ssh_key_name                          // your SSH key-pair name
  iam_instance_profile        = aws_iam_instance_profile.ssm_profile.name // for SSM Session Manager

  user_data = <<-EOF
    #!/bin/bash
    set -eux

    # ─────────────────────────────────────────────────────────────
    # Stop & disable the ECS agent (pre-installed by AL2023 AMI)
    systemctl stop ecs || true
    systemctl disable ecs || true
    systemctl stop amazon-ecs-agent || true
    systemctl disable amazon-ecs-agent || true
    # ─────────────────────────────────────────────────────────────

    # Install Docker via dnf (correct for AL2023)
    dnf install -y docker
    systemctl enable --now docker

    # Log in to your private ECR registry so Docker can pull your image
    aws ecr get-login-password --region ${var.aws_region} \
      | docker login --username AWS --password-stdin ${local.registry_uri}

    # Run your Express API on port 3000
    docker run -d --name express -p 3000:3000 ${var.express_image}

    # Start Watchtower to auto-update the container whenever you push a new image
    docker run -d --name watchtower \
      -e WATCHTOWER_POLL_INTERVAL=30 \
      -v /var/run/docker.sock:/var/run/docker.sock \
      containrrr/watchtower express --cleanup
  EOF

  tags = {
    Name = "express-app"
  }
}

# 5) Allocate a static Elastic IP and attach it to the Express instance
resource "aws_eip" "app_ip" {
  instance = aws_instance.app.id
  domain   = "vpc" // ensures the EIP lives in your VPC

  tags = {
    Name = "express-eip"
  }
}
