# SAST/DAST Security Scanning Integration

## Overview

This document defines the security scanning integration strategy for migrated COBOL-to-Java applications. It covers Static Application Security Testing (SAST), Dynamic Application Security Testing (DAST), dependency scanning, container scanning, and secret detection — all integrated into the CI/CD pipeline.

## SonarQube (SAST)

### Maven Plugin Configuration (pom.xml)

```xml
<properties>
    <sonar.projectKey>${project.groupId}:${project.artifactId}</sonar.projectKey>
    <sonar.projectName>COBOL Migration — ${project.artifactId}</sonar.projectName>
    <sonar.projectVersion>${project.version}</sonar.projectVersion>
    <sonar.host.url>${SONARQUBE_URL}</sonar.host.url>
    <sonar.login>${SONARQUBE_TOKEN}</sonar.login>
    <sonar.java.source>21</sonar.java.source>
    <sonar.java.target>21</sonar.java.target>
    <sonar.coverage.jacoco.xmlReportPaths>
        ${project.basedir}/target/site/jacoco/jacoco.xml
    </sonar.coverage.jacoco.xmlReportPaths>
    <sonar.exclusions>
        **/generated/**,
        **/dto/**/*Request.java,
        **/dto/**/*Response.java,
        **/entity/Q*.java
    </sonar.exclusions>
    <sonar.cpd.exclusions>
        **/dto/**,
        **/entity/**
    </sonar.cpd.exclusions>
</properties>

<build>
    <plugins>
        <plugin>
            <groupId>org.jacoco</groupId>
            <artifactId>jacoco-maven-plugin</artifactId>
            <version>0.8.12</version>
            <executions>
                <execution>
                    <goals>
                        <goal>prepare-agent</goal>
                    </goals>
                </execution>
                <execution>
                    <id>report</id>
                    <phase>verify</phase>
                    <goals>
                        <goal>report</goal>
                    </goals>
                </execution>
            </executions>
        </plugin>
        <plugin>
            <groupId>org.sonarsource.scanner.maven</groupId>
            <artifactId>sonar-maven-plugin</artifactId>
            <version>4.0.0.4121</version>
        </plugin>
    </plugins>
</build>
```

### Project Quality Gate Settings for Migrated Code

```yaml
# sonar-quality-gate.yaml — Applied in SonarQube UI/API
name: COBOL Migration Quality Gate
conditions:
  - metric: new_coverage
    op: LT
    error: "80"
    description: "Coverage on new code < 80%"

  - metric: new_blocker_violations
    op: GT
    error: "0"
    description: "Zero critical/blocker bugs on new code"

  - metric: new_critical_violations
    op: GT
    error: "0"

  - metric: new_duplicated_lines_density
    op: GT
    error: "3"
    description: "Code duplication < 3%"

  - metric: new_security_hotspots_reviewed
    op: LT
    error: "100"
    description: "100% of security hotspots reviewed"

  - metric: new_maintainability_rating
    op: GT
    error: "1"
    description: "Maintainability rating must be A"

  - metric: new_reliability_rating
    op: GT
    error: "1"

  - metric: new_security_rating
    op: GT
    error: "1"

  - metric: new_vulnerabilities
    op: GT
    error: "0"
    description: "Zero new vulnerabilities"
```

### CI Pipeline SonarQube Step

```yaml
# GitLab CI example
sonarqube-check:
  stage: test
  image: maven:3.9-eclipse-temurin-21
  script:
    - mvn verify org.sonarsource.scanner.maven:sonar-maven-plugin:sonar
      -Dsonar.qualitygate.wait=true
  allow_failure: false
  only:
    - merge_requests
    - main
```

## OWASP Dependency Check

### Maven Plugin Configuration (pom.xml)

