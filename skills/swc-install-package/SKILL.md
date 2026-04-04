---
name: swc-install-package
description: >-
  该 Skill 在用户要求"安装软件"、"在 Software Center 安装"、
  "安装已审批的软件"时使用。
version: 1.0.0
displayName: Software Center 安装软件
domain: swc
action: install
object: package
tags: [software-center, install, package]
type: SKILL
inputs:
  - name: package_name
    type: string
    required: true
    description: 软件包名称
---
# Software Center 安装软件

## 触发条件
软件已在 ServiceNow 审批通过并推送到 Software Center，需要执行安装时使用。

## 前置条件
- 软件必须已在 ServiceNow 审批通过
- 如未审批，先使用 sn-request-software 提交申请

## 执行步骤
1. 确认软件名称：{{package_name}}

2. 打开 Software Center：
   - Windows：开始菜单搜索"Software Center"
   - macOS：从 Self Service 应用打开

3. 搜索 {{package_name}}，点击"安装"

4. 等待安装完成，确认状态显示"已安装"

## 约束
- 只负责 Software Center 上的安装操作
- 不负责环境变量配置（使用 env-configure-* 系列 Skill）
- 幂等：已安装则直接告知
