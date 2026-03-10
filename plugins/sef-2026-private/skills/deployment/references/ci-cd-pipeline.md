# CI/CD 파이프라인 구축 가이드

민간 섹터 프로젝트의 지속적 통합 및 배포(CI/CD) 파이프라인 구축 가이드입니다.

## 개요

CI/CD 파이프라인은 코드 변경사항을 자동으로 빌드, 테스트, 배포하는 자동화 프로세스입니다.

### 주요 플랫폼

- **GitHub Actions** (권장): GitHub 통합, 무료 티어
- **GitLab CI/CD**: GitLab 통합, 자체 호스팅 가능
- **Jenkins**: 오픈소스, 고도로 커스터마이즈 가능
- **CircleCI**: 클라우드 기반, 빠른 빌드
- **AWS CodePipeline**: AWS 네이티브

## GitHub Actions

### 기본 구조

```
.github/
└── workflows/
    ├── backend-ci.yml
    ├── frontend-ci.yml
    ├── deploy-staging.yml
    └── deploy-production.yml
```

### backend-ci.yml (백엔드 CI)

```yaml
name: Backend CI

on:
  push:
    branches: [main, develop]
    paths:
      - 'backend/**'
  pull_request:
    branches: [main, develop]
    paths:
      - 'backend/**'

env:
  JAVA_VERSION: '17'
  MAVEN_OPTS: -Xmx1024m

jobs:
  test:
    name: Test
    runs-on: ubuntu-latest

    services:
      postgres:
        image: postgres:15-alpine
        env:
          POSTGRES_DB: testdb
          POSTGRES_USER: test
          POSTGRES_PASSWORD: test
        ports:
          - 5432:5432
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5

      redis:
        image: redis:7-alpine
        ports:
          - 6379:6379
        options: >-
          --health-cmd "redis-cli ping"
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5

    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Set up JDK
        uses: actions/setup-java@v3
        with:
          java-version: ${{ env.JAVA_VERSION }}
          distribution: 'temurin'
          cache: 'maven'

      - name: Cache Maven packages
        uses: actions/cache@v3
        with:
          path: ~/.m2
          key: ${{ runner.os }}-m2-${{ hashFiles('**/pom.xml') }}
          restore-keys: ${{ runner.os }}-m2

      - name: Run tests
        working-directory: ./backend
        env:
          DB_HOST: localhost
          DB_PORT: 5432
          DB_NAME: testdb
          DB_USER: test
          DB_PASSWORD: test
          REDIS_HOST: localhost
          REDIS_PORT: 6379
        run: mvn clean test

      - name: Generate coverage report
        working-directory: ./backend
        run: mvn jacoco:report

      - name: Upload coverage to Codecov
        uses: codecov/codecov-action@v3
        with:
          file: ./backend/target/site/jacoco/jacoco.xml
          flags: backend

      - name: Build
        working-directory: ./backend
        run: mvn clean package -DskipTests

      - name: Upload artifact
        uses: actions/upload-artifact@v3
        with:
          name: backend-jar
          path: backend/target/*.jar
          retention-days: 7

  lint:
    name: Lint
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v3

      - name: Set up JDK
        uses: actions/setup-java@v3
        with:
          java-version: ${{ env.JAVA_VERSION }}
          distribution: 'temurin'

      - name: Run Checkstyle
        working-directory: ./backend
        run: mvn checkstyle:check

      - name: Run SpotBugs
        working-directory: ./backend
        run: mvn spotbugs:check

  security:
    name: Security Scan
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v3

      - name: Run Snyk Security Scan
        uses: snyk/actions/maven@master
        env:
          SNYK_TOKEN: ${{ secrets.SNYK_TOKEN }}
        with:
          command: test
          args: --file=backend/pom.xml
```

### frontend-ci.yml (프론트엔드 CI)

