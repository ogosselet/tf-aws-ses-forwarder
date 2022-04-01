# Implementation of https://nealalan.github.io/AWS-Email-Forwarder/ using Terraform
# 
# Reference to the configuration steps of the blog post

# Step-2 - Create an S3 Bucket
resource "aws_s3_bucket" "mail_store" {
  bucket        = var.bucket_name
  force_destroy = true

  tags = merge(
    local.tags,
    {
      Name = "EFW-${var.domain_name}"
    },
  )

  lifecycle {
    ignore_changes = [
      tags["CreationDate"],
    ]
  }
}

# Step-4 & 5 - Bucket Lifecycle policy
resource "aws_s3_bucket_lifecycle_configuration" "expire_90d" {
  bucket = aws_s3_bucket.mail_store.id

  rule {
    id = "Expire90"

    filter {
      prefix = "email/"
    }

    expiration {
      days = 90
    }

    status = "Enabled"
  }
}

# Step-7 - Query the account id
data "aws_caller_identity" "current" {}

# Step-8 - Create a bucket policy
data "aws_iam_policy_document" "bucket_policy" {
  statement {
    sid     = "AllowSESPuts"
    effect  = "Allow"
    actions = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.mail_store.arn}/*"]
    condition {
      test     = "StringEquals"
      values   = [data.aws_caller_identity.current.account_id]
      variable = "aws:Referer"
    }
    principals {
      type        = "Service"
      identifiers = ["ses.amazonaws.com"]
    }
  }
}

resource "aws_s3_bucket_policy" "ses_put" {
  bucket = aws_s3_bucket.mail_store.id
  policy = data.aws_iam_policy_document.bucket_policy.json
}

# Step-10 - Create a new IAM policy
resource "aws_iam_policy" "ses_actions" {
  name        = var.ses_actions_iam_policy_name
  description = "SES access to S3 & CloudWatch (Email Forwarder)"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ses:SendEmail",
          "logs:CreateLogStream",
          "logs:CreateLogGroup",
          "ses:SendRawEmail",
          "logs:PutLogEvents"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action = [
          "s3:PutObject",
          "s3:GetObject"
        ]
        Effect = "Allow"
        Resource = "${aws_s3_bucket.mail_store.arn}/*"
      }

    ]
  })
}

# Step-14 - Create an IAM role
resource "aws_iam_role" "ses_role" {
  name = var.ses_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      },
    ]
  })

  tags = merge(
    local.tags,
    {
      Name = var.ses_role_name
    },
  )

  lifecycle {
    ignore_changes = [
      tags["CreationDate"],
    ]
  }
}

# Step-17 - Attach policy to the role
resource "aws_iam_role_policy_attachment" "attach" {
  role       = aws_iam_role.ses_role.name
  policy_arn = aws_iam_policy.ses_actions.arn
}

# Step-19 & 20 - Perform the manual action as described in README
/*
curl https://raw.githubusercontent.com/arithmetric/aws-lambda-ses-forwarder/master/index.js > aws-lambda-ses-forwarder.js

Make the changes required in the .js

zip aws-lambda-ses-forwarder.zip aws-lambda-ses-forwarder.js

Your lambda code file is no ready !
*/

# Step-21 - Create the lambda fucntion
resource "aws_lambda_function" "ses_forwarder" {
  filename      = var.aws_lambda_ses_forwarder_zip
  function_name = "arn:aws:lambda:${var.region}:${data.aws_caller_identity.current.id}:function:SESForwarder-${replace(var.domain_name, ".", "_")}"
  role    = aws_iam_role.ses_role.arn
  handler = "aws-lambda-ses-forwarder.handler"

  source_code_hash = filebase64sha256("aws-lambda-ses-forwarder.zip")

  runtime = "nodejs12.x"

}

# Step-22 & 23 - Retrieve domain info & configure MX record
data "aws_route53_zone" "selected" {
  name = "${var.domain_name}."
}

resource "aws_route53_record" "mx" {
  zone_id = data.aws_route53_zone.selected.zone_id
  name    = data.aws_route53_zone.selected.name
  type    = "MX"
  ttl     = "300"
  records = ["10 inbound-smtp.${var.region}.amazonaws.com"]
}

# Step-26 & 27 - DNS Record for SES verification
resource "aws_ses_domain_identity" "forwarded_domain" {
  domain = var.domain_name
}

resource "aws_route53_record" "amazonses_verification_record" {
  zone_id = data.aws_route53_zone.selected.zone_id
  name    = "_amazonses.${var.domain_name}"
  type    = "TXT"
  ttl     = "600"
  records = [aws_ses_domain_identity.forwarded_domain.verification_token]
}

# Step-29 & 30 - Generate SES dkim values
resource "aws_ses_domain_dkim" "forwarded_domain" {
  domain = aws_ses_domain_identity.forwarded_domain.domain
}

resource "aws_route53_record" "amazonses_dkim_record" {
  count   = 3
  zone_id = data.aws_route53_zone.selected.zone_id
  name    = "${element(aws_ses_domain_dkim.forwarded_domain.dkim_tokens, count.index)}._domainkey"
  type    = "CNAME"
  ttl     = "600"
  records = ["${element(aws_ses_domain_dkim.forwarded_domain.dkim_tokens, count.index)}.dkim.amazonses.com"]
}

# Step-34 - Activate a blank SES rule set
resource "aws_ses_receipt_rule_set" "main" {
  rule_set_name = "default-rule-set"
}

# Activate rule-set
resource "aws_ses_active_receipt_rule_set" "main" {
  rule_set_name = "default-rule-set"
}

# Step-35 - SES permission to invoke lambda function
resource "aws_lambda_permission" "allow_ses" {
  statement_id  = "GiveSESPermissionToInvokeFunction"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ses_forwarder.arn
  principal     = "ses.amazonaws.com"
}

# Step-36 - Create rules to the SES rule set
resource "aws_ses_receipt_rule" "store" {
  name          = "store_and_forward-rules"
  rule_set_name = aws_ses_receipt_rule_set.main.rule_set_name
  recipients    = [var.domain_name]
  enabled       = true
  scan_enabled  = true
  tls_policy    = "Optional"

  s3_action {
    bucket_name       = aws_s3_bucket.mail_store.bucket
    position          = 1
    object_key_prefix = "email/"
  }

  lambda_action {
    function_arn    = aws_lambda_function.ses_forwarder.arn
    invocation_type = "Event"
    position        = 2
  }

}

# Step-39 - Verify  
resource "aws_ses_email_identity" "example" {
  for_each = toset(var.email_verification_list)

  email = each.key
}
