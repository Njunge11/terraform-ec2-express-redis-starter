// ────────────────────────────────────────────────────────────────────────────
// ecr.tf — ECR repository + lifecycle policy + output
// ────────────────────────────────────────────────────────────────────────────

# Create a private ECR repo to host your Express Docker images
resource "aws_ecr_repository" "express" {
  name                 = var.ecr_repo_name // from variables.tf
  image_tag_mutability = "MUTABLE"         // allow re-using tags like “latest”

  tags = {
    Name = var.ecr_repo_name
  }
}

# Attach a policy that expires untagged images older than 7 days
resource "aws_ecr_lifecycle_policy" "express" {
  repository = aws_ecr_repository.express.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire untagged images older than 7 days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countNumber = 7
          countUnit   = "days"
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# Export the repo URL so you can wire it into terraform.tfvars or CI
output "ecr_repository_url" {
  description = "URI of the Express ECR repository"
  value       = aws_ecr_repository.express.repository_url
}