```xml
<build>
    <plugins>
        <plugin>
            <groupId>org.owasp</groupId>
            <artifactId>dependency-check-maven</artifactId>
            <version>10.0.4</version>
            <configuration>
                <failBuildOnCVSS>7</failBuildOnCVSS>
                <suppressionFiles>
                    <suppressionFile>
                        ${project.basedir}/owasp-suppressions.xml
                    </suppressionFile>
                </suppressionFiles>
                <formats>
                    <format>HTML</format>
                    <format>JSON</format>
                </formats>
                <skipProvidedScope>true</skipProvidedScope>
                <skipTestScope>true</skipTestScope>
                <nvdApiKey>${NVD_API_KEY}</nvdApiKey>
            </configuration>
            <executions>
                <execution>
                    <goals>
                        <goal>check</goal>
                    </goals>
                    <phase>verify</phase>
                </execution>
            </executions>
        </plugin>
    </plugins>
</build>
```

### Suppression File for Known False Positives

```xml
<!-- owasp-suppressions.xml -->
<?xml version="1.0" encoding="UTF-8"?>
<suppressions xmlns="https://jeremylong.github.io/DependencyCheck/dependency-suppression.1.3.xsd">

    <suppress>
        <notes>
            False positive: Spring Boot Starter transitive dep.
            CVE-2024-XXXXX does not affect the bundled version.
            Reviewed by security team on 2026-05-01.
        </notes>
        <cve>CVE-2024-XXXXX</cve>
    </suppress>

    <suppress>
        <notes>
            Test-only dependency, not deployed to production.
            H2 in-memory database vulnerability.
        </notes>
        <gav regex="true">^com\.h2database:h2:.*$</gav>
        <cve>CVE-2024-YYYYY</cve>
    </suppress>

    <suppress>
        <notes>
            Jackson databind vulnerability — mitigated by
            Spring Boot's ObjectMapper hardening configuration.
            See SecurityConfig.java for details.
        </notes>
        <cve>CVE-2024-ZZZZZ</cve>
    </suppress>
</suppressions>
```

## Container Scanning (Trivy)

### Dockerfile Scanning

```dockerfile
# Dockerfile — must be scanned with Trivy
FROM eclipse-temurin:21-jre-alpine AS runtime

RUN addgroup -S cobolapp && adduser -S cobolapp -G cobolapp

COPY --chown=cobolapp:cobolapp target/*.jar /app/app.jar

USER cobolapp
EXPOSE 8080

ENTRYPOINT ["java", "-jar", "/app/app.jar"]
```

### Trivy CLI Commands

```bash
# Scan Docker image
trivy image --severity HIGH,CRITICAL cobol-inquiry-service:latest

# Scan Dockerfile before build
trivy config ./Dockerfile

# Scan filesystem
trivy fs --severity HIGH,CRITICAL ./target/

# Scan with SARIF output for CI integration
trivy image \
    --format sarif \
    --output trivy-results.sarif \
    --severity HIGH,CRITICAL \
    cobol-inquiry-service:latest

# Scan with exit code (for CI pipeline)
trivy image \
    --exit-code 1 \
    --severity HIGH,CRITICAL \
    --ignore-unfixed \
    cobol-inquiry-service:latest
```

### CI Pipeline Trivy Integration

```yaml
# GitLab CI Trivy step
container-scan:
  stage: security
  image:
    name: aquasec/trivy:latest
    entrypoint: [""]
  script:
    - trivy image --exit-code 1 --severity HIGH,CRITICAL
      --ignore-unfixed
      ${CI_REGISTRY_IMAGE}:${CI_COMMIT_SHORT_SHA}
  allow_failure: true
  only:
    - main

dependency-scan:
  stage: security
  image:
    name: aquasec/trivy:latest
    entrypoint: [""]
  script:
    - trivy fs --exit-code 1 --severity HIGH,CRITICAL
      --scanners vuln,secret,misconfig
      .
  allow_failure: true
```

## DAST: OWASP ZAP Integration

### ZAP API Scan Script Template

```bash
#!/bin/bash
# zap-api-scan.sh

TARGET_URL="${1:-http://localhost:8080}"
API_DEFINITION="${2:-./target/openapi.yaml}"
REPORT_DIR="./zap-reports"

mkdir -p "$REPORT_DIR"

echo "=== OWASP ZAP API Scan ==="
echo "Target: $TARGET_URL"
echo "API Spec: $API_DEFINITION"

docker run --rm \
    -v "$(pwd)/$API_DEFINITION:/zap/wrk/openapi.yaml:ro" \
    -v "$(pwd)/$REPORT_DIR:/zap/wrk/:rw" \
    -t ghcr.io/zaproxy/zaproxy:stable \
    zap-api-scan.py \
    -t /zap/wrk/openapi.yaml \
    -f openapi \
    -T 60 \
    -r zap-report.html \
    -x zap-report.xml \
    -w zap-report.md \
    -z "-config api.addrs.addr.name=.* -config api.addrs.addr.regex=true"
```

