---
name: deployment
description: Government project deployment guide. WAR build, JEUS/WebLogic/Tomcat deployment, Nuxt 4 + Spring Boot integrated build process. Use when deploying to WAS servers.
---

# Deployment

Integrated build and deployment process for packaging Nuxt 4 frontend + Spring Boot 2.7 backend into a single WAR file and deploying to government WAS servers (JEUS, WebLogic, Tomcat).

## Build Process

### Step 1: Build Frontend

```bash
cd frontend
pnpm install
pnpm run build
```

Output: `frontend/.output/public/` containing pre-rendered SPA assets.

### Step 2: Copy Static Assets

```bash
rm -rf src/main/resources/static/*
cp -r frontend/.output/public/* src/main/resources/static/
```

This embeds the Nuxt build output into the Spring Boot classpath so it is served as static content from the WAR.

### Step 3: Build WAR

```bash
./gradlew clean build -x test
```

Output: `build/libs/sef.war`

On Windows use `gradlew.bat` instead of `./gradlew`.

## WAS Deployment Summary

### JEUS 8

Deploy via WebAdmin console (Applications > Deploy) or CLI: `jeusadmin deploy -name sef -path /path/to/sef.war`. See `references/jeus-deployment.md` for details.

### WebLogic 14c / 12c

Deploy via Admin Console (Deployments > Install) or weblogic.Deployer CLI. Place `weblogic.xml` with `prefer-web-inf-classes` to avoid classloader conflicts. See `references/weblogic-deployment.md`.

### Tomcat

Copy `sef.war` to `$CATALINA_HOME/webapps/` and restart. Set `-Dspring.profiles.active=prod` in `CATALINA_OPTS`.

## Environment Profile Configuration

Set `spring.profiles.active` as a JVM argument on the target WAS:

| WAS | Configuration |
|-----|---------------|
| JEUS | `<jvm-option>-Dspring.profiles.active=prod</jvm-option>` in domain `config.xml` |
| WebLogic | `JAVA_OPTIONS` in `$DOMAIN_HOME/bin/setDomainEnv.sh` |
| Tomcat | `CATALINA_OPTS` in `setenv.sh` |

Profile-specific properties are loaded from `src/main/resources/properties/{profile}/env.properties`.

## Deployment Checklist

- [ ] Nuxt build completed without errors (`frontend/.output/public/index.html` exists)
- [ ] Static assets copied to `src/main/resources/static/`
- [ ] WAR file generated at `build/libs/sef.war`
- [ ] WAR contains static files: `jar -tf build/libs/sef.war | grep static/index.html`
- [ ] Database connection properties configured for target environment
- [ ] `spring.profiles.active` set on WAS JVM options
- [ ] Application accessible and WAS server logs show no startup errors

## References

- `references/war-build-process.md` -- WAR file structure and Gradle build details
- `references/jeus-deployment.md` -- JEUS 6/7/8 deployment guide
- `references/weblogic-deployment.md` -- WebLogic 11g/12c/14c deployment guide
