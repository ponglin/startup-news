# Terraform configuration for Startup News platform on GCP
# Manages Cloud Functions, Firestore, Pub/Sub, Cloud Scheduler, and related resources

terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# Enable required APIs
resource "google_project_service" "required_apis" {
  for_each = toset([
    "cloudfunctions.googleapis.com",
    "cloudbuild.googleapis.com",
    "firestore.googleapis.com",
    "pubsub.googleapis.com",
    "cloudscheduler.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "iam.googleapis.com",
    "artifactregistry.googleapis.com"
  ])
  service            = each.value
  disable_on_destroy = false
}

# Firestore Database
resource "google_firestore_database" "startup_news" {
  project             = var.project_id
  name                = "startup-news-db"
  location_id         = var.region
  type                = "FIRESTORE_NATIVE"
  concurrency_mode    = "OPTIMISTIC"
  depends_on = [google_project_service.required_apis]
}

# Cloud Storage bucket for logging and data
resource "google_storage_bucket" "startup_news" {
  name     = "${var.project_id}-startup-news"
  location = var.region
  uniform_bucket_level_access = true

  versioning {
    enabled = true
  }

  lifecycle_rule {
    action {
      type          = "SetStorageClass"
      storage_class = "NEARLINE"
    }
    condition {
      age = 90
    }
  }
}

# Pub/Sub Topic for news aggregation trigger
resource "google_pubsub_topic" "startup_news_trigger" {
  name   = "startup-news-trigger"
  labels = {
    environment = "production"
    application = "startup-news"
  }

  depends_on = [google_project_service.required_apis]
}

# Pub/Sub Subscription
resource "google_pubsub_subscription" "startup_news_sub" {
  name   = "startup-news-subscription"
  topic  = google_pubsub_topic.startup_news_trigger.name
  ack_deadline_seconds = 60

  depends_on = [google_project_service.required_apis]
}

# Service Account for Cloud Functions
resource "google_service_account" "startup_news_function" {
  account_id   = "startup-news-function"
  display_name = "Service Account for Startup News Aggregation"
}

# IAM Binding for Cloud Functions service account
resource "google_project_iam_member" "function_firestore" {
  project = var.project_id
  role    = "roles/datastore.user"
  member  = "serviceAccount:${google_service_account.startup_news_function.email}"
}

resource "google_project_iam_member" "function_pubsub" {
  project = var.project_id
  role    = "roles/pubsub.editor"
  member  = "serviceAccount:${google_service_account.startup_news_function.email}"
}

resource "google_project_iam_member" "function_storage" {
  project = var.project_id
  role    = "roles/storage.objectAdmin"
  member  = "serviceAccount:${google_service_account.startup_news_function.email}"
}

# Cloud Scheduler for automatic news aggregation (daily at 2 AM UTC)
resource "google_cloud_scheduler_job" "startup_news_aggregation" {
  name             = "startup-news-daily-aggregation"
  description      = "Daily aggregation of startup news from multiple sources"
  schedule         = "0 2 * * *"
  time_zone        = "UTC"
  attempt_deadline = "320s"
  region           = var.region

  pubsub_target {
    topic_name = google_pubsub_topic.startup_news_trigger.id
    data       = base64encode(jsonencode({ "action" = "aggregate" }))
  }

  depends_on = [google_project_service.required_apis]
}

# Local variables for Cloud Function
locals {
  function_name = "aggregate-startup-news"
  runtime       = "python39"
  source_dir    = "../../functions/aggregate-news"
}

# Generate archive of Cloud Function source code
data "archive_file" "function_source" {
  type        = "zip"
  source_dir  = "${path.module}/${local.source_dir}"
  output_path = "${path.module}/function-source.zip"
}

# Cloud Function
resource "google_cloudfunctions_function" "startup_news" {
  name        = local.function_name
  description = "Aggregates startup news from multiple sources and processes with Gemini"
  runtime     = local.runtime
  region      = var.region
  available_memory_mb = 256

  source_archive_bucket = google_storage_bucket.startup_news.name
  source_archive_object = google_storage_bucket_object.function_source.name

  event_trigger {
    event_type = "google.pubsub.topic.publish"
    resource   = google_pubsub_topic.startup_news_trigger.id
  }

  entry_point = "main"

  service_account_email = google_service_account.startup_news_function.email

  environment_variables = {
    GEMINI_API_KEY   = var.gemini_api_key
    FIREBASE_PROJECT = var.project_id
  }

  timeout = 540

  depends_on = [
    google_project_service.required_apis,
    google_storage_bucket_object.function_source
  ]
}

# Upload function source to Cloud Storage
resource "google_storage_bucket_object" "function_source" {
  name   = "function-${data.archive_file.function_source.output_base64sha256}.zip"
  bucket = google_storage_bucket.startup_news.name
  source = data.archive_file.function_source.output_path
}

# Outputs
output "firestore_database" {
  value       = google_firestore_database.startup_news.name
  description = "Firestore database name"
}

output "storage_bucket" {
  value       = google_storage_bucket.startup_news.name
  description = "Cloud Storage bucket for data and logs"
}

output "pubsub_topic" {
  value       = google_pubsub_topic.startup_news_trigger.name
  description = "Pub/Sub topic for news aggregation"
}

output "cloud_function_name" {
  value       = google_cloudfunctions_function.startup_news.name
  description = "Cloud Function name"
}

output "scheduler_job" {
  value       = google_cloud_scheduler_job.startup_news_aggregation.name
  description = "Cloud Scheduler job for daily aggregation"
}
