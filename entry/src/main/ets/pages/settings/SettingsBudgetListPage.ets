import { BudgetOverview, createEmptyBudgetOverview } from '../../model/BudgetRule'
import { AmountUtil } from '../../utils/AmountUtil'

@Component
export struct SettingsBudgetListPage {
  @Prop sbHeight: number
  @Prop dayOverview: BudgetOverview = createEmptyBudgetOverview()
  @Prop monthOverview: BudgetOverview = createEmptyBudgetOverview()
  @Prop yearOverview: BudgetOverview = createEmptyBudgetOverview()
  @Prop refreshVersion: number = 0
  onBack: () => void = (): void => {}
  onBeginEditPeriod: (periodType: string) => void = (periodType: string): void => {}
  private budgetScroller: Scroller = new Scroller()

  private scrollToTop(): void {
    try {
      this.budgetScroller.scrollTo({ xOffset: 0, yOffset: 0 })
    } catch (_err) {
    }
  }

  private money(fen: number): string {
    return '¥' + AmountUtil.rawFen2Display(fen)
  }

  private hasBudget(overview: BudgetOverview): boolean {
    return overview.totalFen > 0 || overview.categoryBudgetFen > 0 || overview.activeRuleCount > 0
  }

  private displayTotalFen(overview: BudgetOverview): number {
    if (overview.totalFen > 0) {
      return overview.totalFen
    }
    if (overview.categoryBudgetFen > 0) {
      return overview.categoryBudgetFen
    }
    return 0
  }

  private amountOrUnset(overview: BudgetOverview): string {
    const totalFen = this.displayTotalFen(overview)
    if (totalFen <= 0) {
      return '未设置'
    }
    return this.money(totalFen)
  }

  private remainOrUnset(overview: BudgetOverview): string {
    if (this.displayTotalFen(overview) <= 0) {
      return '--'
    }
    return this.money(overview.remainFen)
  }

  private percentText(overview: BudgetOverview): string {
    if (this.displayTotalFen(overview) <= 0) {
      return '--'
    }
    return overview.percent.toString() + '%'
  }

  private progressWidth(overview: BudgetOverview): string {
    if (this.displayTotalFen(overview) <= 0 || overview.percent <= 0) {
      return '0%'
    }
    if (overview.percent >= 100) {
      return '100%'
    }
    return overview.percent.toString() + '%'
  }

  private budgetColor(periodType: string): ResourceColor {
    if (periodType === 'month') {
      return '#FF8A00'
    }
    if (periodType === 'year') {
      return '#7C3AED'
    }
    return '#1765F5'
  }

  private periodAmountText(overview: BudgetOverview, unit: string): string {
    const totalFen = this.displayTotalFen(overview)
    if (totalFen <= 0) {
      return '未设置'
    }
    return this.money(totalFen) + '/' + unit
  }

  private allocationHint(overview: BudgetOverview): string {
    if (overview.categoryBudgetFen <= 0) {
      return '可选分类分配'
    }
    return '已分配 ' + this.money(overview.categoryBudgetFen)
  }

