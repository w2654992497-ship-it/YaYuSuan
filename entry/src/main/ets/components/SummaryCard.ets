import { AmountUtil } from '../utils/AmountUtil'

@Component
export struct SummaryCard {
  @Prop income: number = 0
  @Prop expense: number = 0

  build() {
    Column() {
      // 主金额区：本月支出
      Column() {
        Text('本月支出')
          .fontSize(12)
          .fontColor('rgba(255,255,255,0.75)')
          .margin({ bottom: 6 })
        Text(`¥${AmountUtil.fen2Display(this.expense)}`)
          .fontSize(34)
          .fontColor('#FFFFFF')
          .fontWeight(FontWeight.Bold)
          .letterSpacing(1)
      }
      .alignItems(HorizontalAlign.Center)
      .padding({ top: 20, bottom: 16 })

      // 分隔线
      Divider()
        .color('rgba(255,255,255,0.2)')
        .margin({ left: 20, right: 20 })

      // 收入 / 结余 行
      Row() {
        Column() {
          Text('收入')
            .fontSize(11)
            .fontColor('rgba(255,255,255,0.65)')
            .margin({ bottom: 4 })
          Text(`+¥${AmountUtil.fen2Display(this.income)}`)
            .fontSize(15)
            .fontColor('#FFFFFF')
            .fontWeight(FontWeight.Medium)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)

        Divider()
          .vertical(true)
          .height(32)
          .color('rgba(255,255,255,0.2)')

        Column() {
          Text('结余')
            .fontSize(11)
            .fontColor('rgba(255,255,255,0.65)')
            .margin({ bottom: 4 })
          Text(`¥${AmountUtil.fen2Display(Math.abs(this.income - this.expense))}`)
            .fontSize(15)
            .fontColor((this.income - this.expense) >= 0 ? '#A5D6A7' : '#FFCDD2')
            .fontWeight(FontWeight.Medium)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)
      }
      .width('100%')
      .padding({ top: 14, bottom: 20 })
    }
    .width('100%')
    .linearGradient({
      angle: 150,
      colors: [['#1E88E5', 0.0], ['#0D47A1', 1.0]]
    })
    .borderRadius(16)
    .margin({ left: 16, right: 16, top: 8, bottom: 8 })
    .shadow({ radius: 16, color: '#401976D2', offsetX: 0, offsetY: 6 })
  }
}
