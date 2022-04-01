# tf-aws-ses-forwarder - Inspired AWS Email Forwarder

Heaviliy inspired by https://nealalan.github.io/AWS-Email-Forwarder/

The author did an excellent explanation and tutorial on how to use Route 53, SES, S3 & Lambda to implement an email forwarder via the AWS CLI. I do have a personnal preference for Terraform.

There are other (and probably more mature) terraform modules out there to perform this task like:

- https://github.com/cloudposse/terraform-aws-ses-lambda-forwarder
- https://github.com/alemuro/terraform-aws-ses-email-forwarding

I still did the exercise to translate this procedure into a Terraform module. This implementation is maybe simpler to
walkthrough if you are newer to Terraform. 

## Assumption

Your DNS domain is managed by AWS Route 53.

## Preparation work

- git clone this repository
- cd tf
- prepare the lambda function code as described here below
 
### Pull the code used in the lambda fucntion

Pull down the pre-written Javascript function that we will modify add to a new Lambda function.

```bash
$ curl https://raw.githubusercontent.com/arithmetric/aws-lambda-ses-forwarder/master/index.js > aws-lambda-ses-forwarder.js
```

### Edit the javascript code

Configure the lambda function for your needs. Make the following changes:

  - **fromEmail**: noreply@example.com changed to noreply@your_domain_com
  - **subjectPrefix**: from “” to “FWD: ” (or anything else to inform on the forwarding origin of the email)
  - **emailBucket**: s3-bucket-name to the bucket name you will use as mail store
  - **emailKeyPrefix**: "emailsPrefix/" to “email/”
  - **forwardMapping**: There are a bunch of entries and you only need to change or apply what applies to you. Only email from the registered domain name will be processed by the Lambda function. Therefore, change: 
  	"@example.com": [ "example.john@example.com" ] 
	  TO
	  “@your_domain_name”: [ “the_email_address_where_you_forward” ]
  - **Save** the JavaScript function
  - **Archive the function** into a ZIP file 
  ```
  $ zip aws-lambda-ses-forwarder.zip aws-lambda-ses-forwarder.js
  ```

## Terraform project configuration

- configure your prefered Terraform backend
- define the terraform variables (non-default & overwritten values)

Minimal value to supply:

```
region = "aws_region"
common_tags = {
    "key" = "value"
    ...
}
bucket_name = "your_email_store_bucket_name"
domain_name = "your_forwarding_domain"
email_verification_list = [ "email_addr_where_you_forward"]
```

## Deploy with Terraform

```
terraform init
terraform plan
terraform apply
```