  @Builder
  Header() {
    Stack({ alignContent: Alignment.TopEnd }) {
      Row() {
        Image($rawfile('icon_chevron_left.svg'))
          .width(24)
          .height(24)
          .fillColor($r('app.color.color_text_primary'))
          .onClick(() => {
            this.onBack()
          })
        Text('预算设置')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.color_text_primary'))
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
        Blank().width(24).height(24)
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: this.sbHeight + 8, bottom: 10 })
      .alignItems(VerticalAlign.Center)

      Image($rawfile('illustration_fish_bowl.png'))
        .width(88)
        .height(62)
        .opacity(0.9)
        .margin({ top: this.sbHeight + 2, right: 8 })
        .hitTestBehavior(HitTestMode.None)
    }
    .width('100%')
    .height(this.sbHeight + 98)
  }

  @Builder
  Progress(overview: BudgetOverview, color: ResourceColor) {
    Stack({ alignContent: Alignment.Start }) {
      Row()
        .width('100%')
        .height(6)
        .borderRadius(4)
        .backgroundColor($r('app.color.color_track'))
      Row()
        .width(this.progressWidth(overview))
        .height(6)
        .borderRadius(4)
        .backgroundColor(color)
    }
    .layoutWeight(1)
    .height(6)
  }

  @Builder
  OverviewMiniCard(title: string, overview: BudgetOverview, periodType: string) {
    Column() {
      Row() {
        Image($rawfile('icon_calendar.svg'))
          .width(15)
          .height(15)
          .fillColor(this.budgetColor(periodType))
        Text(title)
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.color_text_primary'))
          .margin({ left: 6 })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Text(this.amountOrUnset(overview))
        .fontSize(21)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.hasBudget(overview) ? $r('app.color.color_text_primary') : $r('app.color.color_text_secondary'))
        .width('100%')
        .margin({ top: 12, bottom: 12 })
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Row() {
        Text('已用')
          .fontSize(12)
          .fontColor($r('app.color.color_text_secondary'))
        Blank()
        Text(this.money(overview.usedFen))
          .fontSize(12)
          .fontColor($r('app.color.color_text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .margin({ bottom: 5 })

      Row() {
        Text('剩余')
          .fontSize(12)
          .fontColor($r('app.color.color_text_secondary'))
        Blank()
        Text(this.remainOrUnset(overview))
          .fontSize(12)
          .fontColor(this.budgetColor(periodType))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .margin({ bottom: 9 })

      Row() {
        this.Progress(overview, this.budgetColor(periodType))
        Text(this.percentText(overview))
          .fontSize(12)
          .fontColor($r('app.color.color_text_secondary'))
          .width(38)
          .textAlign(TextAlign.End)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
    .layoutWeight(1)
    .height(154)
    .padding({ left: 12, right: 12, top: 13, bottom: 12 })
    .backgroundColor($r('app.color.color_surface'))
    .border({ width: 1, color: $r('app.color.color_divider') })
    .borderRadius(14)
  }

  @Builder
  OverviewCard() {
    Column() {
      Row() {
        Text('预算概览')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.color_text_primary'))
        Image($rawfile('icon_help_circle.svg'))
          .width(18)
          .height(18)
          .fillColor($r('app.color.color_text_secondary'))
          .margin({ left: 8 })
        Blank()
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Row({ space: 12 }) {
        this.OverviewMiniCard('今日预算', this.dayOverview, 'day')
        this.OverviewMiniCard('本月预算', this.monthOverview, 'month')
        this.OverviewMiniCard('本年预算', this.yearOverview, 'year')
      }
      .width('100%')
      .margin({ top: 16 })
    }
    .width('calc(100% - 32vp)')
    .padding({ left: 18, right: 18, top: 18, bottom: 20 })
    .backgroundColor($r('app.color.color_card_overlay'))
    .borderRadius(18)
    .border({ width: 1, color: $r('app.color.color_divider') })
    .shadow({ radius: 10, color: $r('app.color.color_shadow_blue_08'), offsetY: 4 })
    .margin({ left: 16, right: 16, bottom: 14 })
  }

  @Builder
  PeriodIcon(icon: string, color: ResourceColor) {
    Row() {
      Image($rawfile(icon))
        .width(22)
        .height(22)
        .fillColor(color)
    }
    .width(46)
    .height(46)
    .borderRadius(23)
    .backgroundColor($r('app.color.color_selected_bg'))
    .justifyContent(FlexAlign.Center)
    .margin({ right: 14 })
  }

  @Builder
  PeriodEntry(icon: string, title: string, hint: string, amount: string, periodType: string, color: ResourceColor) {
    Row() {
      this.PeriodIcon(icon, color)
      Column() {
        Text(title)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.color_text_primary'))
        Text(hint)
          .fontSize(13)
          .fontColor($r('app.color.color_text_secondary'))
          .margin({ top: 4 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      Text(amount)
        .fontSize(16)
        .fontColor($r('app.color.color_text_primary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .margin({ right: 10 })
      Image($rawfile('icon_chevron_right.svg'))
        .width(16)
        .height(16)
        .fillColor($r('app.color.color_text_muted'))
    }
    .width('100%')
    .height(80)
    .alignItems(VerticalAlign.Center)
    .onClick(() => {
      this.onBeginEditPeriod(periodType)
    })
  }

  @Builder
  PeriodSettingsCard() {
    Column() {
      this.PeriodEntry('icon_calendar.svg', '日预算设置', this.allocationHint(this.dayOverview),
        this.periodAmountText(this.dayOverview, '天'), 'day', '#1765F5')
      Divider().color($r('app.color.color_divider')).margin({ left: 58 })
      this.PeriodEntry('icon_calendar.svg', '月预算设置', this.allocationHint(this.monthOverview),
        this.periodAmountText(this.monthOverview, '月'), 'month', '#7C3AED')
      Divider().color($r('app.color.color_divider')).margin({ left: 58 })
      this.PeriodEntry('icon_calendar.svg', '年预算设置', this.allocationHint(this.yearOverview),
        this.periodAmountText(this.yearOverview, '年'), 'year', '#FF8A00')
    }
    .width('calc(100% - 32vp)')
    .padding({ left: 16, right: 16, top: 8, bottom: 8 })
    .backgroundColor($r('app.color.color_card_overlay'))
    .borderRadius(18)
    .border({ width: 1, color: $r('app.color.color_divider') })
    .margin({ left: 16, right: 16, bottom: 20 })
  }

  build() {
    Column() {
      Text(this.refreshVersion.toString())
        .fontSize(1)
        .fontColor(Color.Transparent)
        .width(0)
        .height(0)
      this.Header()
      Scroll(this.budgetScroller) {
        Column() {
          this.OverviewCard()
          this.PeriodSettingsCard()
          Text('分类分配只在对应预算周期内生效，可随时调整。')
            .fontSize(12)
            .fontColor($r('app.color.color_text_secondary'))
            .width('100%')
            .textAlign(TextAlign.Center)
            .margin({ top: 8, bottom: 28 })
        }
        .width('100%')
        .padding({ bottom: 24 })
      }
      .layoutWeight(1)
      .align(Alignment.Top)
      .scrollBar(BarState.Off)
      .onAppear(() => {
        this.scrollToTop()
      })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
    .alignItems(HorizontalAlign.Center)
  }
}
