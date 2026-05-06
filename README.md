# 小金鱼记账项目文档

## 1. 项目概述

小金鱼记账是一款基于 HarmonyOS / ArkTS / ArkUI 开发的个人记账应用。项目当前实现了本地账号、账单记录、账单查询、账单日历、统计分析、分类管理、预算管理、周期记账、支付账户管理、CSV/JSON 数据导出以及云数据库同步检查等能力。

本文档只描述当前代码中已经实现的页面、数据结构和功能入口，不包含未落地的规划功能。

## 2. 工程组成

项目根目录包含两个主要工程：

| 目录            | 说明                                                         |
| --------------- | ------------------------------------------------------------ |
| `Application/`  | HarmonyOS 应用主体工程，包含 ArkTS 页面、组件、数据层、服务层和资源文件。 |
| `CloudProgram/` | 云侧配置工程，包含 Cloud DB 对象类型、初始数据和 `id-generator` 云函数。 |

应用主体为单模块工程：

| 项目         | 当前值                     |
| ------------ | -------------------------- |
| 模块名       | `entry`                    |
| Target       | `default`                  |
| Product      | `default`                  |
| 设备类型     | `phone`、`tablet`          |
| 目标 SDK     | `6.0.2(22)`                |
| 入口 Ability | `EntryAbility`             |
| 首页         | `pages/Index`              |
| 已声明权限   | `ohos.permission.INTERNET` |

## 3. 目录结构

```text
Application/
├── AppScope/                         应用级资源与配置
├── docs/                             项目文档、设计图、云数据库说明
├── entry/
│   ├── src/main/ets/
│   │   ├── components/               通用 ArkUI 组件
│   │   ├── database/                 本地 RDB 数据访问层
│   │   ├── entryability/             应用生命周期入口
│   │   ├── entrybackupability/       备份扩展能力
│   │   ├── model/                    业务模型与统计模型
│   │   ├── pages/                    主页面与设置子页面
│   │   ├── routes/                   Navigation 路由构建器
│   │   ├── services/                 应用服务、预算服务、云端服务
│   │   └── utils/                    金额、日期、日志、Toast 等工具
│   └── src/main/resources/           页面、路由、颜色、字符串、媒体资源
└── build-profile.json5               工程构建与签名配置

CloudProgram/
├── clouddb/                          Cloud DB 配置、对象类型和数据入口
└── cloudfunctions/id-generator/       UUID 生成云函数
```

## 4. 应用启动流程

`EntryAbility` 负责应用启动初始化：

1. 设置应用颜色模式。
2. 初始化云存储能力。
3. 初始化本地 RDB 数据库。
4. 刷新分类缓存。
5. 执行到期周期账单生成。
6. 启动夜间本地缓存同步。
7. 设置沉浸式窗口、安全区域高度和全局 `AppStorage` 状态。
8. 加载首页 `pages/Index`。

首页 `Index` 负责账号门禁和主导航：

1. 启动时读取本地用户会话。
2. 未登录时显示登录/注册/创建本地用户页面。
3. 登录后创建或确认默认账本和默认分类。
4. 登录后进入五个底部 Tab 页面。

## 5. 页面结构

### 5.1 顶层页面

`Index.ets` 是应用主页面，采用 `Navigation + Tabs` 结构：

| Tab    | 页面组件         | 功能定位                                         |
| ------ | ---------------- | ------------------------------------------------ |
| 账单   | `BillListPage`   | 首页账单总览、月度筛选、最近账单、快捷入口。     |
| 日历   | `CalendarPage`   | 按日历查看账单，支持月份切换和账单删除。         |
| 记一笔 | `AddBillPage`    | 新增收入或支出账单。                             |
| 统计   | `StatisticsPage` | 收入、支出、结余、预算和分类统计分析。           |
| 我的   | `SettingsPage`   | 用户、预算、账户、分类、周期账单和数据工具入口。 |

### 5.2 Navigation 路由

`router_map.json` 通过 `AppRouteBuilders.ets` 注册以下路由：

