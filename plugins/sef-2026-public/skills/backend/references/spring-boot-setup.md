# Spring Boot Setup Reference

## Tech Stack

| Component | Technology | Version |
|-----------|-----------|---------|
| Framework | Spring Boot | 2.7.18 |
| Java | OpenJDK | 8 |
| Build | Gradle Kotlin DSL | `build.gradle.kts` |
| Packaging | WAR | JEUS/WebLogic deploy |
| ORM | MyBatis | 2.3.1 |
| Security | Spring Security + JWT | jjwt 0.11.5 |
| Logging | Log4j2 + log4jdbc | SQL logging |
| Gov Framework | eGovFrame | 4.1.0 |
| API Docs | SpringDoc OpenAPI | 1.7.0 |

## build.gradle.kts

```kotlin
plugins {
    java
    war
    id("org.springframework.boot") version "2.7.18"
    id("io.spring.dependency-management") version "1.1.4"
}

group = "com.sqisoft"

java {
    sourceCompatibility = JavaVersion.VERSION_1_8
    targetCompatibility = JavaVersion.VERSION_1_8
}

tasks.war {
    enabled = true
    archiveClassifier.set("")
}

repositories {
    mavenCentral()
    maven { url = uri("https://maven.egovframe.go.kr/maven") }
}

// JEUS 8 compatibility: exclude conflicting validation-api
configurations {
    all {
        exclude(group = "org.springframework.boot", module = "spring-boot-starter-logging")
        exclude(group = "javax.validation", module = "validation-api")
        exclude(group = "org.hibernate.validator", module = "hibernate-validator")
    }
}

dependencies {
    // Spring Boot
    implementation("org.springframework.boot:spring-boot-starter-jdbc")
    implementation("org.springframework.boot:spring-boot-starter-web")
    implementation("org.springframework.boot:spring-boot-starter-security")
    implementation("org.springframework.boot:spring-boot-starter-mail")
    implementation("org.springframework.boot:spring-boot-starter-log4j2")

    // JEUS 8 compatible validation
    implementation("javax.validation:validation-api:1.1.0.Final")
    implementation("org.hibernate:hibernate-validator:5.4.3.Final")

    // eGovFrame
    implementation("org.egovframe.rte:org.egovframe.rte.fdl.cmmn:4.1.0")
    implementation("org.egovframe.rte:org.egovframe.rte.psl.dataaccess:4.1.0")

    // MyBatis
    implementation("org.mybatis.spring.boot:mybatis-spring-boot-starter:2.3.1")

    // JWT
    implementation("io.jsonwebtoken:jjwt-api:0.11.5")
    runtimeOnly("io.jsonwebtoken:jjwt-impl:0.11.5")
    runtimeOnly("io.jsonwebtoken:jjwt-jackson:0.11.5")

    // Swagger
    implementation("org.springdoc:springdoc-openapi-ui:1.7.0")

    // Database drivers
    runtimeOnly("org.postgresql:postgresql:42.7.2")
    runtimeOnly("com.oracle.database.jdbc:ojdbc8:23.2.0.0")

    // Logging
    implementation("org.bgee.log4jdbc-log4j2:log4jdbc-log4j2-jdbc4.1:1.16")

    // Utilities
    implementation("org.apache.commons:commons-lang3:3.12.0")
    implementation("org.modelmapper:modelmapper:2.4.5")
    implementation("org.apache.poi:poi-ooxml:4.1.2")
    compileOnly("org.projectlombok:lombok:1.18.30")
    annotationProcessor("org.projectlombok:lombok:1.18.30")

    // WAR deployment
    providedRuntime("org.springframework.boot:spring-boot-starter-tomcat")

    // Test
    testImplementation("org.springframework.boot:spring-boot-starter-test")
}
```

## Application Classes

```java
// SefApplication.java
@SpringBootApplication
public class SefApplication {
    public static void main(String[] args) {
        SpringApplication.run(SefApplication.class, args);
    }
}

// ServletInitializer.java (WAR deployment)
public class ServletInitializer extends SpringBootServletInitializer {
    @Override
    protected SpringApplicationBuilder configure(SpringApplicationBuilder application) {
        return application.sources(SefApplication.class);
    }
}
```

## application.yml (Key Sections)

```yaml
spring:
  application:
    name: sef
  profiles:
    active: ${SPRING_PROFILES_ACTIVE:local}
  datasource:
    driver-class-name: net.sf.log4jdbc.sql.jdbcapi.DriverSpy
    url: jdbc:log4jdbc:postgresql://${DB_HOST:localhost}:${DB_PORT:5432}/${DB_NAME:sefdb}
    username: ${DB_USERNAME:postgres}
    password: ${DB_PASSWORD:postgres}
    hikari:
      maximum-pool-size: 10
      minimum-idle: 5
  web:
    resources:
      static-locations: classpath:/static/

mybatis:
  config-location: classpath:mybatis/config/mybatis-config.xml
  mapper-locations: classpath*:mybatis/mapper/**/*.xml

server:
  port: ${SERVER_PORT:7171}
  servlet:
    context-path: /

jwt:
  header: Authorization
  secret: ${JWT_SECRET}
  access-token-validity: 3600000
  refresh-token-validity: 604800000
```

## JEUS 8 Compatibility

1. **validation-api**: Must use 1.1.0.Final + hibernate-validator 5.4.3.Final (exclude newer versions)
2. **javax vs jakarta**: Spring Boot 2.7.x uses `javax.*` packages. Do NOT upgrade to Spring Boot 3.x (jakarta-based)
3. **Logging**: Exclude default logback, use Log4j2 (`spring-boot-starter-log4j2`)

## Build & Run

```bash
# Development
./gradlew bootRun
./gradlew bootRun --args='--spring.profiles.active=dev'

# WAR build
./gradlew clean build -x test
# Output: build/libs/sef.war

# Run WAR directly
java -jar -Dspring.profiles.active=prod build/libs/sef.war
```

## Oracle Database

```yaml
spring:
  datasource:
    url: jdbc:log4jdbc:oracle:thin:@${DB_HOST:localhost}:${DB_PORT:1521}:${DB_SID:XE}
```
