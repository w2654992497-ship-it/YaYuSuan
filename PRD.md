# 鸭鱼算 · 产品需求文档（PRD）

> 版本：v1.1 · 日期：2026-03-31

---

## 一、产品概述

**鸭鱼算**是一款运行在 HarmonyOS 上的轻量个人账单管理工具，支持快速录入收支、分类统计、图表可视化，可选预算提醒。

| 项目 | 说明 |
|------|------|
| 目标用户 | 有记账习惯或想建立记账习惯的个人用户 |
| 核心诉求 | 快速记一笔（< 10秒）、直观看月度收支结构 |
| 优先级 | P0：录入 / 列表 / 统计；P1：筛选 / 删除 / 月份切换；P2：预算提醒 / 导入导出 |

---

## 二、全局规范

| 规则 | 说明 |
|------|------|
| 导航方式 | 底部 Tabs，3 个 Tab：账单 / 记账 / 统计 |
| 默认 Tab | 账单（index = 0） |
| 加载状态 | 数据库查询期间显示 `LoadingProgress`（主题色），居中显示 |
| 空状态 | 大号 emoji + 说明文字，居中显示，无按钮 |
| 错误提示 | `promptAction.showToast`，duration: 2000ms，不崩溃 |
| 金额规则 | 数据库以"分"（整数）存储，UI 显示保留 2 位小数 |
| 收入金额 | 前缀 `+`，绿色 `#4CAF50` |
| 支出金额 | 前缀 `-`，红色 `#F44336` |
| 日期规则 | 当天 → "今天"；昨天 → "昨天"；其余 → "M月D日 星期X" |
| 颜色来源 | 所有颜色引用 `$r('app.color.xxx')`，Canvas 除外 |

---

## 三、页面目录

| 页面 | 文件 | 类型 | 入口 |
|------|------|------|------|
| 主容器 | `pages/Index.ets` | `@Entry` | 应用启动 |
| 账单列表 | `pages/BillList.ets` | `@Component` | Tab 0 |
| 记账录入 | `pages/AddBill.ets` | `@Component` | Tab 1 |
| 统计图表 | `pages/Statistics.ets` | `@Component` | Tab 2 |
| 预算设置 | `pages/Settings.ets` | `@Component`（可选） | 账单页右上角 |

---

---

# 页面 1 · Index · 主容器

---

## 1.1 页面职责

作为整个 App 的宿主容器，承载三个子页面的切换，管理全局 Tab 状态和跨页面通信。

---

## 1.2 页面布局

```
┌──────────────────────────────────────┐  ← 屏幕顶部
│                                      │
│                                      │
│         [ 当前 Tab 内容区域 ]         │  layoutWeight(1)，撑满剩余高度
│                                      │
│                                      │
│                                      │
├──────────────────────────────────────┤
│                                      │
│   📋        ➕        📊            │  ← TabBar，高度 60vp
│  账单       记账       统计           │     白色背景，底部安全区适配
│  （蓝）    （灰）    （灰）           │     选中项主题色 #1976D2，未选中灰色 #9E9E9E
│                                      │
└──────────────────────────────────────┘
```

**TabBar 单项布局：**

```
┌──────────────┐
│      📋      │  ← emoji，22fp
│     账单     │  ← 文字，10fp，选中主题色 / 未选灰色
└──────────────┘
padding: top 6 / bottom 6
```

---

## 1.3 页面状态

| 变量 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `activeTabIndex` | `number` | `0` | `@Provide`，子页面通过 `@Consume` 读写 |
| `currentTabIndex` | `number` | `0` | `@State`，控制 Tabs 组件当前显示项 |

---

## 1.4 交互需求

| 编号 | 触发条件 | 响应行为 |
|------|----------|---------|
| I-01 | 点击"账单" Tab | `currentTabIndex = 0`，账单图标主题色高亮 |
| I-02 | 点击"记账" Tab | `currentTabIndex = 1`，记账图标主题色高亮 |
| I-03 | 点击"统计" Tab | `currentTabIndex = 2`，统计图标主题色高亮 |
| I-04 | AddBill 保存成功 | 子页面写 `activeTabIndex = 0`，容器 `onChange` 同步 `currentTabIndex` |
| I-05 | 左右横向手势 | 不响应（Tab 手势切换禁用，防止误触） |

---

## 1.5 跨页面通信机制

