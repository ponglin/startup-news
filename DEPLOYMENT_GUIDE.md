# Startup News Platform - Deployment Guide

## Overview

This is a comprehensive guide to deploy the Startup News Platform - an automated startup and venture capital news aggregation system powered by Google AI Studio (Gemini), Google Cloud Platform, and Terraform.

## Architecture

### Components
1. **Cloud Functions**: Aggregates news from 5 startup websites
2. **Firestore**: Stores processed news articles
3. **Cloud Pub/Sub**: Event-driven architecture for triggering aggregation
4. **Cloud Scheduler**: Automated daily aggregation (2 AM UTC)
5. **Google Gemini**: AI-powered news summarization and categorization
6. **Cloud Build**: Automated CI/CD deployment pipeline
7. **Terraform**: Infrastructure-as-code for reproducible deployments

### Data Flow
```
Cloud Scheduler (Daily)
       ↓
   Pub/Sub
       ↓
  Cloud Function
       ↓
  Web Scraping (5 sources)
       ↓
  Google Gemini API
       ↓
  Firestore Database
       ↓
  Web Frontend
```

## Prerequisites

Before deployment, ensure you have:

1. **GCP Account** with billing enabled
2. **Google Gemini API Key**
   - Get it from: https://aistudio.google.com/app/api-keys
3. **Terraform** (v1.0+)
4. **gcloud CLI** installed and configured
5. **GitHub account** with this repository

## Deployment Steps

### Step 1: Prepare Your Environment

```bash
# Set your GCP project ID
export PROJECT_ID="your-project-id"
export REGION="asia-east1"

# Authenticate with GCP
gcloud auth login
gcloud config set project $PROJECT_ID

# Enable required APIs
gcloud services enable compute.googleapis.com
gcloud services enable cloudfunctions.googleapis.com
gcloud services enable cloudbuild.googleapis.com
gcloud services enable firestore.googleapis.com
gcloud services enable pubsub.googleapis.com
gcloud services enable cloudscheduler.googleapis.com
```

### Step 2: Set Up GitHub Secrets

In your GitHub repository settings, add these secrets:

```
GCP_PROJECT_ID          = your-project-id
GCP_REGION              = asia-east1
GEMINI_API_KEY          = your-gemini-api-key
GCP_SA_KEY              = (service account JSON key - base64 encoded)
```

### Step 3: Create a Service Account for Cloud Build

```bash
# Create service account
gcloud iam service-accounts create startup-news-builder \
  --display-name="Service Account for Startup News Cloud Build"

# Grant necessary roles
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:startup-news-builder@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/owner"

# Create and download key
gcloud iam service-accounts keys create key.json \
  --iam-account="startup-news-builder@${PROJECT_ID}.iam.gserviceaccount.com"

# Encode key as base64 for GitHub Secrets
cat key.json | base64 > key.json.b64
```

### Step 4: Deploy Infrastructure with Terraform

```bash
# Navigate to Terraform directory
cd infra/terraform

# Initialize Terraform
terraform init

# Create terraform.tfvars
cat > terraform.tfvars << EOF
project_id     = "$PROJECT_ID"
region         = "$REGION"
gemini_api_key = "your-gemini-api-key"
environment    = "production"
EOF

# Plan deployment
terraform plan -out=tfplan

# Apply deployment
terraform apply tfplan

# Save outputs
terraform output > deployment_outputs.json
```

### Step 5: Set Up Cloud Build

```bash
# Connect GitHub repository to Cloud Build
gcloud builds connect --repository-name=startup-news --repository-owner=ponglin

# Create Cloud Build trigger
gcloud builds triggers create github \
  --name=startup-news-deploy \
  --repo-name=startup-news \
  --repo-owner=ponglin \
  --branch-pattern="^main$" \
  --build-config=cloudbuild.yaml
```

### Step 6: Deploy via Cloud Build

```bash
# Trigger manual build
gcloud builds submit --config=cloudbuild.yaml
```

## Verification

After deployment, verify the setup:

