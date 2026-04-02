# 鸭鱼算 · Claude 项目文档

## 基本信息

| 项目 | 值 |
|------|----|
| 应用名 | 鸭鱼算（YaYuSuan） |
| 平台 | HarmonyOS 6.0.2(22)，兼容 phone + tablet |
| 语言 | ArkTS（严格模式：caseSensitiveCheck + useNormalizedOHMUrl） |
| 入口 Ability | `entry/src/main/ets/entryability/EntryAbility.ets` |
| 入口页面 | `pages/Index`（当前为 Hello World 占位，需完全重写） |

---

## 目录结构

```
entry/src/main/ets/
├── entryability/
│   └── EntryAbility.ets          # 应用入口；需在 onCreate() 中初始化数据库
├── pages/
│   ├── Index.ets                 # Tab 主容器（底部导航），当前需重写
│   ├── BillList.ets              # 账单列表页
│   ├── AddBill.ets               # 账单录入页
│   ├── Statistics.ets            # 统计图表页
│   └── Settings.ets              # 预算设置页（可选）
├── components/
│   ├── BillItem.ets              # 单条账单列表项（支持右滑删除）
│   ├── BillGroup.ets             # 按日期分组的账单块
│   ├── FilterBar.ets             # 账单列表筛选栏
│   ├── SummaryCard.ets           # 收支汇总卡片
│   ├── CategoryGrid.ets          # 分类图标宫格选择器
│   ├── PieChart.ets              # Canvas 饼图
│   └── BarChart.ets              # Canvas 柱状图（近6个月）
├── database/
│   ├── DBHelper.ets              # RelationalStore 单例，建表逻辑
│   └── BillDao.ets               # 账单 CRUD 数据访问层
├── model/
│   ├── Bill.ets                  # 账单 interface + 默认值工厂函数
│   ├── Category.ets              # 分类枚举、图标资源名、颜色映射
│   ├── FilterOptions.ets         # 列表筛选条件模型
│   └── StatResult.ets            # 统计结果模型（CategoryStat / MonthStat）
└── utils/
    ├── DateUtil.ets              # 日期格式化（时间戳↔YYYY-MM-DD）
    ├── AmountUtil.ets            # 金额工具（分↔元，格式化显示）
    └── FileUtil.ets              # 文件导入导出工具（可选）
```

新增页面必须同步注册到 `entry/src/main/resources/base/profile/main_pages.json`。

---

## 数据模型

### Bill（账单）

```typescript
interface Bill {
  id: number                      // 主键，自增，查询返回时填充
  amount: number                  // 金额，以"分"为单位（整数），避免浮点精度问题
  type: 'income' | 'expense'      // 收入 / 支出
  category: string                // 分类名，取值来自 Category 枚举
  remark: string                  // 备注（可为空字符串）
  date: string                    // 日期，格式严格为 YYYY-MM-DD
  createdAt: number               // 创建时间戳（毫秒），用于导入去重
}
```

### FilterOptions（筛选条件）

```typescript
interface FilterOptions {
  month: string                   // 格式 YYYY-MM，空字符串表示不限
  type: 'all' | 'income' | 'expense'
  category: string                // 空字符串表示全部分类
}
```

### CategoryStat（饼图数据）

```typescript
interface CategoryStat {
  category: string
  total: number                   // 单位：分
  percent: number                 // 0~1
  color: string                   // 16进制颜色
}
```

### MonthStat（柱状图数据）

```typescript
interface MonthStat {
  month: string                   // 格式 YYYY-MM
  income: number                  // 单位：分
  expense: number                 // 单位：分
}
```

### 分类定义（Category.ets）

| 类型 | 分类列表 |
|------|---------|
| 支出 | 餐饮、交通、购物、娱乐、住房、医疗、教育、其他 |
| 收入 | 工资、兼职、理财、红包、其他 |

每个分类对应：图标资源名（`$media:xxx`）+ 主题色（16进制）。

---

## 页面详细设计

### Index.ets · Tab 主容器

**职责：** 承载底部导航，管理 3 个子页面的切换。

**UI 结构：**
```
Tabs(barPosition: BarPosition.End)
├── TabContent → BillList 页面
├── TabContent → AddBill 页面
└── TabContent → Statistics 页面
```

**状态：**
- `@State currentIndex: number = 0`

**注意：** AddBill Tab 点击后提交成功需通知 BillList 刷新，使用 `@Provide`/`@Consume` 或 EventHub 实现跨页通信。

---

### BillList.ets · 账单列表页

**职责：** 展示按日期分组的账单，支持筛选、滑动删除。

**UI 结构：**
```
Column
├── SummaryCard            # 当前筛选条件下的收支汇总
├── FilterBar              # 月份 + 类型筛选
└── List
    └── BillGroup × N      # 每个日期一组
        └── BillItem × N   # 每条账单
```

