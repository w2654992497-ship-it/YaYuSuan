import { BudgetOverview, createEmptyBudgetOverview } from '../../model/BudgetRule'
import { AmountUtil } from '../../utils/AmountUtil'

@Component
struct BudgetOverviewMiniCard {
  @Prop title: string
  @Prop periodType: string
  @Prop totalFen: number = 0
  @Prop usedFen: number = 0
  @Prop remainFen: number = 0
  @Prop percent: number = 0
  @Prop activeRuleCount: number = 0
  @Prop categoryBudgetFen: number = 0

  private money(fen: number): string {
    return '¥' + AmountUtil.rawFen2Display(fen)
  }

  private hasBudget(): boolean {
    return this.totalFen > 0 || this.categoryBudgetFen > 0 || this.activeRuleCount > 0
  }

  private displayTotalFen(): number {
    if (this.totalFen > 0) {
      return this.totalFen
    }
    if (this.categoryBudgetFen > 0) {
      return this.categoryBudgetFen
    }
    return 0
  }

  private amountText(): string {
    const totalFen = this.displayTotalFen()
    if (totalFen <= 0) {
      return '未设置'
    }
    return this.money(totalFen)
  }

  private remainText(): string {
    if (this.displayTotalFen() <= 0) {
      return '--'
    }
    return this.money(this.remainFen)
  }

  private percentText(): string {
    if (this.displayTotalFen() <= 0) {
      return '--'
    }
    return this.percent.toString() + '%'
  }

  private progressWidth(): string {
    if (this.displayTotalFen() <= 0 || this.percent <= 0) {
      return '0%'
    }
    if (this.percent >= 100) {
      return '100%'
    }
    return this.percent.toString() + '%'
  }

  private color(): ResourceColor {
    if (this.periodType === 'month') {
      return '#FF8A00'
    }
    if (this.periodType === 'year') {
      return '#7C3AED'
    }
    return '#1765F5'
  }

  build() {
    Column() {
      Row() {
        Image($rawfile('icon_calendar.svg'))
          .width(15)
          .height(15)
          .fillColor(this.color())
        Text(this.title)
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.color_text_primary'))
          .margin({ left: 6 })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Text(this.amountText())
        .fontSize(21)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.hasBudget() ? $r('app.color.color_text_primary') : $r('app.color.color_text_secondary'))
        .width('100%')
        .margin({ top: 12, bottom: 12 })
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Row() {
        Text('已用')
          .fontSize(12)
          .fontColor($r('app.color.color_text_secondary'))
        Blank()
        Text(this.money(this.usedFen))
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
        Text(this.remainText())
          .fontSize(12)
          .fontColor(this.color())
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .margin({ bottom: 9 })

      Row() {
        Stack({ alignContent: Alignment.Start }) {
          Row()
            .width('100%')
            .height(6)
            .borderRadius(4)
            .backgroundColor($r('app.color.color_track'))
          Row()
            .width(this.progressWidth())
            .height(6)
            .borderRadius(4)
            .backgroundColor(this.color())
        }
        .layoutWeight(1)
        .height(6)
        Text(this.percentText())
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
}

@Component
struct BudgetPeriodEntry {
  @Prop title: string
  @Prop unit: string
  @Prop periodType: string
  @Prop color: ResourceColor
  @Prop totalFen: number = 0
  @Prop categoryBudgetFen: number = 0
  onTap: () => void = (): void => {}

  private money(fen: number): string {
    return '¥' + AmountUtil.rawFen2Display(fen)
  }

  private displayTotalFen(): number {
    if (this.totalFen > 0) {
      return this.totalFen
    }
    if (this.categoryBudgetFen > 0) {
      return this.categoryBudgetFen
    }
    return 0
  }

  private amountText(): string {
    const totalFen = this.displayTotalFen()
    if (totalFen <= 0) {
      return '未设置'
    }
    return this.money(totalFen) + '/' + this.unit
  }

  private hintText(): string {
    if (this.categoryBudgetFen <= 0) {
      return '可选分类分配'
    }
    return '已分配 ' + this.money(this.categoryBudgetFen)
  }

  build() {
    Row() {
      Row() {
        Image($rawfile('icon_calendar.svg'))
          .width(22)
          .height(22)
          .fillColor(this.color)
      }
      .width(46)
      .height(46)
      .borderRadius(23)
      .backgroundColor($r('app.color.color_selected_bg'))
      .justifyContent(FlexAlign.Center)
      .margin({ right: 14 })

      Column() {
        Text(this.title)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.color_text_primary'))
        Text(this.hintText())
          .fontSize(13)
          .fontColor($r('app.color.color_text_secondary'))
          .margin({ top: 4 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Text(this.amountText())
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
    .onClick(this.onTap)
  }
}

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
        BudgetOverviewMiniCard({
          title: '今日预算',
          periodType: 'day',
          totalFen: this.dayOverview.totalFen,
          usedFen: this.dayOverview.usedFen,
          remainFen: this.dayOverview.remainFen,
          percent: this.dayOverview.percent,
          activeRuleCount: this.dayOverview.activeRuleCount,
          categoryBudgetFen: this.dayOverview.categoryBudgetFen
        })
        BudgetOverviewMiniCard({
          title: '本月预算',
          periodType: 'month',
          totalFen: this.monthOverview.totalFen,
          usedFen: this.monthOverview.usedFen,
          remainFen: this.monthOverview.remainFen,
          percent: this.monthOverview.percent,
          activeRuleCount: this.monthOverview.activeRuleCount,
          categoryBudgetFen: this.monthOverview.categoryBudgetFen
        })
        BudgetOverviewMiniCard({
          title: '本年预算',
          periodType: 'year',
          totalFen: this.yearOverview.totalFen,
          usedFen: this.yearOverview.usedFen,
          remainFen: this.yearOverview.remainFen,
          percent: this.yearOverview.percent,
          activeRuleCount: this.yearOverview.activeRuleCount,
          categoryBudgetFen: this.yearOverview.categoryBudgetFen
        })
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
      BudgetPeriodEntry({
        title: '日预算设置',
        unit: '天',
        periodType: 'day',
        color: '#1765F5',
        totalFen: this.dayOverview.totalFen,
        categoryBudgetFen: this.dayOverview.categoryBudgetFen,
        onTap: () => {
          this.onBeginEditPeriod('day')
        }
      })
      Divider().color($r('app.color.color_divider')).margin({ left: 58 })
      BudgetPeriodEntry({
        title: '月预算设置',
        unit: '月',
        periodType: 'month',
        color: '#7C3AED',
        totalFen: this.monthOverview.totalFen,
        categoryBudgetFen: this.monthOverview.categoryBudgetFen,
        onTap: () => {
          this.onBeginEditPeriod('month')
        }
      })
      Divider().color($r('app.color.color_divider')).margin({ left: 58 })
      BudgetPeriodEntry({
        title: '年预算设置',
        unit: '年',
        periodType: 'year',
        color: '#FF8A00',
        totalFen: this.yearOverview.totalFen,
        categoryBudgetFen: this.yearOverview.categoryBudgetFen,
        onTap: () => {
          this.onBeginEditPeriod('year')
        }
      })
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
        .opacity(0)
        .width('100%')
        .height(1)
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
