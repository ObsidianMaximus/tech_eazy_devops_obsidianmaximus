resource "aws_instance" "techeazy-devops" {
  ami           = var.ami_number
  instance_type = var.instance_type # Use the variable here
  security_groups = [aws_security_group.allow_http_ssh.name]
  iam_instance_profile = aws_iam_instance_profile.ssm_instance_profile.name
  user_data = file("userdata.sh")

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