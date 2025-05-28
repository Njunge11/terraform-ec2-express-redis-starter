// access.tf — IAM Role, Policy Attachments, and Instance Profile for SSM & ECR Access

// 1) Create an IAM Role that EC2 instances can assume to use AWS SSM and ECR
resource "aws_iam_role" "ssm" {
  name = "ssm-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "ec2.amazonaws.com" } // allow EC2 to assume this role
        Action    = "sts:AssumeRole"
      }
    ]
  })
}

// 2) Attach the managed policy for SSM so instances can be accessed via Session Manager
resource "aws_iam_role_policy_attachment" "ssm_attach" {
  role       = aws_iam_role.ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

// 3) Attach the managed policy for ECR ReadOnly so instances can authenticate and pull images
resource "aws_iam_role_policy_attachment" "ecr_readonly" {
  role       = aws_iam_role.ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

// 4) Create an Instance Profile to bind the IAM Role to EC2 instances
resource "aws_iam_instance_profile" "ssm_profile" {
  name = "ssm-profile"
  role = aws_iam_role.ssm.name
}
