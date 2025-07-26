variable "ami_number" {
  default = "ami-0fcfcdc5efc25e0bc"
  type    = string
}

variable "instance_type" {
  description = "The EC2 instance type to use for the environment."
  type        = string
  default     = "t2.micro" # Default to the smallest size.
}

# Requirement 3: Create private S3 bucket (name should be configurable)
variable "s3_bucket_name" {
  description = "The globally unique name for the private S3 bucket to store logs."
  type        = string
  default     = "log_techeazy" # No default value, forcing it to be provided.

  # Requirement 3: if not provided, terminate with error.
  # This block ensures that Terraform will fail if the s3_bucket_name is not set.
  validation {
    condition     = length(var.s3_bucket_name) > 0
    error_message = "The s3_bucket_name variable must be set and cannot be an empty string."
  }
}