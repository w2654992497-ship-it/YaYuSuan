import { BudgetRule, BudgetRuleUsage, createEmptyBudgetRule } from '../../model/BudgetRule'
import { AmountUtil } from '../../utils/AmountUtil'

@Component
export struct SettingsBudgetDetailPage {
  @Prop sbHeight: number
  @Prop ruleUsages: BudgetRuleUsage[] = []
  @Prop draftRule: BudgetRule = createEmptyBudgetRule()
  onCloseEditor: () => void = (): void => {}
  onBeginEdit: (rule: BudgetRule) => void = (rule: BudgetRule): void => {}
  onToggleRule: (rule: BudgetRule) => void = (rule: BudgetRule): void => {}
  onDeleteRule: (rule: BudgetRule) => void = (rule: BudgetRule): void => {}
  onOpenDetail: (rule: BudgetRule) => void = (rule: BudgetRule): void => {}
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

  private progressWidth(percent: number): string {
    if (percent <= 0) {
      return '0%'
    }
    if (percent >= 100) {
      return '100%'
    }
    return percent.toString() + '%'
  }

  private percentText(percent: number): string {
    if (percent > 9999) {
      return '9999%+'
    }
    return percent.toString() + '%'
  }

  private compareLabel(rule: BudgetRule): string {
    if (rule.compareMode === 'none') {
      return '不对比'
    }
    if (rule.periodType === 'day') {
      return '昨日'
    }
    if (rule.periodType === 'year') {
      return '去年'
    }
    return '上月'
  }