### Baseline Scan Configuration

```yaml
# zap-baseline-config.yaml
zap:
  context: cobol-migration
  target_url: ${TARGET_URL}
  authentication:
    method: form
    login_url: /login
    username: testuser
    password_field: password
    username_field: username
  scan_policy: cobol-migration-policy
  spider:
    max_depth: 5
    thread_count: 4
  active_scan:
    thread_per_host: 3
    max_alerts_per_rule: 5
  alerts:
    fail_on_severity: High
    max_high_alerts: 0
    max_medium_alerts: 10
```

### ZAP GitHub Actions Integration

```yaml
# .github/workflows/zap-scan.yml
name: OWASP ZAP Full Scan
on:
  schedule:
    - cron: '0 2 * * 1'  # Weekly Monday 2AM
  workflow_dispatch:

jobs:
  zap_scan:
    runs-on: ubuntu-latest
    steps:
      - name: Start target
        run: |
          docker run -d -p 8080:8080 \
            ${REGISTRY}/${IMAGE}:${TAG}

      - name: ZAP Scan
        uses: zaproxy/action-full-scan@v0.12.0
        with:
          target: 'http://localhost:8080'
          cmd_options: '-T 60 -z "-config api.addrs.addr.name=.*"'
          issue_title: 'OWASP ZAP DAST Report'
```

## Secret Detection

### GitGuardian Integration (GitLab CI)

```yaml
# .gitlab-ci.yml
gitguardian-scan:
  stage: security
  image: 
    name: gitguardian/ggshield:latest
    entrypoint: [""]
  script:
    - ggshield secret scan ci
  allow_failure: false
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"
```

### truffleHog Integration (GitHub Actions)

```yaml
# .github/workflows/secrets-scan.yml
name: Secret Detection
on: [push, pull_request]

jobs:
  trufflehog:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - name: truffleHog Scan
        uses: trufflesecurity/trufflehog@main
        with:
          path: ./
          base: ${{ github.event.before }}
          head: ${{ github.sha }}
          extra_args: --only-verified
```

## Spring Boot Security Hardening Checklist

### Actuator Security

```yaml
# application-prod.yml
management:
  endpoints:
    web:
      exposure:
        include: health,info,prometheus
      base-path: /manage
  endpoint:
    health:
      show-details: when-authorized
      roles: MONITORING
  server:
    port: 8081
```

### Spring Boot Security Hardening Checklist

| # | Check | Configuration |
|---|-------|--------------|
| 1 | Disable shutdown endpoint | Exclude `shutdown` from `management.endpoints.web.exposure.exclude` |
| 2 | Secure actuator endpoints | `management.endpoint.health.roles: MONITORING` |
| 3 | HTTPS enforced | `server.ssl.enabled: true` |
| 4 | CSRF configured | `.csrf(CsrfConfigurer::disable)` for APIs + token-based |
| 5 | CORS restricted | `.cors(cors -> cors.configurationSource(corsConfig()))` |
| 6 | CSP headers | `.headers(h -> h.contentSecurityPolicy(...))` |
| 7 | XSS protection | `.headers(h -> h.xssProtection(...))` |
| 8 | HSTS configured | `.headers(h -> h.httpStrictTransportSecurity(...))` |
| 9 | Request size limits | `server.tomcat.max-http-form-post-size: 10MB` |
| 10 | Session fixation protection | `.sessionManagement(s -> s.sessionFixation().migrateSession())` |
| 11 | Secure cookies | `server.servlet.session.cookie.secure: true` |
| 12 | HttpOnly cookies | `server.servlet.session.cookie.http-only: true` |
| 13 | SameSite cookies | `server.servlet.session.cookie.same-site: strict` |
| 14 | Error handling — no stack traces | Custom `ErrorController` |
| 15 | Rate limiting | Bucket4j / Resilience4j RateLimiter |

