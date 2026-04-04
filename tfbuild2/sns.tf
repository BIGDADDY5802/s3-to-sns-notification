# ---------------------------------------------------------------
# SNS Topic
# ---------------------------------------------------------------

resource "aws_sns_topic" "upload_notifications" {
  name         = var.sns_topic_name
  display_name = var.sns_topic_name  # Required — shows in email "From" header

  tags = {
    Project = "s3-sns-lambda"
  }
}

# ---------------------------------------------------------------
# SNS Topic Policy — allows Lambda to publish
# ---------------------------------------------------------------

resource "aws_sns_topic_policy" "allow_lambda_publish" {
  arn = aws_sns_topic.upload_notifications.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowLambdaPublish"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action   = "SNS:Publish"
        Resource = aws_sns_topic.upload_notifications.arn
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = aws_lambda_function.s3_to_sns.arn
          }
        }
      }
    ]
  })
}

# ---------------------------------------------------------------
# Email Subscription
# ---------------------------------------------------------------

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.upload_notifications.arn
  protocol  = "email"
  endpoint  = var.notification_email

  # NOTE: After terraform apply, AWS sends a confirmation email to
  # var.notification_email. The subscription will show as
  # "PendingConfirmation" until the email link is clicked.
  # Terraform cannot automate this step — it requires human action.
}
