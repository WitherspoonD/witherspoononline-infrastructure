# witherspoononline.com — Terraform Infrastructure

This is a complete Terraform rebuild of the Cloud Resume Challenge infrastructure
originally deployed with SAM. It provisions every AWS resource for
`witherspoononline.com` as code — reproducible, reviewable, and version-controlled.

## Architecture

```
User → Route53 → CloudFront (+ WAF) → S3 (private, OAC)
                       ↓
               API Gateway → Lambda → DynamoDB
```

## What this replaces

| SAM / Console resource     | Terraform equivalent              |
|----------------------------|-----------------------------------|
| S3 bucket (website)        | `modules/s3`                      |
| CloudFront distribution    | `modules/cloudfront`              |
| ACM certificate            | `modules/dns`                     |
| Route53 records            | `modules/dns`                     |
| WAF WebACL                 | `modules/waf`                     |
| API Gateway                | `modules/api_gateway`             |
| Lambda function            | `modules/lambda`                  |
| DynamoDB table             | `modules/dynamodb`                |
| IAM roles & policies       | `modules/iam`                     |
| CloudWatch alarms          | `modules/monitoring`              |

## Security improvements over original SAM deploy

- S3 bucket is **fully private** — served only through CloudFront via OAC
- WAF with AWS Managed Rules (CommonRuleSet + KnownBadInputs) protects CloudFront
- All DynamoDB data encrypted at rest with AWS-managed key
- Lambda has least-privilege IAM role (DynamoDB read/write only, nothing else)
- CloudTrail enabled for audit logging
- CloudWatch alarm on Lambda errors + API 5xx errors

## Prerequisites

- Terraform >= 1.6
- AWS CLI configured with your profile
- S3 bucket for Terraform state (create once manually — see below)
- DynamoDB table for state locking (create once manually — see below)

## Bootstrap (one-time, run manually)

```bash
# Create state backend resources — do this ONCE before anything else
aws s3api create-bucket \
  --bucket witherspoon-terraform-state \
  --region us-east-1

aws s3api put-bucket-versioning \
  --bucket witherspoon-terraform-state \
  --versioning-configuration Status=Enabled

aws dynamodb create-table \
  --table-name witherspoon-terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

## Deploy

```bash
cd environments/prod

# First time
terraform init
terraform plan -out=tfplan
terraform apply tfplan

# Subsequent deploys
terraform plan -out=tfplan
terraform apply tfplan
```

## Destroy (careful — this deletes everything)

```bash
terraform destroy
```

## File layout

```
.
├── README.md
├── modules/
│   ├── s3/             # Website bucket (private) + static file upload
│   ├── cloudfront/     # Distribution, OAC, cache policies
│   ├── dns/            # Route53 records + ACM certificate
│   ├── waf/            # WAF WebACL with managed rules
│   ├── lambda/         # Visitor counter function + packaging
│   ├── dynamodb/       # Visitor count table
│   ├── api_gateway/    # HTTP API + Lambda integration + CORS
│   ├── iam/            # Lambda execution role
│   └── monitoring/     # CloudWatch alarms + SNS alerts
├── environments/
│   └── prod/           # Production wiring — calls all modules
└── scripts/
    └── package_lambda.sh   # Zips Lambda before terraform apply
```
