.PHONY: all setup test verify cleanup status help

all: help

check-prereqs:
	@echo "Checking prerequisites..."
	@command -v kind >/dev/null 2>&1 || { echo "ERROR: kind not installed"; exit 1; }
	@command -v kubectl >/dev/null 2>&1 || { echo "ERROR: kubectl not installed"; exit 1; }
	@command -v docker >/dev/null 2>&1 || { echo "ERROR: docker not installed"; exit 1; }
	@docker ps >/dev/null 2>&1 || { echo "ERROR: Docker daemon not running"; exit 1; }
	@echo "All prerequisites satisfied"

setup: check-prereqs
	@echo "Setting up backup test environment..."
	@chmod +x *.sh
	./test-lab.sh

test:
	@echo "Running backup test with backup-job.yaml..."
	@kubectl delete job rds-backup-job-local 2>/dev/null || echo "No existing job to clean"
	@kubectl delete cronjob rds-backup-cronjob 2>/dev/null || echo "No existing cronjob to clean"
	@kubectl apply -f backup-job.yaml
	@sleep 2
	@# Check what was actually created
	@if kubectl get job rds-backup-job-local >/dev/null 2>&1; then \
		echo "Job created, waiting for completion..."; \
		kubectl wait --for=condition=complete job/rds-backup-job-local --timeout=300s || true; \
		kubectl logs job/rds-backup-job-local; \
	elif kubectl get cronjob rds-backup-cronjob >/dev/null 2>&1; then \
		echo "CronJob created, running manual job..."; \
		kubectl create job --from=cronjob/rds-backup-cronjob manual-test-$(date +%s); \
		sleep 5; \
		LATEST_JOB=$(kubectl get jobs --sort-by=.metadata.creationTimestamp -o name | tail -1); \
		kubectl wait --for=condition=complete $LATEST_JOB --timeout=300s || true; \
		kubectl logs $LATEST_JOB; \
	else \
		echo "Neither job nor cronjob found"; \
		exit 1; \
	fi

deploy-cronjob:
	@echo "Deploying CronJob for regular backups..."
	@kubectl apply -f working-backup-cronjob.yaml
	@kubectl get cronjobs

test-cronjob:
	@echo "Testing CronJob manually..."
	@kubectl create job --from=cronjob/rds-backup-cronjob manual-test-$(date +%s)
	@echo "Watch logs with: make logs"

test-working:
	@echo "Running working backup test..."
	kubectl apply -f backup-cron.yaml
	# kubectl logs -f job/rds-backup-cronjob
 
verify:
	@echo "Verifying backup integrity..."
	./verify-backup.sh

status:
	@echo "=== Lab Environment Status ==="
	@echo ""
	@echo "Docker:"
	@docker ps | grep localstack || echo "LocalStack not running"
	@echo ""
	@echo "KIND Clusters:"
	@kind get clusters || echo "No KIND clusters"
	@echo ""
	@echo "Kubernetes Resources:"
	@kubectl get deployments,jobs,cronjobs 2>/dev/null || echo "Cluster not accessible"
	@echo ""
	@echo "Recent Jobs:"
	@kubectl get jobs --sort-by=.metadata.creationTimestamp 2>/dev/null | tail -5 || true
	@echo ""
	@echo "LocalStack S3:"
	@export AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test AWS_DEFAULT_REGION=us-east-1 && \
	 awslocal s3 ls s3://rds-db-backups-co-create/ --recursive --human-readable 2>/dev/null || echo "S3 not accessible"

logs:
	@LATEST_JOB=$$(kubectl get jobs --sort-by=.metadata.creationTimestamp -o name 2>/dev/null | tail -1); \
	if [ -n "$$LATEST_JOB" ]; then \
		echo "Showing logs for: $$LATEST_JOB"; \
		kubectl logs $$LATEST_JOB; \
	else \
		echo "No backup jobs found"; \
	fi

logs-follow:
	@RUNNING_JOB=$$(kubectl get jobs --field-selector=status.conditions[0].type!=Complete -o name 2>/dev/null | head -1); \
	if [ -n "$$RUNNING_JOB" ]; then \
		echo "Following logs for: $$RUNNING_JOB"; \
		kubectl logs -f $$RUNNING_JOB; \
	else \
		echo "No running backup jobs found"; \
	fi

test-db:
	@echo "Testing database connectivity..."
	kubectl exec deployment/postgres-replica -- pg_isready -h postgres-replica-service.default.svc.cluster.local -p 5432 -U root
	kubectl exec deployment/postgres-replica -- psql -U root -d langfuse -c "SELECT count(*) as records FROM test_backup;"

test-s3:
	@echo "Testing LocalStack S3..."
	@export AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test AWS_DEFAULT_REGION=us-east-1 && \
	curl -s http://localhost:4566/health && echo " - LocalStack healthy" || echo " - LocalStack not responding"
	@export AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test AWS_DEFAULT_REGION=us-east-1 && \
	awslocal s3 ls s3://rds-db-backups-co-create/ >/dev/null && echo "S3 bucket accessible" || echo "S3 bucket not accessible"

clean-jobs:
	@echo "Cleaning old backup jobs..."
	@kubectl delete jobs -l app=backup-test 2>/dev/null || true
	@kubectl delete job manual-backup-test 2>/dev/null || true

e2e: setup clean-jobs test-working verify
	@echo ""
	@echo "=== END-TO-END TEST RESULTS ==="
	@echo "Setup: COMPLETED"
	@echo "Backup: COMPLETED" 
	@echo "Verify: COMPLETED"
	@echo ""
	@echo "PostgreSQL streaming backup to S3 works"

restart: cleanup setup test

cleanup:
	@echo "Cleaning up lab environment..."
	@echo "Stopping LocalStack..."
	@docker-compose down 2>/dev/null || true
	@echo "Deleting KIND cluster..."
	@kind delete cluster --name backup-test 2>/dev/null || true
	@echo "Cleaning temporary files..."
	@rm -f *.dump lifecycle-policy.json 2>/dev/null || true
	@docker system prune -f >/dev/null 2>&1 || true
	@echo "Cleanup complete"

# quick test cycle (setup -> test -> verify)
quick: cleanup setup test-working verify

help:
	@echo "RDS Backup Test Makefile"
	@echo "========================"
	@echo ""
	@echo "Available targets:"
	@echo "  setup           - Setup KIND cluster, LocalStack, and PostgreSQL"
	@echo "  test            - Run manual backup test (cronjob-based)"
	@echo "  test-working    - Run working backup test (simple job)"
	@echo "  verify          - Verify backup integrity and restore"
	@echo "  status          - Show current environment status"
	@echo "  logs            - Show logs from most recent backup job"
	@echo "  logs-follow     - Follow logs of running backup job"
	@echo "  test-db         - Test database connectivity"
	@echo "  test-s3         - Test LocalStack S3 connectivity" 
	@echo "  e2e             - Complete end-to-end test"
	@echo "  quick           - Quick test cycle (cleanup -> setup -> test -> verify)"
	@echo "  cleanup         - Remove all lab resources"
	@echo "  help            - Show this help"
	@echo ""
	@echo "Quick start: make setup && make test-working && make verify"