import { Bill } from '../model/Bill'
import { FilterOptions } from '../model/FilterOptions'
import { DaySummary } from '../model/StatResult'
import { BillDao } from '../database/BillDao'
import { CalendarGrid } from './CalendarGrid'
import { getCategoryColor, getCategoryInfo } from '../model/Category'
import { AmountUtil } from '../utils/AmountUtil'
import { DateUtil } from '../utils/DateUtil'
import { LogUtils } from '../utils/LogUtils'

@Component
export struct CalendarView {
  @Watch('onMonthChanged')
  @Prop currentMonth: string = ''
  @Watch('onRefreshKeyChanged')
  @Prop refreshKey: number = 0
  @Watch('onTodaySignalChanged')
  @Prop todaySignal: number = 0
  @Consume activeTabIndex: number
  @State selectedDate: string = DateUtil.today()
  @State daySummaries: DaySummary[] = []
  @State monthIncome: number = 0
  @State monthExpense: number = 0
  @State dayBills: Bill[] = []
  onDeleteBill: (id: number) => void = () => {}

  onMonthChanged(): void {
    this.loadMonthData()
  }

  onRefreshKeyChanged(): void {
    this.loadMonthData()
  }

  onTodaySignalChanged(): void {
    this.selectedDate = DateUtil.today()
    this.loadMonthData()
  }

  aboutToAppear(): void {
    this.loadMonthData()
  }

  private async loadMonthData(): Promise<void> {
    try {
      const summaries = await BillDao.getInstance().queryDailySummary(this.currentMonth)
      let income = 0
      let expense = 0
      for (let i = 0; i < summaries.length; i++) {
        income += summaries[i].income
        expense += summaries[i].expense
      }
      this.daySummaries = summaries
      this.monthIncome = income
      this.monthExpense = expense

      if (!this.selectedDate.startsWith(this.currentMonth)) {
        const today = DateUtil.today()
        this.selectedDate = today.startsWith(this.currentMonth) ? today : `${this.currentMonth}-01`
      }
      await this.loadDayBills()
    } catch (err) {
      LogUtils.error('CalendarView', 'loadMonthData: %{public}s', JSON.stringify(err))
    }
  }

  private async loadDayBills(): Promise<void> {
    try {
      const filter: FilterOptions = { month: this.currentMonth, type: 'all', category: '' }
      const allBills = await BillDao.getInstance().queryByFilter(filter)
      const result: Bill[] = []
      for (let i = 0; i < allBills.length; i++) {
        if (allBills[i].date === this.selectedDate) {
          result.push(allBills[i])
        }
      }
      this.dayBills = result
    } catch (err) {
      LogUtils.error('CalendarView', 'loadDayBills: %{public}s', JSON.stringify(err))
      this.dayBills = []
    }
  }

  private onDateSelected(date: string): void {
    this.selectedDate = date
    this.loadDayBills()
  }

  private selectedIncome(): number {
    for (let i = 0; i < this.daySummaries.length; i++) {
      if (this.daySummaries[i].date === this.selectedDate) {
        return this.daySummaries[i].income
      }
    }
    return 0
  }

  private selectedExpense(): number {
    for (let i = 0; i < this.daySummaries.length; i++) {
      if (this.daySummaries[i].date === this.selectedDate) {
        return this.daySummaries[i].expense
      }
    }
    return 0
  }

  private monthBalance(): number {
    return this.monthIncome - this.monthExpense
  }

  private selectedDateTitle(): string {
    const parts = this.selectedDate.split('-')
    if (parts.length !== 3) {
      return this.selectedDate
    }
    const month = parseInt(parts[1], 10)
    const day = parseInt(parts[2], 10)
    const weekLabels: string[] = ['周日', '周一', '周二', '周三', '周四', '周五', '周六']
    const date = new Date(this.selectedDate)
    let title = `${month}月${day}日 ${weekLabels[date.getDay()]}`
    if (this.selectedDate === DateUtil.today()) {
      title = `${title} · 今天`
    }
    return title
  }

