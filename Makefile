# Flink-Trino-Superset Pipeline Makefile

BOLD := \033[1m
GREEN := \033[32m
YELLOW := \033[33m
BLUE := \033[34m
MAGENTA := \033[35m
CYAN := \033[36m
RED := \033[31m
RESET := \033[0m

define wait-for-service
	@for i in $$(seq 1 $(2)); do \
		if docker-compose ps $(1) | grep "Up" > /dev/null; then \
			echo "$(GREEN)$(1) is ready$(RESET)"; \
			break; \
		fi; \
		if [ $$i -eq $(2) ]; then \
			echo "$(RED)Timeout waiting for $(1)$(RESET)"; \
			exit 1; \
		fi; \
		sleep 1; \
	done
endef

# Default target
.PHONY: help
help:
	@echo "$(BOLD)$(CYAN)Flink-Trino-Superset Pipeline$(RESET)"
	@echo ""
	@echo "$(BOLD)Quick Start:$(RESET)"
	@echo "  $(YELLOW)demo$(RESET)              - Full automated setup (build + start + deploy + verify)"
	@echo ""
	@echo "$(BOLD)Lifecycle:$(RESET)"
	@echo "  $(YELLOW)build$(RESET)             - Build Flink job JARs"
	@echo "  $(YELLOW)test$(RESET)              - Run Flink job smoke tests"
	@echo "  $(YELLOW)up$(RESET)                - Start all Docker services"
	@echo "  $(YELLOW)down$(RESET)              - Stop containers (keeps volumes)"
	@echo "  $(YELLOW)destroy$(RESET)           - Stop containers, delete volumes and build artifacts"
	@echo "  $(YELLOW)clean$(RESET)             - Clean build artifacts only"
	@echo "  $(YELLOW)logs$(RESET)              - Stream logs from all services"
	@echo ""
	@echo "$(BOLD)Deploy:$(RESET)"
	@echo "  $(YELLOW)deploy-flink-jobs$(RESET) - Deploy all Flink jobs"
	@echo "  $(YELLOW)deploy-sql-scripts$(RESET)- Copy SQL scripts to Flink SQL Client"
	@echo "  $(YELLOW)create-tables$(RESET)     - Create Trino analytics views"
	@echo "  $(YELLOW)setup-superset$(RESET)    - Initialize Superset with Trino connection"
	@echo ""
	@echo "$(BOLD)Docs:$(RESET)"
	@echo "  $(YELLOW)diagrams$(RESET)          - Render D2 diagrams to SVG"
	@echo ""
	@echo "$(BOLD)Iceberg Features:$(RESET)"
	@echo "  $(YELLOW)time-travel$(RESET)       - Show Iceberg snapshots and time-travel queries"
	@echo "  $(YELLOW)schema-evolution$(RESET)  - Demo adding columns without rewriting data"
	@echo "  $(YELLOW)duckdb$(RESET)            - Query Iceberg tables locally via DuckDB (no Trino)"
	@echo ""
	@echo "$(BOLD)Verify:$(RESET)"
	@echo "  $(YELLOW)smoketest$(RESET)         - Check all containers are running"
	@echo "  $(YELLOW)verify-data-flow$(RESET)  - Query Iceberg tables via Trino"
	@echo "  $(YELLOW)verify-demo$(RESET)       - Full end-to-end verification"
	@echo "  $(YELLOW)urls$(RESET)              - Show service URLs and credentials"

# ── Build ───────────────────────────────────────────────

.PHONY: build
build:
	@echo "$(CYAN)Building Flink jobs...$(RESET)"
	cd flink-jobs && ./gradlew buildAllJars

.PHONY: test
test:
	@echo "$(CYAN)Running Flink job smoke tests...$(RESET)"
	cd flink-jobs && ./gradlew test

.PHONY: clean
clean:
	cd flink-jobs && ./gradlew clean
	rm -rf flink-jobs/build

# ── Docker Services ─────────────────────────────────────

.PHONY: up
up:
	@if ! docker info > /dev/null 2>&1; then \
		echo "$(RED)Docker is not running!$(RESET)"; \
		exit 1; \
	fi
	docker-compose up -d --build

.PHONY: down
down:
	docker-compose down

.PHONY: destroy
destroy:
	@echo "$(RED)Destroying all containers, volumes, and build artifacts...$(RESET)"
	docker-compose down -v --remove-orphans
	cd flink-jobs && ./gradlew clean 2>/dev/null || true
	rm -rf flink-jobs/build
	@echo "$(GREEN)Clean slate$(RESET)"

.PHONY: logs
logs:
	docker-compose logs -f

# ── Deploy ──────────────────────────────────────────────

.PHONY: deploy-flink-jobs
deploy-flink-jobs: deploy-user-activity deploy-sensor-data
	@echo "$(GREEN)All Flink jobs deployed$(RESET)"

.PHONY: deploy-user-activity
deploy-user-activity:
	@echo "$(CYAN)Deploying UserActivityProcessor...$(RESET)"
	cd flink-jobs && ./gradlew userActivityProcessorJar
	docker cp flink-jobs/build/libs/user-activity-processor-1.0-SNAPSHOT.jar flink-jobmanager:/opt/flink/usrlib/
	docker exec flink-jobmanager flink run -d -c com.example.UserActivityProcessor /opt/flink/usrlib/user-activity-processor-1.0-SNAPSHOT.jar || \
		echo "$(YELLOW)UserActivityProcessor may already be running$(RESET)"

.PHONY: deploy-sensor-data
deploy-sensor-data:
	@echo "$(CYAN)Deploying SensorDataProcessor...$(RESET)"
	cd flink-jobs && ./gradlew sensorDataProcessorJar
	docker cp flink-jobs/build/libs/sensor-data-processor-1.0-SNAPSHOT.jar flink-jobmanager:/opt/flink/usrlib/
	docker exec flink-jobmanager flink run -d -c com.example.SensorDataProcessor /opt/flink/usrlib/sensor-data-processor-1.0-SNAPSHOT.jar || \
		echo "$(YELLOW)SensorDataProcessor may already be running$(RESET)"

.PHONY: deploy-sql-scripts
deploy-sql-scripts:
	@echo "$(CYAN)Copying SQL scripts to Flink SQL Client...$(RESET)"
	docker exec flink-sql-client mkdir -p /opt/flink-sql-client/scripts
	docker cp flink-jobs/sql-jobs/sensor-data-to-iceberg.sql flink-sql-client:/opt/flink-sql-client/scripts/
	docker cp flink-jobs/sql-jobs/user-activity-to-iceberg.sql flink-sql-client:/opt/flink-sql-client/scripts/
	@echo "$(GREEN)SQL scripts deployed$(RESET)"

.PHONY: create-tables
create-tables:
	@echo "$(CYAN)Creating Trino analytics views...$(RESET)"
	docker cp flink-jobs/create_tables.sql trino-coordinator:/tmp/
	@docker exec trino-coordinator trino --server localhost:8080 --catalog iceberg -f /tmp/create_tables.sql || \
		echo "$(YELLOW)Some views may have failed (tables may not exist yet)$(RESET)"

.PHONY: setup-superset
setup-superset:
	@echo "$(CYAN)Initializing Superset...$(RESET)"
	@docker exec superset /app/init_superset.sh
	@echo "$(GREEN)Superset ready at http://localhost:8088 (admin/admin)$(RESET)"

# ── Wait helpers ────────────────────────────────────────

.PHONY: wait-for-trino
wait-for-trino:
	@echo "$(CYAN)Waiting for Trino...$(RESET)"
	@for i in $$(seq 1 60); do \
		if docker exec trino-coordinator trino --server localhost:8080 --catalog iceberg --execute "SELECT 1" > /dev/null 2>&1; then \
			echo "$(GREEN)Trino is ready$(RESET)"; \
			break; \
		fi; \
		if [ $$i -eq 60 ]; then \
			echo "$(RED)Timeout waiting for Trino$(RESET)"; \
			exit 1; \
		fi; \
		sleep 1; \
	done

.PHONY: wait-for-data
wait-for-data:
	@echo "$(CYAN)Waiting for data in Iceberg tables...$(RESET)"
	@for i in $$(seq 1 60); do \
		if docker exec trino-coordinator trino --server localhost:8080 --catalog iceberg --execute "SELECT COUNT(*) FROM warehouse.user_activity" 2>/dev/null | grep -q '[1-9]'; then \
			echo "$(GREEN)Data is available$(RESET)"; \
			break; \
		fi; \
		if [ $$i -eq 60 ]; then \
			echo "$(YELLOW)Timeout waiting for data, continuing...$(RESET)"; \
			break; \
		fi; \
		sleep 2; \
	done

# ── Iceberg Features ───────────────────────────────────

.PHONY: time-travel
time-travel: wait-for-trino
	@echo "$(BOLD)$(CYAN)Iceberg Time Travel$(RESET)"
	@echo ""
	@echo "$(BOLD)Sensor data snapshots (each = a Flink checkpoint commit):$(RESET)"
	@docker exec trino-coordinator trino --server localhost:8080 --catalog iceberg \
		--execute "SELECT snapshot_id, committed_at, operation FROM iceberg.warehouse.\"sensor_data\$$snapshots\" ORDER BY committed_at DESC LIMIT 5" 2>/dev/null || \
		echo "  $(RED)Table not found - deploy Flink jobs first$(RESET)"
	@echo ""
	@echo "$(BOLD)Record count — now vs 5 minutes ago:$(RESET)"
	@docker exec trino-coordinator trino --server localhost:8080 --catalog iceberg \
		--execute "SELECT (SELECT COUNT(*) FROM warehouse.sensor_data) AS current_count, (SELECT COUNT(*) FROM warehouse.sensor_data FOR TIMESTAMP AS OF (current_timestamp - interval '5' minute)) AS past_count" 2>/dev/null || \
		echo "  $(YELLOW)Not enough history yet - wait a few minutes$(RESET)"

.PHONY: schema-evolution
schema-evolution: wait-for-trino
	@echo "$(BOLD)$(CYAN)Iceberg Schema Evolution$(RESET)"
	@echo ""
	@echo "$(BOLD)Adding alert_threshold column to sensor_data...$(RESET)"
	@docker exec trino-coordinator trino --server localhost:8080 --catalog iceberg \
		--execute "ALTER TABLE iceberg.warehouse.sensor_data ADD COLUMN IF NOT EXISTS alert_threshold DOUBLE" 2>/dev/null && \
		echo "  $(GREEN)Column added (old rows return NULL, no data rewrite)$(RESET)"
	@echo ""
	@echo "$(BOLD)Adding device_type column to user_activity...$(RESET)"
	@docker exec trino-coordinator trino --server localhost:8080 --catalog iceberg \
		--execute "ALTER TABLE iceberg.warehouse.user_activity ADD COLUMN IF NOT EXISTS device_type VARCHAR" 2>/dev/null && \
		echo "  $(GREEN)Column added$(RESET)"
	@echo ""
	@echo "$(BOLD)Verify — sensor_data schema now includes alert_threshold:$(RESET)"
	@docker exec trino-coordinator trino --server localhost:8080 --catalog iceberg \
		--execute "DESCRIBE iceberg.warehouse.sensor_data" 2>/dev/null
	@echo ""
	@echo "$(BOLD)Verify — NULLs for old rows (schema evolution in action):$(RESET)"
	@docker exec trino-coordinator trino --server localhost:8080 --catalog iceberg \
		--execute "SELECT sensor_id, sensor_type, reading, alert_threshold FROM iceberg.warehouse.sensor_data LIMIT 5" 2>/dev/null

.PHONY: duckdb
duckdb:
	@echo "$(BOLD)$(CYAN)Querying Iceberg tables with DuckDB (no Trino)$(RESET)"
	@command -v uv > /dev/null 2>&1 || (echo "$(RED)uv not found — install with: curl -LsSf https://astral.sh/uv/install.sh | sh$(RESET)" && exit 1)
	uv run --with duckdb scripts/duckdb_query.py

# ── Verify ──────────────────────────────────────────────

.PHONY: smoketest
smoketest:
	@echo "$(CYAN)Checking containers...$(RESET)"
	@failed=0; \
	for svc in kafka minio flink-jobmanager flink-taskmanager iceberg-rest trino-coordinator superset data-generator flink-sql-client; do \
		if docker-compose ps $$svc | grep "Up" > /dev/null 2>&1; then \
			echo "  $(GREEN)$$svc$(RESET)"; \
		else \
			echo "  $(RED)$$svc - NOT RUNNING$(RESET)"; \
			failed=1; \
		fi; \
	done; \
	if [ $$failed -eq 1 ]; then exit 1; fi
	@echo "$(GREEN)All containers running$(RESET)"

.PHONY: verify-data-flow
verify-data-flow: wait-for-trino
	@echo "$(CYAN)Verifying data flow...$(RESET)"
	@echo "User activity:"
	@docker exec trino-coordinator trino --server localhost:8080 --catalog iceberg \
		--execute "SELECT event_type, COUNT(*) as cnt FROM warehouse.user_activity GROUP BY event_type ORDER BY cnt DESC" 2>/dev/null || \
		echo "  $(RED)Table not found - Flink jobs may not be running$(RESET)"
	@echo ""
	@echo "Sensor data:"
	@docker exec trino-coordinator trino --server localhost:8080 --catalog iceberg \
		--execute "SELECT sensor_type, COUNT(*) as cnt, ROUND(AVG(reading),2) as avg_reading FROM warehouse.sensor_data GROUP BY sensor_type ORDER BY cnt DESC" 2>/dev/null || \
		echo "  $(RED)Table not found - Flink jobs may not be running$(RESET)"

.PHONY: verify-demo
verify-demo:
	@echo "$(BOLD)$(CYAN)Running end-to-end verification...$(RESET)"
	@echo ""
	@echo "$(BOLD)1. Containers$(RESET)"
	@$(MAKE) -s smoketest
	@echo ""
	@echo "$(BOLD)2. Flink jobs$(RESET)"
	@job_count=$$(docker exec flink-jobmanager flink list 2>/dev/null | grep -c "RUNNING" || echo "0"); \
	echo "  Running jobs: $$job_count"; \
	if [ "$$job_count" -lt 2 ]; then \
		echo "  $(YELLOW)Expected at least 2 - run 'make deploy-flink-jobs'$(RESET)"; \
	fi
	@echo ""
	@echo "$(BOLD)3. Iceberg tables$(RESET)"
	@$(MAKE) -s verify-data-flow
	@echo ""
	@echo "$(BOLD)4. S3 storage$(RESET)"
	@docker exec minio curl -sf http://localhost:9000/warehouse/ > /dev/null 2>&1 && \
		echo "  $(GREEN)Warehouse bucket exists$(RESET)" || \
		echo "  $(RED)Warehouse bucket not found$(RESET)"
	@echo ""
	@echo "$(BOLD)5. Superset$(RESET)"
	@docker-compose ps superset 2>/dev/null | grep -q "Up" && \
		echo "  $(GREEN)Running at http://localhost:8088 (admin/admin)$(RESET)" || \
		echo "  $(RED)Not running$(RESET)"
	@echo ""
	@echo "$(GREEN)Verification complete$(RESET)"

# ── Diagrams ────────────────────────────────────────────

.PHONY: diagrams
diagrams:
	@echo "$(CYAN)Rendering D2 diagrams...$(RESET)"
	@command -v d2 > /dev/null 2>&1 || (echo "$(RED)d2 not found — install with: brew install d2$(RESET)" && exit 1)
	d2 --sketch docs/diagrams/architecture.d2 docs/diagrams/architecture.svg
	d2 --sketch docs/diagrams/data-flow.d2 docs/diagrams/data-flow.svg
	d2 --sketch docs/diagrams/docker-services.d2 docs/diagrams/docker-services.svg
	d2 --sketch docs/diagrams/time-travel.d2 docs/diagrams/time-travel.svg
	d2 --sketch docs/diagrams/schema-evolution.d2 docs/diagrams/schema-evolution.svg
	@echo "$(GREEN)Diagrams rendered$(RESET)"

# ── URLs ────────────────────────────────────────────────

.PHONY: urls
urls:
	@echo "$(BOLD)Service URLs$(RESET)"
	@echo ""
	@echo "  Flink Dashboard     http://localhost:8081"
	@echo "  Flink SQL Client    docker exec -it flink-sql-client ./bin/sql-client.sh"
	@echo "  Kafka               localhost:9092"
	@echo "  SeaweedFS (S3 UI)   http://localhost:9001"
	@echo "  Iceberg REST        http://localhost:8181"
	@echo "  Trino UI            http://localhost:8082/ui/  (user: admin)"
	@echo "  Trino CLI           docker exec -it trino-coordinator trino --server localhost:8080 --catalog iceberg"
	@echo "  Superset            http://localhost:8088      (admin/admin)"

# ── Demo ────────────────────────────────────────────────

.PHONY: demo
demo: build up
	@echo "$(BOLD)$(MAGENTA)Running complete data pipeline demo...$(RESET)"
	@echo ""

	@echo "$(BOLD)Step 1:$(RESET) Waiting for services..."
	$(call wait-for-service,kafka,60)
	$(call wait-for-service,minio,60)
	$(call wait-for-service,flink-jobmanager,60)

	@echo "$(BOLD)Step 2:$(RESET) Ensuring Iceberg schema..."
	$(MAKE) wait-for-trino
	@docker exec trino-coordinator trino --server localhost:8080 --catalog iceberg \
		--execute "CREATE SCHEMA IF NOT EXISTS iceberg.warehouse" 2>/dev/null || true

	@echo "$(BOLD)Step 3:$(RESET) Deploying SQL scripts..."
	$(MAKE) deploy-sql-scripts

	@echo "$(BOLD)Step 4:$(RESET) Deploying Flink jobs..."
	$(MAKE) deploy-flink-jobs

	@echo "$(BOLD)Step 5:$(RESET) Waiting for data..."
	$(MAKE) wait-for-data

	@echo "$(BOLD)Step 6:$(RESET) Creating Trino views..."
	$(MAKE) create-tables

	@echo "$(BOLD)Step 7:$(RESET) Setting up Superset..."
	$(MAKE) setup-superset

	@echo ""
	@echo "$(BOLD)$(GREEN)Demo ready!$(RESET)"
	@$(MAKE) -s urls
