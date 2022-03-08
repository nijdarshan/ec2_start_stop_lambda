data "aws_caller_identity" "account" {}

#----------------------------------------------
# IAM Role for EC2 List, Describe, Start & Stop
#----------------------------------------------

resource "aws_iam_role" "AWSEC2ReadStartStop" {
  count              = var.create_ec2_start_stop_iam_role ? 1 : 0
  name               = "AWSEC2ReadStartStop"
  assume_role_policy = jsonencode(
        {
            Statement = [
                {
                    Action    = "sts:AssumeRole"
                    Effect    = "Allow"
                    Principal = {
                        Service = "lambda.amazonaws.com"
                    }
                },
            ]
            Version = "2012-10-17"
        }
  )
  inline_policy {
    name   = "AWSEC2ReadStartStop"
    policy = jsonencode(
    {
        "Version"  : "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Action": [
                    "logs:CreateLogGroup",
                    "logs:CreateLogStream",
                    "logs:PutLogEvents"
                ],
                "Resource": "arn:aws:logs:*:*:*"
            },
            {
                "Effect": "Allow",
                "Action": [
                    "ec2:Start*",
                    "ec2:Stop*"
                ],
                "Resource": "*"
            },
            {
                "Effect"  : "Allow",
                "Action"  : "ec2:Describe*",
                "Resource": "*"
            },
            {
                "Effect"  : "Allow",
                "Action"  : "elasticloadbalancing:Describe*",
                "Resource": "*"
            },
            {
                "Effect": "Allow",
                "Action": [
                    "cloudwatch:ListMetrics",
                    "cloudwatch:GetMetricStatistics",
                    "cloudwatch:Describe*"
                ],
                "Resource": "*"
            },
            {
                "Effect"  : "Allow",
                "Action"  : "autoscaling:Describe*",
                "Resource": "*"
            }
        ]
    })
  }
}

#----------------------------------------------
# AWS Lambda function for EC2 Start
#----------------------------------------------

resource "aws_lambda_function" "AWSEC2Start" {
  filename         = "${path.module}/aws_ec2_start.zip"
  function_name    = "AWSEC2Start-${var.client_name}"
  role             = var.create_ec2_start_stop_iam_role ? aws_iam_role.AWSEC2ReadStartStop[0].arn : var.ec2_start_stop_iam_role_arn
  handler          = "aws_ec2_start.lambda_handler"
  source_code_hash = filebase64sha256("${path.module}/aws_ec2_start.zip")

  runtime = "python3.9"

  environment {
    variables = {
      CLIENT_NAME = "${var.client_name}"
    }
  }
}

#----------------------------------------------
# AWS Lambda function for EC2 Stop 
#----------------------------------------------

resource "aws_lambda_function" "AWSEC2Stop" {
  filename         = "${path.module}/aws_ec2_stop.zip"
  function_name    = "AWSEC2Stop-${var.client_name}"
  role             = var.create_ec2_start_stop_iam_role ? aws_iam_role.AWSEC2ReadStartStop[0].arn : var.ec2_start_stop_iam_role_arn
  handler          = "aws_ec2_stop.lambda_handler"
  source_code_hash = filebase64sha256("${path.module}/aws_ec2_stop.zip")

  runtime = "python3.9"

  environment {
    variables = {
      CLIENT_NAME = "${var.client_name}"
    }
  }
}

#----------------------------------------------
# AWS Cloudwatch Eventbrifge for EC2 Stop 
#----------------------------------------------

resource "aws_cloudwatch_event_rule" "AWSEC2Stop_cron" {
  name                = "ec2_stop_cron_${var.client_name}"
  schedule_expression = var.ec2_stop_cron_schedule_expression
}

resource "aws_cloudwatch_event_target" "ec2_stop_target_lambda" {
  arn  = aws_lambda_function.AWSEC2Stop.arn
  rule = aws_cloudwatch_event_rule.AWSEC2Stop_cron.id
}

