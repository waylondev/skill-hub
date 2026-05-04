# Phase 11: Cost Estimation & Planning

## Objective

Produce a comprehensive cost estimation covering infrastructure (cloud/on-premise), migration effort (person-hours per role), licensing, and ongoing operational costs. All placeholder values are replaced with concrete calculation formulas so the estimation can be populated once the specific project context (provider, region, scale) is known.

## Input

- Phase 1: Source Inventory — total program/COPYBOOK/BMS/JCL counts
- Phase 2: VSAM Analysis — data volume and access patterns
- Phase 5: Logic Extraction — number of programs and complexity
- Phase 6: Architecture Blueprint — target deployment topology
- Phase 7: Testing Matrix — test case volume

## Deliverables

- `11-cost-estimation/infrastructure-cost-model.xlsx` — Detailed cost breakdown
- `11-cost-estimation/effort-estimation.md` — Resource effort by phase and role
- `11-cost-estimation/total-cost-ownership.md` — 3-year TCO comparison (current vs. migrated)
- `11-cost-estimation/licensing-costs.md` — Third-party license requirements
- `11-cost-estimation/roi-analysis.md` — Return on investment calculation

## Infrastructure Cost Model

### Formula Reference

Replace the bracketed tokens in the table below using these formulas:

| Line Item | Formula | How to Populate |
|-----------|---------|-----------------|
| Compute (VMs/Containers) | `cloud_vm_cost = vCPU_count × price_per_vCPU_hour × 730h × instance_count` | Choose provider (AWS EC2 / Azure VM / GCP Compute Engine), select instance type (e.g., t3.medium), multiply by 730 hours/month |
| Compute (Kubernetes) | `k8s_cost = node_pool_cost + control_plane_cost + network_egress_cost` | Managed K8s (EKS/AKS/GKE): control plane fee + worker node VMs × 730h |
| Database (Managed) | `db_cost = (instance_cost_per_hour × 730h) + (storage_GB × storage_price_per_GB) + backup_storage_cost` | AWS RDS / Azure SQL DB / Cloud SQL — select tier matching VSAM I/O profile |
| Database (Self-managed) | `db_cost = VM_cost + license_cost + DBA_labor_fraction` | For on-premise migration: server + Oracle/DB2/MS-SQL license |
| Cache (Redis/ElastiCache) | `cache_cost = node_type_price × node_count × 730h` | Scale node type based on VSAM hot-data size × 3 (overhead) |
| Load Balancer | `lb_cost = hourly_rate × 730h + data_processed_GB × price_per_GB` | Application LB or Network LB per cloud provider pricing |
| Object Storage | `storage_cost = total_GB × price_per_GB_month + request_cost` | S3/Azure Blob/GCS for batch file archival, logs |
| Monitoring & Observability | `monitoring_cost = metrics_ingest_GB × price_per_GB + log_ingest_GB × price_per_GB + trace_spans × price_per_million` | CloudWatch/Datadog/Grafana Cloud — estimate from traffic volume |
| Network Egress | `egress_cost = estimated_monthly_GB_egress × price_per_GB` | Cross-AZ, cross-region, and internet egress |
| Total Monthly Infrastructure | `total_monthly = SUM(all_above_items)` | Sum after populating each item for the target environment |

### Monthly Infrastructure Cost Table

| Component | Service (Example) | Spec (Example) | Cost Formula |
|-----------|-------------------|----------------|-------------|
| Compute | [provider] Compute Engine | [instance_type] × [count] nodes | `[count] × [price_per_hour] × 730` |
| Database | [provider] Managed DB | [tier] with [storage_size]GB | `[price_per_hour] × 730 + [storage_GB] × [price_per_GB]` |
| Cache | [provider] Redis/ElastiCache | [node_type] × [count] | `[count] × [price_per_hour] × 730` |
| Load Balancer | [provider] ALB/NLB | [type] | `[hourly_rate] × 730` |
| Object Storage | [provider] S3/Blob/GCS | [storage_size]GB + [request_count] | `[storage_GB] × [price_per_GB] + [requests] × [price_per_1k]` |
| Monitoring | [provider] Observability | [metrics_GB/day] + [logs_GB/day] | `([metrics_GB] + [logs_GB]) × 30 × [price_per_GB]` |
| Network | [provider] Egress | [estimated_egress_GB/month] | `[egress_GB] × [price_per_GB]` |
| **Total** | | | **SUM(all rows after populating)** |

## Migration Effort Estimation

### Person-Hour Formulas Per Phase