**状态：**
- `@State billGroups: BillGroupData[] = []`（按日期聚合后的数据）
- `@State filter: FilterOptions`（当前筛选条件）
- `@State totalIncome: number = 0`
- `@State totalExpense: number = 0`

**交互逻辑：**
- 页面 `onPageShow` 时重新查询数据（处理从 AddBill 返回后的刷新）
- `FilterBar` 的筛选变化触发重新查询
- `BillItem` 右滑删除 → `BillDao.deleteById()` → 重新查询
- 无数据时展示空状态插图 + 文字提示

---

### AddBill.ets · 账单录入页

**职责：** 录入一条账单，表单验证后写入数据库。

**UI 结构：**
```
Column
├── 收入/支出 切换         # 自定义 Segment，切换时分类列表同步更新
├── 金额显示区             # 大字体显示，点击激活输入
├── TextInput（金额）      # inputType: NUMBER_DECIMAL，隐藏或置于底部
├── CategoryGrid           # 4列图标宫格，当前选中高亮
├── 日期选择行             # 显示已选日期，点击弹出 DatePickerDialog
├── 备注输入行             # TextInput，maxLength: 50，placeholder "选填"
└── 提交按钮               # 验证通过后调用 BillDao.insert()
```

**状态：**
- `@State billType: 'income' | 'expense' = 'expense'`
- `@State amountText: string = ''`
- `@State selectedCategory: string = ''`
- `@State selectedDate: string`（默认今天，格式 YYYY-MM-DD）
- `@State remark: string = ''`

**表单验证：**
- 金额不能为空且必须 > 0
- 分类必须选择
- 金额超过2位小数自动截断

**提交后：** 清空表单，切换到账单列表 Tab（`currentIndex = 0`）。

---

### Statistics.ets · 统计图表页

**职责：** 可视化展示指定月份的收支结构与近半年趋势。

**UI 结构：**
```
Column
├── 月份导航栏             # "< 2026-03 >" 左右箭头切换
├── 月度汇总卡片           # 收入 / 支出 / 结余
├── 图表类型切换           # Tabs 或 Toggle：饼图 / 柱状图
├── PieChart 或 BarChart   # Canvas 图表区域，高度固定 250vp
└── 分类明细列表           # 饼图模式下显示各分类金额+占比
```

**状态：**
- `@State currentMonth: string`（格式 YYYY-MM，默认当月）
- `@State chartType: 'pie' | 'bar' = 'pie'`
- `@State categoryStats: CategoryStat[] = []`
- `@State monthStats: MonthStat[] = []`（柱状图用近6个月）

**注意：** 月份切换时同时刷新两种图表数据。

---

### Settings.ets · 预算设置页（可选）

**职责：** 为各支出分类设置每月预算上限，超额时触发提醒。

**UI 结构：**
```
List
└── 每个支出分类一行
    ├── 分类图标 + 名称
    └── TextInput（预算金额，元为单位）
```

**存储：** `@ohos.data.preferences`，key 为 `budget_${category}`，value 为分为单位的整数字符串。

---

## 组件详细设计

### BillItem.ets

**Props：**
- `@Prop bill: Bill`
- `@Prop onDelete: () => void`

**布局：** 水平三段式
```
Row
├── 左：分类图标（圆形背景，颜色取自 Category 配置）
├── 中：category 名称（主文字）+ remark（次文字，灰色）
└── 右：金额（收入绿色 #4CAF50，支出红色 #F44336）
```

**滑动删除：** `ListItem.swipeAction({ end: 删除按钮 })`

---

### BillGroup.ets

**Props：**
- `@Prop date: string`（YYYY-MM-DD）
- `@Prop bills: Bill[]`
- `@Prop dayIncome: number`
- `@Prop dayExpense: number`

**布局：**
```
Column
├── 日期头：左侧"MM月DD日 星期X"，右侧当日净额
└── 内嵌 ForEach → BillItem
```

---

### FilterBar.ets

**Props：**
- `@Prop filter: FilterOptions`
- `onFilterChange: (f: FilterOptions) => void`

**布局：** 横向滚动 Row
```
Row
├── 月份按钮（点击弹出 DatePickerDialog，仅选年月）
└── 类型 Chip 组：全部 / 收入 / 支出
```

---

### SummaryCard.ets

**Props：**
- `@Prop income: number`（分）
- `@Prop expense: number`（分）

**布局：** 卡片三列
```
Row: 收入(绿) | 支出(红) | 结余(黑/红)
```

---

### CategoryGrid.ets

**Props：**
- `@Prop billType: 'income' | 'expense'`
- `@Prop selected: string`
- `onSelect: (category: string) => void`

**布局：** `Grid`，4列，根据 `billType` 显示对应分类列表，选中项高亮边框。

---

