variable "client_name" {
  description = "Client name in the EC2 tag called Client"
  type        = string
}

variable "create_ec2_start_stop_iam_role" {
  description = "Whether to create a new EC2 start stop IAM role"
  type        = bool
  default     = true
}

variable "ec2_start_stop_iam_role_arn" {
  description = "ARN of EC2 start stop IAM role"
  type        = string
  default     = ""
}

variable "ec2_stop_cron_schedule_expression" {
  type        = string
  description = "The scheduling expression for stopping EC2. For example, cron(0 20 * * ? *) or rate(5 minutes)"
}

variable "ec2_start_cron_schedule_expression" {
  type        = string
  description = "The scheduling expression for starting EC2. For example, cron(0 20 * * ? *) or rate(5 minutes)"
}

variable "ec2_state_change_email" {
  type        = string
  description = "Email id to send data to"
}
