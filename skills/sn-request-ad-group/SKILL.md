---
name: sn-request-ad-group
description: >-
  Use this skill when the user wants to request access to Active Directory security groups or distribution groups via ServiceNow.
version: 1.0.0
displayName: ServiceNow 申请 AD 组权限
domain: sn
action: request
object: ad-group
tags: [servicenow, ad, active-directory, permission, group]
type: SKILL
inputs:
  - name: group_name
    type: string
    required: true
    description: AD 组名称
  - name: applicant
    type: string
    required: true
    description: 申请人姓名或工号
  - name: reason
    type: string
    required: true
    description: 申请理由
  - name: business_justification
    type: string
    required: false
    description: 业务必要性说明（可选）
---
# ServiceNow 申请 AD 组权限

在 ServiceNow 提交申请，加入指定的 Active Directory 组。

## 前置条件
- 知道要申请的 AD 组名称
- 敏感组（如 prod-*）需要额外的业务必要性说明

## 执行步骤
1. 确认申请信息：AD 组 {{group_name}}，申请人 {{applicant}}
2. 检查用户是否已在组中
3. 如未在组中，在 ServiceNow 提交新申请
4. 填写申请信息和业务必要性
5. 告知用户审批流程和生效时间

## 约束
- 只负责 ServiceNow 申请，不直接修改 AD
- 幂等：已在组中则告知，不重复申请
- 审批链：部门经理 → IT 安全组
- 生效时间：批准后 15 分钟内
