# Phase 12: CI/CD Pipeline

## Objective

Define and configure a complete CI/CD pipeline that automates build, test, quality analysis, packaging, containerization, and deployment of the migrated Java application. The pipeline must support both Jenkins (for organizations with existing Jenkins infrastructure) and GitHub Actions (for greenfield or GitHub-hosted projects).

## Input

- Phase 8: Deliverable Specifications (Maven project structure, test categories)
- Phase 9: Generated Code (source tree layout)
- Phase 10: Frontend Migration (if applicable — Node.js build stage)
- Phase 13: Docker & Kubernetes Deployment (container build targets)

## Deliverables

- `12-cicd-pipeline/Jenkinsfile` — Declarative pipeline for Jenkins
- `12-cicd-pipeline/github-actions.yml` — Workflow for GitHub Actions
- `12-cicd-pipeline/pipeline-config.md` — Configuration reference (secrets, environment variables)
- `12-cicd-pipeline/sonarqube-config.md` — SonarQube quality gate configuration

## Jenkinsfile (Declarative Pipeline)

```groovy
pipeline {
    agent any
    stages {
        stage('Checkout') { steps { checkout scm } }
        stage('Build') { steps { sh 'mvn clean compile' } }
        stage('Test') { steps { sh 'mvn test' } }
        stage('Verify') { steps { sh 'mvn verify -Pintegration' } }
        stage('SonarQube') { steps { sh 'mvn sonar:sonar' } }
        stage('Package') { steps { sh 'mvn package -DskipTests' } }
        stage('Docker Build & Push') { /* docker build + push */ }
        stage('Deploy to Dev') { /* kubectl/k8s deploy */ }
        stage('Integration Tests') { /* run integration suite */ }
        stage('Deploy to Staging') { /* with approval */ }
        stage('Performance Tests') { /* JMeter/Gatling */ }
    }
}
```

## GitHub Actions

```yaml
name: CI/CD Pipeline
on: [push, pull_request]
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Set up JDK 21
        uses: actions/setup-java@v4
        with:
          java-version: '21'
          distribution: 'temurin'
      - name: Build & Test
        run: mvn clean verify
      - name: SonarQube
        run: mvn sonar:sonar -Dsonar.host.url=${{ secrets.SONAR_URL }} -Dsonar.token=${{ secrets.SONAR_TOKEN }}
      - name: Build Docker Image
        run: docker build -t ${{ secrets.REGISTRY }}/app:${{ github.sha }} .
      - name: Push Docker Image
        run: docker push ${{ secrets.REGISTRY }}/app:${{ github.sha }}
```

## Pipeline Architecture

### Stage Sequence

```
Checkout → Build → Unit Tests → Integration Tests → SonarQube Analysis
    ↓
Package (skip tests — already run) → Docker Build → Push to Registry
    ↓
Deploy to DEV → Smoke Tests → [Approval Gate]
    ↓
Deploy to STAGING → Integration Tests → Performance Tests (JMeter/Gatling)
    ↓
[Manual Approval] → Deploy to PRODUCTION → Health Check → Rollback if needed
```

### Environment Strategy

| Environment | Purpose | Deployment Trigger | Approval |
|-------------|---------|-------------------|----------|
| DEV | Developer testing, quick iteration | Every push to `develop` | None |
| STAGING | Pre-production validation, UAT | PR merge to `main` | Auto |
| PRODUCTION | Live traffic | Manual trigger from `main` | Required (2 approvers) |

## Execution Steps

### Step 1: Create Jenkinsfile

Write the declarative Jenkinsfile to `12-cicd-pipeline/Jenkinsfile` using the pipeline code above. Expand Docker Build, Push, and deployment stages with organization-specific registry URLs and kubeconfig paths.

### Step 2: Create GitHub Actions Workflow

Write the workflow YAML to `12-cicd-pipeline/github-actions.yml` and copy to `.github/workflows/ci-cd.yml` in the generated project root.

### Step 3: Configure Secrets

Document all required secrets in `pipeline-config.md`:
- `SONAR_URL`, `SONAR_TOKEN`
- `REGISTRY` (Docker registry URL)
- `REGISTRY_USERNAME`, `REGISTRY_PASSWORD`
- `KUBECONFIG_BASE64` (for K8s deployment)
- `DB_PASSWORD` (for integration tests)

### Step 4: Configure SonarQube Quality Gate

Document quality gate thresholds in `sonarqube-config.md`:
- Code coverage ≥ 80%
- Duplicated lines ≤ 3%
- Maintainability Rating = A
- Security Rating = A
- No blocker/critical issues

### Step 5: Validate Pipeline

Run the pipeline end-to-end in the DEV environment. Verify all stages pass: Checkout → Build → Test → SonarQube → Package → Docker → Deploy DEV.

## Quality Gate

- [ ] Jenkinsfile or GitHub Actions workflow committed to repository
- [ ] All stages defined: Checkout, Build, Test, Verify, SonarQube, Package, Docker, Deploy
- [ ] Environment-specific configuration separated (DEV/STAGING/PROD)
- [ ] Docker image tagged with commit SHA for traceability
- [ ] SonarQube quality gate configured with coverage and security thresholds
- [ ] Integration tests run against deployed DEV environment
- [ ] Production deployment requires manual approval
- [ ] Rollback mechanism documented (kubectl rollout undo / previous Docker tag)
- [ ] All secrets stored in pipeline credential manager (not in source code)
- [ ] `_state-snapshot.json` updated to `{'phase':12,'status':'complete'}`