```
Index
  @Provide activeTabIndex ──────────────────────────────────┐
                                                             │
  BillListPage                 AddBillPage                   │
  @Watch @Consume activeTabIndex  @Consume activeTabIndex ───┘

  当 AddBillPage 保存成功：
    this.activeTabIndex = 0
        ↓ @Provide 变更
    BillListPage @Watch('onTabChanged') 触发
        ↓
    loadData() 重新查询列表
```

---

---

# 页面 2 · BillList · 账单列表

---

## 2.1 页面职责

展示按日期降序分组的全部账单，提供月份 + 类型筛选，支持右滑删除，顶部展示当前筛选条件下的收支汇总。

---

## 2.2 页面布局（完整视图）

```
┌──────────────────────────────────────┐
│ ┌────────────────────────────────┐   │
│ │   收入              支出    结余│   │  ← SummaryCard
│ │  +¥3,200.00    -¥1,580.50  ¥... │   │    圆角 12vp，白色背景
│ │  （绿色）       （红色）  （动态）│   │    margin: 16 四边
│ └────────────────────────────────┘   │
│                                      │
│ [2026年3月 ▼]  [全部] [收入] [支出]  │  ← FilterBar，高度 44vp
│ ────────────────────────────────     │    padding: left/right 16
│                                      │
│  3月31日 星期二             -¥80.00  │  ← BillGroup 日期头
│  ╔══════════════════════════════╗    │    左：friendlyDate，右：当日净额
│  ║ 🍜  餐饮                     ║    │
│  ║      午饭              -¥25.00║    │  ← BillItem（正常态）
│  ╠══════════════════════════════╣    │    分隔线 #E0E0E0
│  ║ 🚇  交通                     ║    │
│  ║      地铁              -¥55.00║    │
│  ╚══════════════════════════════╝    │
│                                      │
│  3月30日 星期一            +¥200.00  │
│  ╔══════════════════════════════╗    │
│  ║ 💰  工资                     ║    │
│  ║      生活费           +¥200.00║    │
│  ╚══════════════════════════════╝    │
│                                      │
└──────────────────────────────────────┘
```

**空状态视图：**

```
┌──────────────────────────────────────┐
│                                      │
│              SummaryCard             │
│                                      │
│              FilterBar               │
│ ──────────────────────────────────── │
│                                      │
│                                      │
│                  🧾                  │  ← 64fp emoji
│             暂无账单记录              │  ← 16fp，灰色
│                                      │
│                                      │
└──────────────────────────────────────┘
```

---

## 2.3 SummaryCard 布局

```
┌───────────────────────────────────────────┐
│  收入          │  支出          │  结余    │
│  ¥3,200.00     │  ¥1,580.50     │  ¥1,619  │
│  （绿 #4CAF50）│  （红 #F44336）│ (正=绿/负=红)│
└───────────────────────────────────────────┘
每列 layoutWeight(1)，居中对齐
标题 12fp 灰色，金额 16fp Medium
列间 Divider 垂直，高度 32，颜色 #E0E0E0
整体 padding: 16，背景白色，borderRadius: 12，margin: 16
```

---

## 2.4 FilterBar 布局

```
Row（padding left/right 16，top/bottom 8）
│
├── [2026年3月 ▼]  ← Button：白底、主题色文字、圆角 16、border 主题色
│     点击 → DatePickerDialog（仅年月，不含日）
│
└── Row（Chip 组）
      ├── [全部]   ← 选中：主题色底+白字；未选：白底+灰字+灰border
      ├── [收入]
      └── [支出]
          每个 Chip：height 32，padding h12，borderRadius 16
```

---

## 2.5 BillGroup 布局

```
Column（width 100%，backgroundColor: color_bg）
│
├── Row（日期头，padding: left/right 16，top/bottom 8）
│    ├── Text（友好日期）  14fp，灰色，layoutWeight(1)
│    └── Text（当日净额）  14fp，正=绿/负=红
│
└── ForEach → BillItem（每项之间 Divider，缩进 16+44+12=72vp）
```

---

## 2.6 BillItem 布局

**正常态：**

```
Row（padding: left/right 16，top/bottom 12，backgroundColor white）
│
├── Column（图标圆）  width/height 44，borderRadius 22
│    backgroundColor: category.color + '33'（20%透明度）
│    Text emoji，fontSize 20
│    margin right 12
│
├── Column（中间信息，layoutWeight 1）
│    ├── Text（category）  16fp，#212121，Medium，maxLines 1
│    └── Text（remark）    12fp，#9E9E9E，maxLines 1（备注为空则不渲染）
│
└── Column（金额，alignItems End）
     └── Text（+/-¥xx.xx）  16fp，Medium
          收入：#4CAF50，支出：#F44336
```

