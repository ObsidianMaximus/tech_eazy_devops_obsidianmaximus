# --- S3 Bucket for Logs ---

# Requirement 3: Create private S3 bucket (name should be configurable)
resource "aws_s3_bucket" "log_bucket" {
  bucket = var.s3_bucket_name
}

resource "aws_s3_bucket_acl" "log_bucket_acl" {
  bucket = aws_s3_bucket.log_bucket.id
  acl    = "private"
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

    # This filter applies the rule to all objects in the bucket.
    filter {}
  }
}

# --- IAM Policies and Roles ---

# Requirement 1.b & 2: Create a policy with S3 write access and attach to the EC2 role.
# An EC2 instance can only have one IAM role, so we add the new permissions
# to the existing role from the first assignment (`ssm_role`).
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
        Resource = "arn:aws:s3:::${var.s3_bucket_name}/*" # Grant access only to objects within the bucket
      }
    ]
  })
}

# Attach the new S3 write policy to the existing EC2 instance role.
resource "aws_iam_role_policy_attachment" "attach_s3_write_policy" {
  role       = aws_iam_role.ssm_role.name # This is the role defined in roles_and_security.tf
  policy_arn = aws_iam_policy.s3_write_policy.arn
}


# Requirement 1.a & 7: Create a separate role with read-only access for verification.
# This role is not attached to any service; it will be assumed by our workflow.
resource "aws_iam_role" "s3_read_only_role" {
  name = "techeazy-s3-read-only-role"

  # Trust policy allowing an IAM user/role to assume this role.
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          # This allows the root user of the AWS account to assume this role.
          # This is a secure way to grant temporary permissions to trusted entities.
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

# Data source to get the current AWS account ID for use in the assume_role_policy.
data "aws_caller_identity" "current" {}

# --- Outputs ---

output "s3_bucket_name" {
  description = "The name of the S3 bucket created for logging."
  value       = aws_s3_bucket.log_bucket.id
}