  private detailUsage(): BudgetRuleUsage {
    for (let i = 0; i < this.ruleUsages.length; i++) {
      if (this.ruleUsages[i].rule.id === this.draftRule.id) {
        return this.ruleUsages[i]
      }
    }
    return {
      rule: this.draftRule,
      usedFen: 0,
      remainFen: this.draftRule.amount,
      percent: 0,
      periodLabel: this.draftRule.periodType,
      scopeLabel: this.draftRule.scopeType,
      compareLabel: this.compareLabel(this.draftRule)
    }
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
            this.onCloseEditor()
          })
        Text('预算规则详情')
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
    .height(this.sbHeight + 102)
  }

  @Builder
  Progress(percent: number) {
    Stack({ alignContent: Alignment.Start }) {
      Row()
        .width('100%')
        .height(7)
        .borderRadius(4)
        .backgroundColor($r('app.color.color_track'))
      Row()
        .width(this.progressWidth(percent))
        .height(7)
        .borderRadius(4)
        .backgroundColor($r('app.color.color_primary'))
    }
    .width('100%')
    .height(7)
  }

  @Builder
  ProgressInline(percent: number) {
    Stack({ alignContent: Alignment.Start }) {
      Row()
        .width('100%')
        .height(7)
        .borderRadius(4)
        .backgroundColor($r('app.color.color_track'))
      Row()
        .width(this.progressWidth(percent))
        .height(7)
        .borderRadius(4)
        .backgroundColor($r('app.color.color_primary'))
    }
    .layoutWeight(1)
    .height(7)
  }

  @Builder
  Metric(label: string, amountFen: number, color: ResourceColor) {
    Column() {
      Text(label)
        .fontSize(12)
        .fontColor($r('app.color.color_text_secondary'))
      Text(this.money(amountFen))
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor(color)
        .margin({ top: 6 })
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  RuleCard(usage: BudgetRuleUsage, index: number) {
    Column() {
      Row() {
        Text((index + 1).toString())
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.color_white'))
          .width(24)
          .height(24)
          .borderRadius(12)
          .backgroundColor($r('app.color.color_primary'))
          .textAlign(TextAlign.Center)
          .margin({ right: 10 })
        Column() {
          Row() {
            Text(usage.rule.name)
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.color_text_primary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Text(usage.periodLabel)
              .fontSize(11)
              .fontColor($r('app.color.color_primary'))
              .padding({ left: 8, right: 8, top: 3, bottom: 3 })
              .backgroundColor($r('app.color.color_selected_bg'))
              .borderRadius(10)
              .margin({ left: 8 })
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)
          Text(usage.scopeLabel)
            .fontSize(12)
            .fontColor($r('app.color.color_text_secondary'))
            .margin({ top: 5 })
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        Image($rawfile('icon_chevron_right.svg'))
          .width(16)
          .height(16)
          .fillColor($r('app.color.color_text_muted'))
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Row() {
        this.Metric('预算', usage.rule.amount, $r('app.color.color_primary'))
        Divider().vertical(true).height(30).color($r('app.color.color_divider'))
        this.Metric('已用', usage.usedFen, $r('app.color.color_text_primary'))
        Divider().vertical(true).height(30).color($r('app.color.color_divider'))
        this.Metric('剩余', usage.remainFen, $r('app.color.color_accent'))
      }
      .width('100%')
      .margin({ top: 14, bottom: 10 })

      Row() {
        this.ProgressInline(usage.percent)
        Text(this.percentText(usage.percent))
          .fontSize(12)
          .fontColor($r('app.color.color_primary'))
          .width(58)
          .textAlign(TextAlign.End)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
    .width('calc(100% - 32vp)')
    .padding(14)
    .backgroundColor(usage.rule.enabled === 1 ? $r('app.color.color_card_overlay') : $r('app.color.color_bg'))
    .borderRadius(16)
    .border({ width: 1, color: $r('app.color.color_divider') })
    .margin({ left: 16, right: 16, bottom: 10 })
    .onClick(() => {
      this.onOpenDetail(usage.rule)
    })
  }

  @Builder
  DetailPage() {
    Column() {
      this.Header()
      Scroll(this.budgetScroller) {
        Column() {
          this.RuleCard(this.detailUsage(), 0)
          Column() {
            this.DetailRow('规则名称', this.draftRule.name)
            this.DetailRow('预算范围', this.detailUsage().scopeLabel)
            this.DetailRow('统计周期', this.detailUsage().periodLabel)
            this.DetailRow('对比周期', this.detailUsage().compareLabel)
            this.DetailRow('状态', this.draftRule.enabled === 1 ? '生效中' : '已停用')
          }
          .width('calc(100% - 32vp)')
          .padding(16)
          .backgroundColor($r('app.color.color_card_overlay'))
          .borderRadius(18)
          .border({ width: 1, color: $r('app.color.color_divider') })
          .margin({ left: 16, right: 16, bottom: 16 })
        }
        .width('100%')
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .onAppear(() => {
        this.scrollToTop()
      })

      Button('编辑规则')
        .width('calc(100% - 32vp)')
        .height(48)
        .fontColor($r('app.color.color_white'))
        .backgroundColor($r('app.color.color_primary'))
        .borderRadius(18)
        .margin({ left: 16, right: 16, bottom: 10 })
        .onClick(() => {
          this.onBeginEdit(this.draftRule)
        })
      Button(this.draftRule.enabled === 1 ? '停用规则' : '启用规则')
        .width('calc(100% - 32vp)')
        .height(46)
        .fontColor($r('app.color.color_primary'))
        .backgroundColor($r('app.color.color_card_overlay'))
        .border({ width: 1, color: $r('app.color.color_primary') })
        .borderRadius(18)
        .margin({ left: 16, right: 16, bottom: 10 })
        .onClick(() => {
          this.onToggleRule(this.draftRule)
        })
      Button('删除规则')
        .width('calc(100% - 32vp)')
        .height(46)
        .fontColor($r('app.color.color_expense'))
        .backgroundColor($r('app.color.color_card_overlay'))
        .border({ width: 1, color: $r('app.color.color_expense') })
        .borderRadius(18)
        .margin({ left: 16, right: 16, bottom: 18 })
        .onClick(() => {
          this.onDeleteRule(this.draftRule)
        })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  DetailRow(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(14)
        .fontColor($r('app.color.color_text_secondary'))
        .width(88)
      Text(value)
        .fontSize(15)
        .fontColor($r('app.color.color_text_primary'))
        .layoutWeight(1)
        .textAlign(TextAlign.End)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .height(42)
    .alignItems(VerticalAlign.Center)
  }


  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      this.DetailPage()
    }
    .width('100%')
    .height('100%')
  }
}
