import { AmountUtil } from '../utils/AmountUtil'

@Component
export struct SummaryCard {
  @Prop income: number = 0
  @Prop expense: number = 0

  build() {
    Row() {
      Column() {
        Text('收入')
          .fontSize(12)
          .fontColor('#9E9E9E') // color_text_secondary
          .margin({ bottom: 4 })
        Text(`¥${AmountUtil.fen2Display(this.income)}`)
          .fontSize(16)
          .fontColor('#4CAF50') // color_income
          .fontWeight(FontWeight.Medium)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Center)

      Divider()
        .vertical(true)
        .height(40)
        .color('#E0E0E0') // color_divider

      Column() {
        Text('支出')
          .fontSize(12)
          .fontColor('#9E9E9E') // color_text_secondary
          .margin({ bottom: 4 })
        Text(`¥${AmountUtil.fen2Display(this.expense)}`)
          .fontSize(16)
          .fontColor('#F44336') // color_expense
          .fontWeight(FontWeight.Medium)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Center)

      Divider()
        .vertical(true)
        .height(40)
        .color('#E0E0E0') // color_divider

      Column() {
        Text('结余')
          .fontSize(12)
          .fontColor('#9E9E9E') // color_text_secondary
          .margin({ bottom: 4 })
        Text(`¥${AmountUtil.fen2Display(this.income - this.expense)}`)
          .fontSize(16)
          .fontColor(this.income - this.expense >= 0 ? '#4CAF50' : '#F44336')
          .fontWeight(FontWeight.Medium)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF') // color_card
    .borderRadius(12)
    .margin({ left: 16, right: 16, top: 8, bottom: 8 })
    .shadow({ radius: 4, color: '#1A000000', offsetX: 0, offsetY: 2 })
  }
}