**右滑态（swipeAction end）：**

```
Row（正常内容区） ┃ [删除] 72vp 宽，高度 100%，红底白字，14fp ┃
```

---

## 2.7 页面状态

| 变量 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `activeTabIndex` | `number` | — | `@Watch` `@Consume`，Tab 切换触发刷新 |
| `billGroups` | `BillGroupData[]` | `[]` | 按日期聚合后的渲染数据 |
| `filter` | `FilterOptions` | `createDefaultFilter()` | 当前筛选条件（当月 + 全部） |
| `totalIncome` | `number` | `0` | 当前筛选下总收入（分） |
| `totalExpense` | `number` | `0` | 当前筛选下总支出（分） |
| `isLoading` | `boolean` | `false` | 控制加载动画显隐 |

---

## 2.8 交互需求

| 编号 | 触发条件 | 响应行为 |
|------|----------|---------|
| BL-01 | `aboutToAppear` | `isLoading = true` → `queryByFilter(filter)` → 聚合分组 → 更新状态 |
| BL-02 | `activeTabIndex` 变更为 0（`@Watch`） | 重新执行 `loadData()` |
| BL-03 | 点击月份按钮 | 弹出 `DatePickerDialog`，仅年月滚轮，不含日；确认后 `filter.month` 更新 → `loadData()` |
| BL-04 | 点击类型 Chip（全部/收入/支出） | 单选切换，`filter.type` 更新 → `loadData()`，SummaryCard 同步变化 |
| BL-05 | 右滑 BillItem | 右侧滑出红色"删除"按钮（72vp），其余 BillItem 自动收回 |
| BL-06 | 点击"删除"按钮 | 弹出 `AlertDialog`（见下方弹窗规格），等待用户确认 |
| BL-07 | 确认删除 | `BillDao.deleteById(id)` → `loadData()` → 列表刷新；若删后为空，显示空状态 |
| BL-08 | 取消删除 | 关闭 Dialog，BillItem 收回，无任何变化 |
| BL-09 | `loadData` 数据库异常 | `showToast("加载失败，请重试")`，`isLoading = false`，保留上次数据 |
| BL-10 | 筛选结果为空 | 显示空状态视图（"该条件下暂无账单"），SummaryCard 三项均为 `¥0.00` |

**删除确认弹窗规格：**

```
AlertDialog.show({
  title: '确认删除',
  message: '删除后无法恢复',
  primaryButton: { value: '取消', action: () => {} },
  secondaryButton: { value: '确认删除', fontColor: '#F44336', action: () => { doDelete() } }
})
```

---

## 2.9 数据流

```
BillList.loadData()
    ↓
BillDao.queryByFilter(filter)   ← SQL: WHERE date LIKE 'YYYY-MM%' AND type = ?
    ↓ Bill[]（按 date DESC 排序）
groupByDate(bills)
    ↓ Map<date, Bill[]> → BillGroupData[]（含 dayIncome/dayExpense）
    ↓
this.billGroups = groups        ← @State 变化，触发 ForEach 重渲染
this.totalIncome = income
this.totalExpense = expense
    ↓
SummaryCard, FilterBar, List 同步更新
```

---

## 2.10 边界情况

| 场景 | 处理方式 |
|------|---------|
| 当月无任何账单 | SummaryCard 三项 `¥0.00`，列表区显示空状态 |
| 备注字段为空 | BillItem 中间列仅显示分类名，不渲染备注行 |
| 账单数量 > 100 条 | 建议后续版本改用 `LazyForEach` 优化性能 |
| 日期头净额为 0 | 显示 `¥0.00`，使用黑色文字 |

---

---

# 页面 3 · AddBill · 记账录入

---

## 3.1 页面职责

提供快速录入一条收支账单的表单。设计目标：核心操作（选类型 → 输金额 → 选分类）3步完成，30秒内记完一笔账。

---

## 3.2 页面布局（完整视图）

