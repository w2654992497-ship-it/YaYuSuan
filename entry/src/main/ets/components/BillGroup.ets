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

  // 删除操作滑出区域（swipeAction 需要 ListItem，已在 List 内）
  @Builder
  DeleteBuilder(bill: Bill) {
    Column() {
      Image($rawfile('icon_other.svg'))
        .width(20)
        .height(20)
        .fillColor('#FFFFFF')
        .margin({ bottom: 4 })
      Text('删除')
        .fontSize(12)
        .fontColor('#FFFFFF')
    }
    .width(72)
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor('#F44336')
    .onClick(() => {
      this.getUIContext().showAlertDialog({
        title: '删除账单',
        message: `确认删除「${bill.category}」这条记录吗？`,
        primaryButton: {
          value: '取消',
          fontColor: '#1976D2',
          action: () => {}
        },
        secondaryButton: {
          value: '删除',
          fontColor: '#F44336',
          action: () => { this.onDeleteBill(bill.id) }
        },
        alignment: DialogAlignment.Bottom,
        offset: { dx: 0, dy: -20 }
      })
    })
  }

  build() {
    Column() {
      // 日期头
      Row() {
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

        Text(this.getDayNetDisplay())
          .fontSize(13)
          .fontColor(this.getDayNet() >= 0 ? '#4CAF50' : '#F44336')
          .fontWeight(FontWeight.Medium)
      }
      .width('100%')
      .padding({ left: 14, right: 14, top: 10, bottom: 10 })

      Divider()
        .color('#E0E0E0')
        .margin({ left: 14, right: 14 })

      // 账单列表：用 List+ListItem 支持 swipeAction
      List() {
        ForEach(this.bills, (bill: Bill) => {
          ListItem() {
            BillItem({
              bill: bill,
              onDelete: (id: number) => { this.onDeleteBill(id) }
            })
          }
          .swipeAction({ end: () => { this.DeleteBuilder(bill) } })
        }, (bill: Bill) => bill.id.toString())
      }
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.None)
      .nestedScroll({
        scrollForward: NestedScrollMode.PARENT_FIRST,
        scrollBackward: NestedScrollMode.SELF_FIRST
      })
      .divider({ strokeWidth: 0.5, color: '#F5F5F5', startMargin: 70 })
    }
    .width('100%')
    .backgroundColor('#FFFFFF')
    .borderRadius(14)
    .margin({ bottom: 10 })
    .shadow({ radius: 6, color: '#0D000000', offsetX: 0, offsetY: 2 })
    .clip(true)
  }
}
