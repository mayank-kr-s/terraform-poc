# ─────────────────────────────────────────────
#  EC2 Module — Launch Template + Auto Scaling
# ─────────────────────────────────────────────

# Lookup latest Amazon Linux 2023 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ─── EC2 Security Group ───
resource "aws_security_group" "ec2" {
  name_prefix = "${var.environment}-ec2-sg-"
  description = "Security group for EC2 web servers"
  vpc_id      = var.vpc_id

  # Allow HTTP only from ALB
  ingress {
    description     = "HTTP from ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [var.alb_security_group_id]
  }

  # Allow SSH from specified CIDR (your IP)
  ingress {
    description = "SSH access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.ssh_allowed_cidrs
  }

  # Allow all outbound
  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.environment}-ec2-sg"
    Environment = var.environment
    Project     = var.project_name
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ─── Launch Template ───
resource "aws_launch_template" "web" {
  name_prefix   = "${var.environment}-web-"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type
  key_name      = var.key_name

  vpc_security_group_ids = [aws_security_group.ec2.id]

  # User data script — runs on first boot
  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    environment = var.environment
    project     = var.project_name
  }))

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = "${var.environment}-web-server"
      Environment = var.environment
      Project     = var.project_name
      Role        = "webserver"
    }
  }

  tag_specifications {
    resource_type = "volume"
    tags = {
      Name        = "${var.environment}-web-server-volume"
      Environment = var.environment
      Project     = var.project_name
    }
  }

  tags = {
    Name        = "${var.environment}-web-lt"
    Environment = var.environment
    Project     = var.project_name
  }
}

# ─── Auto Scaling Group ───
resource "aws_autoscaling_group" "web" {
  name                = "${var.environment}-web-asg"
  desired_capacity    = var.desired_capacity
  min_size            = var.min_size
  max_size            = var.max_size
  vpc_zone_identifier = var.subnet_ids
  target_group_arns   = [var.target_group_arn]

  # Use the latest launch template version
  launch_template {
    id      = aws_launch_template.web.id
    version = "$Latest"
  }

  # Health check from ALB (more reliable than EC2 status check)
  health_check_type         = "ELB"
  health_check_grace_period = 300

  # Instance refresh — rolling updates when launch template changes
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
  }

  tag {
    key                 = "Name"
    value               = "${var.environment}-web-server"
    propagate_at_launch = true
  }

  tag {
    key                 = "Environment"
    value               = var.environment
    propagate_at_launch = true
  }

  tag {
    key                 = "Project"
    value               = var.project_name
    propagate_at_launch = true
  }
}

# ─── Auto Scaling Policy — Target Tracking (CPU) ───
resource "aws_autoscaling_policy" "cpu_target" {
  name                   = "${var.environment}-cpu-target-policy"
  autoscaling_group_name = aws_autoscaling_group.web.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = var.cpu_target_value
  }
}
