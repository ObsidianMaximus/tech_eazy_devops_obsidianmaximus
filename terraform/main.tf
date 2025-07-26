resource "aws_instance" "techeazy-devops" {
  ami           = var.ami_number
  instance_type = var.instance_type # Use the variable here
  security_groups = [aws_security_group.allow_http.name]
  iam_instance_profile = aws_iam_instance_profile.ssm_instance_profile.name
  user_data = file("userdata.sh")

  tags = {
    Name = "techeazy-SSM-Managed-Instance"
  }
}

resource "aws_iam_instance_profile" "s3_instance_profile" {
  name = "S3InstanceProfile"
  role = aws_iam_role.s3_write_role.name
}

output "ec2_instance_id" {
  value = aws_instance.techeazy-devops.id
}

output "ec2_public_ip" {
  value = aws_instance.techeazy-devops.public_ip
}