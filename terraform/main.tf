resource "aws_instance" "techeazy-devops" {
  ami           = var.ami_number
  instance_type = var.instance_type # Use the variable here
  security_groups = [aws_security_group.allow_http.name]
  iam_instance_profile = aws_iam_instance_profile.ssm_instance_profile.name
  # This line is the key change.
  # It takes the userdata.sh script and replaces any variables inside it
  # (like ${S3_BUCKET_NAME}) with values we provide from our Terraform configuration.
  # This is how the shutdown script on the instance will know which bucket to upload logs to.
  user_data = templatefile("${path.module}/userdata.sh", {
    S3_BUCKET_NAME = var.s3_bucket_name
  })

  # This ensures that if we change the user_data script, Terraform will replace
  # the instance to apply the new script.
  user_data_replace_on_change = true

  tags = {
    Name = "techeazy-SSM-Managed-Instance"
  }
}

output "ec2_instance_id" {
  value = aws_instance.techeazy-devops.id
}

output "ec2_public_ip" {
  value = aws_instance.techeazy-devops.public_ip
}