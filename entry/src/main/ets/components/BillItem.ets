import { Bill } from '../model/Bill'
import { getCategoryColor, getCategoryInfo } from '../model/Category'
import { AmountUtil } from '../utils/AmountUtil'
import { DateUtil } from '../utils/DateUtil'

@Component
export struct BillItem {
  @Prop bill: Bill
  onDelete: () => void = () => {}

  @Builder
  DeleteButton() {
    Button() {
      Image($rawfile('icon_list.svg'))
        .width(24)
        .height(24)
        .fillColor($r('app.color.color_surface'))
    }
    .width(64)
    .height('100%')
    .type(ButtonType.Normal)
    .backgroundColor($r('app.color.color_expense'))
    .onClick(() => {
      this.onDelete()
    })
  }

  build() {
    ListItem() {
      Row() {
        Column() {
          Image($rawfile(getCategoryInfo(this.bill.category).icon + '.svg'))
            .width(24)
            .height(24)
            .fillColor($r('app.color.color_surface'))
        }
        .width(44)
        .height(44)
        .borderRadius(22)
        .backgroundColor(getCategoryColor(this.bill.category))
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .margin({ right: 16 })

        Column() {
          Text(this.bill.category)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.color_text_primary'))
            .margin({ bottom: 4 })
          
          Row() {
            if (this.bill.remark) {
              Text(this.bill.remark)
                .fontSize(12)
                .fontColor($r('app.color.color_text_secondary'))
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .margin({ right: 8 })
            }
            Text(DateUtil.getRelativeTime(this.bill.createdAt))
              .fontSize(11)
              .fontColor($r('app.color.color_tab_inactive'))
          }
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Text(`${this.bill.type === 'income' ? '+' : '-'}¥${AmountUtil.fen2Display(this.bill.amount)}`)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.bill.type === 'income' ? $r('app.color.color_income') : $r('app.color.color_expense'))
          .fontFamily('cursive')
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })
      .backgroundColor($r('app.color.color_surface'))
      .borderRadius(16)
      .margin({ top: 4, bottom: 4 })
      .border({ width: 1, color: 'rgba(0,0,0,0.05)', radius: 16 })
      .shadow({ radius: 0, color: 'rgba(43,45,66,0.1)', offsetX: 4, offsetY: 4 }) // Neo-brutalism flat offset shadow
    }
    .swipeAction({ end: this.DeleteButton() })
    .margin({ left: 16, right: 16 })
  }
}