| 路由名              | 页面                                   | 说明                     |
| ------------------- | -------------------------------------- | ------------------------ |
| `billSearch`        | `BillSearchPage`                       | 账单搜索页。             |
| `billDetail`        | `BillDetailPage`                       | 账单详情、编辑和删除页。 |
| `categoryManage`    | `CategoryManagePage`                   | 分类管理页。             |
| `expenseRankingAll` | `ExpenseRankingAllPage`                | 支出排行榜完整列表。     |
| `budgetSettings`    | `SettingsPage(initialPage='budget')`   | 预算设置页。             |
| `periodBill`        | `SettingsPage(initialPage='period')`   | 周期记账页。             |
| `accountSettings`   | `SettingsPage(initialPage='account')`  | 支付账户管理页。         |
| `accountCreate`     | `AccountFormPage(mode='create')`       | 新增支付账户页。         |
| `accountEdit`       | `AccountFormPage(mode='edit')`         | 编辑支付账户页。         |
| `themeMode`         | `SettingsPage(initialPage='theme')`    | 主题设置页。             |
| `generalSettings`   | `SettingsPage(initialPage='general')`  | 通用设置页。             |
| `userDataSettings`  | `SettingsPage(initialPage='userData')` | 用户数据页。             |
| `dataTools`         | `SettingsPage(initialPage='data')`     | 数据工具页。             |
| `privacySettings`   | `SettingsPage(initialPage='privacy')`  | 隐私设置页。             |
| `syncSettings`      | `SettingsPage(initialPage='sync')`     | 同步相关页面。           |
| `securitySettings`  | `SettingsPage(initialPage='security')` | 安全偏好页。             |
| `feedbackPage`      | `SettingsPage(initialPage='feedback')` | 反馈页面入口。           |
| `aboutPage`         | `SettingsPage(initialPage='about')`    | 关于页。                 |

## 6. 页面功能说明

### 6.1 登录门禁页

位置：`entry/src/main/ets/pages/Index.ets`

已实现功能：

- 本地读取当前用户会话。
- 账号登录。
- 账号注册并登录。
- 仅创建本地用户名使用。
- 登录成功后初始化默认账本、默认分类和分类缓存。
- 退出登录后回到登录门禁页。
- 提供 UserInfo 云数据库调试查询和测试写入按钮。

### 6.2 账单首页

位置：`entry/src/main/ets/pages/BillList.ets`

已实现功能：

- 按月份读取账单。
- 统计当前筛选范围内收入、支出、账单数量。
- 展示日预算、月预算、年预算使用情况。
- 支持月份左右切换、日期选择器选择月份。
- 支持全部、支出、收入筛选。
- 展示最近账单，支持展开全部账单。
- 点击账单进入账单详情页。
- 搜索入口进入账单搜索页。
- 快捷入口跳转到记一笔、日历、统计、分类和预算相关页面。

### 6.3 记一笔页面

位置：`entry/src/main/ets/pages/AddBill.ets`

已实现功能：

- 新增支出或收入账单。
- 输入金额，限制为数字和两位小数。
- 选择付款账户。
- 选择账单日期，日期不能超过当天。
- 选择当前账单类型对应的分类。
- 填写备注。
- 使用常用模板快速填充分类、备注和金额。
- 从页面打开分类编辑器。
- 保存账单后写入本地数据，并按当前配置触发云端同步。
- 支出账单保存前检查账户余额，余额不足或未设置余额时给出提醒。
- 支出账单保存后检查预算超额并提示。

### 6.4 账单详情页

位置：`entry/src/main/ets/pages/BillDetailPage.ets`

已实现功能：

- 根据账单 ID 读取账单详情。
- 查看账单金额、类型、分类、账户、日期和备注。
- 进入编辑模式后修改账单类型、金额、分类、账户、日期和备注。
- 保存修改后更新本地账单，并同步账户余额变化。
- 删除账单前弹出确认框。
- 删除账单后回滚账户余额，并尝试同步删除云端账单。

### 6.5 账单搜索页

位置：`entry/src/main/ets/pages/BillSearchPage.ets`