```
┌──────────────────────────────────────┐
│                                      │
│  ┌─────────────┬─────────────┐       │  ← 收/支切换
│  │    支出     │    收入     │       │    高度 40vp，圆角 20vp
│  │  (红底白字) │  (灰底灰字) │       │    padding: 16 左右，8 下
│  └─────────────┴─────────────┘       │
│                                      │
│            ¥ 128.50                  │  ← 金额展示区
│         ───────────────              │    48fp Bold，居中
│                                      │    padding top 16 / bottom 8
│  ┌────┐  ┌────┐  ┌────┐  ┌────┐     │
│  │ 🍜 │  │ 🚇 │  │ 🛍️ │  │ 🎮 │     │  ← CategoryGrid（支出模式）
│  │餐饮│  │交通│  │购物│  │娱乐│     │    4列，每格正方形
│  └────┘  └────┘  └────┘  └────┘     │    选中：主题色边框 2vp
│  ┌────┐  ┌────┐  ┌────┐  ┌────┐     │
│  │ 🏠 │  │ 💊 │  │ 📚 │  │ 📦 │     │
│  │住房│  │医疗│  │教育│  │其他│     │
│  └────┘  └────┘  └────┘  └────┘     │
│                                      │
│  ┌──────────────────────────────┐    │  ← 日期行
│  │ 📅  2026-03-31           >  │    │    白底圆角 8，margin 16
│  └──────────────────────────────┘    │    点击整行弹出 DatePickerDialog
│                                      │
│  ┌──────────────────────────────┐    │  ← 备注行
│  │ ✏️  备注（选填）              │    │    TextInput 内嵌，maxLength 50
│  └──────────────────────────────┘    │    白底圆角 8，margin 16
│                                      │
│  ┌──────────────────────────────┐    │  ← 保存按钮
│  │           保  存              │    │    高度 48vp，主题色背景
│  └──────────────────────────────┘    │    borderRadius 24，margin 16
│                                      │
└──────────────────────────────────────┘
```

**收入模式（切换后 CategoryGrid 变化）：**

```
切换为"收入"后，CategoryGrid 变为：
┌────┐  ┌────┐  ┌────┐  ┌────┐  ┌────┐
│ 💰 │  │ 💼 │  │ 📈 │  │ 🧧 │  │ ✨ │
│工资│  │兼职│  │理财│  │红包│  │其他│
└────┘  └────┘  └────┘  └────┘  └────┘
（5个分类，最后一行不满时左对齐）
```

**CategoryGrid 单格两态对比：**

```
未选中                    已选中
┌──────────────┐          ┌──────────────┐
│              │          │              │ ← 2vp 主题色边框，borderRadius 8
│     🍜       │          │     🍜       │ ← 图标圆背景色不变
│              │          │              │
│    餐饮      │          │    餐饮      │ ← 文字改为主题色 #1976D2
└──────────────┘          └──────────────┘
 灰色文字                  圆角边框高亮
```

---

## 3.3 金额输入交互细节

```
初始状态：显示 "¥ 0.00"（占位），灰色

点击金额区域（Text 组件 + 透明 TextInput 叠加）
    ↓
系统数字键盘弹出
页面整体上移（Scroll 容器自动适应）
    ↓
用户输入（TextInput onChange 过滤）：
  规则1：只允许数字和一个小数点
  规则2：小数点后最多 2 位
  规则3：整数部分最多 8 位（超出不接受）
  规则4：不允许 "0" 开头的多位整数（如输入 "01" → 保持 "0"）
    ↓
amountText 更新 → 金额展示 Text 实时变化
    ↓
收起键盘：金额展示保持最新值
    ↓
清空所有字符：金额展示回到 "¥ 0.00"
```

---

## 3.4 日期选择器规格

```
DatePickerDialog.show({
  start: new Date('2020-01-01'),
  end: new Date()             ← 不可选未来日期
  selected: new Date(selectedDate),
  lunar: false,
  onAccept: (value) => {
    // value.month 是 0-indexed，需 +1
    selectedDate = `${value.year}-${String(value.month+1).padStart(2,'0')}-${String(value.day).padStart(2,'0')}`
  }
})
```

---

## 3.5 页面状态

| 变量 | 类型 | 默认值 | 重置时机 |
|------|------|--------|---------|
| `billType` | `'income' \| 'expense'` | `'expense'` | 保存成功后 |
| `amountText` | `string` | `''` | 保存成功后 |
| `selectedCategory` | `string` | `''` | 保存成功后 / 切换收支类型时 |
| `selectedDate` | `string` | `DateUtil.today()` | 保存成功后（重置为今天） |
| `remark` | `string` | `''` | 保存成功后 |

---

## 3.6 交互需求

