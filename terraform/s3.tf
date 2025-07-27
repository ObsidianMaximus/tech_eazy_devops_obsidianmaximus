resource "aws_s3_bucket" "log_bucket" {
  bucket = var.bucket_name
  force_destroy = true

  tags = {
    Name        = "TechEazyLogs"
  }
}

resource "aws_s3_bucket_versioning" "log_bucket_versioning" {
  bucket = aws_s3_bucket.log_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "expire_logs" {
  bucket = aws_s3_bucket.log_bucket.id

  rule {
    id = "expire_logs_rule"

    filter {}  # Applies to all objects

    expiration {
      days = 7
    }

    noncurrent_version_expiration {
      noncurrent_days = 7
    }

    status = "Enabled"
  }
}

# Read-only part

resource "aws_iam_policy" "s3_read_policy" {
  name        = "S3ReadPolicy"
  description = "Policy to allow read access to the S3 bucket"
  policy      = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect    = "Allow",
        Action    = ["s3:GetObject", "s3:ListBucket"],
        Resource  = [
          "${aws_s3_bucket.log_bucket.arn}/*",
          aws_s3_bucket.log_bucket.arn
        ]
      }
    ]
  })
}

resource "aws_iam_role" "s3_read_role" {
  name               = "S3ReadRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect    = "Allow",
            Principal = {
            Service = "ec2.amazonaws.com"
            },
            Action    = "sts:AssumeRole"
        }
        ]
    })
}

resource "aws_iam_role_policy_attachment" "s3_read_policy_attachment" {
  role       = aws_iam_role.s3_read_role.name
  policy_arn = aws_iam_policy.s3_read_policy.arn
}

# Write only part

resource "aws_iam_policy" "s3_write_policy" {
  name        = "S3WritePolicy"
  description = "Policy to allow write access to the S3 bucket"
  policy      = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect    = "Allow",
        Action    = ["s3:PutObject", "s3:CreateBucket"],
        Resource = [
          "${aws_s3_bucket.log_bucket.arn}/*",
          aws_s3_bucket.log_bucket.arn
        ]
      }
    ]
  })
}

resource "aws_iam_role" "s3_write_role" {
  name               = "S3WriteRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect    = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        },
        Action    = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "s3_write_policy_attachment" {
  role       = aws_iam_role.s3_write_role.name
  policy_arn = aws_iam_policy.s3_write_policy.arn
}