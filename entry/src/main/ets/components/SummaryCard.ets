import { AmountUtil } from '../utils/AmountUtil'

@Component
struct SummaryIconView {
  @Prop icon: ResourceStr
  @Prop color: ResourceColor

  build() {
    Row() {
      Image(this.icon)
        .width(15)
        .height(15)
        .fillColor(this.color)
    }
    .width(28)
    .height(28)
    .borderRadius(14)
    .justifyContent(FlexAlign.Center)
    .backgroundColor($r('app.color.color_soft_blue'))
  }
}

@Component
struct SummaryMetricItem {
  @Prop title: string
  @Prop value: string
  @Prop hint: string
  @Prop valueColor: ResourceColor = $r('app.color.color_text_deep')

  build() {
    Column() {
      Text(this.title)
        .fontSize(12)
        .fontColor($r('app.color.color_text_secondary'))
        .maxLines(1)
      Text(this.value)
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.valueColor)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .margin({ top: 7 })
      Text(this.hint)
        .fontSize(11)
        .fontColor($r('app.color.color_text_secondary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .margin({ top: 5 })
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Start)
  }
}

@Component
struct BudgetMiniCard {
  @Prop title: string
  @Prop icon: ResourceStr
  @Prop color: ResourceColor
  @Prop limit: number = 0
  @Prop spent: number = 0

  private budgetPercent(): number {
    if (this.limit <= 0) {
      return 0
    }
    const percent = Math.floor((this.spent / this.limit) * 100)
    return Math.min(999, Math.max(0, percent))
  }

  private budgetProgressWidth(): string {
    if (this.limit <= 0) {
      return '0%'
    }
    const percent = Math.floor((this.spent / this.limit) * 100)
    return `${Math.min(100, Math.max(4, percent))}%`
  }

  private budgetAmountLabel(): string {
    if (this.limit <= 0) {
      return '未设置'
    }
    return `¥${AmountUtil.fen2Display(this.limit)}`
  }

