---
name: sn-request-software
description: >-
  Use this skill when the user wants to request software installation (Java, IDE, Node.js, etc.) via ServiceNow.
version: 1.0.0
displayName: ServiceNow 申请软件
domain: sn
action: request
object: software
tags: [servicenow, software, apply, install]
type: SKILL
inputs:
  - name: software_name
    type: string
    required: true
    description: 软件名称
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
    description: 指定版本（可选）
---
# ServiceNow 申请软件

在 ServiceNow 提交软件安装申请，审批通过后推送到 Software Center。

## 前置条件
- 软件必须是公司 Software Center 提供的
- 如未提供，先确认软件是否在可用列表中

## 执行步骤
1. 确认申请信息：{{software_name}}，申请人 {{applicant}}，版本 {{version}}
2. 检查是否已申请过，避免重复
3. 如未申请，在 ServiceNow 提交新申请
4. 填写申请信息并提交
5. 告知用户审批流程和时间

## 约束
- 只负责 ServiceNow 申请，不负责安装
- 幂等：已申请则告知状态，不重复提交
- 审批时间：1-2 个工作日
