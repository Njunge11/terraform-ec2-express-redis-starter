# security-groups.tf

# 2️⃣ API Security Group
resource "aws_security_group" "api" {
  name        = "api-sg"
  description = "Allow HTTP to Express API"
  vpc_id      = data.aws_vpc.default.id

  # Inbound: Express listens on port 3000
  ingress {
    description      = "Allow HTTP from anywhere"
    from_port        = 3000
    to_port          = 3000
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  # Outbound: allow all
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

# 3️⃣ Redis Security Group
resource "aws_security_group" "redis" {
  name        = "redis-sg"
  description = "Lock down Redis to API SG only"
  vpc_id      = data.aws_vpc.default.id

  # Inbound: only allow the API SG on port 6379
  ingress {
    description     = "Allow Redis from API SG"
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.api.id]
  }

  # Outbound: allow all (for snapshot or AWS calls)
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