```yaml
name: Frontend CI

on:
  push:
    branches: [main, develop]
    paths:
      - 'frontend/**'
  pull_request:
    branches: [main, develop]
    paths:
      - 'frontend/**'

env:
  NODE_VERSION: '20'

jobs:
  test:
    name: Test
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: ${{ env.NODE_VERSION }}
          cache: 'pnpm'
          cache-dependency-path: frontend/pnpm-lock.yaml

      - name: Install pnpm
        run: npm install -g pnpm

      - name: Install dependencies
        working-directory: ./frontend
        run: pnpm install --frozen-lockfile

      - name: Run linter
        working-directory: ./frontend
        run: pnpm lint

      - name: Run type check
        working-directory: ./frontend
        run: pnpm typecheck

      - name: Run unit tests
        working-directory: ./frontend
        run: pnpm test:unit

      - name: Run E2E tests
        working-directory: ./frontend
        run: pnpm test:e2e

      - name: Build
        working-directory: ./frontend
        env:
          NUXT_PUBLIC_API_BASE_URL: https://api.example.com
        run: pnpm build

      - name: Upload build artifact
        uses: actions/upload-artifact@v3
        with:
          name: frontend-dist
          path: frontend/.output
          retention-days: 7

  lighthouse:
    name: Lighthouse CI
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v3

      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: ${{ env.NODE_VERSION }}

      - name: Install pnpm
        run: npm install -g pnpm

      - name: Install dependencies
        working-directory: ./frontend
        run: pnpm install

      - name: Build
        working-directory: ./frontend
        run: pnpm build

      - name: Run Lighthouse CI
        uses: treosh/lighthouse-ci-action@v9
        with:
          urls: |
            http://localhost:3000
          uploadArtifacts: true
```

### deploy-staging.yml (스테이징 배포)

```yaml
name: Deploy to Staging

on:
  push:
    branches: [develop]

env:
  AWS_REGION: ap-northeast-2
  ECR_REPOSITORY_BACKEND: myapp-backend
  ECR_REPOSITORY_FRONTEND: myapp-frontend
  ECS_CLUSTER: myapp-staging-cluster
  ECS_SERVICE_BACKEND: backend-staging
  ECS_SERVICE_FRONTEND: frontend-staging

jobs:
  deploy-backend:
    name: Deploy Backend to Staging
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v3

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ env.AWS_REGION }}

      - name: Login to Amazon ECR
        id: login-ecr
        uses: aws-actions/amazon-ecr-login@v1

      - name: Build and push Docker image
        env:
          ECR_REGISTRY: ${{ steps.login-ecr.outputs.registry }}
          IMAGE_TAG: staging-${{ github.sha }}
        run: |
          cd backend
          docker build -t $ECR_REGISTRY/$ECR_REPOSITORY_BACKEND:$IMAGE_TAG .
          docker tag $ECR_REGISTRY/$ECR_REPOSITORY_BACKEND:$IMAGE_TAG \
                     $ECR_REGISTRY/$ECR_REPOSITORY_BACKEND:staging-latest
          docker push $ECR_REGISTRY/$ECR_REPOSITORY_BACKEND:$IMAGE_TAG
          docker push $ECR_REGISTRY/$ECR_REPOSITORY_BACKEND:staging-latest

      - name: Deploy to ECS
        run: |
          aws ecs update-service \
            --cluster ${{ env.ECS_CLUSTER }} \
            --service ${{ env.ECS_SERVICE_BACKEND }} \
            --force-new-deployment

      - name: Wait for deployment
        run: |
          aws ecs wait services-stable \
            --cluster ${{ env.ECS_CLUSTER }} \
            --services ${{ env.ECS_SERVICE_BACKEND }}

  deploy-frontend:
    name: Deploy Frontend to Staging
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v3

      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '20'

      - name: Install pnpm
        run: npm install -g pnpm

      - name: Install dependencies
        working-directory: ./frontend
        run: pnpm install

      - name: Build
        working-directory: ./frontend
        env:
          NUXT_PUBLIC_API_BASE_URL: https://api-staging.example.com
        run: pnpm build

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ env.AWS_REGION }}

      - name: Deploy to S3
        run: |
          aws s3 sync frontend/.output/public s3://myapp-staging-frontend --delete

      - name: Invalidate CloudFront
        run: |
          aws cloudfront create-invalidation \
            --distribution-id ${{ secrets.CLOUDFRONT_DISTRIBUTION_ID_STAGING }} \
            --paths "/*"

  notify:
    name: Notify Deployment
    runs-on: ubuntu-latest
    needs: [deploy-backend, deploy-frontend]

    steps:
      - name: Send Slack notification
        uses: slackapi/slack-github-action@v1
        with:
          payload: |
            {
              "text": "Staging deployment completed!",
              "blocks": [
                {
                  "type": "section",
                  "text": {
                    "type": "mrkdwn",
                    "text": "Staging deployment completed! :rocket:\n*Commit:* ${{ github.sha }}\n*URL:* https://staging.example.com"
                  }
                }
              ]
            }
        env:
          SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}
```

