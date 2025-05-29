// redis.tf — EC2 instance for Redis with persistent EBS volume
// This file provisions a Redis server in your VPC with durability and auto-updates via Watchtower

# Reuse the public subnet defined in network.tf (do not redeclare)
# Latest Amazon Linux 2 x86_64 AMI for t3.nano
data "aws_ami" "al2_x86" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# 1 GiB gp3 encrypted EBS volume for Redis data
resource "aws_ebs_volume" "redis_data" {
  availability_zone = aws_subnet.public.availability_zone
  size              = 1
  type              = "gp3"
  encrypted         = true

  tags = {
    Name = "redis-data"
  }
}

# EC2 instance to host Redis, with public IP for Docker Hub pulls
resource "aws_instance" "redis" {
  ami                         = data.aws_ami.al2_x86.id
  instance_type               = "t3.nano"
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.redis.id]
  associate_public_ip_address = true  # public IP needed for Docker Hub pulls
  key_name                    = var.ssh_key_name
  iam_instance_profile        = aws_iam_instance_profile.ssm_profile.name

  user_data = <<-EOF
    #!/bin/bash
    set -eux
    
    # Install Docker
    yum install -y docker
    systemctl enable --now docker
    
    # Format & mount EBS volume at /data
    file -s /dev/xvdf | grep -q filesystem || mkfs -t xfs /dev/xvdf
    mkdir -p /data
    mount /dev/xvdf /data
    grep -q '/dev/xvdf /data' /etc/fstab || echo '/dev/xvdf /data xfs defaults 0 0' >> /etc/fstab
    
    # Run Redis, listen on all interfaces
    docker run -d --name redis-server \
      -v /data:/data \
      -p 6379:6379 \
      redis:7 \
      --appendonly yes \
      --dir /data \
      --bind 0.0.0.0
    
    # Watchtower to auto-update Redis daily
    docker run -d --name watchtower-redis \
      -e WATCHTOWER_POLL_INTERVAL=86400 \
      -v /var/run/docker.sock:/var/run/docker.sock \
      containrrr/watchtower redis-server --cleanup
  EOF

  tags = {
    Name = "redis-box"
  }
}

# Attach the EBS volume to the Redis instance
resource "aws_volume_attachment" "redis_attach" {
  device_name = "/dev/xvdf"
  volume_id   = aws_ebs_volume.redis_data.id
  instance_id = aws_instance.redis.id
}