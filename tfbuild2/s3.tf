# ---------------------------------------------------------------
# S3 Bucket
# ---------------------------------------------------------------

resource "aws_s3_bucket" "upload_bucket" {
  bucket = var.bucket_name

  tags = {
    Project = "s3-sns-lambda"
  }
}

resource "aws_s3_bucket_public_access_block" "upload_bucket" {
  bucket = aws_s3_bucket.upload_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ---------------------------------------------------------------
# S3 → Lambda Notification Trigger
# ---------------------------------------------------------------

resource "aws_s3_bucket_notification" "trigger_lambda" {
  bucket = aws_s3_bucket.upload_bucket.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.s3_to_sns.arn
    events              = ["s3:ObjectCreated:Put"]
    # To trigger on ALL object creates (Put, Post, Copy, MultipartUpload):
    # events = ["s3:ObjectCreated:*"]
  }

  # Notification depends on the permission being granted first
  depends_on = [aws_lambda_permission.allow_s3_invoke]
}

# Allow S3 to invoke the Lambda function
resource "aws_lambda_permission" "allow_s3_invoke" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.s3_to_sns.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.upload_bucket.arn
}
