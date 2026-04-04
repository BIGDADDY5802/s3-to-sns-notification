output "s3_bucket_name" {
  description = "Name of the S3 upload bucket"
  value       = aws_s3_bucket.upload_bucket.id
}

output "sns_topic_arn" {
  description = "ARN of the SNS notification topic"
  value       = aws_sns_topic.upload_notifications.arn
}

output "lambda_function_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.s3_to_sns.function_name
}

output "lambda_function_arn" {
  description = "ARN of the Lambda function"
  value       = aws_lambda_function.s3_to_sns.arn
}

output "subscription_note" {
  description = "Reminder about email confirmation"
  value       = "ACTION REQUIRED: Check ${var.notification_email} and confirm the SNS subscription before testing."
}