### deploy-production.yml (프로덕션 배포)

```yaml
name: Deploy to Production

on:
  push:
    tags:
      - 'v*.*.*'

env:
  AWS_REGION: ap-northeast-2
  ECR_REPOSITORY_BACKEND: myapp-backend
  ECS_CLUSTER: myapp-prod-cluster
  ECS_SERVICE_BACKEND: backend-prod

jobs:
  deploy:
    name: Deploy to Production
    runs-on: ubuntu-latest
    environment:
      name: production
      url: https://example.com

    steps:
      - uses: actions/checkout@v3

      - name: Extract version
        id: version
        run: echo "VERSION=${GITHUB_REF#refs/tags/v}" >> $GITHUB_OUTPUT

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ env.AWS_REGION }}

      - name: Login to Amazon ECR
        id: login-ecr
        uses: aws-actions/amazon-ecr-login@v1

      - name: Build and push Docker image
        env:
          ECR_REGISTRY: ${{ steps.login-ecr.outputs.registry }}
          VERSION: ${{ steps.version.outputs.VERSION }}
        run: |
          cd backend
          docker build -t $ECR_REGISTRY/$ECR_REPOSITORY_BACKEND:$VERSION .
          docker tag $ECR_REGISTRY/$ECR_REPOSITORY_BACKEND:$VERSION \
                     $ECR_REGISTRY/$ECR_REPOSITORY_BACKEND:latest
          docker push $ECR_REGISTRY/$ECR_REPOSITORY_BACKEND:$VERSION
          docker push $ECR_REGISTRY/$ECR_REPOSITORY_BACKEND:latest

      - name: Deploy to ECS
        run: |
          aws ecs update-service \
            --cluster ${{ env.ECS_CLUSTER }} \
            --service ${{ env.ECS_SERVICE_BACKEND }} \
            --force-new-deployment

      - name: Wait for deployment
        run: |
          aws ecs wait services-stable \
            --cluster ${{ env.ECS_CLUSTER }} \
            --services ${{ env.ECS_SERVICE_BACKEND }}

      - name: Create GitHub Release
        uses: actions/create-release@v1
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        with:
          tag_name: ${{ github.ref }}
          release_name: Release ${{ steps.version.outputs.VERSION }}
          body: |
            Production deployment for version ${{ steps.version.outputs.VERSION }}
          draft: false
          prerelease: false

      - name: Send notification
        uses: slackapi/slack-github-action@v1
        with:
          payload: |
            {
              "text": "Production deployment completed!",
              "blocks": [
                {
                  "type": "section",
                  "text": {
                    "type": "mrkdwn",
                    "text": ":rocket: *Production deployment completed!*\n*Version:* ${{ steps.version.outputs.VERSION }}\n*URL:* https://example.com"
                  }
                }
              ]
            }
        env:
          SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}
```

## GitLab CI/CD

### .gitlab-ci.yml