已实现功能：

- 按关键词搜索备注、分类和金额。
- 按账单类型筛选：全部、收入、支出。
- 按分类筛选。
- 按开始日期和结束日期筛选。
- 日期范围反向输入时自动归一化。
- 显示搜索结果数量、收入合计、支出合计和净额。
- 按日期分组展示搜索结果。
- 点击搜索结果进入账单详情页。
- 支持清空关键词和重置筛选条件。

### 6.6 日历页

位置：`entry/src/main/ets/pages/Calendar.ets`、`components/CalendarView.ets`

已实现功能：

- 按月份展示日历。
- 支持上月、下月和回到今天。
- 支持横向滑动切换月份。
- 进入页面或切换 Tab 时刷新账单数据。
- 日历内展示账单数据。
- 支持从日历页打开搜索页。
- 支持删除账单并刷新日历。

### 6.7 统计页

位置：`entry/src/main/ets/pages/Statistics.ets`

已实现功能：

- 支持月度统计和年度统计。
- 支持支出与收入统计维度切换。
- 展示收入、支出和结余概览。
- 展示与上一周期的金额对比。
- 展示预算概览。
- 展示趋势图，月度模式支持近 7 天和本月趋势，年度模式展示年内月度趋势。
- 趋势图支持点击选择柱状数据。
- 展示分类占比和分类排行。
- 支出排行榜支持查看完整列表。
- 支持筛选面板切换统计年份、月份和统计维度。
- 支持横向滑动切换统计周期。

### 6.8 分类管理页

位置：`entry/src/main/ets/pages/CategoryManage.ets`

已实现功能：

- 支出分类和收入分类分组管理。
- 新增分类。
- 编辑分类名称、图标和颜色。
- 删除分类。
- 删除分类前检查是否存在关联账单。
- 默认分类展示默认标识。
- 长按拖拽调整分类顺序。

### 6.9 我的页

位置：`entry/src/main/ets/pages/Settings.ets`、`pages/settings/SettingsMainPage.ets`

已实现功能：

- 展示用户卡片。
- 展示今日、本月、本年预算概览。
- 展示支付账户概览、默认账户、启用账户数量和手动余额合计。
- 提供分类管理、预算设置、周期记账、通用设置入口。
- 提供 CSV 导出按钮。
- 提供退出登录按钮。

### 6.10 支付账户管理

位置：`entry/src/main/ets/pages/settings/SettingsAccountPage.ets`、`AccountFormPage.ets`

已实现功能：

- 查询支付账户列表。
- 新增支付账户。
- 编辑支付账户。
- 设置默认支付账户。
- 启用或停用支付账户。
- 删除支付账户采用软删除。
- 支持银行卡、支付宝、微信、现金和其他类型。
- 支持账户名称、银行名、尾号、颜色、手动余额等字段。
- 记账时可选择支付账户，并根据账户余额进行提醒。

### 6.11 预算设置

位置：`entry/src/main/ets/pages/settings/SettingsBudgetPage.ets`、`services/BudgetService.ets`

已实现功能：

- 展示日预算、月预算、年预算概览。
- 编辑日、月、年周期预算。
- 支持总预算金额。
- 支持分类预算分配。
- 保存预算规则。
- 检查分类预算合计是否超过总预算。
- 查询预算规则使用情况。
- 账单首页、统计页和我的页均读取预算概览。

### 6.12 周期记账

位置：`entry/src/main/ets/pages/settings/SettingsPeriodPage.ets`、`database/PeriodRuleDao.ets`

已实现功能：

- 按支出和收入查看周期记账规则。
- 新增周期记账规则。
- 设置标题、金额、分类、备注、执行日和周期。
- 支持按月和按年周期生成下一次执行日期。
- 启用或停用周期规则。
- 删除周期规则。
- 应用启动时生成到期账单。

### 6.13 用户数据与数据工具

位置：`entry/src/main/ets/pages/settings/SettingsUserDataPage.ets`、`SettingsDataToolsPage.ets`

已实现功能：

