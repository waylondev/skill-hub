---
name: cobol-modernization
version: 2.0.0
description: >
  COBOL 遗留系统现代化迁移技能，支持大规模生产代码分析、增量处理、
  调用图构建、方言适配、动态调用处理、自动化回归测试及安全合规检查。
---

# COBOL 现代化技能（cobol-modernization）

## 概述

本技能用于将 COBOL 程序、Copybook、批处理作业、在线事务等遗留资产迁移至现代 Java 技术栈。技能覆盖从源码解析、架构设计、代码生成到生产部署的完整生命周期，并针对大体量生产项目提供了增量分析、并行处理、断点续传等企业级能力。

## 适用场景

- 大型主机 COBOL 应用的全面迁移
- 增量式现代化（逐步替换模块）
- 多方言 COBOL 源码的统一分析
- 需要严格回归测试和安全合规的金融、保险等领域

## 前置条件

- 提供 COBOL 源码的编码格式（EBCDIC/ASCII）及记录长度
- 明确目标方言（IBM Enterprise COBOL、Micro Focus、GnuCOBOL 等）
- 准备可执行的测试用例或输入/输出对（用于回归验证）

## 技能版本

当前版本：2.0.0（详见 CHANGELOG.md）

## 阶段流程

技能按以下阶段顺序执行，每个阶段对应一个独立的指导文件（位于 `phases/` 目录）：

1. **Copybook 解析与转换** (`04-copybook.md`)  
   解析 COPY 语句，展开嵌套，生成 Java DTO 或记录类。

2. **业务逻辑迁移** (`05-logic.md`)  
   将 PROCEDURE DIVISION 转换为 Spring Service 或领域逻辑。

3. **目标架构设计** (`06-architecture.md`)  
   定义微服务拆分、通信方式、数据存储策略。

4. **交付物清单** (`08-deliverables.md`)  
   明确迁移产出的代码、配置、文档等。

5. **代码生成** (`09-codegen.md`)  
   基于中间表示生成 Java 代码、SQL 脚本等。

6. **DTO 规范** (`10-dto-specification.md`)  
   统一数据传输对象的命名、结构、校验规则。

7. **前端迁移** (`10-frontend-migration.md`)  
   处理 CICS BMS、SDF II 等屏幕定义到 Web 前端的转换。

8. **数据库迁移（Flyway）** (`11-flyway-migration.md`)  
   管理数据库版本，生成迁移脚本。

9. **CI/CD 流水线** (`12-cicd-pipeline.md`)  
   构建、测试、部署的自动化流水线定义。

10. **OpenAPI 规范** (`12-openapi.md`)  
    为生成的 REST API 编写 OpenAPI 文档。

11. **容器化与编排** (`13-docker-kubernetes.md`)  
    Docker 镜像构建及 Kubernetes 部署配置。

12. **安全审计** (`13-security-audit.md`)  
    源码安全扫描、敏感数据识别、许可证检查。

13. **批处理依赖分析** (`14-batch-deps.md`)  
    分析 JCL/PROC 中的作业依赖关系。

14. **开发者入职** (`14-developer-onboarding.md`)  
    新成员环境搭建、代码结构导航。

15. **消息队列目录** (`15-mq-catalog.md`)  
    梳理 MQ 队列、通道、消息格式。

16. **工具链实用程序** (`16-toolchain-utilities.md`)  
    辅助脚本、格式转换、编码处理工具。

17. **生产合规** (`17-production-compliance.md`)  
    确保迁移后系统满足运维、监控、审计要求。

18. **数据迁移策略** (`18-data-migration-strategy.md`)  
    历史数据清洗、转换、校验方案。

19. **回归测试** (`19-regression-testing.md`)  
    自动化回归测试框架与用例生成。

20. **性能基准测试** (`20-performance-benchmarking.md`)  
    迁移前后性能对比与调优建议。

21. **代码审查协议** (`cp-review-protocol.md`)  
    审查清单、评审流程、质量门禁。

## 增强功能（v2.0 新增）

### 增量分析与变更检测
- 基于 Git diff 或文件时间戳，仅分析变更的程序。
- 维护分析结果缓存，避免重复处理。

### 调用图与依赖分析
- 构建程序间调用图（CALL、LINK、XCTL）。
- 识别 Copybook 包含关系，生成依赖矩阵。
- 支持循环依赖检测与报告。

### 方言适配层
- 提供 COBOL 方言配置文件，声明关键字、内建函数、编译指令差异。
- 内置 IBM Enterprise COBOL、Micro Focus、GnuCOBOL 等预设。

### 动态调用处理策略
- 静态分析可解析的调用（常量 CALL）。
- 对动态调用提供桩代码生成或人工标注接口。

### 自动化回归测试框架
- 基于输入/输出对生成迁移前后的测试用例。
- 集成到 CI 流水线，确保行为一致。

### 安全与合规检查
- 扫描源码中的敏感字段（如 SSN、账号）。
- 生成数据流图，标记敏感数据路径。
- 检查第三方库许可证兼容性。

### 并行与分布式处理
- 支持按子系统/程序拆分任务，并行分析。
- 提供资源预估模型（CPU/内存/时间）。

### 断点续传与错误恢复
- 分析状态持久化，支持中断后从检查点继续。
- 错误隔离：单个程序失败不影响整体流程。

### 输入格式标准化
- 明确支持的编码（EBCDIC/ASCII）、记录长度、行号区域。
- 提供预处理工具（如 `iconv`、`cobol-formatter`）。

### 输出质量度量
- 定义迁移后代码的 KPI：编译通过率、测试覆盖率、圈复杂度变化。
- 生成质量报告并与基线对比。

## 参考文档

以下参考文档位于 `references/` 目录，提供详细的技术映射和最佳实践：

- `assembler-replacement.md`：汇编代码替换指南
- `cobol-intrinsic-functions.md`：COBOL 内建函数映射
- `cobol-to-java-mappings.md`：COBOL 到 Java 的类型/语句映射
- `complex-copybook-guide.md`：复杂 Copybook 处理
- `ebcdic-conversion-toolchain.md`：EBCDIC 转换工具链
- `golden-examples.md`：黄金示例
- `observability-standards.md`：可观测性标准
- `production-patterns.md`：生产模式
- `quality-checklist.md`：质量检查清单

## 使用方式

1. 配置方言和输入格式（参见 `phases/04-copybook.md` 中的预处理步骤）。
2. 运行增量分析，生成调用图和依赖矩阵。
3. 按阶段顺序执行迁移，每个阶段输出中间产物供下一阶段使用。
4. 在关键阶段后运行自动化回归测试，验证正确性。
5. 最终通过 CI/CD 流水线部署至目标环境。

## 限制与注意事项

- 对于极度复杂的嵌套 Copybook（深度 > 20），建议人工拆分。
- 动态调用无法完全自动解析，需结合运行时追踪或人工标注。
- 迁移后的性能需通过基准测试验证，必要时进行调优。
- 敏感数据在分析过程中应使用脱敏环境或加密存储。

## 版本历史

- 2.0.0：新增增量分析、调用图、方言支持、动态调用处理、回归测试、安全扫描、并行处理、断点续传、输入标准化、质量度量。
- 1.0.0：初始版本，覆盖基本迁移阶段。