| 编号 | 触发条件 | 响应行为 |
|------|----------|---------|
| AB-01 | Tab 切换到"记账" | 不重置表单（允许用户查看后回来继续填） |
| AB-02 | 点击"支出" / "收入"切换 | 按钮颜色切换（支出红色 / 收入绿色）；CategoryGrid 分类列表更新；`selectedCategory` 清空 |
| AB-03 | 点击金额展示区 | 聚焦下方透明 TextInput，弹出数字键盘 |
| AB-04 | 输入金额 | onChange 过滤非法字符，实时更新金额展示 |
| AB-05 | 点击分类格 | 选中高亮（主题色边框），其余恢复默认；`selectedCategory` 更新 |
| AB-06 | 点击日期行 | 弹出 DatePickerDialog（见 3.4），不可选未来 |
| AB-07 | 确认日期 | `selectedDate` 更新，日期行文字同步 |
| AB-08 | 点击备注输入区 | 弹出普通键盘，输入长度上限 50 字 |
| AB-09 | 点击"保存" | 执行表单验证（见 3.7） |
| AB-10 | 验证失败：金额为空 | `showToast("请输入金额")`，金额区域抖动动画 |
| AB-11 | 验证失败：金额 ≤ 0 | `showToast("金额必须大于0")` |
| AB-12 | 验证失败：未选分类 | `showToast("请选择分类")`，CategoryGrid 区域标题短暂变红 |
| AB-13 | 验证通过 | 构造 Bill → `BillDao.insert()` → 重置表单 → `activeTabIndex = 0` |
| AB-14 | 数据库写入失败 | `showToast("保存失败，请重试")`，表单保留当前填写内容 |

---

## 3.7 表单验证逻辑

```
用户点击"保存"
    │
    ├── amountText 为空或长度为 0？
    │       ↓ YES → showToast("请输入金额") + 抖动 → return
    │
    ├── yuan2Fen(amountText) <= 0？
    │       ↓ YES → showToast("金额必须大于0") → return
    │
    ├── selectedCategory 为空？
    │       ↓ YES → showToast("请选择分类") → return
    │
    └── 全部通过
            ↓
          构造 Bill {
            id: 0,
            amount: yuan2Fen(amountText),
            type: billType,
            category: selectedCategory,
            remark: remark.trim(),
            date: selectedDate,
            createdAt: Date.now()
          }
            ↓
          BillDao.insert(bill)
            ↓ 成功
          showToast("记账成功")
          resetForm()
          activeTabIndex = 0   ← 触发 BillList 刷新
```

---

## 3.8 数据流

```
用户填写表单
    ↓ 点击保存
构造 Bill 对象（amount 转换为分）
    ↓
BillDao.insert(bill)  ← INSERT INTO bills ...
    ↓ 返回 rowId > 0
AppStorage.set('needRefresh', true)   ← （已被 @Watch/@Consume 机制替代，保留兼容）
activeTabIndex = 0
    ↓
Index.onChange 触发
    ↓
BillListPage.onTabChanged() → loadData()
```

---

## 3.9 边界情况

| 场景 | 处理方式 |
|------|---------|
| 连续点两次小数点 | onChange 过滤，第二个小数点被忽略 |
| 粘贴内容包含非数字 | 过滤后仅保留数字和第一个小数点 |
| 备注粘贴超 50 字 | `maxLength(50)` 自动截断 |
| 快速重复点击"保存" | 第一次触发后按钮短暂禁用（防重复提交） |
| 金额全部删除 | 展示区显示占位 `¥ 0.00` |

---

---

# 页面 4 · Statistics · 统计图表

---

## 4.1 页面职责

可视化展示指定月份的支出分类占比（饼图），以及近6个月的收支趋势（柱状图）。帮助用户快速了解消费结构。

---

## 4.2 页面布局（完整视图）

```
┌──────────────────────────────────────┐
│                                      │
│  ┌──────────────────────────────┐    │  ← 月份导航栏，高度 44vp
│  │  <    2026年3月    >         │    │    "<" ">" 各 44×44vp，透明背景
│  └──────────────────────────────┘    │    当月时 ">" 置灰禁用
│                                      │
│  ┌──────────────────────────────┐    │  ← SummaryCard（同账单页组件）
│  │  收入  ¥3,200  支出  ¥1,580  │    │    margin: 16
│  │           结余  ¥1,620       │    │
│  └──────────────────────────────┘    │
│                                      │
│  ┌───────────────┬──────────────┐    │  ← 图表类型切换
│  │  支出分布     │  收支趋势    │    │    左右各占 1/2，高度 36vp
│  │  (主题色底)   │  (灰色底)    │    │    padding: 16 左右，8 上下
│  └───────────────┴──────────────┘    │
│  ────────────────────────────────    │
│                                      │
│  ┄┄┄┄┄┄[ 饼图区 / 柱状图区 ]┄┄┄┄┄   │  ← 根据 chartType 显示
│                                      │
│  ┄┄┄┄┄┄[ 图例/明细列表 ]┄┄┄┄┄┄┄┄    │  ← 饼图模式专属
│                                      │
└──────────────────────────────────────┘
```