- 导出 CSV 账单文件。
- 导出 JSON 备份文件。
- 上传云备份。
- 查询云备份列表。
- 注册云账号并上传数据。
- 上传本地数据到云数据库。
- 检查云数据库完整度。

### 6.14 通用、主题、隐私、安全、关于页面

位置：`entry/src/main/ets/pages/settings/`

已实现功能：

- 通用设置页提供主题、安全、隐私、反馈页面和关于入口。
- 主题页支持选择主题模式和主题色，并保存到本地偏好。
- 隐私页支持隐藏金额、本地优先开关，并保存到本地偏好。
- 安全页支持应用锁、自动锁定开关，并保存到本地偏好。
- 关于页支持展示版本并检查当前版本状态。

## 7. 主要组件说明

| 组件                               | 说明                           |
| ---------------------------------- | ------------------------------ |
| `SummaryCard`                      | 首页收入、支出和预算概览卡片。 |
| `WaterPageBg`                      | 页面统一水感背景。             |
| `CalendarView`                     | 日历主体视图。                 |
| `MonthSelector`                    | 月份切换组件。                 |
| `SearchResultItem`                 | 搜索结果账单行。               |
| `CategoryEditor`                   | 底部弹出的分类编辑器。         |
| `CategoryEditDialog`               | 分类新增/编辑弹窗。            |
| `ConfirmActionDialog`              | 通用确认操作弹窗。             |
| `CommonHintDialog`                 | 成功、信息等轻提示弹窗。       |
| `StyledPieChart`、`StyledBarChart` | 统计图表组件。                 |

## 8. 本地数据设计

本地数据使用 HarmonyOS `relationalStore`，数据库文件名为 `yayusuan.db`，安全等级为 `S1`。

### 8.1 数据表

| 表名               | 用途                                               |
| ------------------ | -------------------------------------------------- |
| `users`            | 本地用户、密码哈希、盐值和登录时间。               |
| `account_books`    | 账本信息和云端账本 ID。                            |
| `bills`            | 账单主表，记录金额、类型、分类、账户、日期和备注。 |
| `categories`       | 收入/支出分类。                                    |
| `period_rules`     | 周期记账规则。                                     |
| `budgets`          | 旧版分类预算表。                                   |
| `budget_rules`     | 当前预算规则表。                                   |
| `payment_accounts` | 支付账户、类型、余额、默认状态和启用状态。         |

### 8.2 数据访问层

| DAO                 | 职责                                                       |
| ------------------- | ---------------------------------------------------------- |
| `DBHelper`          | 数据库初始化、表创建、字段迁移、默认分类和默认账本初始化。 |
| `UserDao`           | 用户注册、登录、登出和会话读取。                           |
| `BillDao`           | 账单新增、查询、搜索、统计、更新和删除。                   |
| `CategoryDao`       | 分类查询、新增、更新、删除、排序和缓存刷新。               |
| `PaymentAccountDao` | 支付账户查询、保存、默认账户、启停、软删除和余额处理。     |
| `BudgetRuleDao`     | 预算规则创建、保存、启停、软删除和冲突检查。               |
| `PeriodRuleDao`     | 周期规则保存、启停、删除、下一日期计算和到期账单生成。     |
| `AccountBookDao`    | 账本读取和默认账本创建。                                   |

## 9. 服务层说明

| 服务                   | 说明                                                         |
| ---------------------- | ------------------------------------------------------------ |
| `AppDataApi`           | 应用数据统一入口，封装账单、分类、支付账户、预算、周期规则和用户相关操作，并在数据变更后更新全局版本号。 |
| `BudgetService`        | 预算概览、规则使用情况、预算超额检测和账单预算提醒。         |
| `CloudDatabaseService` | Cloud DB 用户、账本、账单、分类、支付账户、周期规则、预算规则的上传、恢复、查询计数和完整度检查。 |
| `CloudBackupService`   | JSON 数据备份上传和云备份列表查询。                          |
| `CloudCacheService`    | 夜间本地缓存同步入口。                                       |
| `CloudDbCommon`        | 云数据库通用辅助能力。                                       |

