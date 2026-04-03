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
          .fontSize(36)
          .fontColor($r('app.color.color_surface'))
          .fontWeight(FontWeight.Bold)
          .letterSpacing(1)
      }
      .alignItems(HorizontalAlign.Start) // 改为左对齐
      .width('100%')
      .padding({ top: 24, left: 24, bottom: 16 })

      // 分隔线
      Divider()
        .color('rgba(255,255,255,0.15)')
        .width('100%')

      // 收入 / 结余 行
      Row() {
        Column() {
          Text('收入')
            .fontSize(12)
            .fontColor('rgba(255,255,255,0.7)')
            .margin({ bottom: 4 })
          Text(`+¥${AmountUtil.fen2Display(this.income)}`)
            .fontSize(16)
            .fontColor($r('app.color.color_surface'))
            .fontWeight(FontWeight.Medium)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Divider()
          .vertical(true)
          .height(28)
          .color('rgba(255,255,255,0.15)')

        Column() {
          Text('结余')
            .fontSize(12)
            .fontColor('rgba(255,255,255,0.7)')
            .margin({ bottom: 4 })
          Text(`¥${AmountUtil.fen2Display(Math.abs(this.income - this.expense))}`)
            .fontSize(16)
            .fontColor((this.income - this.expense) >= 0 ? $r('app.color.color_duck') : $r('app.color.color_expense'))
            .fontWeight(FontWeight.Medium)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        .padding({ left: 24 })
      }
      .width('100%')
      .padding({ top: 16, left: 24, bottom: 20 })
    }
    .width('calc(100% - 32vp)')
    .linearGradient({
      direction: GradientDirection.RightBottom, // 水流渐变方向
      colors: [['#457B9D', 0.0], ['#1D3557', 1.0]] // 深水青到深蓝灰
    })
    .borderRadius(24) // 水滴大圆角
    .margin({ left: 16, right: 16, top: 12, bottom: 12 })
    .shadow({ radius: 20, color: 'rgba(44, 122, 123, 0.25)', offsetX: 0, offsetY: 8 }) // 更弥散的同色系阴影
  }
}