#----------------------------------------------
# AWS Cloudwatch Eventbrifge for EC2 Start 
#----------------------------------------------

resource "aws_cloudwatch_event_rule" "AWSEC2Start_cron" {
  name                = "ec2_start_cron_${var.client_name}"
  schedule_expression = var.ec2_start_cron_schedule_expression
}

resource "aws_cloudwatch_event_target" "ec2_start_target_lambda" {
  arn  = aws_lambda_function.AWSEC2Start.arn
  rule = aws_cloudwatch_event_rule.AWSEC2Start_cron.id
}

#----------------------------------------------
# Allow Lambda Permissions to Cloudwatch Rules
#----------------------------------------------

resource "aws_lambda_permission" "allow_cloudwatch_ec2_stop" {
  statement_id  = "AllowExecutionFromCloudWatchEC2Stop"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.AWSEC2Stop.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.AWSEC2Stop_cron.arn
}

resource "aws_lambda_permission" "allow_cloudwatch_ec2_start" {
  statement_id  = "AllowExecutionFromCloudWatchEC2Start"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.AWSEC2Start.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.AWSEC2Start_cron.arn
}

#----------------------------------------------
# Send Email notification for EC2 state change 
#----------------------------------------------

resource "aws_sns_topic" "ec2_state_change" {
  name = "ec2-state-change-sns-topic"
}

resource "aws_sns_topic_subscription" "user_updates_sqs_target" {
  topic_arn = aws_sns_topic.ec2_state_change.arn
  protocol  = "email"
  endpoint  = var.ec2_state_change_email
}

resource "aws_cloudwatch_event_rule" "ec2_state_change" {
  name = "ec2-state-change-cw-rule"
  event_bus_name = "default"
  event_pattern  = jsonencode(
      {
          detail-type = [
              "EC2 Instance State-change Notification",
          ]
          source      = [
              "aws.ec2",
          ]
      }
  )
  is_enabled     = true
}

resource "aws_cloudwatch_event_target" "ec2_state_change_target" {
  arn  = aws_sns_topic.ec2_state_change.arn
  rule = aws_cloudwatch_event_rule.ec2_state_change.id

  input_transformer {
    input_paths = {
      "instance-id":"$.detail.instance-id", 
      "state":"$.detail.state", 
      "time":"$.time", 
      "region":"$.region", 
      "account":"$.account"
      }
    input_template = "\"At <time>, the status of your EC2 instance <instance-id> on account <account> in the AWS Region <region> has changed to <state>.\""
  }
}

resource "aws_sns_topic_policy" "user_updates" {
  arn    = aws_sns_topic.ec2_state_change.arn
  policy = jsonencode(
      {
          Id        = "__default_policy_ID"
          Statement = [
              {
                  Action    = [
                      "SNS:GetTopicAttributes",
                      "SNS:SetTopicAttributes",
                      "SNS:AddPermission",
                      "SNS:RemovePermission",
                      "SNS:DeleteTopic",
                      "SNS:Subscribe",
                      "SNS:ListSubscriptionsByTopic",
                      "SNS:Publish",
                  ]
                  Condition = {
                      StringEquals = {
                          "AWS:SourceOwner" = "${data.aws_caller_identity.account.id}"
                      }
                  }
                  Effect    = "Allow"
                  Principal = {
                      AWS = "*"
                  }
                  Resource  = "${aws_sns_topic.ec2_state_change.arn}"
                  Sid       = "__default_statement_ID"
              },
              {
                  Action    = "sns:Publish"
                  Effect    = "Allow"
                  Principal = {
                      Service = "events.amazonaws.com"
                  }
                  Resource  = "${aws_sns_topic.ec2_state_change.arn}"
                  Sid       = "AWSEC2InstanceChange"
              },
          ]
          Version   = "2008-10-17"
      }
  )
}