### Security Hardening Implementation

```java
@Configuration
public class SecurityHardeningConfig {

    @Bean
    public SecurityFilterChain hardened(HttpSecurity http) throws Exception {
        http
            .headers(headers -> headers
                .xssProtection(xss -> xss.headerValue(XXssProtectionHeaderWriter
                    .HeaderValue.ENABLED_MODE_BLOCK))
                .contentSecurityPolicy(csp -> csp
                    .policyDirectives("default-src 'self'; script-src 'self'"))
                .httpStrictTransportSecurity(hsts -> hsts
                    .includeSubDomains(true)
                    .maxAgeInSeconds(31536000))
                .frameOptions(frame -> frame.deny())
            )
            .sessionManagement(session -> session
                .sessionFixation(SessionFixationConfigurer::migrateSession)
                .maximumSessions(1)
            );
        return http.build();
    }

    @Bean
    public CorsConfigurationSource corsConfig() {
        CorsConfiguration config = new CorsConfiguration();
        config.setAllowedOrigins(List.of("${ALLOWED_ORIGIN}"));
        config.setAllowedMethods(List.of("GET", "POST", "PUT", "DELETE"));
        config.setAllowedHeaders(List.of("Authorization", "Content-Type"));
        config.setAllowCredentials(true);

        UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
        source.registerCorsConfiguration("/api/**", config);
        return source;
    }
}
```

## Application Security Hardening (application.yml)

```yaml
server:
  port: 8443
  ssl:
    enabled: true
    key-store: classpath:keystore.p12
    key-store-password: ${SSL_KEYSTORE_PASSWORD}
    key-store-type: PKCS12
    key-alias: cobol-migration
  servlet:
    session:
      cookie:
        secure: true
        http-only: true
        same-site: strict
  tomcat:
    max-http-form-post-size: 10MB
    max-swallow-size: 2MB

spring:
  security:
    user:
      name: ${ACTUATOR_USER}
      password: ${ACTUATOR_PASSWORD}
      roles: MONITORING

app:
  security:
    rate-limit:
      enabled: true
      requests-per-second: 100
      burst: 200
```

## Complete CI/CD Security Pipeline (pom.xml Integration Summary)

```xml
<profiles>
    <profile>
        <id>security-scan</id>
        <build>
            <plugins>
                <!-- OWASP Dependency Check -->
                <plugin>
                    <groupId>org.owasp</groupId>
                    <artifactId>dependency-check-maven</artifactId>
                    <version>10.0.4</version>
                </plugin>
                <!-- JaCoCo for SonarQube -->
                <plugin>
                    <groupId>org.jacoco</groupId>
                    <artifactId>jacoco-maven-plugin</artifactId>
                    <version>0.8.12</version>
                </plugin>
                <!-- SonarQube Scanner -->
                <plugin>
                    <groupId>org.sonarsource.scanner.maven</groupId>
                    <artifactId>sonar-maven-plugin</artifactId>
                    <version>4.0.0.4121</version>
                </plugin>
                <!-- SpotBugs (额外的SAST) -->
                <plugin>
                    <groupId>com.github.spotbugs</groupId>
                    <artifactId>spotbugs-maven-plugin</artifactId>
                    <version>4.8.6.0</version>
                </plugin>
                <!-- PMD -->
                <plugin>
                    <groupId>org.apache.maven.plugins</groupId>
                    <artifactId>maven-pmd-plugin</artifactId>
                    <version>3.24.0</version>
                </plugin>
            </plugins>
        </build>
    </profile>
</profiles>
```

### Security Scan Maven Command

```bash
mvn clean verify \
    -Psecurity-scan \
    -Dsonar.qualitygate.wait=true \
    dependency-check:check \
    sonar:sonar
```

## Integration Notes

- Referenced by: quality-checklist.md checks 1-30 (security ci checks), SKILL.md Phase 13 (Security Audit), SKILL.md Stage 3 Phase 10e (Security deliverable), racf-spring-security-mapping.md (RACF equivalents)
- Last reviewed: 2026-05-04
