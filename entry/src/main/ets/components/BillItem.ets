import { Bill } from '../model/Bill'
import { getCategoryInfo, CategoryInfo } from '../model/Category'
import { AmountUtil } from '../utils/AmountUtil'
import { DateUtil } from '../utils/DateUtil'

@Component
export struct BillItem {
  @Prop bill: Bill = {
    id: 0, amount: 0, type: 'expense',
    category: '', remark: '', date: '', createdAt: 0
  }
  onDelete: (id: number) => void = () => {}

  @Builder
  deleteBuilder() {
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
      AlertDialog.show({
        title: '删除账单',
        message: `确认删除「${this.bill.category}」这条记录吗？`,
        primaryButton: {
          value: '取消',
          fontColor: '#1976D2',
          action: () => {}
        },
        secondaryButton: {
          value: '删除',
          fontColor: '#F44336',
          action: () => { this.onDelete(this.bill.id) }
        },
        alignment: DialogAlignment.Bottom,
        offset: { dx: 0, dy: -20 }
      })
    })
  }

  build() {
    Row() {
      // 左侧分类色条
      Column()
        .width(3)
        .height(52)
        .backgroundColor(getCategoryInfo(this.bill.category).color)
        .borderRadius({ topLeft: 3, bottomLeft: 3 })
        .margin({ right: 12 })

      // 图标圆
      Column() {
        Image($rawfile(getCategoryInfo(this.bill.category).icon + '.svg'))
          .width(22)
          .height(22)
          .fillColor('#FFFFFF')
      }
      .width(42)
      .height(42)
      .borderRadius(21)
      .backgroundColor(getCategoryInfo(this.bill.category).color)
      .alignItems(HorizontalAlign.Center)
      .justifyContent(FlexAlign.Center)
      .margin({ right: 12 })

      // 中间文字
      Column() {
        Text(this.bill.category)
          .fontSize(15)
          .fontColor('#212121')
          .fontWeight(FontWeight.Medium)
          .maxLines(1)
        Text(this.bill.remark && this.bill.remark.length > 0
          ? this.bill.remark
          : DateUtil.getRelativeTime(this.bill.createdAt))
          .fontSize(12)
          .fontColor('#9E9E9E')
          .maxLines(1)
          .margin({ top: 3 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      // 金额
      Text(AmountUtil.formatWithSign(this.bill.amount, this.bill.type))
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.bill.type === 'income' ? '#4CAF50' : '#F44336')
    }
    .width('100%')
    .height(64)
    .padding({ left: 0, right: 16 })
    .backgroundColor('#FFFFFF')
    .alignItems(VerticalAlign.Center)
    .swipeAction({ end: this.deleteBuilder })
  }
}
