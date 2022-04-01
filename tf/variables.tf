# Variables to be supplied to meet your setup requirements
variable "region" {
  description = "AWS Region where to deploy this Email forwarder"
  type        = string
}

variable "common_tags" {
  description = "A map of tags to use on all resources"
  type        = map(string)
  default     = {}

  # Suggested common tags
  # default = {
  #    AppID = "Email-Fw"
  #    Env = "Prod"
  #    Owner = "your_name" 
  # }

}

variable "domain_name" {
  description = "DNS domain for which you will apply the Email forwarder"
  type        = string
}

variable "email_verification_list" {
  description = "List to validate all adresses used as final recipient in your lambda function"
  type        = list(string)
}

variable "bucket_name" {
  description = "Name of the S3 bucket to store the incoming mail"
  type        = string
}

# Default value for the lambda path assume you are following the README.md
variable "aws_lambda_ses_forwarder_zip" {
  description = "ZIP file containing the personnalized email forwarder lambda function"
  type        = string
  default     = "../../aws-lambda-ses-forwarder.zip"
}

# Variables with Default value provided (update if they don't meet your AWS naming convention)
variable "ses_actions_iam_policy_name" {
  description = "Name of the IAM policy allowing SES to write to S3 & CloudWatchLogs"
  type        = string
  default     = "SES-Write-S3-CloudWatchLogs"
}

variable "ses_role_name" {
  description = "Name of the IAM role for SES"
  type        = string
  default     = "SESMailForwarder"
}