```yaml
stages:
  - test
  - build
  - deploy

variables:
  DOCKER_DRIVER: overlay2
  DOCKER_TLS_CERTDIR: "/certs"
  MAVEN_OPTS: "-Dmaven.repo.local=$CI_PROJECT_DIR/.m2/repository"
  AWS_DEFAULT_REGION: ap-northeast-2

# 캐시 설정
cache:
  paths:
    - .m2/repository
    - frontend/node_modules/
    - frontend/.nuxt/

# 백엔드 테스트
backend-test:
  stage: test
  image: maven:3.9-eclipse-temurin-17
  services:
    - postgres:15-alpine
    - redis:7-alpine
  variables:
    POSTGRES_DB: testdb
    POSTGRES_USER: test
    POSTGRES_PASSWORD: test
  script:
    - cd backend
    - mvn clean test
  artifacts:
    reports:
      junit: backend/target/surefire-reports/TEST-*.xml
    paths:
      - backend/target/

# 프론트엔드 테스트
frontend-test:
  stage: test
  image: node:20-alpine
  before_script:
    - npm install -g pnpm
    - cd frontend
    - pnpm install
  script:
    - pnpm lint
    - pnpm typecheck
    - pnpm test:unit
  artifacts:
    paths:
      - frontend/.output/

# 백엔드 빌드
backend-build:
  stage: build
  image: docker:24
  services:
    - docker:24-dind
  before_script:
    - apk add --no-cache aws-cli
    - aws ecr get-login-password --region $AWS_DEFAULT_REGION | docker login --username AWS --password-stdin $ECR_REGISTRY
  script:
    - cd backend
    - docker build -t $ECR_REGISTRY/myapp-backend:$CI_COMMIT_SHA .
    - docker tag $ECR_REGISTRY/myapp-backend:$CI_COMMIT_SHA $ECR_REGISTRY/myapp-backend:latest
    - docker push $ECR_REGISTRY/myapp-backend:$CI_COMMIT_SHA
    - docker push $ECR_REGISTRY/myapp-backend:latest
  only:
    - main
    - develop

# 프론트엔드 빌드
frontend-build:
  stage: build
  image: node:20-alpine
  before_script:
    - npm install -g pnpm
    - cd frontend
    - pnpm install
  script:
    - pnpm build
  artifacts:
    paths:
      - frontend/.output/
  only:
    - main
    - develop

# 스테이징 배포
deploy-staging:
  stage: deploy
  image: amazon/aws-cli
  script:
    - aws ecs update-service --cluster myapp-staging-cluster --service backend-staging --force-new-deployment
    - aws s3 sync frontend/.output/public s3://myapp-staging-frontend --delete
  environment:
    name: staging
    url: https://staging.example.com
  only:
    - develop

# 프로덕션 배포
deploy-production:
  stage: deploy
  image: amazon/aws-cli
  script:
    - aws ecs update-service --cluster myapp-prod-cluster --service backend-prod --force-new-deployment
    - aws s3 sync frontend/.output/public s3://myapp-prod-frontend --delete
    - aws cloudfront create-invalidation --distribution-id $CLOUDFRONT_DISTRIBUTION_ID --paths "/*"
  environment:
    name: production
    url: https://example.com
  only:
    - tags
  when: manual
```

## Jenkins Pipeline

### Jenkinsfile

