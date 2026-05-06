import { Bill } from '../model/Bill'
import { AmountUtil } from '../utils/AmountUtil'
import { getCategoryColor, getCategoryInfo } from '../model/Category'

@Component
export struct SearchResultItem {
  @Prop bill: Bill
  @Prop hitRemark: boolean = false
  @Prop hitCategory: boolean = false
  @Prop hitAmount: boolean = false
  onTap: () => void = () => {}

  build() {
    Row() {
      Column() {
        Image($rawfile(getCategoryInfo(this.bill.category).icon + '.svg'))
          .width(26)
          .height(26)
          .fillColor($r('app.color.color_surface'))
      }
      .width(50)
      .height(50)
      .borderRadius(25)
      .backgroundColor(getCategoryColor(this.bill.category))
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .margin({ right: 14 })

      Column({ space: 4 }) {
        Text(this.bill.category)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.hitCategory ? $r('app.color.color_primary') : $r('app.color.color_text_primary'))
          .backgroundColor(this.hitCategory ? 'rgba(255,209,102,0.25)' : Color.Transparent)
          .borderRadius(8)
          .padding(this.hitCategory ? { left: 6, right: 6, top: 2, bottom: 2 } : { left: 0, right: 0, top: 0, bottom: 0 })

        Text(this.bill.remark && this.bill.remark.length > 0 ? this.bill.remark : '无备注')
          .fontSize(12)
          .fontColor(this.hitRemark ? $r('app.color.color_primary') : $r('app.color.color_text_secondary'))
          .backgroundColor(this.hitRemark ? 'rgba(255,209,102,0.25)' : Color.Transparent)
          .borderRadius(8)
          .padding(this.hitRemark ? { left: 6, right: 6, top: 2, bottom: 2 } : { left: 0, right: 0, top: 0, bottom: 0 })
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Text(`${this.bill.type === 'income' ? '+' : '-'}¥${AmountUtil.fen2Display(this.bill.amount)}`)
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.bill.type === 'income' ? $r('app.color.color_income') : $r('app.color.color_expense'))
        .backgroundColor(this.hitAmount ? 'rgba(255,209,102,0.25)' : Color.Transparent)
        .borderRadius(8)
        .padding(this.hitAmount ? { left: 6, right: 6, top: 2, bottom: 2 } : { left: 0, right: 0, top: 0, bottom: 0 })
    }
    .width('calc(100% - 32vp)')
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .backgroundColor($r('app.color.color_card_overlay'))
    .borderRadius(18)
    .border({ width: 1, color: $r('app.color.color_divider') })
    .shadow({ radius: 12, color: $r('app.color.color_shadow_blue_09'), offsetX: 0, offsetY: 5 })
    .margin({ left: 16, right: 16, top: 5, bottom: 5 })
    .onClick(() => {
      this.onTap()
    })
  }
}
