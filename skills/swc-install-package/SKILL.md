---
name: swc-install-package
description: >-
  在 Software Center 安装已审批通过的软件包。
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

在 Software Center 中安装已审批通过的软件包。

## 前置条件
- 软件必须已在 ServiceNow 审批通过
- 软件必须已推送到 Software Center
- 如未审批，先使用 sn-request-software 提交申请

## 执行步骤
1. 确认软件名称：{{package_name}}
2. 打开 Software Center
3. 搜索 {{package_name}}
4. 点击"安装"
5. 等待安装完成，确认状态为"已安装"

## 约束
- 只负责 Software Center 安装，不负责申请
- 不负责环境变量配置（使用 env-configure-*）
- 幂等：已安装则告知
