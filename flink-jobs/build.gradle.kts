plugins {
    java
}

group = "com.example"
version = "1.0-SNAPSHOT"

repositories {
    mavenCentral()
}

val flinkVersion = "2.3.0"
val icebergVersion = "1.12.0"
val kafkaConnectorVersion = "5.0.0-2.2"

dependencies {
    // Apache Flink 2.x dependencies (flink-java removed in 2.x)
    implementation("org.apache.flink:flink-streaming-java:$flinkVersion")
    implementation("org.apache.flink:flink-clients:$flinkVersion")
    implementation("org.apache.flink:flink-table-api-java-bridge:$flinkVersion")
    implementation("org.apache.flink:flink-table-common:$flinkVersion")
    implementation("org.apache.flink:flink-runtime:$flinkVersion")

    // Flink Table API dependencies
    implementation("org.apache.flink:flink-table-runtime:$flinkVersion")
    implementation("org.apache.flink:flink-table-planner-loader:$flinkVersion")

    // Flink Kafka connector (4.x for Flink 2.x)
    implementation("org.apache.flink:flink-sql-connector-kafka:$kafkaConnectorVersion")

    // Flink File connector
    implementation("org.apache.flink:flink-connector-files:$flinkVersion")

    // Flink JSON serialization
    implementation("org.apache.flink:flink-json:$flinkVersion")

    // Iceberg integration for Flink (iceberg-flink-runtime-2.3 for Flink 2.x)
    implementation("org.apache.iceberg:iceberg-flink-runtime-2.3:$icebergVersion")
    implementation("org.apache.iceberg:iceberg-aws-bundle:$icebergVersion")

    // Hadoop S3 support
    implementation("org.apache.flink:flink-s3-fs-hadoop:$flinkVersion")

    // Logging
    implementation("org.slf4j:slf4j-api:2.0.20")
    implementation("ch.qos.logback:logback-classic:1.6.5")

    // Caffeine cache (required by Iceberg REST catalog)
    implementation("com.github.ben-manes.caffeine:caffeine:3.3.1")

    // Jackson for JSON processing
    implementation("com.fasterxml.jackson.core:jackson-databind:2.22.4")
    implementation("com.fasterxml.jackson.datatype:jackson-datatype-jsr310:2.22.4")

    // Test
    testImplementation("org.junit.jupiter:junit-jupiter:6.1.3")
    testRuntimeOnly("org.junit.platform:junit-platform-launcher")
}

java {
    sourceCompatibility = JavaVersion.VERSION_17
    targetCompatibility = JavaVersion.VERSION_17
}

tasks.test {
    useJUnitPlatform()
    testLogging {
        events("passed", "skipped", "failed")
        showStandardStreams = false
        exceptionFormat = org.gradle.api.tasks.testing.logging.TestExceptionFormat.SHORT
    }
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
