# WAR Build Process

## WAR File Structure

```
sef.war
├── META-INF/
│   └── MANIFEST.MF
├── WEB-INF/
│   ├── classes/
│   │   ├── com/sqisoft/sef/          # compiled Java classes
│   │   │   ├── core/
│   │   │   ├── infra/
│   │   │   └── modules/
│   │   ├── mybatis/                  # MyBatis config and mappers
│   │   ├── static/                   # Nuxt build output
│   │   │   ├── _nuxt/
│   │   │   ├── index.html
│   │   │   └── ...
│   │   ├── application.yml
│   │   └── properties/              # env-specific properties
│   └── lib/                          # dependency JARs
│       ├── spring-*.jar
│       ├── mybatis-*.jar
│       └── ...
```

## Build Flow

```
pnpm install + pnpm run build (in frontend/)
        |
        v
Copy frontend/.output/public/* --> src/main/resources/static/
        |
        v
./gradlew clean build -x test
        |
        v
build/libs/sef.war
```

## Step-by-Step Commands

### 1. Build Nuxt Frontend

```bash
cd frontend
pnpm install
pnpm run build
```

Produces `frontend/.output/public/` with pre-rendered HTML, JS bundles under `_nuxt/`, and static assets.

### 2. Copy Static Assets to Spring Boot Resources

**Linux/Mac:**
```bash
rm -rf src/main/resources/static/*
cp -r frontend/.output/public/* src/main/resources/static/
```

**Windows:**
```cmd
rmdir /S /Q src\main\resources\static
mkdir src\main\resources\static
xcopy frontend\.output\public src\main\resources\static /E /I /Y
```

### 3. Build WAR with Gradle

```bash
./gradlew clean build -x test
```

Windows: `gradlew.bat clean build -x test`

Output: `build/libs/sef.war`

## build.gradle.kts WAR Configuration

Key settings from the project's actual build file:

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
    archiveClassifier.set("")  // produces sef.war (no classifier suffix)
}

// JEUS 8 compatibility: exclude conflicting validation libraries
configurations {
    all {
        exclude(group = "javax.validation", module = "validation-api")
        exclude(group = "org.hibernate.validator", module = "hibernate-validator")
    }
}

dependencies {
    // JEUS 8 compatible validation
    implementation("javax.validation:validation-api:1.1.0.Final")
    implementation("org.hibernate:hibernate-validator:5.4.3.Final")

    // WAR deployment: mark embedded Tomcat as provided
    providedRuntime("org.springframework.boot:spring-boot-starter-tomcat")
}
```

The root project name is `sef` (in `settings.gradle.kts`), so the output is `build/libs/sef.war`.

## Gradle Node Plugin Integration (Optional)

To integrate the frontend build into the Gradle lifecycle so `./gradlew build` handles everything:

```kotlin
plugins {
    id("com.github.node-gradle.node") version "7.0.1"
}

node {
    version.set("20.11.0")
    download.set(true)
    nodeProjectDir.set(file("${project.projectDir}/frontend"))
}

tasks.register<com.github.gradle.node.npm.task.NpxTask>("pnpmInstall") {
    command.set("pnpm")
    args.set(listOf("install"))
}

tasks.register<com.github.gradle.node.npm.task.NpxTask>("pnpmBuild") {
    dependsOn("pnpmInstall")
    command.set("pnpm")
    args.set(listOf("run", "build"))
}

tasks.register<Copy>("copyFrontend") {
    dependsOn("pnpmBuild")
    from("${project.projectDir}/frontend/.output/public")
    into("${project.buildDir}/resources/main/static")
}

tasks.named("processResources") {
    dependsOn("copyFrontend")
}
```

## Build Verification

```bash
# Confirm WAR exists
ls -lh build/libs/sef.war

# Check static files are included
jar -tf build/libs/sef.war | grep "WEB-INF/classes/static/index.html"

# Check compiled classes exist
jar -tf build/libs/sef.war | grep "WEB-INF/classes/com/sqisoft"

# Count dependency JARs
jar -tf build/libs/sef.war | grep "WEB-INF/lib/" | wc -l
```

## JEUS 8 Validation-API Compatibility Note

JEUS 8 ships with Bean Validation 1.1 (JSR-349). Spring Boot 2.7 defaults to Bean Validation 2.0 (`validation-api:2.0.x` + `hibernate-validator:6.x`), which conflicts at runtime on JEUS 8.

The project's `build.gradle.kts` excludes the default versions globally and pins:
- `javax.validation:validation-api:1.1.0.Final`
- `org.hibernate:hibernate-validator:5.4.3.Final`

If you see `NoSuchMethodError` or `ClassCastException` related to `javax.validation` on JEUS, verify these exclusions are in place and that no transitive dependency re-introduces the 2.0 versions. Run:

```bash
./gradlew dependencies --configuration runtimeClasspath | grep validation
```
