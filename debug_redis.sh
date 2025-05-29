#!/bin/bash
# debug_redis.sh - Run this script to debug Redis connectivity issues

echo "=== Redis Connectivity Debug ==="
echo "Date: $(date)"
echo

# 1. Check Terraform outputs
echo "1. Getting instance information from Terraform..."
terraform output -json > tf_outputs.json 2>/dev/null || echo "No Terraform outputs available"

# Get instance IDs and IPs
REDIS_INSTANCE_ID=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=redis-box" "Name=instance-state-name,Values=running" \
  --query "Reservations[0].Instances[0].InstanceId" --output text)

EXPRESS_INSTANCE_ID=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=express-app" "Name=instance-state-name,Values=running" \
  --query "Reservations[0].Instances[0].InstanceId" --output text)

REDIS_PRIVATE_IP=$(aws ec2 describe-instances \
  --instance-ids $REDIS_INSTANCE_ID \
  --query "Reservations[0].Instances[0].PrivateIpAddress" --output text)

EXPRESS_PRIVATE_IP=$(aws ec2 describe-instances \
  --instance-ids $EXPRESS_INSTANCE_ID \
  --query "Reservations[0].Instances[0].PrivateIpAddress" --output text)

echo "Redis Instance ID: $REDIS_INSTANCE_ID"
echo "Express Instance ID: $EXPRESS_INSTANCE_ID"
echo "Redis Private IP: $REDIS_PRIVATE_IP"
echo "Express Private IP: $EXPRESS_PRIVATE_IP"
echo

# 2. Check instance status
echo "2. Checking instance status..."
aws ec2 describe-instance-status --instance-ids $REDIS_INSTANCE_ID $EXPRESS_INSTANCE_ID \
  --query "InstanceStatuses[*].[InstanceId,InstanceStatus.Status,SystemStatus.Status]" \
  --output table

# 3. Check security groups
echo "3. Checking security group rules..."
REDIS_SG_ID=$(aws ec2 describe-instances \
  --instance-ids $REDIS_INSTANCE_ID \
  --query "Reservations[0].Instances[0].SecurityGroups[0].GroupId" --output text)

echo "Redis Security Group ID: $REDIS_SG_ID"
aws ec2 describe-security-groups --group-ids $REDIS_SG_ID \
  --query "SecurityGroups[0].IpPermissions[*].[IpProtocol,FromPort,ToPort,UserIdGroupPairs[0].GroupId]" \
  --output table

# 4. Check Redis container status via SSM
echo "4. Checking Redis container status..."
echo "Connecting to Redis instance via SSM..."

aws ssm send-command \
  --instance-ids $REDIS_INSTANCE_ID \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=[
    "echo === Docker Status ===",
    "sudo docker ps -a",
    "echo",
    "echo === Redis Container Logs ===", 
    "sudo docker logs redis-server --tail 20",
    "echo",
    "echo === Port Check ===",
    "sudo netstat -tlnp | grep 6379 || echo No process listening on 6379",
    "echo",
    "echo === Redis Ping Test ===",
    "sudo docker exec redis-server redis-cli ping || echo Redis ping failed",
    "echo",
    "echo === Network Interface Check ===",
    "ip addr show",
    "echo",
    "echo === EBS Volume Mount ===",
    "df -h | grep data || echo No data volume mounted"
  ]' \
  --output text \
  --query "Command.CommandId" > redis_command_id.txt

REDIS_CMD_ID=$(cat redis_command_id.txt)
echo "Redis SSM Command ID: $REDIS_CMD_ID"

# Wait for command to complete
sleep 10

echo "Redis diagnostics output:"
aws ssm get-command-invocation \
  --command-id $REDIS_CMD_ID \
  --instance-id $REDIS_INSTANCE_ID \
  --query "StandardOutputContent" \
  --output text

# 5. Check Express container status
echo "5. Checking Express container status..."
aws ssm send-command \
  --instance-ids $EXPRESS_INSTANCE_ID \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=[
    "echo === Docker Status ===",
    "sudo docker ps -a",
    "echo",
    "echo === Express Container Logs ===",
    "sudo docker logs express --tail 20",
    "echo",
    "echo === Network Connectivity Test ===",
    "ping -c 3 '$REDIS_PRIVATE_IP' || echo Cannot ping Redis",
    "echo",
    "echo === Port Connectivity Test ===", 
    "timeout 5 bash -c \"</dev/tcp/'$REDIS_PRIVATE_IP'/6379\" && echo \"Port 6379 is open\" || echo \"Port 6379 is closed or filtered\""
  ]' \
  --output text \
  --query "Command.CommandId" > express_command_id.txt

EXPRESS_CMD_ID=$(cat express_command_id.txt)
echo "Express SSM Command ID: $EXPRESS_CMD_ID"

sleep 10

echo "Express diagnostics output:"
aws ssm get-command-invocation \
  --command-id $EXPRESS_CMD_ID \
  --instance-id $EXPRESS_INSTANCE_ID \
  --query "StandardOutputContent" \
  --output text

echo
echo "=== Debug Complete ==="
echo "If Redis is not running, try: terraform apply -replace=aws_instance.redis"
echo "If connectivity fails, check security group configuration"