---

## 4.3 饼图模式布局

```
┌──────────────────────────────────────┐
│                                      │
│            ╭───────────────╮         │  ← Canvas，高度 260vp，宽度 100%
│         ╭──┤  ¥1,580.00    ├──╮      │    圆环（外半径 40%，内半径 22%）
│        ╱   └───────────────┘   ╲     │    扇形间距 0.02 rad
│       │       总支出              │    │    起始角 -π/2（顶部）
│        ╲                       ╱     │    颜色来自各分类主题色
│         ╰───────────────────╯        │
│                                      │
└──────────────────────────────────────┘

┌──────────────────────────────────────┐  ← 图例列表卡片（白底圆角 12）
│  ● 餐饮     ¥580.00          36%     │  ← 每行：色块(12×12)+分类+金额+占比
│  ────────────────────────────────    │
│  ● 交通     ¥320.00          20%     │
│  ────────────────────────────────    │
│  ● 购物     ¥280.00          18%     │
│  ────────────────────────────────    │
│  ● 其他     ¥400.00          25%     │
└──────────────────────────────────────┘
margin: 16，padding: 16
```

**饼图圆心文字：**

```
第一行：¥1,580.00   16px bold，#212121
第二行：总支出       12px，#9E9E9E
```

**饼图空状态：**

```
灰色全圆（#E0E0E0）+ 内圆（白色）+ 中心文字"暂无数据"（#9E9E9E）
```

---

## 4.4 柱状图模式布局

```
┌──────────────────────────────────────┐
│                                      │
│  ¥3000  ┤ · · · · · · · · · · · ·   │  ← Canvas，高度 260vp
│  ¥2000  ┤ · · · · · · · · · · · ·   │    Y轴：5条虚线刻度（#E0E0E0，4px间隔）
│  ¥1000  ┤ · · · · · ·█ · · · · · ·  │    Y轴标签：右对齐，50px左边距
│       0 └─────────────────────────── │    X轴：底部30px
│          10月 11月 12月 1月  2月  3月  │
│                                      │
│  ■ 收入（蓝 #2196F3）  ■ 支出（红 #F44336）│  ← 图例
└──────────────────────────────────────┘

每月双柱：
  slotWidth = chartWidth / 6
  barWidth = slotWidth × 0.35（每根）
  gap = slotWidth × 0.1（双柱间距）
  蓝色柱（收入）在左，红色柱（支出）在右
```

---

## 4.5 页面状态

| 变量 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `currentMonth` | `string` | `DateUtil.currentMonth()` | 当前浏览月份，格式 YYYY-MM |
| `chartType` | `string` | `'pie'` | `'pie'` 或 `'bar'` |
| `incomeTotal` | `number` | `0` | 当月收入总额（分） |
| `expenseTotal` | `number` | `0` | 当月支出总额（分） |
| `categoryStats` | `CategoryStat[]` | `[]` | 饼图数据（含占比） |
| `monthStats` | `MonthStat[]` | `[]` | 近6个月数据，柱状图用 |
| `isLoading` | `boolean` | `false` | 加载状态 |

---

## 4.6 交互需求

| 编号 | 触发条件 | 响应行为 |
|------|----------|---------|
| ST-01 | `aboutToAppear` | `loadData()`：依次加载月度汇总 + 分类统计 + 月趋势 |
| ST-02 | 点击 "<" 上月按钮 | `currentMonth = getPrevMonth(currentMonth)` → `loadData()` |
| ST-03 | 点击 ">" 下月按钮 | 仅当非当月时可点击；`currentMonth = getNextMonth(currentMonth)` → `loadData()` |
| ST-04 | 当月时点击 ">" | 按钮灰色，`enabled: false`，不响应 |
| ST-05 | 点击"支出分布" | `chartType = 'pie'`，饼图区域显示，图例列表显示 |
| ST-06 | 点击"收支趋势" | `chartType = 'bar'`，柱状图区域显示，图例列表隐藏 |
| ST-07 | `categoryStats` 数据变更（`@Watch`） | `PieChart.redraw()` 重绘 Canvas |
| ST-08 | `monthStats` 数据变更（`@Watch`） | `BarChart.redraw()` 重绘 Canvas |
| ST-09 | 饼图无数据 | 绘制灰色全圆 + 白色内圆 + "暂无数据"文字，图例列表显示"本月暂无支出记录" |
| ST-10 | 柱状图某月无数据 | 该月柱高度为 0，X 轴标签正常显示 |

