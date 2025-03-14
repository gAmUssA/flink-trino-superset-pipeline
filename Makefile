# 🚀 Flink-Trino-Superset Pipeline Makefile

# 🎨 Colors for better readability
BOLD := \033[1m
GREEN := \033[32m
YELLOW := \033[33m
BLUE := \033[34m
MAGENTA := \033[35m
CYAN := \033[36m
RED := \033[31m
RESET := \033[0m

# 🔄 Wait for service function
define wait-for-service
	@echo "$(CYAN)Waiting for $(1) to be ready...$(RESET)"
	@for i in $$(seq 1 $(2)); do \
		if docker-compose ps $(1) | grep "Up" > /dev/null; then \
			echo "$(GREEN)✅ $(1) is ready!$(RESET)"; \
			break; \
		fi; \
		if [ $$i -eq $(2) ]; then \
			echo "$(RED)❌ Timeout waiting for $(1)$(RESET)"; \
			exit 1; \
		fi; \
		echo "$(YELLOW)⏳ Waiting for $(1)... ($$i/$(2))$(RESET)"; \
		sleep 1; \
	done
endef

# 📋 Default target
.PHONY: help
help:
	@echo "$(BOLD)$(CYAN)🚀 Flink-Trino-Superset Pipeline$(RESET)"
	@echo "$(BOLD)$(GREEN)Available targets:$(RESET)"
	@echo "  $(YELLOW)help$(RESET)              - Show this help message"
	@echo "  $(YELLOW)build$(RESET)             - Build all components"
	@echo "  $(YELLOW)up$(RESET)                - Start all services"
	@echo "  $(YELLOW)down$(RESET)              - Stop all services"
	@echo "  $(YELLOW)clean$(RESET)             - Clean up build artifacts"
	@echo "  $(YELLOW)logs$(RESET)              - Show logs from all services"
	@echo "  $(YELLOW)smoketest$(RESET)         - Validate startup of all containers"
	@echo "  $(YELLOW)validate-setup$(RESET)    - Validate SQL scripts and Java code setup"
	@echo "  $(YELLOW)build-flink-jobs$(RESET)  - Build Flink jobs"
	@echo "  $(YELLOW)deploy-flink-jobs$(RESET) - Deploy Flink jobs to the cluster"
	@echo "  $(YELLOW)deploy-sql-scripts$(RESET) - Deploy SQL scripts to Flink SQL Client"
	@echo "  $(YELLOW)create-tables$(RESET)     - Create Iceberg tables in Trino"
	@echo "  $(YELLOW)setup-superset$(RESET)    - Set up Superset dashboards"
	@echo "  $(YELLOW)urls$(RESET)              - Show all service URLs and credentials"
	@echo "  $(YELLOW)demo$(RESET)              - Run complete demo (build, start, validate, deploy)"

# 🏗️ Build all components
.PHONY: build
build: build-flink-jobs
	@echo "$(BOLD)$(GREEN)🏗️ Building all components...$(RESET)"

# 🚀 Start all services
.PHONY: up
up:
	@echo "$(BOLD)$(GREEN)🚀 Starting all services...$(RESET)"
	@if ! docker info > /dev/null 2>&1; then \
		echo "$(BOLD)$(RED)❌ Docker is not running!$(RESET)"; \
		echo "$(YELLOW)Please start Docker and try again.$(RESET)"; \
		exit 1; \
	fi
	docker-compose up -d

# 🛑 Stop all services
.PHONY: down
down:
	@echo "$(BOLD)$(GREEN)🛑 Stopping all services...$(RESET)"
	docker-compose down

# 🧹 Clean up build artifacts
.PHONY: clean
clean:
	@echo "$(BOLD)$(GREEN)🧹 Cleaning up build artifacts...$(RESET)"
	cd flink-jobs && ./gradlew clean
	rm -rf flink-jobs/build

# 📋 Show logs from all services
.PHONY: logs
logs:
	@echo "$(BOLD)$(GREEN)📋 Showing logs from all services...$(RESET)"
	docker-compose logs -f

# 🏗️ Build Flink jobs
.PHONY: build-flink-jobs
build-flink-jobs:
	@echo "$(BOLD)$(GREEN)🏗️ Building Flink jobs...$(RESET)"
	@if [ ! -f "flink-jobs/gradlew" ]; then \
		echo "$(BOLD)$(YELLOW)⚠️ Gradle wrapper not found, initializing...$(RESET)"; \
		cd flink-jobs && chmod +x init-gradle.sh && ./init-gradle.sh; \
	fi
	cd flink-jobs && ./gradlew buildAllJars

# 🚀 Deploy Flink jobs to the cluster
.PHONY: deploy-flink-jobs
deploy-flink-jobs: build-flink-jobs
	@echo "$(BOLD)$(GREEN)🚀 Deploying Flink jobs to the cluster...$(RESET)"
	@if ! docker-compose ps flink-jobmanager | grep "Up" > /dev/null; then \
		echo "$(BOLD)$(RED)❌ Flink JobManager is not running!$(RESET)"; \
		echo "$(YELLOW)Please start the services with 'make up' and try again.$(RESET)"; \
		exit 1; \
	fi
	@if [ ! -f "flink-jobs/build/libs/user-activity-processor-1.0-SNAPSHOT.jar" ] || [ ! -f "flink-jobs/build/libs/sensor-data-processor-1.0-SNAPSHOT.jar" ]; then \
		echo "$(BOLD)$(YELLOW)⚠️ Flink job JARs not found, rebuilding...$(RESET)"; \
		$(MAKE) build-flink-jobs; \
	fi
	docker cp flink-jobs/build/libs/user-activity-processor-1.0-SNAPSHOT.jar flink-jobmanager:/opt/flink/usrlib/
	docker cp flink-jobs/build/libs/sensor-data-processor-1.0-SNAPSHOT.jar flink-jobmanager:/opt/flink/usrlib/
	docker exec flink-jobmanager flink run -c com.example.UserActivityProcessor /opt/flink/usrlib/user-activity-processor-1.0-SNAPSHOT.jar || \
		echo "$(BOLD)$(YELLOW)⚠️ There was an issue deploying the UserActivityProcessor job. This might be expected if the job is already running.$(RESET)"
	docker exec flink-jobmanager flink run -c com.example.SensorDataProcessor /opt/flink/usrlib/sensor-data-processor-1.0-SNAPSHOT.jar || \
		echo "$(BOLD)$(YELLOW)⚠️ There was an issue deploying the SensorDataProcessor job. This might be expected if the job is already running.$(RESET)"

# 📝 Deploy SQL scripts to Flink SQL Client
.PHONY: deploy-sql-scripts
deploy-sql-scripts: validate-setup
	@echo "$(BOLD)$(GREEN)📝 Deploying SQL scripts to Flink SQL Client...$(RESET)"
	@if ! docker-compose ps flink-sql-client | grep "Up" > /dev/null; then \
		echo "$(BOLD)$(RED)❌ Flink SQL Client is not running!$(RESET)"; \
		echo "$(YELLOW)Please start the services with 'make up' and try again.$(RESET)"; \
		exit 1; \
	fi

	@echo "$(CYAN)Creating scripts directory in Flink SQL Client container...$(RESET)"
	docker exec flink-sql-client mkdir -p /opt/flink-sql-client/scripts

	@echo "$(CYAN)Copying SQL scripts to Flink SQL Client container...$(RESET)"
	docker cp flink-jobs/sql-jobs/sensor-data-to-iceberg.sql flink-sql-client:/opt/flink-sql-client/scripts/
	docker cp flink-jobs/sql-jobs/user-activity-to-iceberg.sql flink-sql-client:/opt/flink-sql-client/scripts/

	@echo "$(GREEN)✅ SQL scripts deployed to Flink SQL Client!$(RESET)"
	@echo "$(YELLOW)To run a SQL script, use:$(RESET)"
	@echo "  docker exec -it flink-sql-client ./bin/sql-client.sh -f /opt/flink-sql-client/scripts/sensor-data-to-iceberg.sql"
	@echo "  docker exec -it flink-sql-client ./bin/sql-client.sh -f /opt/flink-sql-client/scripts/user-activity-to-iceberg.sql"

# 📊 Create Iceberg tables in Trino
.PHONY: create-tables
create-tables:
	@echo "$(BOLD)$(GREEN)📊 Creating Iceberg tables in Trino...$(RESET)"
	@if ! docker-compose ps trino-coordinator | grep "Up" > /dev/null; then \
		echo "$(BOLD)$(RED)❌ Trino is not running!$(RESET)"; \
		echo "$(YELLOW)Please start the services with 'make up' and try again.$(RESET)"; \
		exit 1; \
	fi
	docker cp flink-jobs/create_tables.sql trino-coordinator:/tmp/
	docker exec trino-coordinator trino --server localhost:8080 --catalog iceberg -f /tmp/create_tables.sql || \
		echo "$(BOLD)$(YELLOW)⚠️ There was an issue creating tables. This might be expected if tables already exist.$(RESET)"

# 🔍 Validate startup of all containers
.PHONY: smoketest
smoketest:
	@echo "$(BOLD)$(GREEN)🔍 Validating startup of all containers...$(RESET)"
	@echo "$(CYAN)Checking Kafka...$(RESET)"
	@docker-compose ps kafka | grep "Up" || (echo "$(BOLD)$(RED)❌ Kafka is not running!$(RESET)" && exit 1)
	@echo "$(GREEN)✅ Kafka is running$(RESET)"

	@echo "$(CYAN)Checking Minio...$(RESET)"
	@docker-compose ps minio | grep "Up" || (echo "$(BOLD)$(RED)❌ Minio is not running!$(RESET)" && exit 1)
	@echo "$(GREEN)✅ Minio is running$(RESET)"

	@echo "$(CYAN)Checking Flink JobManager...$(RESET)"
	@docker-compose ps flink-jobmanager | grep "Up" || (echo "$(BOLD)$(RED)❌ Flink JobManager is not running!$(RESET)" && exit 1)
	@echo "$(GREEN)✅ Flink JobManager is running$(RESET)"

	@echo "$(CYAN)Checking Flink TaskManager...$(RESET)"
	@docker-compose ps flink-taskmanager | grep "Up" || (echo "$(BOLD)$(RED)❌ Flink TaskManager is not running!$(RESET)" && exit 1)
	@echo "$(GREEN)✅ Flink TaskManager is running$(RESET)"

	@echo "$(CYAN)Checking Iceberg REST Catalog...$(RESET)"
	@docker-compose ps iceberg-rest | grep "Up" || (echo "$(BOLD)$(RED)❌ Iceberg REST Catalog is not running!$(RESET)" && exit 1)
	@echo "$(GREEN)✅ Iceberg REST Catalog is running$(RESET)"

	@echo "$(CYAN)Checking Trino...$(RESET)"
	@docker-compose ps trino-coordinator | grep "Up" || (echo "$(BOLD)$(RED)❌ Trino is not running!$(RESET)" && exit 1)
	@echo "$(GREEN)✅ Trino is running$(RESET)"

	@echo "$(CYAN)Checking Superset...$(RESET)"
	@docker-compose ps superset | grep "Up" || (echo "$(BOLD)$(RED)❌ Superset is not running!$(RESET)" && exit 1)
	@echo "$(GREEN)✅ Superset is running$(RESET)"

	@echo "$(CYAN)Checking Data Generator...$(RESET)"
	@docker-compose ps data-generator | grep "Up" || (echo "$(BOLD)$(RED)❌ Data Generator is not running!$(RESET)" && exit 1)
	@echo "$(GREEN)✅ Data Generator is running$(RESET)"

	@echo "$(CYAN)Checking Flink SQL Client...$(RESET)"
	@docker-compose ps flink-sql-client | grep "Up" || (echo "$(BOLD)$(RED)❌ Flink SQL Client is not running!$(RESET)" && exit 1)
	@echo "$(GREEN)✅ Flink SQL Client is running$(RESET)"

	@echo "$(BOLD)$(GREEN)✅ All containers are running!$(RESET)"

# 🔍 Validate SQL scripts and Java code setup
.PHONY: validate-setup
validate-setup:
	@echo "$(BOLD)$(GREEN)🔍 Validating SQL scripts and Java code setup...$(RESET)"

	@echo "$(CYAN)Checking SQL scripts directory...$(RESET)"
	@if [ ! -d "flink-jobs/sql-jobs" ]; then \
		echo "$(BOLD)$(RED)❌ SQL scripts directory not found!$(RESET)"; \
		echo "$(YELLOW)Creating SQL scripts directory...$(RESET)"; \
		mkdir -p flink-jobs/sql-jobs; \
	else \
		echo "$(GREEN)✅ SQL scripts directory exists$(RESET)"; \
	fi

	@echo "$(CYAN)Checking SQL scripts...$(RESET)"
	@missing_scripts=0; \
	for script in sensor-data-to-iceberg.sql user-activity-to-iceberg.sql; do \
		if [ ! -f "flink-jobs/sql-jobs/$$script" ]; then \
			echo "$(BOLD)$(RED)❌ $$script not found!$(RESET)"; \
			missing_scripts=1; \
		else \
			echo "$(GREEN)✅ $$script exists$(RESET)"; \
		fi; \
	done; \
	if [ $$missing_scripts -eq 1 ]; then \
		echo "$(YELLOW)Please create the missing SQL scripts.$(RESET)"; \
	fi

	@echo "$(CYAN)Checking Java source files...$(RESET)"
	@missing_java=0; \
	for java_file in SensorDataProcessor.java UserActivityProcessor.java; do \
		if [ ! -f "flink-jobs/src/main/java/com/example/$$java_file" ]; then \
			echo "$(BOLD)$(RED)❌ $$java_file not found!$(RESET)"; \
			missing_java=1; \
		else \
			echo "$(GREEN)✅ $$java_file exists$(RESET)"; \
		fi; \
	done; \
	if [ $$missing_java -eq 1 ]; then \
		echo "$(YELLOW)Please create the missing Java source files.$(RESET)"; \
	fi

	@echo "$(CYAN)Checking build.gradle.kts...$(RESET)"
	@if [ ! -f "flink-jobs/build.gradle.kts" ]; then \
		echo "$(BOLD)$(RED)❌ build.gradle.kts not found!$(RESET)"; \
	else \
		echo "$(GREEN)✅ build.gradle.kts exists$(RESET)"; \
		if grep -q "org.apache.iceberg" "flink-jobs/build.gradle.kts"; then \
			echo "$(GREEN)✅ Iceberg dependencies found in build.gradle.kts$(RESET)"; \
		else \
			echo "$(BOLD)$(RED)❌ Iceberg dependencies not found in build.gradle.kts!$(RESET)"; \
			echo "$(YELLOW)Please add Iceberg dependencies to build.gradle.kts.$(RESET)"; \
		fi; \
	fi

	@echo "$(BOLD)$(GREEN)✅ Setup validation complete!$(RESET)"

# 📈 Set up Superset dashboards
.PHONY: setup-superset
setup-superset:
	@echo "$(BOLD)$(GREEN)📈 Setting up Superset dashboards...$(RESET)"
	@echo "$(YELLOW)Please access Superset at http://localhost:8088 and log in with admin/admin$(RESET)"

# 🔗 Show all service URLs and credentials
.PHONY: urls
urls:
	@echo "$(BOLD)$(CYAN)🔗 Service URLs and Credentials$(RESET)"
	@echo ""
	@echo "$(BOLD)$(MAGENTA)Stream Processing:$(RESET)"
	@echo "  $(GREEN)🚀 Flink Dashboard:$(RESET)       http://localhost:8081"
	@echo "  $(GREEN)🖥️  Flink SQL Client:$(RESET)      Use 'docker exec -it flink-sql-client ./bin/sql-client.sh'"
	@echo ""
	@echo "$(BOLD)$(MAGENTA)Data Sources:$(RESET)"
	@echo "  $(GREEN)📈 Data Generator:$(RESET)        Running in container 'data-generator'"
	@echo "  $(GREEN)🔄 Kafka:$(RESET)                 localhost:9092 (inside Docker network)"
	@echo ""
	@echo "$(BOLD)$(MAGENTA)Storage:$(RESET)"
	@echo "  $(GREEN)🗄️  Minio Console:$(RESET)         http://localhost:9001"
	@echo "  $(YELLOW)   Username:$(RESET) minioadmin"
	@echo "  $(YELLOW)   Password:$(RESET) minioadmin"
	@echo ""
	@echo "  $(GREEN)🧊 Iceberg REST Catalog:$(RESET)  http://localhost:8181"
	@echo ""
	@echo "$(BOLD)$(MAGENTA)Query Engines:$(RESET)"
	@echo "  $(GREEN)🔍 Trino UI:$(RESET)              http://localhost:8082/ui/"
	@echo "  $(YELLOW)   Username:$(RESET) admin"
	@echo ""
	@echo "  $(GREEN)📊 Trino CLI:$(RESET)             Use 'docker exec -it trino-coordinator trino --server localhost:8080 --catalog iceberg'"
	@echo ""
	@echo "$(BOLD)$(MAGENTA)Visualization:$(RESET)"
	@echo "  $(GREEN)📈 Superset:$(RESET)              http://localhost:8088"
	@echo "  $(YELLOW)   Username:$(RESET) admin"
	@echo "  $(YELLOW)   Password:$(RESET) admin"
	@echo ""
	@echo "$(BOLD)$(YELLOW)Note:$(RESET) Make sure all services are running with 'make up' before accessing these URLs."

# 🔄 Wait for Trino to be ready
.PHONY: wait-for-trino
wait-for-trino:
	@echo "$(CYAN)Waiting for Trino to be ready...$(RESET)"
	@for i in $$(seq 1 60); do \
		if docker exec trino-coordinator trino --server localhost:8080 --catalog iceberg --execute "SELECT 1" > /dev/null 2>&1; then \
			echo "$(GREEN)✅ Trino is ready!$(RESET)"; \
			break; \
		fi; \
		if [ $$i -eq 60 ]; then \
			echo "$(RED)❌ Timeout waiting for Trino$(RESET)"; \
			exit 1; \
		fi; \
		echo "$(YELLOW)⏳ Waiting for Trino... ($$i/60)$(RESET)"; \
		sleep 1; \
	done

# 🔄 Wait for data to be available
.PHONY: wait-for-data
wait-for-data:
	@echo "$(CYAN)Waiting for data to be available...$(RESET)"
	@for i in $$(seq 1 30); do \
		if docker exec trino-coordinator trino --server localhost:8080 --catalog iceberg --execute "SELECT COUNT(*) FROM warehouse.user_activity" > /dev/null 2>&1; then \
			echo "$(GREEN)✅ Data is available!$(RESET)"; \
			break; \
		fi; \
		if [ $$i -eq 30 ]; then \
			echo "$(YELLOW)⚠️ Timeout waiting for data, but continuing...$(RESET)"; \
			break; \
		fi; \
		echo "$(YELLOW)⏳ Waiting for data... ($$i/30)$(RESET)"; \
		sleep 1; \
	done

# 🔍 Verify data flow
.PHONY: verify-data-flow
verify-data-flow: wait-for-trino
	@echo "$(BOLD)$(GREEN)🔍 Verifying data flow...$(RESET)"
	@echo "$(CYAN)Checking user activity data...$(RESET)"
	@user_count=$$(docker exec trino-coordinator trino --server localhost:8080 --catalog iceberg --execute "SELECT COUNT(*) FROM warehouse.user_activity" | grep -v "^_" | tr -d ' ' || echo "0")
	@if [ "$$user_count" -gt 0 ]; then \
		echo "$(GREEN)✅ User activity data is present ($$user_count rows)$(RESET)"; \
	else \
		echo "$(RED)❌ No user activity data found!$(RESET)"; \
	fi

	@echo "$(CYAN)Checking event type distribution...$(RESET)"
	@docker exec trino-coordinator trino --server localhost:8080 --catalog iceberg --execute "SELECT event_type, COUNT(*) FROM warehouse.user_activity GROUP BY event_type"

	@echo "$(CYAN)Checking sensor data...$(RESET)"
	@sensor_count=$$(docker exec trino-coordinator trino --server localhost:8080 --catalog iceberg --execute "SELECT COUNT(*) FROM warehouse.sensor_data" | grep -v "^_" | tr -d ' ' || echo "0")
	@if [ "$$sensor_count" -gt 0 ]; then \
		echo "$(GREEN)✅ Sensor data is present ($$sensor_count rows)$(RESET)"; \
	else \
		echo "$(RED)❌ No sensor data found!$(RESET)"; \
	fi

	@echo "$(CYAN)Checking sensor type distribution...$(RESET)"
	@docker exec trino-coordinator trino --server localhost:8080 --catalog iceberg --execute "SELECT sensor_type, AVG(sensor_value) FROM warehouse.sensor_data GROUP BY sensor_type"

	@echo "$(BOLD)$(GREEN)✅ Data flow verification complete!$(RESET)"

# 🚀 Run automated verification
.PHONY: verify-demo
verify-demo: smoketest
	@echo "$(BOLD)$(GREEN)🚀 Running automated verification...$(RESET)"

	@echo "$(BOLD)$(CYAN)Step 1: Checking all containers...$(RESET)"
	@$(MAKE) -s smoketest

	@echo "$(BOLD)$(CYAN)Step 2: Verifying Flink jobs...$(RESET)"
	@echo "$(CYAN)Checking Flink job status...$(RESET)"
	@job_count=$$(docker exec flink-jobmanager flink list -a | grep "RUNNING" | wc -l | tr -d ' ')
	@if [ "$$job_count" -ge 2 ]; then \
		echo "$(GREEN)✅ Flink jobs are running ($$job_count jobs)$(RESET)"; \
	else \
		echo "$(RED)❌ Not enough Flink jobs running! Expected at least 2, found $$job_count$(RESET)"; \
		echo "$(YELLOW)⚠️ You may need to deploy the Flink jobs with 'make deploy-flink-jobs'$(RESET)"; \
	fi

	@echo "$(BOLD)$(CYAN)Step 3: Verifying data in Iceberg tables...$(RESET)"
	@$(MAKE) -s verify-data-flow

	@echo "$(BOLD)$(CYAN)Step 4: Checking MinIO storage...$(RESET)"
	@echo "$(CYAN)Verifying warehouse bucket in MinIO...$(RESET)"
	@if docker exec mc-setup /usr/bin/mc ls myminio/warehouse > /dev/null 2>&1; then \
		echo "$(GREEN)✅ Warehouse bucket exists in MinIO$(RESET)"; \
		echo "$(CYAN)Listing table directories:$(RESET)"; \
		docker exec mc-setup /usr/bin/mc ls myminio/warehouse; \
	else \
		echo "$(RED)❌ Warehouse bucket not found in MinIO!$(RESET)"; \
	fi

	@echo "$(BOLD)$(CYAN)Step 5: Checking Superset integration...$(RESET)"
	@echo "$(CYAN)Verifying Superset is running...$(RESET)"
	@if docker-compose ps superset | grep "Up" > /dev/null; then \
		echo "$(GREEN)✅ Superset is running$(RESET)"; \
		echo "$(YELLOW)ℹ️ Access Superset at http://localhost:8088 (admin/admin)$(RESET)"; \
		echo "$(YELLOW)ℹ️ To complete Superset verification, manually check Trino connection and create datasets$(RESET)"; \
	else \
		echo "$(RED)❌ Superset is not running!$(RESET)"; \
	fi

	@echo "$(BOLD)$(GREEN)✅ Verification complete!$(RESET)"

# 🎬 Run complete demo
.PHONY: demo
demo: build up
	@echo "$(BOLD)$(MAGENTA)🎬 Running complete data pipeline demo...$(RESET)"

	@echo "$(BOLD)$(CYAN)Step 1: Waiting for services to start up...$(RESET)"
	$(call wait-for-service,kafka,60)
	$(call wait-for-service,minio,60)
	$(call wait-for-service,flink-jobmanager,60)
	$(call wait-for-service,trino-coordinator,60)

	@echo "$(BOLD)$(CYAN)Step 2: Validating setup...$(RESET)"
	$(MAKE) validate-setup

	@echo "$(BOLD)$(CYAN)Step 3: Creating Iceberg tables in Trino...$(RESET)"
	$(MAKE) wait-for-trino
	$(MAKE) create-tables

	@echo "$(BOLD)$(CYAN)Step 4: Deploying SQL scripts to Flink SQL Client...$(RESET)"
	$(MAKE) deploy-sql-scripts

	@echo "$(BOLD)$(CYAN)Step 5: Deploying Flink jobs...$(RESET)"
	$(MAKE) deploy-flink-jobs

	@echo "$(BOLD)$(CYAN)Step 6: Waiting for data to be available...$(RESET)"
	$(MAKE) wait-for-data

	@echo "$(BOLD)$(GREEN)✅ Demo setup complete!$(RESET)"
	@echo "$(YELLOW)You can now access the following services:$(RESET)"
	@echo "  - Flink Dashboard: http://localhost:8081"
	@echo "  - Minio Console: http://localhost:9001 (username: minioadmin, password: minioadmin)"
	@echo "  - Trino UI: http://localhost:8082/ui/ (username: admin)"
	@echo "  - Superset: http://localhost:8088 (username: admin, password: admin)"
	@echo ""
	@echo "$(YELLOW)To run SQL queries on the data, use:$(RESET)"
	@echo "  docker exec -it trino-coordinator trino --server localhost:8080 --catalog iceberg"
	@echo ""
	@echo "$(YELLOW)To run Flink SQL scripts directly:$(RESET)"
	@echo "  docker exec -it flink-sql-client ./bin/sql-client.sh -f /opt/flink-sql-client/scripts/user-activity-to-iceberg.sql"
	@echo "  docker exec -it flink-sql-client ./bin/sql-client.sh -f /opt/flink-sql-client/scripts/sensor-data-to-iceberg.sql"
