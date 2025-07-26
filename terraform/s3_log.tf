# -----------------------------------------------------------------------------
# FILE: terraform/s3_and_iam.tf (Corrected)
#
# This version fixes the "AccessControlListNotSupported" error by:
#   1. Removing the outdated `aws_s3_bucket_acl` resource.
#   2. Explicitly disabling ACLs using `aws_s3_bucket_ownership_controls`.
#   3. Adding `aws_s3_bucket_public_access_block` to ensure the bucket is private.
# -----------------------------------------------------------------------------

# --- S3 Bucket for Logs ---

resource "aws_s3_bucket" "log_bucket" {
  bucket = var.s3_bucket_name
}

# **FIX:** The `aws_s3_bucket_acl` resource has been removed.

# **NEW:** This resource explicitly sets the bucket owner as the owner of all
# objects and disables ACLs. This is the modern, recommended approach.
resource "aws_s3_bucket_ownership_controls" "log_bucket_ownership" {
  bucket = aws_s3_bucket.log_bucket.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# **NEW:** This resource ensures that no public access policies can be applied
# to the bucket, making it truly private.
resource "aws_s3_bucket_public_access_block" "log_bucket_public_access" {
  bucket = aws_s3_bucket.log_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Requirement 6: Add S3 lifecycle rule to delete logs after 7 days.
resource "aws_s3_bucket_lifecycle_configuration" "log_bucket_lifecycle" {
  bucket = aws_s3_bucket.log_bucket.id

  rule {
    id     = "delete-logs-after-7-days"
    status = "Enabled"

    expiration {
      days = 7
    }
    filter {}
  }
}

# --- IAM Policies and Roles ---
# (The rest of the file remains the same)

resource "aws_iam_policy" "s3_write_policy" {
  name        = "techeazy-s3-write-policy"
  description = "Allows creating buckets and uploading objects to a specific S3 bucket."

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = [
            "s3:PutObject"
        ],
        Resource = "arn:aws:s3:::${var.s3_bucket_name}/*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_s3_write_policy" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = aws_iam_policy.s3_write_policy.arn
}

resource "aws_iam_role" "s3_read_only_role" {
  name = "techeazy-s3-read-only-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_policy" "s3_read_only_policy" {
  name        = "techeazy-s3-read-only-policy"
  description = "Allows listing and reading objects from a specific S3 bucket."

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = [
            "s3:ListBucket",
            "s3:GetObject"
        ],
        Resource = [
          "arn:aws:s3:::${var.s3_bucket_name}",
          "arn:aws:s3:::${var.s3_bucket_name}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_s3_read_policy" {
  role       = aws_iam_role.s3_read_only_role.name
  policy_arn = aws_iam_policy.s3_read_only_policy.arn
}

data "aws_caller_identity" "current" {}

# --- Outputs ---

output "s3_bucket_name" {
  description = "The name of the S3 bucket created for logging."
  value       = aws_s3_bucket.log_bucket.id
}
