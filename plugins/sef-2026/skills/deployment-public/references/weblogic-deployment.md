# WebLogic Deployment Guide

## Version Compatibility

| Version | Java Support | Spec Level |
|---------|-------------|------------|
| WebLogic 11g (10.3.x) | Java 6, 7 | Java EE 5/6 |
| WebLogic 12c (12.2.x) | Java 7, 8 | Java EE 7 |
| WebLogic 14c (14.1.x) | Java 8, 11, 17 | Jakarta EE 8 |

This project targets WebLogic 14c or 12c with Java 8.

## Prerequisites

- `ORACLE_HOME` and `WL_HOME` environment variables set
- WebLogic domain created and Admin Server running
- WAR file built: `build/libs/sef.war` (see `war-build-process.md`)

## Deployment Methods

### Method 1: Admin Console

1. Access Admin Console at `http://<host>:7001/console` and log in
2. Click **Deployments** in the left Domain Structure tree
3. Click **Lock & Edit** (production mode), then **Install**
4. Upload or browse to `sef.war`, click **Next**
5. Select **Install this deployment as an application**, click **Next**
6. Choose target server(s), set Name (`sef`) and Context Path (`/`)
7. Click **Finish**, then **Activate Changes** and start the application

### Method 2: WLST (WebLogic Scripting Tool)

```bash
$ORACLE_HOME/oracle_common/common/bin/wlst.sh
```

```python
connect('weblogic', '<password>', 't3://localhost:7001')

deploy('sef', '/path/to/sef.war', targets='AdminServer', stageMode='nostage')
start('sef', 'AppDeployment')
state('sef', 'AppDeployment')

disconnect()
exit()
```

### Method 3: weblogic.Deployer CLI

```bash
# Deploy
java weblogic.Deployer -adminurl t3://localhost:7001 \
  -username weblogic -password <password> \
  -deploy -name sef -source /path/to/sef.war -targets AdminServer

# Start
java weblogic.Deployer -adminurl t3://localhost:7001 \
  -username weblogic -password <password> \
  -start -name sef

# Stop
java weblogic.Deployer -adminurl t3://localhost:7001 \
  -username weblogic -password <password> \
  -stop -name sef
```

## Redeployment

```bash
java weblogic.Deployer -adminurl t3://localhost:7001 \
  -username weblogic -password <password> \
  -redeploy -name sef -source /path/to/sef.war
```

Or via WLST: `redeploy('sef', '/path/to/sef.war')`.

For a clean redeployment, stop and undeploy first, then deploy again.

## JVM Options (setDomainEnv.sh)

Edit `$DOMAIN_HOME/bin/setDomainEnv.sh`:

```bash
USER_MEM_ARGS="-Xms1024m -Xmx2048m -XX:MaxMetaspaceSize=512m"

JAVA_OPTIONS="${JAVA_OPTIONS} -Dspring.profiles.active=prod"
JAVA_OPTIONS="${JAVA_OPTIONS} -Dfile.encoding=UTF-8"
export USER_MEM_ARGS JAVA_OPTIONS
```

On Windows, edit `setDomainEnv.cmd`:

```cmd
set USER_MEM_ARGS=-Xms1024m -Xmx2048m -XX:MaxMetaspaceSize=512m
set JAVA_OPTIONS=%JAVA_OPTIONS% -Dspring.profiles.active=prod
set JAVA_OPTIONS=%JAVA_OPTIONS% -Dfile.encoding=UTF-8
```

## weblogic.xml for Classloader Isolation

Place `src/main/webapp/WEB-INF/weblogic.xml` to ensure the WAR's bundled libraries take precedence over WebLogic's shared libraries:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<weblogic-web-app xmlns="http://xmlns.oracle.com/weblogic/weblogic-web-app">
    <container-descriptor>
        <prefer-web-inf-classes>true</prefer-web-inf-classes>
    </container-descriptor>
</weblogic-web-app>
```

This prevents conflicts between Spring Boot dependencies (e.g., Jackson, validation-api) and WebLogic's built-in versions.

## Key Troubleshooting

- **ClassLoader conflict (Jackson, JAXB, etc.)**: Ensure `weblogic.xml` has `prefer-web-inf-classes` set to `true`; alternatively use `prefer-application-packages` for fine-grained control
- **Deployment timeout**: Increase the deployment timeout in Admin Console under Configuration > General, or add `-timeout <seconds>` to `weblogic.Deployer` commands
- **Memory issues on startup**: Increase heap in `setDomainEnv.sh` and check for duplicate library loading; run `jar -tf build/libs/sef.war | grep "WEB-INF/lib" | wc -l` to verify dependency count is reasonable