---

## 4.7 数据流

```
loadData() 并发执行三个查询：

① loadMonthSummary()
     BillDao.queryByFilter({ month: currentMonth, type: 'all' })
         ↓ Bill[]
     遍历计算 incomeTotal / expenseTotal
         ↓
     SummaryCard 更新

② loadCategoryStats()
     BillDao.queryCategoryStats(currentMonth, 'expense')
         ↓ SQL: GROUP BY category, 计算 percent
     categoryStats 更新
         ↓ @Watch 触发
     PieChart.redraw()

③ loadMonthStats()
     DateUtil.getLast6Months(currentMonth)   → ['2025-10','2025-11',...,'2026-03']
         ↓
     BillDao.queryMonthStats(months)
         ↓ MonthStat[]（每月收/支合计）
     monthStats 更新
         ↓ @Watch 触发
     BarChart.redraw()
```

---

## 4.8 图表绘制规范

**PieChart Canvas 绘制步骤：**

```
1. clearRect(0, 0, width, height)
2. 若 data 为空 → 绘制空状态（灰圆 + 白内圆 + 文字）→ return
3. cx = width/2, cy = height/2
   outerR = min(width,height) × 0.4
   innerR = outerR × 0.55
4. startAngle = -π/2
5. for each stat:
   sliceAngle = stat.percent/100 × 2π - 0.02（间距）
   ctx.beginPath()
   ctx.arc(cx, cy, outerR, startAngle, startAngle + sliceAngle)
   ctx.arc(cx, cy, innerR, 反向)  ← 圆环效果
   ctx.fillStyle = stat.color → ctx.fill()
   startAngle += sliceAngle + 0.02
6. 绘制白色内圆（遮盖）
7. 圆心绘制总金额 + "总支出"标签
```

**BarChart Canvas 绘制步骤：**

```
1. clearRect(0, 0, width, height)
2. 绘制 Y 轴（实线）+ X 轴（实线）
3. 计算 maxVal = max(所有 income, expense)，若为0则取100
4. for i = 0..5（5条刻度线）:
   y = bottom - i/5 × chartHeight
   绘制虚线（setLineDash([4,4])）
   绘制 Y 轴标签（AmountUtil.shortFormat(i/5 × maxVal)）
5. for each month（6个）:
   incomeX = slotCenter - gap/2 - barWidth
   expenseX = slotCenter + gap/2
   蓝色矩形（收入）+ 红色矩形（支出）
   X 轴月份标签（MM月）
6. 绘制图例（■收入 ■支出）
```

---

## 4.9 边界情况

| 场景 | 处理方式 |
|------|---------|
| 某分类占比极小（< 2%） | 扇形正常绘制，不显示文字标签（防遮挡） |
| 近6个月全部无数据 | BarChart 绘制坐标轴，所有柱高度为 0 |
| 切换月份时数据加载中 | `isLoading = true`，显示 LoadingProgress 覆盖图表区 |
| Canvas 容器宽度为 0 | `onReady` 中判断 `ctx.width === 0` 则 return，不绘制 |
| 当月收支均为 0 | SummaryCard 三项均显示 `¥0.00`，结余黑色 |

---

---

# 页面 5 · Settings · 预算设置（P2 可选）

---

## 5.1 页面职责

为每个支出分类设置月度预算上限，在录入账单时超额提醒用户。

---

## 5.2 页面入口

从账单列表页右上角设置图标（⚙️）进入，使用 `router.pushUrl` 跳转（独立路由页面，需注册到 `main_pages.json`）。

---

## 5.3 页面布局

