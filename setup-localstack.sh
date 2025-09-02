#!/bin/bash
set -euo pipefail

echo "Setting up LocalStack S3 for backup testing..."

echo "⏳ Waiting for LocalStack to start..."
while ! curl -s http://localhost:4566/health > /dev/null; do
  sleep 2
done

echo "✅ LocalStack is ready"

# config aws cli
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=us-east-1
export AWS_ENDPOINT_URL=http://localhost:4566

echo "Creating S3 bucket..."
awslocal s3 mb s3://rds-db-backups-co-create

# lifecycle policy for s3
cat > lifecycle-policy.json << EOF
{
  "Rules": [
    {
      "ID": "move-to-glacier",
      "Status": "Enabled",
      "Filter": {
        "Prefix": ""
      },
      "Transitions": [
        {
          "Days": 30,
          "StorageClass": "GLACIER"
        }
      ],
      "Expiration": {
        "Days": 365
      }
    }
  ]
}
EOF

echo "⚙️ Applying lifecycle policy..."
awslocal s3api put-bucket-lifecycle-configuration \
  --bucket rds-db-backups-co-create \
  --lifecycle-configuration file://lifecycle-policy.json

echo "✅ LocalStack S3 setup complete!"
echo "📋 Bucket contents:"
awslocal s3 ls s3://rds-db-backups-co-create/