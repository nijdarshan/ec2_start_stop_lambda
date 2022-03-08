provider "aws" {
  region = "ap-south-1"
}

module "ec2_start_stop"{
	source = "../"

	client_name                        = "AWS"
	create_ec2_start_stop_iam_role     = true
	ec2_start_stop_iam_role_arn        = ""
	ec2_start_cron_schedule_expression = "cron(27 10 ? * MON-SUN *)"
	ec2_stop_cron_schedule_expression  = "cron(29 10 ? * MON-SUN *)"
	ec2_state_change_email             = "xxxxxxxxxxxx@xxxx.com"
}
