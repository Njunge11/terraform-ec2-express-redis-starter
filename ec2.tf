data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Latest Amazon Linux 2023 Arm64 AMI
data "aws_ami" "al2023_arm" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-*-arm64"]
  }
}

locals {
  subnet_id = data.aws_subnets.public.ids[0] # first public subnet
}

############################################
#            Express API VM                #
############################################
resource "aws_instance" "app" {
  ami                         = data.aws_ami.al2023_arm.id
  instance_type               = "t4g.nano"
  subnet_id                   = local.subnet_id
  security_groups             = [aws_security_group.api.id]
  associate_public_ip_address = true

  user_data = <<-EOF
    #!/bin/bash
    set -eux
    yum -y update
    amazon-linux-extras install docker -y
    systemctl enable --now docker

    # Pull and run Express container
    docker run -d --name express -p 3000:3000 ${var.express_image}

    # Watchtower: auto-pull :latest every 30 s
    docker run -d --name watchtower \
      -e WATCHTOWER_POLL_INTERVAL=30 \
      -v /var/run/docker.sock:/var/run/docker.sock \
      containrrr/watchtower express --cleanup
  EOF

  tags = {
    Name = "express-app"
  }
}

# Elastic IP so the public URL stays constant
resource "aws_eip" "app_ip" {
  instance = aws_instance.app.id
  domain   = "vpc" # modern replacement
  tags     = { Name = "express-eip" }
}

############################################
#   1 GiB gp3 volume for Redis persistence #
############################################
resource "aws_ebs_volume" "redis_data" {
  availability_zone = aws_instance.app.availability_zone
  size              = 1 # GiB
  type              = "gp3"

  tags = {
    Name = "redis-data"
  }
}

############################################
#               Redis VM                   #
############################################
resource "aws_instance" "redis" {
  ami                         = data.aws_ami.al2023_arm.id
  instance_type               = "t4g.nano"
  subnet_id                   = local.subnet_id
  security_groups             = [aws_security_group.redis.id]
  associate_public_ip_address = false # private-only host

  user_data = <<-EOF
    #!/bin/bash
    set -eux
    yum -y update
    amazon-linux-extras install docker -y
    systemctl enable --now docker

    # Format & mount the attached volume if it's fresh
    file -s /dev/xvdf | grep -q 'filesystem' || mkfs -t xfs /dev/xvdf
    mkdir -p /data
    mount /dev/xvdf /data
    grep -q '/dev/xvdf' /etc/fstab || echo '/dev/xvdf /data xfs defaults 0 0' >> /etc/fstab

    # Run Redis with AOF persistence to /data
    docker run -d --name redis \
      -v /data:/data \
      -p 6379:6379 \
      redis:7 \
      --appendonly yes \
      --dir /data
  EOF

  tags = {
    Name = "redis-box"
  }
}

########  Attach the EBS volume to Redis VM  ########
resource "aws_volume_attachment" "redis_data_attach" {
  instance_id = aws_instance.redis.id
  volume_id   = aws_ebs_volume.redis_data.id
  device_name = "/dev/xvdf"
}

############################################
#   IAM role so DLM can snapshot volumes   #
############################################
resource "aws_iam_role" "dlm" {
  name = "dlm-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "dlm.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "dlm_snapshot" {
  role = aws_iam_role.dlm.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "ec2:CreateSnapshot",
        "ec2:DeleteSnapshot",
        "ec2:DescribeSnapshots",
        "ec2:DescribeVolumes",
        "ec2:CreateTags",
        "ec2:DescribeTags"
      ]
      Resource = "*"
    }]
  })
}

############################################
#      Data Lifecycle Manager policy       #
############################################
resource "aws_dlm_lifecycle_policy" "redis_snapshots" {
  description        = "Daily Redis volume snapshots"
  state              = "ENABLED"
  execution_role_arn = aws_iam_role.dlm.arn

  policy_details {
    resource_types = ["VOLUME"]
    target_tags    = { Name = "redis-data" }

    schedule {
      name = "daily"

      create_rule {
        interval      = 24
        interval_unit = "HOURS"
      }

      retain_rule {
        count = 7
      }
    }
  }
}
