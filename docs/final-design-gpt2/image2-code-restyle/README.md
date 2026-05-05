# 小金鱼记账 Image2 代码对齐重绘稿

本文件夹包含根据 `docs/final-design-gpt2/正式-pages` 的 10 张参考图，以及当前 ArkTS 页面/组件结构重新生成的 Image2 高保真页面稿。

## 输出文件

- `01_home.png`：账单首页，对应 `BillList.ets`、`SummaryCard.ets`、`BillItem.ets`、`MonthSelector.ets`
- `02_add_bill.png`：记账页，对应 `AddBill.ets`、`CategoryGrid.ets`
- `03_search.png`：搜索筛选页，对应 `BillSearchPage.ets`、`SearchResultItem.ets`
- `04_settings_budget.png`：设置 / 预算页，对应 `Settings.ets`
- `05_calendar.png`：日历页，对应 `Calendar.ets`、`CalendarView.ets`
- `06_statistics.png`：统计页，对应 `Statistics.ets`、`StyledPieChart.ets`、`StyledBarChart.ets`
- `07_category_manage_expense.png`：支出分类管理页，对应 `CategoryManage.ets`
- `08_category_manage_income.png`：收入分类管理页，对应 `CategoryManage.ets`
- `09_edit_category_modal.png`：编辑分类弹窗，对应 `CategoryEditDialog.ets`
- `10_edit_icons_page.png`：编辑图标页，对应分类编辑入口 / 图标批量编辑流程
- `_contact_sheet.png`：10 张页面总览图，便于快速检查风格一致性

## 设计调整原则

- 页面主背景统一为浅水蓝，保持学生群体需要的清爽感。
- 关键账务摘要使用深青水色，增强信息权重和专业感。
- 金鱼元素只放在背景、摘要卡、空状态、弹窗角落等非交互区域。
- 按钮、Tab、筛选 Chip、分类图标选中态保持简单，方便 ArkUI 落地。
- 主按钮使用金鱼橙，支出金额使用珊瑚红，收入金额使用绿色。
- 不使用复杂发光、双层气泡、渐变描边、复杂鱼鳞选中态。

## 后续代码落地建议

- 先统一 `color.json` 色板，再逐页替换背景色、按钮色、摘要卡渐变。
- `SummaryCard.ets` 优先调整为深青水色，并加入极简水波线或静态背景图。
- `NavBar.ets`、`MonthSelector.ets`、`FilterBar.ets` 保持结构不变，只调整圆角、间距、颜色。
- 分类图标选中态只改圆底色和图标色，不增加复杂装饰。
- 金鱼、水波、气泡建议拆成少量静态 PNG/SVG 资源，通过 `Image($r/$rawfile)` 放入背景层。
