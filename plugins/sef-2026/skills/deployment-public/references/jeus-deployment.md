# JEUS Deployment Guide

## Version Compatibility

| Version | Java Support | Spec Level |
|---------|-------------|------------|
| JEUS 6 | Java 6, 7 | Java EE 6 |
| JEUS 7 | Java 7, 8 | Java EE 7 |
| JEUS 8 | Java 8, 11 | Jakarta EE 8 |

This project targets JEUS 8 with Java 8. Validation-api 1.1.0.Final is used to avoid conflicts with JEUS 8's bundled libraries.

## Prerequisites

- `JEUS_HOME` environment variable set and JEUS domain configured
- WAR file built: `build/libs/sef.war` (see `war-build-process.md`)

## Deployment Methods

### Method 1: WebAdmin Console

1. Access WebAdmin at `http://<host>:9736/webadmin` and log in
2. Navigate to **Applications** in the left menu
3. Click **Deploy**, browse to select `sef.war`
4. Set Application ID (`sef`), Context Path (`/`), and target server
5. Click **OK**, then start the application from the application list

### Method 2: CLI (jeusadmin)

```bash
$JEUS_HOME/bin/jeusadmin -u administrator -p <password>

# Deploy
deploy -name sef -path /path/to/sef.war -contextpath / -server server1

# Start
start-application -name sef -server server1

# Verify
application-info -name sef

quit
```

### Method 3: Autodeploy Directory

```bash
cp build/libs/sef.war $JEUS_HOME/domains/<domain>/servers/<server>/autodeploy/
```

JEUS automatically detects and deploys the WAR file.

## Redeployment

```bash
$JEUS_HOME/bin/jeusadmin -u administrator -p <password>

stop-application -name sef -server server1
redeploy -name sef -path /path/to/sef.war -server server1
start-application -name sef -server server1

quit
```

For zero-downtime redeployment, add the `-graceful` flag to the `redeploy` command.

## JVM Options for Spring Profiles

Edit `$JEUS_HOME/domains/<domain>/config.xml`:

```xml
<jvm-config>
    <jvm-option>-Xms1024m</jvm-option>
    <jvm-option>-Xmx2048m</jvm-option>
    <jvm-option>-Dspring.profiles.active=prod</jvm-option>
    <jvm-option>-Dfile.encoding=UTF-8</jvm-option>
</jvm-config>
```

Or set at runtime via jeusadmin:

```bash
set-jvm-option -server server1 -jvmoptions "-Dspring.profiles.active=prod"
```

## Log Locations

```
$JEUS_HOME/domains/<domain>/servers/<server>/logs/JeusServer.log    # server log
$JEUS_HOME/domains/<domain>/servers/<server>/logs/JeusServer.err    # error log
$JEUS_HOME/domains/<domain>/servers/<server>/logs/<app-name>.log    # app log
```

## Key Troubleshooting

- **validation-api conflict**: Ensure WAR excludes `javax.validation:validation-api:2.x` and `hibernate-validator:6.x`; use `1.1.0.Final` and `5.4.3.Final` respectively (already configured in `build.gradle.kts`)
- **ClassNotFoundException**: Inspect WAR contents with `jar -tf build/libs/sef.war | grep <ClassName>` and check for library conflicts between WAR and JEUS shared libs
- **Port conflict / Address already in use**: Check `netstat -an | grep <port>` and stop conflicting processes or change the JEUS HTTP listener port
