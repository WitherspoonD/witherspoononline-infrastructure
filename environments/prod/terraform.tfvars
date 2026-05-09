# environments/prod/terraform.tfvars
# ─────────────────────────────────────────────────────────────────────────────
# This file is in .gitignore — safe to put real values here.
# Never commit credentials, account IDs, or personal emails to git.
# ─────────────────────────────────────────────────────────────────────────────

aws_region   = "us-east-1"
project_name = "witherspoon-resume"
domain_name  = "witherspoononline.com"
alert_email  = "desmond.witherspoon@gmail.com"
dynamodb_table_name = "cloudResumeCounter"
lambda_function_name = "lambdaDynamodbCloudResumeChallenge"