```groovy
pipeline {
    agent any

    environment {
        AWS_REGION = 'ap-northeast-2'
        ECR_REGISTRY = '123456789012.dkr.ecr.ap-northeast-2.amazonaws.com'
        ECR_REPOSITORY = 'myapp-backend'
        ECS_CLUSTER = 'myapp-cluster'
        ECS_SERVICE = 'backend'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Test Backend') {
            agent {
                docker {
                    image 'maven:3.9-eclipse-temurin-17'
                }
            }
            steps {
                dir('backend') {
                    sh 'mvn clean test'
                }
            }
            post {
                always {
                    junit 'backend/target/surefire-reports/*.xml'
                }
            }
        }

        stage('Test Frontend') {
            agent {
                docker {
                    image 'node:20-alpine'
                }
            }
            steps {
                dir('frontend') {
                    sh 'npm install -g pnpm'
                    sh 'pnpm install'
                    sh 'pnpm test:unit'
                }
            }
        }

        stage('Build Backend') {
            steps {
                dir('backend') {
                    sh 'mvn clean package -DskipTests'
                }
            }
        }

        stage('Build Frontend') {
            agent {
                docker {
                    image 'node:20-alpine'
                }
            }
            steps {
                dir('frontend') {
                    sh 'npm install -g pnpm'
                    sh 'pnpm install'
                    sh 'pnpm build'
                }
            }
        }

        stage('Build Docker Images') {
            steps {
                script {
                    docker.withRegistry("https://${ECR_REGISTRY}", 'ecr:ap-northeast-2:aws-credentials') {
                        def backendImage = docker.build("${ECR_REGISTRY}/${ECR_REPOSITORY}:${env.BUILD_NUMBER}", "./backend")
                        backendImage.push()
                        backendImage.push('latest')
                    }
                }
            }
        }

        stage('Deploy to ECS') {
            steps {
                withAWS(credentials: 'aws-credentials', region: "${AWS_REGION}") {
                    sh """
                        aws ecs update-service \
                          --cluster ${ECS_CLUSTER} \
                          --service ${ECS_SERVICE} \
                          --force-new-deployment
                    """
                }
            }
        }
    }

    post {
        success {
            slackSend(
                color: 'good',
                message: "Deployment successful: ${env.JOB_NAME} #${env.BUILD_NUMBER} (<${env.BUILD_URL}|Open>)"
            )
        }
        failure {
            slackSend(
                color: 'danger',
                message: "Deployment failed: ${env.JOB_NAME} #${env.BUILD_NUMBER} (<${env.BUILD_URL}|Open>)"
            )
        }
    }
}
```

## 모범 사례

### 1. 환경별 분리

- **개발(dev)**: 개발자 로컬 환경
- **스테이징(staging)**: 프로덕션과 동일한 환경에서 테스트
- **프로덕션(prod)**: 실제 사용자 환경

### 2. 시크릿 관리

```yaml
# GitHub Secrets 사용
- name: Configure AWS credentials
  uses: aws-actions/configure-aws-credentials@v2
  with:
    aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
    aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
```

### 3. 캐싱 활용

```yaml
- name: Cache Maven packages
  uses: actions/cache@v3
  with:
    path: ~/.m2
    key: ${{ runner.os }}-m2-${{ hashFiles('**/pom.xml') }}
    restore-keys: ${{ runner.os }}-m2
```

### 4. 병렬 실행

```yaml
jobs:
  test-backend:
    runs-on: ubuntu-latest
    # ...

  test-frontend:
    runs-on: ubuntu-latest
    # ...

  deploy:
    needs: [test-backend, test-frontend]
    runs-on: ubuntu-latest
    # ...
```

### 5. 롤백 전략

```yaml
- name: Rollback on failure
  if: failure()
  run: |
    aws ecs update-service \
      --cluster ${{ env.ECS_CLUSTER }} \
      --service ${{ env.ECS_SERVICE }} \
      --task-definition previous-task-definition
```

## 알림 통합

### Slack 알림

```yaml
- name: Slack Notification
  uses: slackapi/slack-github-action@v1
  with:
    payload: |
      {
        "text": "Deployment Status: ${{ job.status }}",
        "blocks": [
          {
            "type": "section",
            "text": {
              "type": "mrkdwn",
              "text": "*Deployment Status:* ${{ job.status }}\n*Commit:* ${{ github.sha }}\n*Author:* ${{ github.actor }}"
            }
          }
        ]
      }
  env:
    SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}
```

### Discord 알림

```yaml
- name: Discord Notification
  uses: sarisia/actions-status-discord@v1
  with:
    webhook: ${{ secrets.DISCORD_WEBHOOK }}
    status: ${{ job.status }}
    title: "Deployment"
    description: "Deployment to ${{ github.ref }}"
```

## 참고 자료

- [GitHub Actions 공식 문서](https://docs.github.com/en/actions)
- [GitLab CI/CD 공식 문서](https://docs.gitlab.com/ee/ci/)
- [Jenkins 공식 문서](https://www.jenkins.io/doc/)
- 관련 워크플로우: `.github/workflows/`
