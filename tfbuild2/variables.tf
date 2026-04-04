variable "aws_region" {
  description = "AWS region to deploy resources into"
  type        = string
  default     = "us-east-1"
}

variable "bucket_name" {
  description = "Globally unique name for the S3 bucket"
  type        = string
  default     = "s3snslambda-project"
}

variable "sns_topic_name" {
  description = "Name for the SNS topic"
  type        = string
  default     = "s3-email-notification"
}

variable "notification_email" {
  description = "Email address to receive S3 upload notifications"
  type        = string
  # No default — always provide this at apply time:
  # terraform apply -var="notification_email=you@example.com"
}

variable "lambda_function_name" {
  description = "Name of the Lambda function"
  type        = string
  default     = "S3ToSNSLambda"
}
