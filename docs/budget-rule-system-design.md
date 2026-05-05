# 小金鱼预算规则系统实施方案

## 目标

预算从“给每个分类填一个月预算”升级为“预算规则系统”。用户创建一条预算规则，选择预算范围、统计周期和金额，系统根据账单动态计算预算进度。

V1 完成：

- 规则创建、编辑、停用、删除和列表展示。
- 总预算和多分类预算。
- 按日、按月、按年三种主统计周期。
- 同周期总预算唯一、同周期同分类唯一。
- 分类预算合计超过总预算时只提醒，不强制拦截。
- 本地旧 `budgets` 迁移到 `budget_rules`。
- 新账单写入 `categoryId`，旧账单按分类名称回填。
- 云端继续通过 `CloudUserDataBundle.budgetJson` 同步 `BudgetRule[]`。

## 数据结构

新增 `budget_rules` 表：

```text
id TEXT PRIMARY KEY
userId INTEGER NOT NULL
bookId INTEGER NOT NULL
name TEXT NOT NULL
periodType TEXT NOT NULL
scopeType TEXT NOT NULL
amount INTEGER NOT NULL
categoryIdsJson TEXT DEFAULT ''
categoryNamesJson TEXT DEFAULT ''
dateMode TEXT DEFAULT 'current'
periodValue TEXT DEFAULT ''
startDay INTEGER DEFAULT 1
endDay INTEGER DEFAULT 31
compareMode TEXT DEFAULT 'previous'
status TEXT DEFAULT 'active'
enabled INTEGER NOT NULL DEFAULT 1
createdAt INTEGER NOT NULL
updatedAt INTEGER NOT NULL
deleted INTEGER NOT NULL DEFAULT 0
```

`bills` 新增：

```text
categoryId INTEGER NOT NULL DEFAULT 0
```

金额统一按“分”存整数。

## 规则

- 同一用户、同一账本、同一周期只能有一条总预算。
- 同一用户、同一账本、同一周期下，同一个分类只能属于一条分类预算。
- 跨周期预算允许共存。
- 预算统计优先使用 `categoryId`，旧数据 `categoryId=0` 时用分类名称兜底。
- 云端失败不能阻塞本地保存和本地显示。

## 恢复与同步

登录恢复顺序：

1. 用户与账本。
2. 分类。
3. 预算规则。
4. 账单。
5. 刷新分类缓存和预算概览。

保存预算时先写本地，再异步同步云端。云端失败只记录日志和提示。

## 统计页预算生效规则

- 月度统计只读取所选月份实际生效的月度预算规则。
- `dateMode=current` 的月度预算只代表真实当前月，不会套用到上个月或其他历史月份。
- `dateMode=fixed` 的月度预算只在 `periodValue=YYYY-MM` 对应月份生效。
- 年度统计优先读取所选年份实际生效的年度预算规则。
- 如果没有年度预算规则，则按该年 1-12 月内实际生效的月度预算逐月合计。
- 年度月度预算合计只计算有预算规则的月份，避免没有设置预算的月份被错误算入预算进度。
- 如果所选年份既没有年度预算，也没有任何生效月度预算，统计页预算进度显示“未设置”。

## 云数据库重新部署提醒

本次统计页改造不新增 AGC 对象类型字段，仍然通过 `CloudUserDataBundle.budgetJson` 存储新版 `BudgetRule[]`。需要确认平台对象类型已经包含：

```text
CloudUserDataBundle.budgetJson  Text
CloudUserDataBundle.categoryJson Text
CloudUserDataBundle.billJson     Text
CloudUserDataBundle.periodRuleJson Text
```

如果 AGC 平台当前对象类型缺少 `budgetJson`，或之前部署的 `CloudUserDataBundle` 不是最新版本，需要重新部署云数据库对象类型后再测试登录恢复和预算同步。

本地数据库需要确认已经执行迁移：

```text
budget_rules 表已创建
bills.categoryId 字段已存在
旧 budgets 已迁移为 budget_rules
旧 bills 已按分类名称尽量回填 categoryId
```

## 页面交互

- “我的”页展示当前周期预算概览。
- “预算设置”页展示总览、规则列表和新增按钮。
- “新建 / 编辑预算规则”使用独立表单视图。
- 预算范围和分类选择用底部选择层。
- 删除和停用使用确认交互。

## 测试场景

- 删除应用后登录，云端恢复分类、预算规则、账单。
- 云端 `1008231001` 不影响本地预算显示。
- 新用户创建“本月总预算”。
- 重复总预算被阻止。
- 同周期同分类重复绑定被阻止。
- 分类预算合计超过总预算时可继续保存。
- 旧 `budgets` 正确迁移为月度分类预算规则。
- 用户 A 和用户 B 的分类、预算、账单互不串数据。
