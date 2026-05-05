# 小金鱼记账设计图与拆分资源清单

## 成品页面图

| 文件 | 用途 |
| --- | --- |
| `xjy_finished_pages_board.png` | 6 个页面总览设计板 |
| `page_home.png` | 账单首页成品稿 |
| `page_add_bill.png` | 记账页成品稿 |
| `page_calendar.png` | 日历页成品稿 |
| `page_search.png` | 搜索页成品稿 |
| `page_stats.png` | 统计页成品稿 |
| `page_settings.png` | 设置页成品稿 |

## 拆分资源

| 文件 | 用途 |
| --- | --- |
| `assets/xjy_app_icon.png` | App 主图标，1024 x 1024 |
| `assets/xjy_goldfish_mark.png` | 小金鱼品牌图形，透明背景 |
| `assets/xjy_header_bg.png` | 顶部水感背景图 |
| `assets/xjy_summary_card_bg.png` | 统计/首页摘要卡片背景 |
| `assets/xjy_empty_bill.png` | 空状态插图 |
| `assets/tab_bill_active.png` | 底部 Tab：账单选中 |
| `assets/tab_bill_inactive.png` | 底部 Tab：账单未选中 |
| `assets/tab_calendar_active.png` | 底部 Tab：日历选中 |
| `assets/tab_calendar_inactive.png` | 底部 Tab：日历未选中 |
| `assets/tab_add.png` | 底部中间新增按钮图标 |
| `assets/tab_stats_active.png` | 底部 Tab：统计选中 |
| `assets/tab_stats_inactive.png` | 底部 Tab：统计未选中 |
| `assets/tab_settings_active.png` | 底部 Tab：设置选中 |
| `assets/tab_settings_inactive.png` | 底部 Tab：设置未选中 |
| `assets/cat_food.png` | 分类：餐饮 |
| `assets/cat_transport.png` | 分类：交通 |
| `assets/cat_shopping.png` | 分类：购物 |
| `assets/cat_entertainment.png` | 分类：娱乐 |
| `assets/cat_housing.png` | 分类：住房 |
| `assets/cat_medical.png` | 分类：医疗 |
| `assets/cat_education.png` | 分类：教育 |
| `assets/cat_other.png` | 分类：其他 |

## 接入建议

- App 图标可先替换 `entry/src/main/resources/base/media/startIcon.png`，确认效果后再处理 `foreground.png` 和 `background.png`。
- Tab 与分类图标建议先放入 `entry/src/main/resources/base/media`，命名保持 `xjy_` 或 `tab_` 前缀，避免和旧鸭子资源冲突。
- 背景类图片可以只用于页面顶部和摘要卡片，不建议全页面铺满，避免干扰账单信息阅读。
