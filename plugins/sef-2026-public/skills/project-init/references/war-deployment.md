# WAR Deployment Guide

## Overview

SEF 2026 produces a single WAR file containing the Spring Boot 2.7 backend and Nuxt 4 static frontend. This WAR is deployed to a Java EE-compatible WAS.

## Supported WAS

| WAS | Version | Notes |
|-----|---------|-------|
| JEUS | 8 | Primary target; requires Java 8, validation-api 1.1.0 |
| WebLogic | 14c, 12c | Oracle enterprise WAS |
| Tomcat | 9.x | Lightweight, dev/small-scale |

## Pre-Deployment

### 1. Build WAR

```bash
cd frontend && pnpm build                            # Build Nuxt
cp -r .output/public/* ../src/main/resources/static/  # Copy static files
cd .. && gradlew.bat clean build -x test              # Package WAR
```

Output: `build/libs/sef.war`

### 2. Verify WAR Contents

```bash
jar -tf build/libs/sef.war | grep static/index.html
jar -tf build/libs/sef.war | grep "com/sqisoft/sef"
```

Confirm both static frontend files and compiled backend classes are present.

### 3. Environment Variables

Set these on the target WAS or OS before deployment:

| Variable | Example | Purpose |
|----------|---------|---------|
| SPRING_PROFILES_ACTIVE | prod | Active Spring profile |
| DB_HOST | prod-db | Database host |
| DB_PORT | 5432 | Database port |
| DB_NAME | sefdb | Database name |
| DB_USERNAME | sefuser | Database user |
| DB_PASSWORD | (secret) | Database password |
| JWT_SECRET | (secret) | JWT signing key |

Profile-specific properties are in `src/main/resources/properties/{profile}/env.properties`.

## JEUS 8 Deployment

### WebAdmin Console
Access `http://<server>:9736/webadmin` -> Applications -> Deploy -> select WAR -> Start.

### CLI (jeusadmin)
```bash
$JEUS_HOME/bin/jeusadmin -u administrator -p <password>
> deploy -name sef -path /path/to/sef.war -server server1
> start-application -name sef -server server1
```

### Auto-deploy Directory
```bash
cp build/libs/sef.war $JEUS_HOME/domains/domain1/servers/server1/autodeploy/
```

**Note**: JEUS 8 ships validation-api 1.0. The project excludes the newer version and bundles validation-api 1.1.0.Final to avoid classpath conflicts.

## WebLogic Deployment

### Admin Console
Access `http://<server>:7001/console` -> Deployments -> Install -> upload WAR -> configure targets -> Finish.

### WLST Script
```bash
$ORACLE_HOME/oracle_common/common/bin/wlst.sh
> connect('weblogic', '<password>', 't3://localhost:7001')
> deploy('sef', '/path/to/sef.war', targets='AdminServer')
```

## Tomcat Deployment

### webapps Copy
```bash
cp build/libs/sef.war $CATALINA_HOME/webapps/
# Tomcat auto-extracts and deploys on startup
```

For ROOT context deployment, rename to `ROOT.war` or configure `server.xml`.

## Post-Deployment Checks

### 1. Application Log
```bash
# JEUS
tail -f $JEUS_HOME/domains/domain1/servers/server1/logs/JeusServer.log
# WebLogic
tail -f $DOMAIN_HOME/servers/AdminServer/logs/AdminServer.log
# Tomcat
tail -f $CATALINA_HOME/logs/catalina.out
```

Look for: `Started SefApplication in X seconds`

### 2. Health Check
```bash
curl http://<server>:<port>/api/health
```

### 3. Frontend Page Access
```bash
curl -o /dev/null -s -w "%{http_code}" http://<server>:<port>/
# Expect: 200
```

## Deployment Checklist

- [ ] `pnpm build` completed without errors
- [ ] Static files copied to `src/main/resources/static/`
- [ ] WAR built successfully (`build/libs/sef.war` exists)
- [ ] WAR contains `static/index.html` (verify with `jar -tf`)
- [ ] Environment variables set on target server (DB, JWT, profile)
- [ ] Previous WAR version backed up
- [ ] WAR deployed and application started on WAS
- [ ] Post-deployment checks passed (log, health, page access)
