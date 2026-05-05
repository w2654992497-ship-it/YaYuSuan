# Image2 金鱼游记风重绘提示词

## 通用基底

每张图先带上这段：

```text
Use case: ui-mockup
Asset type: high-fidelity standalone mobile app screen.
Primary request: Redesign this bookkeeping app screen for the student-focused brand "小金鱼记账" using a new youthful visual language called "Goldfish Journey".

Use goldfish elements as a systematic visual language, not childish cartoons: goldfish silhouettes, fish-tail curves, water trails, bubble tags, and subtle fish-scale textures. Increase goldfish brand presence, but keep the UI practical and readable.

The style should be young, warm, fresh, and suitable for students. Keep the background light water blue, use deep teal for key financial cards, use goldfish orange for primary actions and selected states, and use coral red/green only for expense/income semantics.

Do not copy the old layout exactly. Keep the business function, but redesign the composition, spacing, cards, navigation, and visual rhythm. Cards can feel more flowing, with curved water dividers and bubble chips. Avoid large flat yellow headers, avoid childish sticker fish, avoid realistic fish, avoid heavy illustration, avoid dark mode.

Make Chinese UI text legible. Output a standalone full mobile app screen, not a design board, not a crop, no device frame, no watermark.

Color palette: #EAF8FA light water blue background, #CFF3F2 pale water, #0F6F73 deep teal, #17323D deep navy text, #FF8A3D goldfish orange, #FFD27A goldfish highlight, #F45D6C expense coral, #35B977 income green, #8FA1AF secondary gray, #E2EEF0 divider.

Implementation constraint: buttons and selected states must be simple and ArkUI-friendly. Main buttons are solid #FF8A3D with white text. Secondary buttons are white with light border. Selected chips are solid deep teal or orange with white text. Category icon selected state only changes circle fill to orange and icon to white; do not use glow, complex shadows, fish-scale textures, gradient borders, double bubble rings, or decorative tails inside interactive controls. Put complex goldfish/water visuals only in backgrounds, summary cards, empty states, and non-interactive illustrations.
```

## 01 首页

```text
Page: bill home page.
Keep functions: brand title 小金鱼记账, search entry, month selector 2026年4月, monthly balance/expense summary, income/expense/balance indicators, filter tabs 全部/收入/支出, one bill row 餐饮 / 猪脚饭 / -¥25.00, bottom tab bar.
Redesign direction: make "本月结余" or "本月概览" the hero, use a deep teal financial card with fish-tail water trails, bubble chips for filters, category icon with subtle fish-scale texture, one small goldfish silhouette near the summary card edge.
```

## 02 记账页

```text
Page: add bill page.
Keep functions: 支出/收入 switch, amount input ¥0.00, date 2026-04-29, category grid, note input, save action, bottom tab.
Redesign direction: amount input as a water-surface card, 支出/收入 as bubble segmented control, date as floating bubble, category grid as fish-scale badges, selected category in goldfish orange bubble, save button with fish-tail highlight.
```

## 03 搜索页

```text
Page: search and filter page.
Keep functions: search input, clear action, category filter, time range filter, result summary, income/expense/net totals, result list.
Redesign direction: search field as a long bubble, filters as bubble cards, result summary as a small flowing water card, matched result with pale goldfish highlight, low-opacity fish-tail wave at bottom.
```

## 04 设置 / 预算页

```text
Page: settings and budget page.
Keep functions: category management entrance, monthly budget list, save budget, export CSV, about row.
Redesign direction: student budget dashboard, budget rows as water-level cards, category management entrance with fish-scale badge, primary save button in goldfish orange, CSV export as quiet secondary action.
```

## 05 日历页

```text
Page: calendar page.
Keep functions: month selection, calendar grid, selected date 29, spending marker on 15, income/expense/balance summary, budget progress, today empty state.
Redesign direction: selected date with water ripple ring, daily records as tiny bubbles, month card with fish-tail curve, budget progress as waterline, empty state with floating bill paper and small bubble trail.
```

## 06 统计页

```text
Page: statistics page.
Keep functions: month selector, summary, structure/trend switch, donut chart, category ranking.
Redesign direction: professional but young analytics page, donut chart like a fish bubble ring, category ranking as flowing water progress bars, minimal goldfish silhouette in the header only.
```

## 07 分类管理：支出

```text
Page: expense category management.
Keep functions: back, title 分类管理, 支出/收入 switch, sorting hint, expense category list, default tag, edit action, add category.
Redesign direction: editable life-tag library, drag handles as bubble dots, default tags as small bubbles, category icons as fish-scale badges, add category button with dashed fish-scale border.
```

## 08 分类管理：收入

```text
Page: income category management.
Keep functions: income categories 工资/兼职/理财/红包/其他, drag handles, default tags, edit actions, add category.
Redesign direction: compact income tag library, calm green/gold/cyan income palette, small goldfish tail curve in the header, avoid awkward blank space with helper bubble note.
```

## 09 编辑分类弹窗

```text
Page/modal: edit category bottom sheet.
Keep functions: preview selected category, category name input, icon selection grid, color selection grid, cancel and confirm.
Redesign direction: bottom sheet with water-wave handle, preview card with fish-scale texture, icon grid as bubbles, color palette as fish-scale swatches, confirm button in goldfish orange.
```

## 10 编辑图标页

```text
Page: edit category icons page.
Keep functions: cancel, title 编辑分类, sort action, 支出/收入 switch, category icon grid, add, reset, complete.
Redesign direction: each category as an editable fish-scale badge tile, selected state with double bubble ring, bottom actions fixed and clear, page feels like organizing student life tags.
```

## 11 编辑图标弹窗

```text
Page/modal: icon selection bottom sheet.
Keep functions: selected category preview, icon picker grid, cancel and confirm.
Redesign direction: icon picker grid with pale water bubble backgrounds, selected icon with goldfish orange ring, subtle fish-tail curve behind modal title, compact and focused.
```
