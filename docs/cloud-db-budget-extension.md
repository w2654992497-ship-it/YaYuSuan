# 云数据库预算与账单扩展说明

## 当前问题

“我的”页预算卡片依赖本地 `budget_rules` 和本地账单计算。如果删除应用后重新登录，云端恢复的数据必须满足两个条件：

1. `CloudUserDataBundle.budgetJson` 能恢复预算规则。
2. `CloudBill` 能恢复账单的分类 ID，否则分类预算只能靠分类名称兜底，分类改名或重建后容易统计失败。

本次已补齐 `CloudBill.categoryLocalId`，恢复账单时优先通过云端分类 ID 映射本地分类，再按分类名称兜底。

## 已扩展的数据

### CloudBill

新增字段：

```text
categoryLocalId Long
```

用途：

- 上传账单时记录本地 `bills.categoryId`。
- 云端恢复时通过 `CloudCategory.localId -> 本地 categories.id` 的映射恢复 `bills.categoryId`。
- 预算统计优先用 `categoryId`，分类名称只作为兜底。

新增索引：

```text
idxBillUserCategoryId(accountId, userId, bookId, categoryLocalId)
```

用途：

- 后续按用户、账本、分类追踪账单和预算统计。

### CloudUserDataBundle

当前已承载：

```text
bookJson
categoryJson
accountJson
budgetJson
periodRuleJson
```

`budgetJson` 继续保存新版 `BudgetRule[]`，不再依赖旧 `CloudBudget` 单表作为主预算来源。

## 已优化的本地接口

### AppDataApi

预算相关写入统一刷新：

```text
upsertCategoryBudget()
deleteBudgetByCategoryId()
saveBudgetRule()
setBudgetRuleEnabled()
deleteBudgetRule()
restoreCloudToLocal()
```

这些接口会同时更新：

```text
appDataVersion
budgetVersion
```

这样“我的”页、预算页、统计页后续只要监听版本号，就能在保存、删除、云端恢复后刷新预算卡片。

## 还建议继续增加的接口

### 预算查询接口

建议保留在 `AppDataApi` 层，页面不要直接碰 DAO：

```text
queryBudgetOverview(periodType)
queryBudgetRuleUsages()
queryBudgetRules()
checkBudgetRuleConflict(rule)
checkBudgetRuleOverflow(rule)
```

后续可以继续增加：

```text
queryBudgetOverviewByMonth(month)
queryBudgetOverviewByYear(year)
queryBudgetCategoryCoverage(month)
```

这样统计页年度/月度预算展示不会和“我的”页各算一套。

### 云端同步接口

当前是全量同步：

```text
syncCloud()
restoreCloudToLocal()
```

后续可以增加：

```text
syncBudgetBundleOnly()
syncBillOnly()
restoreBudgetOnly()
```

目的不是现在立刻拆分，而是减少后续每次改预算都上传整套数据的压力。

## 需要重新部署的云端对象类型

本次需要重新部署：

```text
CloudBill.json
```

原因：

- 新增 `categoryLocalId` 字段。
- 新增 `idxBillUserCategoryId` 索引。

部署后需要确认应用侧模型包含：

```text
CloudBill.categoryLocalId
```

如果 IDE 重新生成模型，会覆盖手工改动，需要确认 `CloudBill.ts` 中仍有该字段。

## 预算卡片显示规则

“我的”页本月预算卡片读取新版预算规则：

```text
totalFen    当前月预算
usedFen     当前月已用
remainFen   当前月剩余
percent     当前月进度
```

“已设置 x/y 个分类”含义：

```text
x = 当前月分类预算规则覆盖的去重分类数
y = 当前用户当前账本下支出分类总数
```

总预算规则会影响预算金额和进度，但不会计入“已设置分类数”。
