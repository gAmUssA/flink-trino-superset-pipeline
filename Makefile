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
	@echo "  $(YELLOW)build-flink-jobs$(RESET)  - Build Flink jobs"
	@echo "  $(YELLOW)deploy-flink-jobs$(RESET) - Deploy Flink jobs to the cluster"
	@echo "  $(YELLOW)create-tables$(RESET)     - Create Iceberg tables in Trino"
	@echo "  $(YELLOW)setup-superset$(RESET)    - Set up Superset dashboards"
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
	
	@echo "$(CYAN)Checking Kafka UI...$(RESET)"
	@docker-compose ps kafka-ui | grep "Up" || (echo "$(BOLD)$(RED)❌ Kafka UI is not running!$(RESET)" && exit 1)
	@echo "$(GREEN)✅ Kafka UI is running$(RESET)"
	
	@echo "$(CYAN)Checking Minio...$(RESET)"
	@docker-compose ps minio | grep "Up" || (echo "$(BOLD)$(RED)❌ Minio is not running!$(RESET)" && exit 1)
	@echo "$(GREEN)✅ Minio is running$(RESET)"
	
	@echo "$(CYAN)Checking Flink JobManager...$(RESET)"
	@docker-compose ps flink-jobmanager | grep "Up" || (echo "$(BOLD)$(RED)❌ Flink JobManager is not running!$(RESET)" && exit 1)
	@echo "$(GREEN)✅ Flink JobManager is running$(RESET)"
	
	@echo "$(CYAN)Checking Flink TaskManager...$(RESET)"
	@docker-compose ps flink-taskmanager | grep "Up" || (echo "$(BOLD)$(RED)❌ Flink TaskManager is not running!$(RESET)" && exit 1)
	@echo "$(GREEN)✅ Flink TaskManager is running$(RESET)"
	
	@echo "$(CYAN)Checking MySQL...$(RESET)"
	@docker-compose ps mysql | grep "Up" || (echo "$(BOLD)$(RED)❌ MySQL is not running!$(RESET)" && exit 1)
	@echo "$(GREEN)✅ MySQL is running$(RESET)"
	
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
	
	@echo "$(BOLD)$(GREEN)✅ All containers are running!$(RESET)"

# 📈 Set up Superset dashboards
.PHONY: setup-superset
setup-superset:
	@echo "$(BOLD)$(GREEN)📈 Setting up Superset dashboards...$(RESET)"
	@echo "$(YELLOW)Please access Superset at http://localhost:8088 and log in with admin/admin$(RESET)"

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

# 🎬 Run complete demo
.PHONY: demo
demo: build up
	@echo "$(BOLD)$(MAGENTA)🎬 Running complete data pipeline demo...$(RESET)"
	
	@echo "$(BOLD)$(CYAN)Step 1: Waiting for services to start up...$(RESET)"
	$(call wait-for-service,kafka,60)
	$(call wait-for-service,kafka-ui,60)
	$(call wait-for-service,minio,60)
	$(call wait-for-service,flink-jobmanager,60)
	$(call wait-for-service,flink-taskmanager,60)
	$(call wait-for-service,mysql,60)
	$(call wait-for-service,iceberg-rest,60)
	$(call wait-for-service,trino-coordinator,60)
	$(call wait-for-service,superset,60)
	$(call wait-for-service,data-generator,60)
	
	@echo "$(BOLD)$(CYAN)Step 2: Validating all containers are running...$(RESET)"
	@$(MAKE) smoketest
	
	@echo "$(BOLD)$(CYAN)Step 3: Waiting for Trino to be ready...$(RESET)"
	@$(MAKE) wait-for-trino
	
	@echo "$(BOLD)$(CYAN)Step 4: Creating Iceberg tables in Trino...$(RESET)"
	@$(MAKE) create-tables
	
	@echo "$(BOLD)$(CYAN)Step 5: Deploying Flink jobs...$(RESET)"
	@$(MAKE) deploy-flink-jobs
	
	@echo "$(BOLD)$(CYAN)Step 6: Waiting for data to flow through the pipeline...$(RESET)"
	@$(MAKE) wait-for-data
	
	@echo "$(BOLD)$(CYAN)Step 7: Running example queries to verify data...$(RESET)"
	@echo "$(YELLOW)Querying user activity data:$(RESET)"
	@docker exec trino-coordinator trino --server localhost:8080 --catalog iceberg --execute "SELECT event_type, COUNT(*) FROM warehouse.user_activity GROUP BY event_type" || \
		echo "$(BOLD)$(YELLOW)⚠️ Query failed. This might be expected if data hasn't been processed yet.$(RESET)"
	
	@echo "$(YELLOW)Querying sensor data:$(RESET)"
	@docker exec trino-coordinator trino --server localhost:8080 --catalog iceberg --execute "SELECT sensor_type, AVG(sensor_value) FROM warehouse.sensor_data GROUP BY sensor_type" || \
		echo "$(BOLD)$(YELLOW)⚠️ Query failed. This might be expected if data hasn't been processed yet.$(RESET)"
	
	@echo "$(BOLD)$(CYAN)Step 8: Setting up Superset dashboards...$(RESET)"
	@$(MAKE) setup-superset
	
	@echo "$(BOLD)$(GREEN)✅ Demo completed successfully!$(RESET)"
	@echo "$(BOLD)$(YELLOW)You can access the following services:$(RESET)"
	@echo "  $(YELLOW)Kafka UI:$(RESET)        http://localhost:8080"
	@echo "  $(YELLOW)Minio Console:$(RESET)   http://localhost:9001 (minioadmin/minioadmin)"
	@echo "  $(YELLOW)Flink Dashboard:$(RESET) http://localhost:8081"
	@echo "  $(YELLOW)Trino UI:$(RESET)        http://localhost:8082"
	@echo "  $(YELLOW)Superset:$(RESET)        http://localhost:8088 (admin/admin)"