```bash
# Check Cloud Function status
gcloud functions describe aggregate-startup-news --region=$REGION

# Check Cloud Scheduler job
gcloud scheduler jobs describe startup-news-daily-aggregation --location=$REGION

# Check Firestore database
gcloud firestore databases list

# View Cloud Function logs
gcloud functions logs read aggregate-startup-news --limit 50
```

## Data Sources

The platform aggregates news from:

1. **SparkLabs Taiwan** - https://www.sparklabstaiwan.com
2. **Startup 101** - https://startup101.biz/
3. **886 Studios** - https://886studios.com/resources
4. **500 Global** - https://500.co/
5. **AppWorks** - https://appworks.tw/

## Configuration

### Customize Aggregation Schedule

Edit `infra/terraform/main.tf` and modify the Cloud Scheduler schedule:

```hcl
schedule = "0 2 * * *"  # Daily at 2 AM UTC
```

Common cron expressions:
- `0 2 * * *` - Daily at 2 AM UTC
- `0 2 * * 1-5` - Weekdays at 2 AM UTC
- `*/6 * * * *` - Every 6 hours

### Adjust Cloud Function Memory

In `infra/terraform/main.tf`, modify:

```hcl
available_memory_mb = 512  # Default: 256
```

## Monitoring

### View Cloud Function Metrics

```bash
# Using gcloud
gcloud monitoring time-series list \
  --filter='metric.type="cloudfunctions.googleapis.com/function/execution_times"'
```

### Set Up Alerts

```bash
# Create alert policy for function errors
gcloud alpha monitoring policies create \
  --notification-channels=YOUR_CHANNEL_ID \
  --display-name="Startup News Function Errors" \
  --condition-display-name="High error rate"
```

## Troubleshooting

### Cloud Function Fails to Deploy

```bash
# Check build logs
gcloud builds log <BUILD_ID>

# Verify service account permissions
gcloud projects get-iam-policy $PROJECT_ID
```

### News Not Being Aggregated

```bash
# Check Cloud Scheduler execution history
gcloud scheduler jobs describe startup-news-daily-aggregation \
  --location=$REGION --format='json' | jq '.lastScheduleTime'

# Check Pub/Sub topic
gcloud pubsub topics list

# Test Cloud Function manually
gcloud functions call aggregate-startup-news --region=$REGION
```

### Firestore Access Issues

```bash
# Check Firestore permissions
gcloud firestore databases iam get-policy startup-news-db

# Grant additional permissions if needed
gcloud firestore databases add-iam-policy-binding startup-news-db \
  --member=serviceAccount:startup-news-function@${PROJECT_ID}.iam.gserviceaccount.com \
  --role=roles/datastore.user
```

## Cost Optimization

1. **Cloud Functions**: Only billed for execution time
   - Current: ~5 minutes daily = ~2.5 million invocations/month
   
2. **Firestore**: Free tier includes 1 GB storage
   
3. **Cloud Scheduler**: First 3 jobs free per month
   
4. **Cloud Build**: 120 build-minutes free per day

## Cleanup

To remove all resources:

```bash
# Destroy Terraform resources
cd infra/terraform
terraform destroy

# Delete service accounts
gcloud iam service-accounts delete startup-news-function@${PROJECT_ID}.iam.gserviceaccount.com
gcloud iam service-accounts delete startup-news-builder@${PROJECT_ID}.iam.gserviceaccount.com

# Delete Cloud Build triggers
gcloud builds triggers delete startup-news-deploy
```

## Support & Contributing

For issues or improvements, please:
1. Check existing GitHub issues
2. Submit bug reports with logs
3. Create pull requests for enhancements

## License

MIT License - See LICENSE file

## References

- [Google Cloud Platform Documentation](https://cloud.google.com/docs)
- [Terraform Google Provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
- [Google Gemini API](https://ai.google.dev/tutorials/python_quickstart)
- [Cloud Functions](https://cloud.google.com/functions/docs)
- [Cloud Scheduler](https://cloud.google.com/scheduler/docs)
- [Firestore](https://cloud.google.com/firestore/docs)
