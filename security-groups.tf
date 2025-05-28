// ────────────────────────────────────────────────────────────────────────────
// security-groups.tf — API & Redis Security Groups
// ────────────────────────────────────────────────────────────────────────────

# 1) API Security Group — allows SSH from your IP and HTTP to port 3000
resource "aws_security_group" "api" {
  name        = "api-sg"
  description = "Allow SSH & HTTP to Express API"
  vpc_id      = aws_vpc.main.id // reference your custom VPC

  # SSH ingress from your workstation only
  ingress {
    description = "SSH from my IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_source_cidr] // defined in variables.tf
  }

  # HTTP ingress for your Express app
  ingress {
    description      = "Express HTTP"
    from_port        = 3000
    to_port          = 3000
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  # Allow all outbound (to ECR, Bugsnag, etc.)
  egress {
    description      = "Allow all outbound"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "api-sg"
  }
}

# 2) Redis Security Group — only accepts traffic from api-sg on port 6379
resource "aws_security_group" "redis" {
  name        = "redis-sg"
  description = "Allow Redis only from API SG"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Redis access from API"
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.api.id]
  }

  # Allow all outbound (for backups, AWS APIs)
  egress {
    description      = "Allow all outbound"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "redis-sg"
  }
}

