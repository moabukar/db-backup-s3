# DB Backup to S3

A simple K8s cron to backup a database to S3. Using localstack, KIND and PostgreSQL on K8s. 

## Usage

```bash
RDS Backup Test Makefile
========================

Available targets:
  setup           - Setup KIND cluster, LocalStack, and PostgreSQL
  test            - Run manual backup test (cronjob-based)
  test-working    - Run working backup test (simple job)
  verify          - Verify backup integrity and restore
  status          - Show current environment status
  logs            - Show logs from most recent backup job
  logs-follow     - Follow logs of running backup job
  test-db         - Test database connectivity
  test-s3         - Test LocalStack S3 connectivity
  e2e             - Complete end-to-end test
  quick           - Quick test cycle (cleanup -> setup -> test -> verify)
  cleanup         - Remove all lab resources
  help            - Show this help

Quick start: make setup && make test-working && make verify
```


## Known commands

```bash
# localstack conf (fake creds :) )
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=us-east-1

# list all backups
awslocal s3 ls s3://rds-db-backups-co-create/ --recursive --human-readable

# list just the backup folders
awslocal s3 ls s3://rds-db-backups-co-create/

# check a specific backup folder (replace with your timestamp)
awslocal s3 ls s3://rds-db-backups-co-create/2025-09-02-09-10/ --human-readable

# get file details for a specific backup
awslocal s3api head-object \
  --bucket rds-db-backups-co-create \
  --key "2025-09-02-09-10/langfuse_backup.dump"
```
