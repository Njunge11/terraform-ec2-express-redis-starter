# single default-VPC lookup
data "aws_vpc" "default" {
  default = true
}

