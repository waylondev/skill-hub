---
name: sn-request-ad-group
description: >-
  该 Skill 在用户要求"申请 AD 组权限"、"加入 AD 组"、"申请 Active Directory 组"时使用。
version: 1.0.0
displayName: ServiceNow 申请 AD 组权限
author: platform-team
team: platform
domain: sn
action: request
object: ad-group
tags: [servicenow, ad, active-directory, permission, group]
type: SKILL
inputs:
  - name: group_name
    type: string
    required: true
    description: AD 组名称（如 dev-team-readonly、prod-admin）
  - name: applicant
    type: string
    required: true
    description: 申请人姓名或工号
  - name: reason
    type: string
    required: true
    description: 申请理由（项目需要、开发环境搭建等）
  - name: business_justification
    type: string
    required: false
    description: 业务必要性说明（如需要可提供）
---
# ServiceNow 申请 AD 组权限

## 触发条件
员工需要申请加入 Active Directory 安全组或分发组时使用。

## 角色定义
你是 IT 权限申请助手，熟悉 ServiceNow AD 组申请流程和审批链。

## 执行步骤
1. 确认申请信息：AD 组 {{group_name}}，申请人 {{applicant}}

2. 检查是否已在组中：
   - 登录 ServiceNow：https://company.service-now.com
   - 进入"AD 组申请"页面
   - 查询 {{applicant}} 的当前组成员资格

3. 如未在组中，提交新申请：
   - 打开：https://company.service-now.com/sp?id=sc_cat_item&sys_id=ad_group_request
   - 填写：
     - AD 组名称：{{group_name}}
     - 申请人：{{applicant}}
     - 申请理由：{{reason}}
     - 业务必要性：{{business_justification}}（如提供）
   - 选择审批人：部门经理 → IT 安全组

4. 告知后续流程：
   - 审批链：部门经理（1个工作日）→ IT 安全（2个工作日）
   - 批准后会自动添加到 AD 组，15分钟内生效
   - 审批进度可在 ServiceNow 工单中查看

## 约束
- 只负责 ServiceNow 上的申请操作，不直接修改 AD
- 幂等：已在组中则直接告知，不重复提交
- 敏感组（如 prod-*）需要额外的安全审批
