plugins {
    java
    id("org.springframework.boot") version "3.4.2"
    id("io.spring.dependency-management") version "1.1.7"
}

group = "site.thaonv.voca"
version = "2.0.0-SNAPSHOT"

java {
    toolchain {
        languageVersion = JavaLanguageVersion.of(21)
    }
}

repositories {
    mavenCentral()
}

dependencies {
    // Web + validation + actuator
    implementation("org.springframework.boot:spring-boot-starter-web")
    implementation("org.springframework.boot:spring-boot-starter-validation")
    implementation("org.springframework.boot:spring-boot-starter-actuator")

    // Security + JWT end-user auth
    implementation("org.springframework.boot:spring-boot-starter-security")
    implementation("io.jsonwebtoken:jjwt-api:0.12.6")
    runtimeOnly("io.jsonwebtoken:jjwt-impl:0.12.6")
    runtimeOnly("io.jsonwebtoken:jjwt-jackson:0.12.6")

    // WebClient (reactive) used to call LLM/TTS providers
    implementation("org.springframework.boot:spring-boot-starter-webflux")

    // Persistence
    implementation("org.springframework.boot:spring-boot-starter-data-jpa")
    implementation("org.flywaydb:flyway-core")
    implementation("org.flywaydb:flyway-database-postgresql")
    runtimeOnly("org.postgresql:postgresql")

    // OpenAPI docs (contract source for generated TS + Swift clients)
    implementation("org.springdoc:springdoc-openapi-starter-webmvc-ui:2.7.0")

    // Lombok
    compileOnly("org.projectlombok:lombok")
    annotationProcessor("org.projectlombok:lombok")

    // Test
    testImplementation("org.springframework.boot:spring-boot-starter-test")
    testImplementation("org.springframework.security:spring-security-test")
    testImplementation("org.springframework.boot:spring-boot-testcontainers")
    testImplementation("org.testcontainers:junit-jupiter")
    testImplementation("org.testcontainers:postgresql")
    testRuntimeOnly("org.junit.platform:junit-platform-launcher")
}

tasks.withType<Test> {
    useJUnitPlatform()
}

// Bundle the web app (voca-v2/web/dist) into the jar so one binary serves API + SPA on a single port.
val copyWebApp = tasks.register<Copy>("copyWebApp") {
    val dist = layout.projectDirectory.dir("../web/dist")
    onlyIf { dist.asFile.exists() }
    dependsOn("processResources")
    from(dist)
    into(layout.buildDirectory.dir("resources/main/static"))
}
tasks.named("classes") { dependsOn(copyWebApp) }
tasks.named("bootJar") { dependsOn(copyWebApp) }