| Phase | Role(s) | Effort Formula | Duration Formula | Notes |
|-------|---------|---------------|-----------------|-------|
| Program Analysis (Phase 1, 4, 5) | Senior COBOL Dev | `effort_h = program_count × avg_lines_per_program / lines_analyzed_per_hour` | `duration_wk = effort_h / (dev_count × 40)` | `lines_analyzed_per_hour ≈ 100-300` depending on complexity |
| Entity/Repository Design (Phase 2, 4) | Java Architect | `effort_h = copybook_count × hours_per_copybook + vsam_file_count × hours_per_file` | `duration_wk = effort_h / (arch_count × 40)` | `hours_per_copybook ≈ 2-4`, `hours_per_file ≈ 3-6` |
| Service Implementation (Phase 5 → 8, 9) | Java Developer | `effort_h = program_count × avg_complexity_factor × hours_per_program` | `duration_wk = effort_h / (dev_count × 40)` | Complexity: simple=8h, medium=16h, complex=40h |
| DTO & API Design (Phase 3, 8) | Java Developer | `effort_h = bms_screen_count × hours_per_screen` | `duration_wk = effort_h / (dev_count × 40)` | `hours_per_screen ≈ 4-6` |
| Database Migration (Phase 2, 9) | DBA | `effort_h = vsam_file_count × hours_per_vsam + table_count × hours_per_table` | `duration_wk = effort_h / (dba_count × 40)` | `hours_per_vsam ≈ 4-8`, `hours_per_table ≈ 2-4` |
| Testing (Phase 7) | QA Engineer | `effort_h = test_case_count × (avg_test_minutes / 60) + automation_script_hours` | `duration_wk = effort_h / (qa_count × 40)` | Include test data setup time × 1.3 overhead |
| Frontend Migration (Phase 10) | Frontend Developer | `effort_h = bms_screen_count × hours_per_screen_frontend` | `duration_wk = effort_h / (fe_count × 40)` | `hours_per_screen_frontend ≈ 16-40` |
| DevOps / Pipeline (Phase 12-13) | DevOps Engineer | `effort_h = pipeline_stage_count × hours_per_stage + deploy_env_count × hours_per_env` | `duration_wk = effort_h / (devops_count × 40)` | `hours_per_stage ≈ 4-8`, `hours_per_env ≈ 8-16` |
| **Total** | | `TOTAL_h = SUM(all_effort_h)` | `TOTAL_wk = MAX(phase_durations) with parallelization` | Use critical path analysis |

### Resource Estimation Table

| Phase | Resource Type | Effort Formula | Duration Formula |
|-------|--------------|----------------|-----------------|
| COBOL Program Analysis | Senior COBOL Developer | `program_count × avg_lines / 200` hours | `effort_h / (dev_count × 40)` weeks |
| Entity/Repository Design | Java Architect | `copybook_count × 3 + vsam_count × 4` hours | `effort_h / (arch_count × 40)` weeks |
| Service Implementation | Java Developer | `program_count × complexity_factor × 16` hours | `effort_h / (dev_count × 40)` weeks |
| Database Migration | DBA | `vsam_count × 6 + table_count × 3` hours | `effort_h / (dba_count × 40)` weeks |
| Testing | QA Engineer | `test_case_count × 0.5 + automation_effort` hours | `effort_h / (qa_count × 40)` weeks |
| Deployment / DevOps | DevOps Engineer | `pipeline_stages × 6 + env_count × 12` hours | `effort_h / (devops_count × 40)` weeks |
| **Total** | | **SUM(all effort)** hours | **Critical path** weeks |

## Total Cost of Ownership (3-Year)

| Cost Category | Current COBOL (Annual) | Migrated Java (Annual) | Calculation Method |
|---------------|----------------------|----------------------|-------------------|
| Mainframe / Server | `mainframe_annual_lease_or_depreciation` | `12 × monthly_infrastructure_cost` | Quote from provider + depreciation schedule |
| Software Licenses | `cobol_license + cics_license + db2_license` | `spring_none + db_license + k8s_license` | Vendor quotes (Spring Boot = $0 OSS) |
| Personnel | `cobol_dev_count × avg_salary × 1.3` | `java_dev_count × avg_salary × 1.3` | Market salary surveys × burden factor |
| Maintenance & Support | `vendor_support_contracts` | `cloud_support_plan + open_source_support` | Vendor quotes |
| Disaster Recovery | `dr_site_cost` | `multi_region_cloud_cost` | Cloud DR ≈ 20-40% of primary |
| **Annual Total** | **SUM(current)** | **SUM(migrated)** | |
| **3-Year TCO** | **3 × annual_current** | **3 × annual_migrated + one_time_migration_cost** | |

## ROI Analysis

```
one_time_migration_cost = TOTAL_h × blended_hourly_rate + tool_license_cost + training_cost
annual_savings = annual_current_cost - annual_migrated_cost
breakeven_months = (one_time_migration_cost / annual_savings) × 12
roi_3_year = ((3 × annual_savings) - one_time_migration_cost) / one_time_migration_cost × 100%
```

## Execution Steps

### Step 1: Gather Context Parameters

Collect from earlier phases:
- `program_count`, `copybook_count`, `bms_screen_count`, `vsam_file_count` (Phase 1)
- `avg_lines_per_program` (Phase 1 total lines / program count)
- `test_case_count` (Phase 7)
- `data_volume_GB` (Phase 2 — VSAM file sizes)

### Step 2: Select Cloud Provider and Region

Choose provider (AWS/Azure/GCP) and region. Pull current pricing from provider calculator for all infrastructure components.

### Step 3: Populate Infrastructure Cost Table

Fill each row using the formulas above with real pricing data from the selected provider.

### Step 4: Estimate Effort by Phase

Apply the effort formulas using program/copybook/BMS counts from Phase 1. Adjust `complexity_factor` per program based on Phase 5 analysis (1.0 = simple CRUD, 2.5 = complex multi-file orchestration).

### Step 5: Calculate TCO and ROI

Compare current mainframe operational costs against projected cloud costs. Include one-time migration cost amortized over 3 years.

### Step 6: Produce Final Estimate Document

Combine all tables into `total-cost-ownership.md` with executive summary, detailed breakdowns, and assumptions log.

## Quality Gate

- [ ] All formula placeholders replaced with actual calculation formulas, not hardcoded numbers
- [ ] Infrastructure costs sourced from current cloud provider pricing pages
- [ ] Effort estimates reviewed by senior architect and project manager
- [ ] Assumptions documented (team size, parallelization factor, hourly rates)
- [ ] Sensitivity analysis included (±20% on key variables)
- [ ] Current mainframe costs verified with IT finance or vendor invoices
- [ ] 3-year TCO includes inflation adjustment and cloud price trends
- [ ] `_state-snapshot.json` updated to `{'phase':11,'status':'complete'}`