  build() {
    Column() {
      Row({ space: 7 }) {
        SummaryIconView({ icon: this.icon, color: this.color })
        Column() {
          Text(this.title)
            .fontSize(13)
            .fontColor($r('app.color.color_text_secondary'))
            .maxLines(1)
          Text(this.budgetAmountLabel())
            .fontSize(this.limit > 0 ? 13 : 12)
            .fontColor(this.limit > 0 ? $r('app.color.color_text_secondary') : $r('app.color.color_text_muted'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ top: 3 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Row() {
        Text(`已用 ¥${AmountUtil.fen2Display(this.spent)}`)
          .fontSize(11)
          .fontColor($r('app.color.color_text_secondary'))
          .maxLines(1)
      }
      .width('100%')
      .margin({ top: 10 })

      Stack({ alignContent: Alignment.Start }) {
        Row()
          .width('100%')
          .height(5)
          .borderRadius(3)
          .backgroundColor($r('app.color.color_track'))
        Row()
          .width(this.budgetProgressWidth())
          .height(5)
          .borderRadius(3)
          .backgroundColor(this.color)
      }
      .width('100%')
      .margin({ top: 7 })
    }
    .layoutWeight(1)
    .height(86)
    .padding({ left: 9, right: 9, top: 10, bottom: 9 })
    .borderRadius(14)
    .backgroundColor($r('app.color.color_white'))
    .border({ width: 1, color: $r('app.color.color_divider') })
  }
}

@Component
export struct SummaryCard {
  @Prop filterType: string = 'all'
  @Prop billCount: number = 0
  @Prop income: number = 0
  @Prop expense: number = 0
  @Prop dayBudgetSpent: number = 0
  @Prop dayBudgetLimit: number = 0
  @Prop monthBudgetSpent: number = 0
  @Prop monthBudgetLimit: number = 0
  @Prop yearBudgetSpent: number = 0
  @Prop yearBudgetLimit: number = 0
  @Prop budgetRefreshVersion: number = 0

  private money(fen: number): string {
    return `¥${AmountUtil.fen2Display(fen)}`
  }

  private signedMoney(fen: number): string {
    if (fen > 0) {
      return `+${this.money(fen)}`
    }
    if (fen < 0) {
      return `-${this.money(0 - fen)}`
    }
    return this.money(0)
  }

  private balance(): number {
    return this.income - this.expense
  }

  private budgetRemain(): number {
    const remain = this.monthBudgetLimit - this.monthBudgetSpent
    if (remain <= 0) {
      return 0
    }
    return remain
  }

  private mainTitle(): string {
    if (this.filterType === 'expense') {
      return '本月支出'
    }
    if (this.filterType === 'income') {
      return '本月收入'
    }
    return '本月结余'
  }

  private mainAmount(): string {
    if (this.filterType === 'expense') {
      return this.money(this.expense)
    }
    if (this.filterType === 'income') {
      return this.money(this.income)
    }
    return this.money(this.balance())
  }

  private mainColor(): ResourceColor {
    if (this.filterType === 'income') {
      return $r('app.color.color_income')
    }
    return $r('app.color.color_text_deep')
  }

  private averageExpense(): number {
    if (this.billCount <= 0) {
      return 0
    }
    return Math.round(this.expense / this.billCount)
  }

  private monthBudgetText(): string {
    if (this.monthBudgetLimit <= 0) {
      return '未设置'
    }
    return this.money(this.monthBudgetLimit)
  }

  private monthBudgetHint(): string {
    if (this.monthBudgetLimit <= 0) {
      return '剩余 --'
    }
    return `剩余 ${this.money(this.budgetRemain())}`
  }

  build() {
    Column() {
      Text(this.budgetRefreshVersion.toString())
        .fontSize(1)
        .fontColor(Color.Transparent)
        .opacity(0)
        .width('100%')
        .height(1)

      Row() {
        Column() {
          Row({ space: 7 }) {
            Text(this.mainTitle())
              .fontSize(15)
              .fontColor($r('app.color.color_text_secondary'))
              .fontWeight(FontWeight.Medium)
            Image($rawfile('icon_help_circle.svg'))
              .width(15)
              .height(15)
              .fillColor($r('app.color.color_text_secondary'))
          }
          .alignItems(VerticalAlign.Center)

          Text(this.mainAmount())
            .fontSize(40)
            .fontColor(this.mainColor())
            .fontWeight(FontWeight.Bolder)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ top: 12 })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        SummaryIconView({ icon: $rawfile('icon_account_cash.svg'), color: $r('app.color.color_primary') })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      if (this.filterType === 'expense') {
        Row() {
          SummaryMetricItem({ title: '日均支出', value: this.money(this.averageExpense()), hint: '较上月 --' })
          Divider().vertical(true).height(42).color($r('app.color.color_divider')).margin({ left: 8, right: 8 })
          SummaryMetricItem({ title: '支出笔数', value: this.billCount.toString() + ' 笔', hint: '较上月 --' })
          Divider().vertical(true).height(42).color($r('app.color.color_divider')).margin({ left: 8, right: 8 })
          SummaryMetricItem({ title: '本月预算', value: this.monthBudgetText(), hint: this.monthBudgetHint() })
        }
        .width('100%')
        .margin({ top: 18 })
      } else if (this.filterType === 'income') {
        Row() {
          SummaryMetricItem({ title: '收入笔数', value: this.billCount.toString() + ' 个', hint: '较上月 --' })
          Divider().vertical(true).height(42).color($r('app.color.color_divider')).margin({ left: 8, right: 8 })
          SummaryMetricItem({ title: '本月结余', value: this.money(this.balance()), hint: '较上月 --' })
          Divider().vertical(true).height(42).color($r('app.color.color_divider')).margin({ left: 8, right: 8 })
          SummaryMetricItem({ title: '本月预算', value: this.monthBudgetText(), hint: this.monthBudgetHint() })
        }
        .width('100%')
        .margin({ top: 18 })
      } else {
        Row() {
          SummaryMetricItem({ title: '收入', value: this.money(this.income), hint: '较上月 --', valueColor: $r('app.color.color_income') })
          Divider().vertical(true).height(42).color($r('app.color.color_divider')).margin({ left: 8, right: 8 })
          SummaryMetricItem({ title: '支出', value: this.money(this.expense), hint: '较上月 --' })
          Divider().vertical(true).height(42).color($r('app.color.color_divider')).margin({ left: 8, right: 8 })
          SummaryMetricItem({ title: '结余', value: this.signedMoney(this.balance()), hint: '较上月 --', valueColor: this.balance() < 0 ? $r('app.color.color_expense') : $r('app.color.color_text_deep') })
        }
        .width('100%')
        .margin({ top: 18 })
      }

      Row({ space: 10 }) {
        BudgetMiniCard({
          title: '今日预算',
          icon: $rawfile('icon_calendar.svg'),
          color: $r('app.color.color_primary'),
          limit: this.dayBudgetLimit,
          spent: this.dayBudgetSpent
        })
        BudgetMiniCard({
          title: '本月预算',
          icon: $rawfile('icon_tab_bills.svg'),
          color: $r('app.color.color_accent_deep'),
          limit: this.monthBudgetLimit,
          spent: this.monthBudgetSpent
        })
        BudgetMiniCard({
          title: '本年预算',
          icon: $rawfile('icon_tab_stats.svg'),
          color: $r('app.color.color_purple'),
          limit: this.yearBudgetLimit,
          spent: this.yearBudgetSpent
        })
      }
      .width('100%')
      .margin({ top: 18 })
    }
    .width('calc(100% - 32vp)')
    .padding({ left: 18, right: 18, top: 18, bottom: 18 })
    .backgroundColor($r('app.color.color_card_overlay'))
    .borderRadius(22)
    .border({ width: 1, color: $r('app.color.color_divider') })
    .shadow({ radius: 14, color: $r('app.color.color_shadow_blue_09'), offsetX: 0, offsetY: 6 })
    .margin({ left: 16, right: 16, top: 10, bottom: 8 })
  }
}