## 10. 云端能力

### 10.1 Cloud DB

云数据库区域名为 `XiaoJinYu`。当前配置的对象类型包括：

- `UserInfo`
- `CloudAccountBook`
- `CloudBill`
- `CloudCategory`
- `CloudPeriodRule`
- `CloudBudgetRule`
- `CloudUserDataBundle`

应用侧会将本地用户、账本、账单、分类、支付账户、周期规则和预算规则整理后写入云数据库。恢复时优先读取 `CloudUserDataBundle` 中的结构化 JSON 数据，再恢复分类、支付账户、周期规则、预算规则和账单。

### 10.2 云函数

`CloudProgram/cloudfunctions/id-generator` 已实现 `IdGenerator.randomUUID()`，用于生成 UUID。

## 11. 资源与样式

应用资源位于 `entry/src/main/resources/`：

| 目录                              | 说明                   |
| --------------------------------- | ---------------------- |
| `base/element/color.json`         | 浅色模式颜色资源。     |
| `dark/element/color.json`         | 深色模式颜色资源。     |
| `base/element/string.json`        | 字符串资源。           |
| `base/media/`                     | 图标、插画和页面资源。 |
| `base/profile/main_pages.json`    | 首页注册。             |
| `base/profile/router_map.json`    | Navigation 路由配置。  |
| `base/profile/backup_config.json` | 备份扩展配置。         |

页面统一使用资源颜色和 `WaterPageBg` 背景，主要视觉元素包括小金鱼插画、圆角卡片、底部 Tab 和轻量阴影。

## 12. 构建与运行

### 12.1 DevEco Studio

1. 使用 DevEco Studio 打开 `Application/`。
2. 等待 `ohpm install` 完成。
3. 选择 `entry` 模块、`default` target 和 `default` product。
4. 连接 HarmonyOS 设备或模拟器后运行。

### 12.2 命令行构建

根据当前工程配置，模块和产品参数为：

```powershell
.\hvigorw.bat --mode module -p module=entry@default -p product=default assembleHap
```

实际命令行构建前需要按本机 DevEco 安装路径设置 `DEVECO_SDK_HOME`、`JAVA_HOME` 和 `Path`。

## 13. 已实现数据流

### 13.1 新增账单

```text
AddBillPage
  -> AppDataApi.addBill()
  -> BillDao.insert()
  -> 更新 billDataVersion / appDataVersion
  -> 可选触发 CloudDatabaseService 同步
  -> 首页、日历、统计、预算相关页面刷新
```

### 13.2 编辑或删除账单

```text
BillDetailPage / CalendarView
  -> AppDataApi.updateBill() 或 AppDataApi.deleteBill()
  -> BillDao 更新或删除
  -> PaymentAccountDao 调整账户余额
  -> 更新全局数据版本
  -> 可选同步云数据库
```

### 13.3 预算刷新

```text
SettingsPage / BillListPage / StatisticsPage
  -> AppDataApi.queryBudgetOverview()
  -> BudgetService.buildOverview()
  -> BudgetRuleDao + BillDao 读取规则和支出
  -> 生成日/月/年预算概览
```

### 13.4 周期账单生成

```text
EntryAbility.onCreate()
  -> PeriodRuleDao.generateDueBills()
  -> 读取启用周期规则
  -> 生成到期账单
  -> 更新下一次执行日期
```

## 14. 当前文档依据

本文档依据以下当前项目文件整理：

- `Application/build-profile.json5`
- `Application/entry/src/main/module.json5`
- `Application/entry/src/main/resources/base/profile/main_pages.json`
- `Application/entry/src/main/resources/base/profile/router_map.json`
- `Application/entry/src/main/ets/entryability/EntryAbility.ets`
- `Application/entry/src/main/ets/pages/`
- `Application/entry/src/main/ets/components/`
- `Application/entry/src/main/ets/database/`
- `Application/entry/src/main/ets/services/`
- `CloudProgram/clouddb/`
- `CloudProgram/cloudfunctions/id-generator/`
