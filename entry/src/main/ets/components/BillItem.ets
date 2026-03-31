import { Bill } from '../model/Bill'
import { getCategoryInfo } from '../model/Category'
import { AmountUtil } from '../utils/AmountUtil'

@Component
export struct BillItem {
  @Prop bill: Bill = {
    id: 0,
    amount: 0,
    type: 'expense',
    category: '',
    remark: '',
    date: '',
    createdAt: 0
  }
  onDelete: (id: number) => void = () => {}

  @Builder
  deleteBuilder() {
    Button('删除')
      .width(72)
      .height('100%')
      .backgroundColor('#F44336') // color_expense
      .fontColor('#FFFFFF')
      .fontSize(14)
      .onClick(() => {
        this.onDelete(this.bill.id)
      })
  }

  build() {
    Row() {
      // Category icon
      Column() {
        Text(getCategoryInfo(this.bill.category).emoji)
          .fontSize(20)
      }
      .width(44)
      .height(44)
      .borderRadius(22)
      .backgroundColor(getCategoryInfo(this.bill.category).color + '33')
      .alignItems(HorizontalAlign.Center)
      .justifyContent(FlexAlign.Center)
      .margin({ right: 12 })

      // Middle info
      Column() {
        Text(this.bill.category)
          .fontSize(16)
          .fontColor('#212121') // color_text_primary
          .fontWeight(FontWeight.Medium)
          .maxLines(1)
        if (this.bill.remark && this.bill.remark.length > 0) {
          Text(this.bill.remark)
            .fontSize(12)
            .fontColor('#9E9E9E') // color_text_secondary
            .maxLines(1)
            .margin({ top: 2 })
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      // Amount
      Column() {
        Text(AmountUtil.formatWithSign(this.bill.amount, this.bill.type))
          .fontSize(16)
          .fontColor(this.bill.type === 'income' ? '#4CAF50' : '#F44336')
          .fontWeight(FontWeight.Medium)
      }
      .alignItems(HorizontalAlign.End)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .backgroundColor('#FFFFFF') // color_card
    .swipeAction({ end: this.deleteBuilder })
  }
}
