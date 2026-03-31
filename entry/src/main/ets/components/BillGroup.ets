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
    if (net > 0) return `+¥${AmountUtil.fen2Display(net)}`
    if (net < 0) return `-¥${AmountUtil.fen2Display(-net)}`
    return `¥0.00`
  }

  build() {
    Column() {
      // 日期头
      Row() {
        // 左侧日期标签
        Row() {
          Text(DateUtil.friendlyDate(this.date))
            .fontSize(12)
            .fontColor('#757575')
            .fontWeight(FontWeight.Medium)
        }
        .padding({ left: 10, right: 10, top: 4, bottom: 4 })
        .backgroundColor('#F5F5F5')
        .borderRadius(10)

        Blank()

        // 右侧当日净额
        Text(this.getDayNetDisplay())
          .fontSize(13)
          .fontColor(this.getDayNet() >= 0 ? '#4CAF50' : '#F44336')
          .fontWeight(FontWeight.Medium)
      }
      .width('100%')
      .padding({ left: 14, right: 14, top: 10, bottom: 10 })

      // 分隔线
      Divider()
        .color('#F0F0F0')
        .margin({ left: 14, right: 14 })

      // 账单列表
      ForEach(this.bills, (bill: Bill, index: number) => {
        BillItem({
          bill: bill,
          onDelete: (id: number) => { this.onDeleteBill(id) }
        })
        if (index < this.bills.length - 1) {
          Divider()
            .color('#F5F5F5')
            .margin({ left: 70 })  // 缩进对齐文字区域
        }
      })
    }
    .width('100%')
    .backgroundColor('#FFFFFF')
    .borderRadius(14)
    .margin({ left: 16, right: 16, bottom: 10 })
    .shadow({ radius: 6, color: '#0D000000', offsetX: 0, offsetY: 2 })
    .clip(true)
  }
}
