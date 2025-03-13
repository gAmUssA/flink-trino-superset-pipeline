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
val icebergVersion = "1.5.0" 
val kafkaConnectorVersion = "3.4.0-1.20"

dependencies {
    // Apache Flink dependencies
    implementation("org.apache.flink:flink-java:$flinkVersion")
    implementation("org.apache.flink:flink-streaming-java:$flinkVersion")
    implementation("org.apache.flink:flink-clients:$flinkVersion")
    implementation("org.apache.flink:flink-table-api-java-bridge:$flinkVersion")
    implementation("org.apache.flink:flink-table-common:$flinkVersion")
    implementation("org.apache.flink:flink-runtime:$flinkVersion")

    // Flink Kafka connector
    implementation("org.apache.flink:flink-connector-kafka:$kafkaConnectorVersion")

    // Flink JSON serialization
    implementation("org.apache.flink:flink-json:$flinkVersion")

    // Temporarily commenting out Iceberg dependencies to fix build issues
    // implementation("org.apache.iceberg:iceberg-flink-runtime-1.20:$icebergVersion")
    // implementation("org.apache.iceberg:iceberg-core:$icebergVersion")
    // implementation("org.apache.iceberg:iceberg-api:$icebergVersion")
    // implementation("org.apache.iceberg:iceberg-common:$icebergVersion")
    // implementation("org.apache.iceberg:iceberg-data:$icebergVersion")
    // implementation("org.apache.iceberg:iceberg-parquet:$icebergVersion")

    // AWS S3 dependencies
    implementation("org.apache.hadoop:hadoop-aws:3.3.4")
    implementation("org.apache.hadoop:hadoop-common:3.3.4")

    // Logging
    implementation("org.slf4j:slf4j-api:1.7.36")
    implementation("org.slf4j:slf4j-log4j12:1.7.36")
    implementation("log4j:log4j:1.2.17")

    // Jackson for JSON processing
    implementation("com.fasterxml.jackson.core:jackson-databind:2.13.4.2")
}

java {
    sourceCompatibility = JavaVersion.VERSION_21
    targetCompatibility = JavaVersion.VERSION_21
}

tasks.withType<KotlinCompile> {
    kotlinOptions.jvmTarget = "21"
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

// Add a task to build all jars
tasks.register("buildAllJars") {
    dependsOn("jar", "userActivityProcessorJar", "sensorDataProcessorJar")
}
