variable "ami_number" {
  default = "ami-0fcfcdc5efc25e0bc"
  type    = string
}

variable "instance_type" {
  description = "The EC2 instance type to use for the environment."
  type        = string
  default     = "t2.micro" # Default to the smallest size.
}

variable "bucket_name" {
  description = "The name of the S3 bucket to create."
  type        = string
}

variable "stage" {
  description = "Deployment stage"
  type        = string
}