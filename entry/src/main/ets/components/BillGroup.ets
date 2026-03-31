import { Bill } from '../model/Bill'
import { DateUtil } from '../utils/DateUtil'
import { AmountUtil } from '../utils/AmountUtil'
import { BillItem } from './BillItem'

@Component
export struct BillGroup {
  @Prop date: string = ''
  @Prop bills: Bill[] = []
  @Prop dayIncome: number = 0
  @Prop dayExpense: number = 0
  onDeleteBill: (id: number) => void = () => {}

  private getDayNet(): number {
    return this.dayIncome - this.dayExpense
  }

  private getDayNetDisplay(): string {
    const net = this.getDayNet()
    if (net > 0) {
      return `+¥${AmountUtil.fen2Display(net)}`
    } else if (net < 0) {
      return `-¥${AmountUtil.fen2Display(-net)}`
    } else {
      return `¥0.00`
    }
  }

  build() {
    Column() {
      // Date header
      Row() {
        Text(DateUtil.friendlyDate(this.date))
          .fontSize(14)
          .fontColor('#9E9E9E') // color_text_secondary
        Blank()
        Text(this.getDayNetDisplay())
          .fontSize(14)
          .fontColor(this.getDayNet() >= 0 ? '#4CAF50' : '#F44336')
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 8, bottom: 8 })

      // Bill items
      ForEach(this.bills, (bill: Bill) => {
        BillItem({ bill: bill, onDelete: (id: number) => { this.onDeleteBill(id) } })
        Divider()
          .color('#E0E0E0') // color_divider
          .margin({ left: 72 })
      })
    }
    .width('100%')
    .backgroundColor('#FFFFFF') // color_card
    .borderRadius(12)
    .margin({ left: 16, right: 16, bottom: 8 })
    .clip(true)
  }
}
