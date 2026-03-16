# ─────────────────────────────────────────────
#  ALB Module — Application Load Balancer
# ─────────────────────────────────────────────

# ─── ALB Security Group ───
resource "aws_security_group" "alb" {
  name_prefix = "${var.environment}-alb-sg-"
  description = "Security group for Application Load Balancer"
  vpc_id      = var.vpc_id

  # Allow HTTP from internet
  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound (for health checks)
  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.environment}-alb-sg"
    Environment = var.environment
    Project     = var.project_name
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ─── Application Load Balancer ───
resource "aws_lb" "main" {
  name               = "${var.environment}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.public_subnet_ids

  enable_deletion_protection = false # Set true in production

  tags = {
    Name        = "${var.environment}-alb"
    Environment = var.environment
    Project     = var.project_name
  }
}

# ─── Target Group ───
resource "aws_lb_target_group" "main" {
  name     = "${var.environment}-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    enabled             = true
    path                = "/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }

  tags = {
    Name        = "${var.environment}-tg"
    Environment = var.environment
    Project     = var.project_name
  }
}

# ─── Listener ───
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }

  tags = {
    Name        = "${var.environment}-http-listener"
    Environment = var.environment
    Project     = var.project_name
  }
}
