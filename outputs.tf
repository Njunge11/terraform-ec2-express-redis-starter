// outputs.tf — expose key resource attributes for easy CLI access

# Public IP address of the Express API EC2 instance
output "app_public_ip" {
  description = "Public IPv4 address of the Express API instance"
  value       = aws_eip.app_ip.public_ip
}

# Instance ID of the Express API EC2 instance (for SSM or CLI operations)
output "app_instance_id" {
  description = "EC2 instance ID of the Express API instance"
  value       = aws_instance.app.id
}

# # Private IP address of the Redis EC2 instance
# output "redis_private_ip" {
#   description = "Private IPv4 address of the Redis instance"
#   value       = aws_instance.redis.private_ip
# }

# # Volume ID of the Redis data EBS volume (for backup verification)
# output "redis_volume_id" {
#   description = "EBS volume ID for Redis data"
#   value       = aws_ebs_volume.redis_data.id
# }
