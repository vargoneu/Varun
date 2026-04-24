provider "aws" {
  region = var.region
}

# -----------------------------
# SNS (ALERTING)
# -----------------------------
resource "aws_sns_topic" "alerts" {
  name = "cloudwatch-alerts"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.sns_email
}

# -----------------------------
# IAM ROLE FOR EC2
# -----------------------------
resource "aws_iam_role" "ec2_role" {
  name = "ec2-cloudwatch-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Action = "sts:AssumeRole",
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "cw_policy" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2-profile"
  role = aws_iam_role.ec2_role.name
}

# -----------------------------
# SECURITY GROUP
# -----------------------------
resource "aws_security_group" "ec2_sg" {
  name = "ec2-sg"
  vpc_id = "vpc-009751cd517b6a638"

  ingress {
    description = "SSH Access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # restrict in real env
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# -----------------------------
# EC2 INSTANCE
# -----------------------------
resource "aws_instance" "app" {
  ami           = var.ami_id
  instance_type = var.instance_type

  key_name               = var.key_name
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]

  depends_on = [aws_iam_role_policy_attachment.cw_policy]

  tags = {
    Name = "Terraform-Instance"
  }
}

# -----------------------------
# CLOUDWATCH LOG GROUP
# -----------------------------
resource "aws_cloudwatch_log_group" "app_logs" {
  name              = "/ec2/app/logs"
  retention_in_days = 7
}

# -----------------------------
# CLOUDWATCH ALARM (CPU)
# -----------------------------
resource "aws_cloudwatch_metric_alarm" "cpu_alarm" {
  alarm_name          = "High-CPU-Alarm"
  comparison_operator = "GreaterThanThreshold"

  evaluation_periods  = 2
  datapoints_to_alarm = 2

  metric_name = "CPUUtilization"
  namespace   = "AWS/EC2"
  period      = 60
  statistic   = "Average"
  threshold   = 70

  alarm_actions = [aws_sns_topic.alerts.arn]

  dimensions = {
    InstanceId = aws_instance.app.id
  }

  treat_missing_data = "notBreaching"
}