### PieChart.ets

**Props：**
- `@Prop data: CategoryStat[]`

**绘制流程（必须在 `onReady` 回调内执行）：**
1. 计算圆心、半径（取 canvas 宽高最小值的 40%）
2. 遍历 `data`，累加 `startAngle`，调用 `ctx.arc()` 绘制扇形
3. 圆心绘制总金额文字
4. Canvas 下方 `ForEach` 渲染图例行（色块 + 分类名 + 金额 + 占比）

**空数据处理：** 绘制灰色全圆 + "暂无数据"文字。

---

### BarChart.ets

**Props：**
- `@Prop data: MonthStat[]`（长度固定为6，不足补零）

**绘制流程（必须在 `onReady` 回调内执行）：**
1. 计算 Y 轴最大值（取所有 income/expense 最大值，向上取整到整百）
2. 绘制 Y 轴刻度线（5条虚线）+ 金额标签
3. 每月绘制双柱（收入蓝 #2196F3，支出红 #F44336），柱宽 = 槽宽 × 0.3
4. X 轴绘制月份标签（MM月）

---

## 数据库规范

- **引擎**：`@ohos.data.relationalStore`（SQLite）
- **表名**：`bills`
- **建表 SQL**：

```sql
CREATE TABLE IF NOT EXISTS bills (
  id        INTEGER PRIMARY KEY AUTOINCREMENT,
  amount    INTEGER NOT NULL,
  type      TEXT    NOT NULL,
  category  TEXT    NOT NULL,
  remark    TEXT    DEFAULT '',
  date      TEXT    NOT NULL,
  createdAt INTEGER NOT NULL
)
```

- `DBHelper` 为单例，`EntryAbility.onCreate()` 中调用 `DBHelper.init(context)`
- 所有数据库操作必须 `async/await`，禁止同步阻塞主线程
- 失败时调用 `promptAction.showToast()` 提示用户

**BillDao 对外接口：**

| 方法 | 说明 |
|------|------|
| `insert(bill: Bill): Promise<number>` | 插入并返回新 id |
| `deleteById(id: number): Promise<void>` | 按 id 删除 |
| `queryByFilter(f: FilterOptions): Promise<Bill[]>` | 条件查询，按 date DESC 排序 |
| `queryMonthStats(months: string[]): Promise<MonthStat[]>` | 批量查询多月统计 |
| `queryCategoryStats(month: string, type: string): Promise<CategoryStat[]>` | 指定月份分类统计 |

---

## 资源规范

### 颜色（color.json）—— 需扩充

| name | 用途 | 建议值 |
|------|------|--------|
| `start_window_background` | 启动页背景（已有） | `#FFFFFF` |
| `color_income` | 收入金额文字 | `#4CAF50` |
| `color_expense` | 支出金额文字 | `#F44336` |
| `color_primary` | 主题色 | `#1976D2` |
| `color_surface` | 卡片背景 | `#F5F5F5` |
| `color_text_secondary` | 次要文字 | `#757575` |

### 字体尺寸（float.json）—— 需扩充

| name | 用途 | 建议值 |
|------|------|--------|
| `page_text_font_size` | 已有，暂不使用 | `50fp` |
| `font_amount_large` | 录入页金额大字 | `48fp` |
| `font_title` | 页面标题 | `20fp` |
| `font_body` | 正文 | `16fp` |
| `font_caption` | 辅助文字 | `12fp` |

---

## 设计规范

### 调色板（Design Token）

全局只允许使用下表中的颜色，禁止在 `.ets` 中出现其他颜色字符串（Canvas 绘图除外）。

| Token | 色值 | 用途 |
|-------|------|------|
| Primary | `#1976D2` | 主按钮、激活状态、链接、焦点环 |
| Surface | `#FFFFFF` | 卡片背景、导航栏、弹窗背景 |
| Background | `#F5F5F5` | 页面底色、未激活 Chip 背景 |
| Text Primary | `#212121` | 主要文字 |
| Text Secondary | `#757575` | 辅助文字、占位符、未激活图标 |
| Divider | `#E0E0E0` | 分割线、边框 |
| Income | `#4CAF50` | 收入金额、收入相关正向状态 |
| Expense | `#F44336` | 支出金额、删除/危险操作 |
| Primary Tint | `#E3F2FD` | 筛选按钮/切换按钮的浅蓝背景 |
| Primary Light | `#64B5F6` | 深色弹出菜单中的选中高亮文字 |

**灰色约束**：只允许 `#757575`（次要文字/图标）和 `#E0E0E0`（分割线）两种灰色。
禁止使用：`#9E9E9E`、`#BDBDBD`、`#666666`、`#EEEEEE`、`#F0F0F0`。

### 图标规范

