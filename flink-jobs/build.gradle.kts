import org.jetbrains.kotlin.gradle.tasks.KotlinCompile

plugins {
    java
    kotlin("jvm") version "1.9.22"
}

group = "com.example"
version = "1.0-SNAPSHOT"

repositories {
    mavenCentral()
}

val flinkVersion = "1.20.0"
val icebergVersion = "1.8.1" 
val kafkaConnectorVersion = "3.4.0-1.20"

dependencies {
    // Apache Flink dependencies
    implementation("org.apache.flink:flink-java:$flinkVersion")
    implementation("org.apache.flink:flink-streaming-java:$flinkVersion")
    implementation("org.apache.flink:flink-clients:$flinkVersion")
    implementation("org.apache.flink:flink-table-api-java-bridge:$flinkVersion")
    implementation("org.apache.flink:flink-table-common:$flinkVersion")
    implementation("org.apache.flink:flink-runtime:$flinkVersion")

    // Flink Table API dependencies
    implementation("org.apache.flink:flink-table-runtime:$flinkVersion")
    implementation("org.apache.flink:flink-table-planner-loader:$flinkVersion")

    // Flink Kafka connector
    implementation("org.apache.flink:flink-sql-connector-kafka:$kafkaConnectorVersion")

    // Flink File connector
    implementation("org.apache.flink:flink-connector-files:$flinkVersion")

    // Flink JSON serialization
    implementation("org.apache.flink:flink-json:$flinkVersion")

    // Iceberg integration for Flink
    implementation("org.apache.iceberg:iceberg-flink-runtime-1.20:$icebergVersion")
    implementation("org.apache.iceberg:iceberg-aws:$icebergVersion")
    implementation("org.apache.iceberg:iceberg-core:$icebergVersion")

    // AWS S3 dependencies
    implementation("org.apache.flink:flink-s3-fs-hadoop:$flinkVersion")
    implementation("org.apache.hadoop:hadoop-aws:3.3.6")
    implementation("org.apache.hadoop:hadoop-common:3.4.1")
    implementation("software.amazon.awssdk:s3:2.25.12")

    // Logging
    implementation("org.slf4j:slf4j-api:2.0.17")
    implementation("ch.qos.logback:logback-classic:1.4.14")

    // Jackson for JSON processing
    implementation("com.fasterxml.jackson.core:jackson-databind:2.18.3")
    implementation("com.fasterxml.jackson.datatype:jackson-datatype-jsr310:2.18.3")
}

java {
    sourceCompatibility = JavaVersion.VERSION_17
    targetCompatibility = JavaVersion.VERSION_17
}

tasks.withType<KotlinCompile> {
    kotlinOptions.jvmTarget = "17"
}

tasks.jar {
    manifest {
        attributes["Main-Class"] = "com.example.UserActivityProcessor"
    }

    // Include all dependencies in the jar
    from(configurations.runtimeClasspath.get().map { if (it.isDirectory) it else zipTree(it) })

    // Exclude META-INF signatures to avoid security exceptions
    exclude("META-INF/*.SF", "META-INF/*.DSA", "META-INF/*.RSA")

    duplicatesStrategy = DuplicatesStrategy.EXCLUDE

    // Enable zip64 extension to support more than 65535 entries
    isZip64 = true
}

// Create a task for building the SensorDataProcessor jar
tasks.register<Jar>("sensorDataProcessorJar") {
    archiveBaseName.set("sensor-data-processor")
    manifest {
        attributes["Main-Class"] = "com.example.SensorDataProcessor"
    }

    from(sourceSets.main.get().output)

    // Include all dependencies in the jar
    from(configurations.runtimeClasspath.get().map { if (it.isDirectory) it else zipTree(it) })

    // Exclude META-INF signatures to avoid security exceptions
    exclude("META-INF/*.SF", "META-INF/*.DSA", "META-INF/*.RSA")

    duplicatesStrategy = DuplicatesStrategy.EXCLUDE

    // Enable zip64 extension to support more than 65535 entries
    isZip64 = true
}

// Create a task for building the UserActivityProcessor jar
tasks.register<Jar>("userActivityProcessorJar") {
    archiveBaseName.set("user-activity-processor")
    manifest {
        attributes["Main-Class"] = "com.example.UserActivityProcessor"
    }

    from(sourceSets.main.get().output)

    // Include all dependencies in the jar
    from(configurations.runtimeClasspath.get().map { if (it.isDirectory) it else zipTree(it) })

    // Exclude META-INF signatures to avoid security exceptions
    exclude("META-INF/*.SF", "META-INF/*.DSA", "META-INF/*.RSA")

    duplicatesStrategy = DuplicatesStrategy.EXCLUDE

    // Enable zip64 extension to support more than 65535 entries
    isZip64 = true
}

// Create a task for building the MessageCounterJob jar
tasks.register<Jar>("messageCounterJobJar") {
    archiveBaseName.set("message-counter-job")
    manifest {
        attributes["Main-Class"] = "com.example.MessageCounterJob"
    }

    from(sourceSets.main.get().output)

    // Include all dependencies in the jar
    from(configurations.runtimeClasspath.get().map { if (it.isDirectory) it else zipTree(it) })

    // Explicitly include the Kafka connector
    from(configurations.runtimeClasspath.get().filter { it.name.contains("flink-sql-connector-kafka") })

    // Exclude META-INF signatures to avoid security exceptions
    exclude("META-INF/*.SF", "META-INF/*.DSA", "META-INF/*.RSA")

    duplicatesStrategy = DuplicatesStrategy.EXCLUDE

    // Enable zip64 extension to support more than 65535 entries
    isZip64 = true
}

// Add a task to build all jars
tasks.register("buildAllJars") {
    dependsOn("jar", "userActivityProcessorJar", "sensorDataProcessorJar", "messageCounterJobJar")
}
