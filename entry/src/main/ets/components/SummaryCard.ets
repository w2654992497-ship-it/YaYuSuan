import { AmountUtil } from '../utils/AmountUtil'

@Component
export struct SummaryCard {
  @Prop income: number = 0
  @Prop expense: number = 0
  @Prop budgetSpent: number = 0
  @Prop budgetLimit: number = 0

  private budgetRemain(): number {
    const remain = this.budgetLimit - this.budgetSpent
    if (remain <= 0) {
      return 0
    }
    return remain
  }

  private budgetPercent(): number {
    if (this.budgetLimit <= 0) {
      return 0
    }
    const percent = Math.floor((this.budgetSpent / this.budgetLimit) * 100)
    return Math.min(999, Math.max(0, percent))
  }

  private budgetProgressWidth(): string {
    if (this.budgetLimit <= 0) {
      return '0%'
    }
    const percent = Math.floor((this.budgetSpent / this.budgetLimit) * 100)
    return `${Math.min(100, Math.max(4, percent))}%`
  }

  @Builder
  SummaryIcon(icon: ResourceStr, color: ResourceColor) {
    Row() {
      Image(icon)
        .width(16)
        .height(16)
        .fillColor(color)
    }
    .width(30)
    .height(30)
    .borderRadius(15)
    .justifyContent(FlexAlign.Center)
    .backgroundColor($r('app.color.color_white'))
    .border({ width: 1, color: $r('app.color.color_divider') })
    .shadow({ radius: 10, color: $r('app.color.color_shadow_blue_08'), offsetX: 0, offsetY: 4 })
    .margin({ right: 8 })
  }

  build() {
    Stack({ alignContent: Alignment.TopEnd }) {
      Image($rawfile('illustration_fish_bowl.png'))
        .width(116)
        .height(82)
        .objectFit(ImageFit.Contain)
        .margin({ top: 18, right: 12 })
        .hitTestBehavior(HitTestMode.None)

      Column() {
        Text('本月支出')
          .fontSize(15)
          .fontColor($r('app.color.color_text_secondary'))
          .fontWeight(FontWeight.Medium)

        Text(`¥${AmountUtil.fen2Display(this.expense)}`)
          .fontSize(34)
          .fontColor($r('app.color.color_text_deep'))
          .fontWeight(FontWeight.Bolder)
          .margin({ top: 8 })

        Row() {
          Row() {
            this.SummaryIcon($rawfile('icon_tab_bills.svg'), $r('app.color.color_primary'))
            Column() {
              Text('收入')
                .fontSize(12)
                .fontColor($r('app.color.color_text_secondary'))
              Text(`¥${AmountUtil.fen2Display(this.income)}`)
                .fontSize(13)
                .fontColor($r('app.color.color_text_deep'))
                .fontWeight(FontWeight.Medium)
                .margin({ top: 2 })
            }
            .alignItems(HorizontalAlign.Start)
          }
          .layoutWeight(1)
          .alignItems(VerticalAlign.Center)

          Divider()
            .vertical(true)
            .height(36)
            .color($r('app.color.color_divider'))

          Row() {
            this.SummaryIcon($rawfile('icon_tab_stats.svg'), $r('app.color.color_accent'))
            Column() {
              Text('预算剩余')
                .fontSize(12)
                .fontColor($r('app.color.color_text_secondary'))
              Text(`¥${AmountUtil.fen2Display(this.budgetRemain())}`)
                .fontSize(13)
                .fontColor($r('app.color.color_text_deep'))
                .fontWeight(FontWeight.Medium)
                .margin({ top: 2 })
            }
            .alignItems(HorizontalAlign.Start)
          }
          .layoutWeight(1.25)
          .alignItems(VerticalAlign.Center)
          .padding({ left: 10 })

          Divider()
            .vertical(true)
            .height(36)
            .color($r('app.color.color_divider'))

          Column() {
            Text(`${this.budgetPercent()}%`)
              .fontSize(19)
              .fontWeight(FontWeight.Bolder)
              .fontColor($r('app.color.color_primary'))
            Text('预算进度')
              .fontSize(11)
              .fontColor($r('app.color.color_text_secondary'))
              .margin({ top: 2 })
          }
          .width(58)
          .alignItems(HorizontalAlign.Center)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
        .margin({ top: 16 })

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
            .backgroundColor($r('app.color.color_primary'))
        }
        .width('100%')
        .margin({ top: 14 })

        Text(`已用 ¥${AmountUtil.fen2Display(this.budgetSpent)} / 预算 ¥${AmountUtil.fen2Display(this.budgetLimit)}`)
          .fontSize(12)
          .fontColor($r('app.color.color_text_secondary'))
          .margin({ top: 8 })
      }
      .width('100%')
      .height('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 18, right: 18, top: 20, bottom: 16 })
    }
    .width('calc(100% - 48vp)')
    .height(190)
    .backgroundColor($r('app.color.color_card_overlay'))
    .borderRadius(22)
    .border({ width: 1, color: $r('app.color.color_divider') })
    .shadow({ radius: 14, color: $r('app.color.color_shadow_blue_09'), offsetX: 0, offsetY: 6 })
    .margin({ left: 24, right: 24, top: 12, bottom: 10 })
  }
}
