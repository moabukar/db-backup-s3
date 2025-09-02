# DB Backup to S3

A simple K8s cron to backup a database to S3.

## Usage

```bash
kind create cluster --config=kind-config.yaml --name backup-test

docker-compose up -d
```

## Commands

```bash
# Setup
./test-lab.sh

# 2. Create test data 
./create-test-data.sh

# 3. Wait for backup job or trigger manually
kubectl create job --from=cronjob/rds-backup-job-local manual-test-$(date +%s)

# 4. Verify backup worked
./verify-backup.sh

# 5. Check LocalStack S3 contents
awslocal s3 ls s3://rds-db-backups-co-create/ --recursive
```

## Cleanup

```bash
# Stop everything
kind delete cluster --name backup-test
docker-compose down
docker system prune -f

# Remove test files
rm -f *.dump lifecycle-policy.json
```