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