```
┌──────────────────────────────────────┐
│  ←  预算设置                          │  ← 顶部导航栏（NavigationBar 或自定义）
│  ──────────────────────────────────  │
│                                      │
│  🍜  餐饮                [¥   500]   │  ← 每行：图标(20fp) + 分类名(16fp)
│  ──────────────────────────────────  │    + TextInput 右对齐(inputType NUMBER)
│  🚇  交通                [¥   300]   │    placeholder "0（不限制）"
│  ──────────────────────────────────  │
│  🛍️  购物                [¥   800]   │
│  ──────────────────────────────────  │
│  🎮  娱乐                [¥   200]   │
│  ──────────────────────────────────  │
│  🏠  住房                [¥  2000]   │
│  ──────────────────────────────────  │
│  💊  医疗                [¥   500]   │
│  ──────────────────────────────────  │
│  📚  教育                [¥   300]   │
│  ──────────────────────────────────  │
│  📦  其他                [¥   200]   │
│  ──────────────────────────────────  │
│                                      │
│   💡 设置为 0 表示不限制该分类预算    │  ← 说明文字，12fp 灰色，居中
│                                      │
└──────────────────────────────────────┘
```

---

## 5.4 数据存储

使用 `@ohos.data.preferences`（轻量键值存储）：

| Key | Value | 说明 |
|-----|-------|------|
| `budget_餐饮` | `"50000"` | 预算金额（分），字符串存储 |
| `budget_交通` | `"30000"` | 同上 |
| … | … | 每个支出分类一个 key |

---

## 5.5 交互需求

| 编号 | 触发条件 | 响应行为 |
|------|----------|---------|
| SE-01 | 页面进入 | 读取 Preferences 中各分类预算，填入对应输入框；无记录则显示空 |
| SE-02 | 修改输入框（`onChange`） | 实时保存到 Preferences（`preferences.put(key, value)`），无需确认按钮 |
| SE-03 | 输入框失焦 | 若为空，Preferences 存入 `"0"`（表示不限制） |
| SE-04 | 输入值为 `0` | 表示该分类不设预算，不触发提醒 |
| SE-05 | 点击返回 | `router.back()`，返回账单列表 |

---

## 5.6 预算超额提醒（在 AddBill 中触发）

在 AddBill 的 `onSave()` 中，验证通过后、写库前执行：

```
if (billType !== 'expense') → 跳过预算检查，直接写库

读取 preferences.get('budget_' + selectedCategory, '0')
    ↓
budget = parseInt(value) → 单位：分

budget === 0 → 直接写库（不限制）

查询本月该分类已支出：
  BillDao.queryCategoryStats(currentMonth, 'expense')
      ↓ 找到对应分类的 total
  used = total（分）

used + fen > budget ？
    ↓ YES
  AlertDialog.show({
    title: '⚠️ 预算超额提醒',
    message: `${selectedCategory}本月预算 ¥${budget/100}，
              已支出 ¥${used/100}，
              本次记录后将超出 ¥${(used+fen-budget)/100}。`,
    primaryButton: { value: '取消', action: () => {} },
    secondaryButton: { value: '仍然保存', action: () => { doInsert() } }
  })
    ↓ NO
  直接写库
```

---

## 5.7 边界情况

| 场景 | 处理方式 |
|------|---------|
| Preferences 读取失败 | 默认预算为 0（不限制），不影响正常记账 |
| 输入框粘贴超大数字 | 限制最大值为 999999（元），折合分存储时上限 99999900 |
| 同月已删除部分账单 | 超额计算基于当月实际留存账单，动态更新 |

---

---

# 附录 A · 异常处理汇总

| 场景 | 页面 | 处理方式 |
|------|------|---------|
| 数据库初始化失败 | EntryAbility | `showDialog("初始化失败，请重启")` |
| 查询无结果 | BillList / Statistics | 显示对应空状态视图，不报错 |
| 插入失败 | AddBill | `showToast("保存失败，请重试")`，表单保留 |
| 删除失败 | BillList | `showToast("删除失败，请重试")` |
| Canvas 宽度为 0 | PieChart / BarChart | `onReady` 判断后不绘制 |
| Preferences 读写失败 | Settings | 默认值兜底，`hilog` 记录错误 |

---

# 附录 B · 数据流总览

```
┌─────────────────────────────────────────────────────┐
│                     SQLite bills 表                  │
└──────────────┬──────────────────────────────────────┘
               │
    ┌──────────┼──────────┐
    │          │          │
    ▼          ▼          ▼
AddBill     BillList   Statistics
 insert()  queryByFilter  queryCategoryStats
           groupByDate()  queryMonthStats
    │          │          │
    │          ▼          ▼
    │     BillGroup     PieChart
    │     BillItem      BarChart
    │     SummaryCard
    │          │
    └──────────┘
     activeTabIndex = 0
     触发 BillList.loadData()
```
