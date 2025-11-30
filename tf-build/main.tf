#Configure S3 Bucket

resource "aws_s3_bucket" "s3_bucket" {
  bucket = "s3snsprojectwithterraform"




  tags = {
    Name        = "My bucket"
    Environment = "test"
  }
}


#Enable Versioning

resource "aws_s3_bucket_versioning" "s3_bucket_versioning" {
  bucket = aws_s3_bucket.s3_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

#Sns Topic

resource "aws_sns_topic" "s3_load_topic" {
  name = "s3_load_topic"
}

