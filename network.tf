// ────────────────────────────────────────────────────────────────────────────
// network.tf — Custom VPC + one public subnet + Internet Gateway + routing
// ────────────────────────────────────────────────────────────────────────────

# 1) Create your own VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16" // gives you room to grow
  enable_dns_support   = true          // resolve AWS service names
  enable_dns_hostnames = true          // get DNS names for instances

  tags = {
    Name = "main-vpc"
  }
}

# 2) Internet Gateway for outbound Internet access
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "main-igw"
  }
}

# 3) Single public subnet (choose your preferred AZ)
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24" // 256 addresses
  availability_zone       = "af-south-1a" // single AZ
  map_public_ip_on_launch = true          // auto-assign public IPs

  tags = {
    Name = "public-subnet"
  }
}

# 4) Route table sending 0.0.0.0/0 out the IGW
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "public-rt"
  }
}

# 5) Attach that route table to your single subnet
resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public_rt.id
}

