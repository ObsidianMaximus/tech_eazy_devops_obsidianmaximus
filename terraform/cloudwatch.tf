# SIMPLE CLOUDWATCH SETUP - TRIGGER ON ERROR

resource "aws_sns_topic" "app_alerts" {
  name = "app-alerts-topic"
}

resource "aws_sns_topic_subscription" "email_alerts" {
  topic_arn = aws_sns_topic.app_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_cloudwatch_log_group" "app_log_group" {
  name              = "techeazy-app-logs"
  retention_in_days = 1
}

# Simple error detection - matches any line with "ERROR"
resource "aws_cloudwatch_log_metric_filter" "error_filter" {
  name           = "error-metric-filter"
  log_group_name = aws_cloudwatch_log_group.app_log_group.name
  pattern        = "ERROR"

  metric_transformation {
    name      = "ErrorCount"
    namespace = "TecheazyApp"
    value     = "1"
  }
}

# Trigger immediately when any ERROR appears
resource "aws_cloudwatch_metric_alarm" "error_alarm" {
  alarm_name          = "AppErrorAlarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ErrorCount"
  namespace           = "TecheazyApp"
  period              = 60
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "Triggers when ERROR appears in app.log"
  alarm_actions       = [aws_sns_topic.app_alerts.arn]
  treat_missing_data  = "notBreaching"
}

output "sns_topic_arn" {
  value = aws_sns_topic.app_alerts.arn
}