  @Builder
  BillRow(bill: Bill) {
    Row() {
      Row() {
        Image($rawfile(getCategoryInfo(bill.category).icon + '.svg'))
          .width(20)
          .height(20)
          .fillColor($r('app.color.color_white'))
      }
      .width(42)
      .height(42)
      .borderRadius(21)
      .backgroundColor(getCategoryColor(bill.category))
      .justifyContent(FlexAlign.Center)
      .margin({ right: 12 })

      Column() {
        Row() {
          Text(bill.category)
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.color_text_deep'))
            .margin({ right: 10 })
          if (bill.remark.length > 0) {
            Text(bill.remark)
              .fontSize(13)
              .fontColor($r('app.color.color_text_secondary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
        }
        .width('100%')

        Text(DateUtil.getRelativeTime(bill.createdAt))
          .fontSize(11)
          .fontColor($r('app.color.color_text_secondary'))
          .margin({ top: 3 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Text(`${bill.type === 'income' ? '+' : '-'}¥${AmountUtil.fen2Display(bill.amount)}`)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(bill.type === 'income' ? $r('app.color.color_income') : $r('app.color.color_expense'))
        .margin({ right: 8 })

      Image($rawfile('icon_chevron_right.svg'))
        .width(14)
        .height(14)
        .fillColor($r('app.color.color_text_secondary'))
    }
    .width('100%')
    .height(58)
    .padding({ left: 12, right: 10 })
    .alignItems(VerticalAlign.Center)
  }

  build() {
    Scroll() {
      Column() {
        Row() {
          Column() {
            Text('本月收入')
              .fontSize(12)
              .fontColor($r('app.color.color_text_secondary'))
            Text(`¥${AmountUtil.fen2Display(this.monthIncome)}`)
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.color_income'))
              .margin({ top: 3 })
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Center)

          Divider().vertical(true).height(30).color($r('app.color.color_divider'))

          Column() {
            Text('本月支出')
              .fontSize(12)
              .fontColor($r('app.color.color_text_secondary'))
            Text(`¥${AmountUtil.fen2Display(this.monthExpense)}`)
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.color_expense'))
              .margin({ top: 3 })
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Center)

          Divider().vertical(true).height(30).color($r('app.color.color_divider'))

          Column() {
            Text('本月结余')
              .fontSize(12)
              .fontColor($r('app.color.color_text_secondary'))
            Text(`${this.monthBalance() < 0 ? '-' : ''}¥${AmountUtil.fen2Display(Math.abs(this.monthBalance()))}`)
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.monthBalance() < 0 ? $r('app.color.color_primary') : $r('app.color.color_income'))
              .margin({ top: 3 })
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Center)
        }
        .width('calc(100% - 32vp)')
        .height(58)
        .padding({ left: 12, right: 12 })
        .backgroundColor($r('app.color.color_card_overlay'))
        .borderRadius(16)
        .border({ width: 1, color: $r('app.color.color_divider') })
        .shadow({ radius: 10, color: $r('app.color.color_shadow_blue_09'), offsetX: 0, offsetY: 4 })
        .margin({ left: 16, right: 16, top: 4, bottom: 8 })

        Column() {
          CalendarGrid({
            currentMonth: this.currentMonth,
            selectedDate: this.selectedDate,
            daySummaries: this.daySummaries,
            onSelectDate: (date: string) => {
              this.onDateSelected(date)
            }
          })
        }
        .width('calc(100% - 32vp)')
        .padding({ left: 10, right: 10, top: 10, bottom: 8 })
        .backgroundColor($r('app.color.color_card_overlay'))
        .borderRadius(16)
        .border({ width: 1, color: $r('app.color.color_divider') })
        .shadow({ radius: 10, color: $r('app.color.color_shadow_blue_09'), offsetX: 0, offsetY: 4 })
        .margin({ left: 16, right: 16, top: 0, bottom: 8 })

        Column() {
          Row() {
            Text(this.selectedDateTitle())
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.color_text_deep'))
            Blank()
            if (this.selectedExpense() > 0) {
              Text(`支出 ¥${AmountUtil.fen2Display(this.selectedExpense())}`)
                .fontSize(14)
                .fontColor($r('app.color.color_expense'))
                .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                .backgroundColor('#FFFFECEC')
                .borderRadius(14)
            }
            if (this.selectedIncome() > 0) {
              Text(`收入 ¥${AmountUtil.fen2Display(this.selectedIncome())}`)
                .fontSize(14)
                .fontColor($r('app.color.color_income'))
                .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                .backgroundColor($r('app.color.color_selected_bg'))
                .borderRadius(14)
                .margin({ left: 6 })
            }
          }
          .width('100%')
          .padding({ left: 12, right: 12, top: 10 })

          Row({ space: 6 }) {
            Row() {
              Text('+')
                .fontSize(18)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.color_white'))
            }
            .width(20)
            .height(20)
            .borderRadius(10)
            .backgroundColor($r('app.color.color_primary'))
            .justifyContent(FlexAlign.Center)

            Text('记一笔')
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.color_primary'))
          }
          .width('100%')
          .padding({ left: 12, right: 12, top: 7, bottom: 7 })
          .onClick(() => {
            this.activeTabIndex = 2
          })

          if (this.dayBills.length === 0) {
            Column() {
              Image($rawfile('icon_list.svg'))
                .width(34)
                .height(34)
                .fillColor($r('app.color.color_divider'))
                .margin({ bottom: 8 })
              Text('当日暂无账单')
                .fontSize(13)
                .fontColor($r('app.color.color_text_secondary'))
            }
            .width('100%')
            .padding({ top: 20, bottom: 24 })
            .alignItems(HorizontalAlign.Center)
          } else {
            Column() {
              ForEach(this.dayBills, (bill: Bill, index: number) => {
                Column() {
                  this.BillRow(bill)
                  if (index < this.dayBills.length - 1) {
                    Divider()
                      .color($r('app.color.color_divider'))
                      .margin({ left: 66, right: 12 })
                  }
                }
                .width('100%')
              }, (bill: Bill) => bill.id.toString())
            }
            .width('100%')
            .backgroundColor($r('app.color.color_white'))
            .borderRadius(16)
            .border({ width: 1, color: $r('app.color.color_divider') })
            .clip(true)
          }
        }
        .width('calc(100% - 32vp)')
        .padding({ left: 0, right: 0, top: 0, bottom: 10 })
        .backgroundColor($r('app.color.color_card_overlay'))
        .borderRadius(16)
        .border({ width: 1, color: $r('app.color.color_divider') })
        .shadow({ radius: 10, color: $r('app.color.color_shadow_blue_09'), offsetX: 0, offsetY: 4 })
        .margin({ left: 16, right: 16, top: 0, bottom: 12 })
      }
      .width('100%')
    }
    .layoutWeight(1)
    .width('100%')
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
  }
}
