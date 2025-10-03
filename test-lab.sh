#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"


echo "Creating KIND cluster..."

if kind get clusters | grep -q backup-test; then
  echo "KIND cluster already exists, skipping creation"
else
  kind create cluster --config=kind-config.yaml --name backup-test
fi

echo "Starting LocalStack..."

if docker ps | grep -q localstack; then
  echo "LocalStack container already exists, skipping creation"
else
  docker-compose up -d
fi

echo "⏳ Waiting for LocalStack..."
sleep 10

echo "Setting up LocalStack S3..."
./setup-localstack.sh

echo "Deploying test PostgreSQL..."
kubectl apply -f postgres-deployment.yaml

echo "⏳ Waiting for PostgreSQL to start..."
kubectl wait --for=condition=ready pod -l app=postgres-replica --timeout=120s

echo "Creating test data..."

# ensure langfuse database exists (idempotent)
kubectl exec deployment/postgres-replica -- psql -U root -d postgres -tc "SELECT 1 FROM pg_database WHERE datname = 'langfuse'" | grep -q 1 || \
  kubectl exec deployment/postgres-replica -- psql -U root -d postgres -c "CREATE DATABASE langfuse;"

kubectl exec deployment/postgres-replica -- psql -U root -d langfuse -c "
CREATE TABLE IF NOT EXISTS test_backup (
  id SERIAL PRIMARY KEY,
  name VARCHAR(100),
  created_at TIMESTAMP DEFAULT NOW()
);

INSERT INTO test_backup (name) VALUES 
  ('Test Record 1'),
  ('Test Record 2'),
  ('Test Record 3');

SELECT * FROM test_backup;
"

echo "Deploying backup system..."
kubectl apply -f local-backup-secret.yaml
kubectl apply -f backup-cron.yaml

echo "Running manual backup test..."
kubectl create job --from=cronjob/rds-backup-cronjob manual-backup-test || true

echo "Watching backup job logs..."
kubectl wait --for=condition=complete job/manual-backup-test --timeout=300s
kubectl logs job/manual-backup-test

# verify in localstack
echo "Verifying backup in LocalStack S3..."
awslocal s3 ls s3://rds-db-backups-co-create/ --recursive --human-readable

echo "🎉 Lab test complete!"
