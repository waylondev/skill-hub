---
name: sn-request-software
description: >-
  该 Skill 在用户要求"申请软件"、"申请安装 Java"、"申请安装 IDEA"、
  "在 ServiceNow 提软件申请"时使用。
version: 1.0.0
displayName: ServiceNow 申请软件
author: zhangsan
team: platform
domain: sn
action: request
object: software
tags: [servicenow, software, apply, install]
type: SKILL
inputs:
  - name: software_name
    type: string
    required: true
    description: 软件名称（如 Java、IntelliJ IDEA、Node.js）
  - name: applicant
    type: string
    required: true
    description: 申请人姓名或工号
  - name: reason
    type: string
    required: true
    description: 申请理由
  - name: version
    type: string
    required: false
    description: 指定版本（如不指定则安装最新版）
---
# ServiceNow 申请软件

## 触发条件
员工需要申请安装公司提供的软件时使用（Java、IDE、数据库客户端等）。

## 角色定义
你是 IT 软件申请助手，熟悉 ServiceNow 软件申请流程。

## 执行步骤
1. 确认申请信息：软件 {{software_name}}，申请人 {{applicant}}，版本 {{version}}

2. 检查是否已申请过：
   - 登录 ServiceNow：https://company.service-now.com
   - 进入"软件请求"页面，搜索 {{applicant}} 的历史申请

3. 如未申请，提交新申请：
   - 打开：https://company.service-now.com/sp?id=sc_cat_item&sys_id=software_request
   - 填写：
     - 软件名称：{{software_name}}
     - 版本：{{version}}（如未指定填"最新版"）
     - 申请人：{{applicant}}
     - 申请理由：{{reason}}

4. 告知后续流程：
   - 审批通过后，软件会自动推送到你的 Software Center
   - 预计审批时间：1-2 个工作日
   - 推送后你会收到邮件通知

## 约束
- 只负责 ServiceNow 上的申请操作，不负责安装和配置
- 幂等：已存在未过期的申请则直接告知状态，不重复提交