- 图标格式：Material Design SVG，存放于 `rawfile/`，文件名 `icon_*.svg`
- SVG 文件不含 `fill` 属性，颜色通过 `.fillColor()` 动态设置
- 激活/主色图标：`#1976D2`；未激活/辅助图标：`#757575`；危险操作图标：`#F44336`
- 功能图标尺寸：`20×20`；底部导航图标：`24×24`；空状态插图：`64×64`

### 字体层级

| 层级 | 字号 | 字重 | 颜色 | 用途 |
|------|------|------|------|------|
| 大金额 | 40fp | Bold | Text Primary | 录入页金额显示 |
| 标题 | 17fp | Medium | Text Primary | 导航栏标题 |
| 正文 | 15fp | Normal | Text Primary | 列表项主文字 |
| 辅助 | 13fp | Normal | Text Secondary | 筛选项、标签 |
| 说明 | 12fp | Normal | Text Secondary | 日期、占比、提示 |
| 极小 | 10–11fp | Normal | Text Secondary | 底部导航文字、分类名 |

---

## 技术选型

| 功能 | API | 备注 |
|------|-----|------|
| 关系型数据库 | `@ohos.data.relationalStore` | 主持久化方案 |
| 轻量配置存储 | `@ohos.data.preferences` | 仅用于预算等少量配置 |
| Canvas 绘图 | `CanvasRenderingContext2D` | 须在 `onReady` 回调内绘制 |
| 滑动删除 | `ListItem.swipeAction` | 右侧端点出现删除按钮 |
| 文件读写 | `@ohos.file.fs` | 导入导出，需声明权限 |
| 文件选择器 | `@ohos.file.picker` | DocumentViewPicker |
| 弹窗提示 | `@ohos.promptAction` | showToast / showDialog |

---

## 开发计划与进度

| 阶段 | 核心任务 | 涉及文件 | 状态 |
|------|---------|---------|------|
| Day 1 | 数据模型 + 数据库层 + Tab 主框架 | `model/*`, `database/*`, `Index.ets`, `EntryAbility.ets` | ✅ 已完成 |
| Day 2 | 账单录入页 | `AddBill.ets`, `CategoryGrid.ets` | ✅ 已完成 |
| Day 3 | 账单列表页 | `BillList.ets`, `BillItem.ets`, `BillGroup.ets`, `FilterBar.ets`, `SummaryCard.ets` | ✅ 已完成 |
| Day 4 | 统计图表页 | `Statistics.ets`, `PieChart.ets`, `BarChart.ets` | ✅ 已完成 |
| Day 5 | 预算提醒（可选） | `Settings.ets`, `BillDao.ets`（超额检查） | ✅ 已完成（Settings UI + preferences 存储 + 超额 Toast） |
| Day 6 | 数据导出（可选） | `Settings.ets` | ✅ 已完成（CSV 导出 + DocumentViewPicker） |
| Day 7 | 资源完善、UI 打磨、联调测试 | `color.json`, `float.json`, `string.json` | ✅ 已完成（颜色 token 规范、沉浸式、动画优化） |

---

## 实际交付与规范偏差说明

| 项目 | 规范要求 | 实际交付 | 备注 |
|------|---------|---------|------|
| Tab 数量 | 3 个（账单/记账/统计） | 4 个（+设置） | 设置页单独 Tab，更易发现 |
| FilterBar | 独立组件供 BillList 使用 | BillList 内联实现筛选 Chip | FilterBar.ets 保留备用 |
| PieChart 图例 | Canvas 下方 ForEach 渲染 | Statistics.ets 中独立渲染 | 组件职责分离更清晰 |
| BarChart 图例 | Canvas 下方 | Canvas 内部底部绘制 | 一体感更强 |
| 颜色引用 | 统一 `$r('app.color.xxx')` | 大量硬编码（Canvas 除外） | ArkUI 组件链式调用中 `$r()` 受限，实际以 design token 字符串统一 |
| IS_DEBUG | 发布前改 false | true | 开发阶段保持，发布前切换 |

---

## 编码规范

- 文件名：大驼峰，如 `BillItem.ets`、`DateUtil.ets`
- 组件 `@State` 只在本页面定义；跨组件传值优先用 `@Prop`（单向）/`@Link`（双向）；跨页通信用 `AppStorage` 或 `EventHub`
- **金额**：数据库与内存中统一以"分"（整数）存储；UI 显示时调用 `AmountUtil.fen2Yuan()` 转换
- **颜色**：禁止在 `.ets` 中硬编码颜色字符串，统一引用 `$r('app.color.xxx')`；图表绘制中 Canvas 颜色除外（Canvas API 不支持资源引用）
- **异步**：数据库和文件操作全部使用 `async/await`，禁止 `.then().catch()` 混用
- 页面跳转使用 `router.pushUrl`；Tab 切换通过修改 `currentIndex` 实现，不使用路由
