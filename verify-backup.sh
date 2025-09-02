#!/bin/bash
set -euo pipefail

echo "🔍 Verifying backup integrity..."

# Configure LocalStack AWS CLI
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=us-east-1
export AWS_ENDPOINT_URL=http://localhost:4566

# List all backups
echo "📋 Available backups:"
awslocal s3 ls s3://rds-db-backups-co-create/ --recursive --human-readable

# Download latest backup
LATEST_BACKUP=$(awslocal s3 ls s3://rds-db-backups-co-create/ --recursive | sort | tail -n 1 | awk '{print $4}')

if [ -z "$LATEST_BACKUP" ]; then
    echo "❌ No backups found!"
    exit 1
fi

echo "📥 Downloading latest backup: $LATEST_BACKUP"
awslocal s3 cp s3://rds-db-backups-co-create/$LATEST_BACKUP ./test-restore.dump

# Test restore to temporary database
echo "🔄 Testing restore..."
kubectl exec -it deployment/postgres-replica -- createdb -U root test_restore

kubectl exec -i deployment/postgres-replica -- pg_restore \
    -U root \
    -d test_restore \
    --verbose \
    --clean \
    --if-exists < ./test-restore.dump

# Verify restored data
echo "✅ Verifying restored data..."
kubectl exec -it deployment/postgres-replica -- psql -U root -d test_restore -c "
SELECT 'Restored users:' as info, count(*) as count FROM users
UNION ALL  
SELECT 'Restored projects:' as info, count(*) as count FROM projects;
"

echo "🎉 Backup verification complete!"