module "aws_ses_forwarder" {
  source = "./modules/aws-ses-forwarder"

  # variable with no default value
  common_tags             = var.common_tags
  region                  = var.region
  bucket_name             = var.bucket_name
  domain_name             = var.domain_name
  email_verification_list = var.email_verification_list

}