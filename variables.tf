variable "ssh_source_cidr" {
  description = "My public IP / CIDR for SSH access"
  type        = string
}

variable "ecr_repo_name" {
  description = "Name of the ECR repository for Express API"
  type        = string
  default     = "express-api"
}
variable "express_image" {
  description = "ECR URI + tag for the Express API image"
  type        = string
}

variable "aws_region" {
  description = "AWS region where resources will be created"
  type        = string
  default     = "af-south-1"
}
variable "ssh_key_name" {
  description = "Name of the EC2 key-pair to use for SSH access"
  type        = string
  default     = "express-key"
}

