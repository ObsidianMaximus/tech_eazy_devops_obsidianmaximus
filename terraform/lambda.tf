resource "aws_iam_role" "lambda_ec2_stop_role" {
  name = "lambda-ec2-stop-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "lambda_ec2_stop_policy" {
  name = "lambda-ec2-stop-policy"
  role = aws_iam_role.lambda_ec2_stop_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:StopInstances",
          "ec2:DescribeInstances"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_lambda_function" "stop_ec2" {
  filename         = "${path.module}/stop_ec2_lambda.zip"
  function_name    = "stop-ec2-lambda"
  role             = aws_iam_role.lambda_ec2_stop_role.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.9"
  source_code_hash = filebase64sha256("${path.module}/stop_ec2_lambda.zip")

  environment {
    variables = {
      # Optionally add any env vars here
    }
  }
}

output "stop_ec2_lambda_arn" {
  value = aws_lambda_function.stop_ec2.arn
}