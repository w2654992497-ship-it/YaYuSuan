import { Bill } from '../model/Bill'
import { FilterOptions } from '../model/FilterOptions'
import { DaySummary } from '../model/StatResult'
import { BillDao } from '../database/BillDao'
import { CalendarGrid } from './CalendarGrid'
import { BillItem } from './BillItem'
import { AmountUtil } from '../utils/AmountUtil'
import { DateUtil } from '../utils/DateUtil'
import { LogUtils } from '../utils/LogUtils'
import { EXPENSE_CATEGORIES } from '../model/Category'
import { preferences } from '@kit.ArkData'

interface BudgetProgress {
  name: string
  color: string
  budgetFen: number
  usedFen: number
}

@Component
export struct CalendarView {
  @Watch('onMonthChanged')
  @Prop currentMonth: string = ''
  @Watch('onRefreshKeyChanged')
  @Prop refreshKey: number = 0
  @State selectedDate: string = DateUtil.today()
  @State daySummaries: DaySummary[] = []
  @State monthIncome: number = 0
  @State monthExpense: number = 0
  @State dayBills: Bill[] = []
  @State budgetList: BudgetProgress[] = []
  onDeleteBill: (id: number) => void = () => {}

  onMonthChanged(): void { this.loadMonthData() }
  onRefreshKeyChanged(): void { this.loadMonthData() }
  aboutToAppear(): void { this.loadMonthData() }

  async loadMonthData(): Promise<void> {
    try {
      this.daySummaries = await BillDao.getInstance().queryDailySummary(this.currentMonth)
      let income = 0
      let expense = 0
      for (const s of this.daySummaries) {
        income += s.income
        expense += s.expense
      }
      this.monthIncome = income
      this.monthExpense = expense

      if (!this.selectedDate.startsWith(this.currentMonth)) {
        const today = DateUtil.today()
        this.selectedDate = today.startsWith(this.currentMonth) ? today : `${this.currentMonth}-01`
      }
      await this.loadBudgetProgress()
      await this.loadDayBills()
    } catch (err) {
      LogUtils.error('CalendarView', 'loadMonthData: %{public}s', JSON.stringify(err))
    }
  }

  private async loadBudgetProgress(): Promise<void> {
    try {
      const pref = await preferences.getPreferences(this.getUIContext().getHostContext()!, { name: 'yayusuan_budget' })
      const filter: FilterOptions = { month: this.currentMonth, type: 'expense', category: '' }
      const bills = await BillDao.getInstance().queryByFilter(filter)
      const usageMap: Map<string, number> = new Map()
      for (const b of bills) {
        usageMap.set(b.category, (usageMap.get(b.category) ?? 0) + b.amount)
      }
      const result: BudgetProgress[] = []
      for (const cat of EXPENSE_CATEGORIES) {
        const budgetFen = await pref.get(`budget_${cat.name}`, 0) as number
        if (budgetFen > 0) {
          result.push({ name: cat.name, color: cat.color, budgetFen: budgetFen, usedFen: usageMap.get(cat.name) ?? 0 })
        }
      }
      this.budgetList = result
    } catch (_e) { this.budgetList = [] }
  }

  private async loadDayBills(): Promise<void> {
    try {
      const filter: FilterOptions = { month: this.currentMonth, type: 'all', category: '' }
      const allBills = await BillDao.getInstance().queryByFilter(filter)
      this.dayBills = allBills.filter((b: Bill): boolean => b.date === this.selectedDate)
    } catch (err) {
      LogUtils.error('CalendarView', 'loadDayBills: %{public}s', JSON.stringify(err))
      this.dayBills = []
    }
  }

  private onDateSelected(date: string): void {
    this.selectedDate = date
    this.loadDayBills()
  }

  private getSelectedDaySummary(): DaySummary {
    return this.daySummaries.find((s: DaySummary): boolean => s.date === this.selectedDate)
      ?? { date: this.selectedDate, income: 0, expense: 0 }
  }

  private formatBalance(income: number, expense: number): string {
    const balance = income - expense
    if (balance >= 0) return `+${AmountUtil.fen2Display(balance)}`
    return `-${AmountUtil.fen2Display(balance * -1)}`
  }

  @Builder
  DeleteBuilder(bill: Bill) {
    Column() {
      Image($rawfile('icon_other.svg')).width(20).height(20).fillColor('#FFFFFF').margin({ bottom: 4 })
      Text('删除').fontSize(12).fontColor('#FFFFFF')
    }
    .width(72).height('100%')
    .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
    .backgroundColor('#F44336')
    .onClick(() => {
      this.getUIContext().showAlertDialog({
        title: '删除账单',
        message: `确认删除「${bill.category}」这条记录吗？`,
        primaryButton: { value: '取消', fontColor: '#1976D2', action: () => {} },
        secondaryButton: { value: '删除', fontColor: '#F44336', action: () => { this.onDeleteBill(bill.id) } },
        alignment: DialogAlignment.Bottom,
        offset: { dx: 0, dy: -20 }
      })
    })
  }

  @Builder
  SummaryPill(label: string, value: string, color: string) {
    Column() {
      Text(label).fontSize(10).fontColor('#757575')
      Text(value).fontSize(15).fontColor(color).fontWeight(FontWeight.Medium).margin({ top: 2 })
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
  }

  build() {
    Scroll() {
      Column() {
        // ── 日历网格 ──
        Column() {
          CalendarGrid({
            currentMonth: this.currentMonth,
            selectedDate: this.selectedDate,
            daySummaries: this.daySummaries,
            onSelectDate: (date: string) => { this.onDateSelected(date) }
          })
        }
        .width('100%')
        .backgroundColor('#FFFFFF')
        .borderRadius({ topLeft: 0, topRight: 0, bottomLeft: 14, bottomRight: 14 })
        .padding({ left: 6, right: 6, top: 0, bottom: 4 })
        .shadow({ radius: 4, color: '#0A000000', offsetX: 0, offsetY: 2 })

        // ── 月度汇总条 ──
        Row() {
          this.SummaryPill('收入', `¥${AmountUtil.fen2Display(this.monthIncome)}`, '#4CAF50')

          Divider().vertical(true).height(26).color('#E0E0E0')

          this.SummaryPill('支出', `¥${AmountUtil.fen2Display(this.monthExpense)}`, '#F44336')

          Divider().vertical(true).height(26).color('#E0E0E0')

          this.SummaryPill('结余', this.formatBalance(this.monthIncome, this.monthExpense),
            (this.monthIncome - this.monthExpense) >= 0 ? '#4CAF50' : '#F44336')
        }
        .width('100%')
        .padding({ top: 10, bottom: 10 })
        .margin({ left: 12, right: 12, top: 10 })
        .backgroundColor('#FFFFFF')
        .borderRadius(12)
        .shadow({ radius: 4, color: '#0A000000', offsetX: 0, offsetY: 1 })

        // ── 预算进度 ──
        if (this.budgetList.length > 0) {
          Column() {
            Row() {
              Text('预算')
                .fontSize(13).fontColor('#212121').fontWeight(FontWeight.Medium)
              Blank()
              Text('已用 / 上限')
                .fontSize(10).fontColor('#757575')
            }
            .width('100%')
            .margin({ bottom: 8 })

            ForEach(this.budgetList, (bp: BudgetProgress) => {
              Column() {
                Row() {
                  Text(bp.name).fontSize(12).fontColor('#212121')
                  Blank()
                  Text(`¥${AmountUtil.fen2Display(bp.usedFen)} / ¥${AmountUtil.fen2Display(bp.budgetFen)}`)
                    .fontSize(10)
                    .fontColor(bp.usedFen > bp.budgetFen ? '#F44336' : '#757575')
                }
                .width('100%')
                .margin({ bottom: 4 })

                Stack({ alignContent: Alignment.Start }) {
                  Row().width('100%').height(4).borderRadius(2).backgroundColor('#F5F5F5')
                  Row()
                    .width(`${Math.min(bp.usedFen / bp.budgetFen * 100, 100)}%`)
                    .height(4).borderRadius(2)
                    .backgroundColor(bp.usedFen > bp.budgetFen ? '#F44336' : bp.color)
                }
                .width('100%')
                .height(4)
              }
              .margin({ bottom: 8 })
            }, (bp: BudgetProgress) => bp.name)
          }
          .width('100%')
          .padding(12)
          .margin({ left: 12, right: 12, top: 10 })
          .backgroundColor('#FFFFFF')
          .borderRadius(12)
          .shadow({ radius: 4, color: '#0A000000', offsetX: 0, offsetY: 1 })
        }

        // ── 选中日期的账单 ──
        Column() {
          // 日期头 + 当日汇总
          Row() {
            // 日期标签
            Row() {
              Text(DateUtil.friendlyDate(this.selectedDate))
                .fontSize(14)
                .fontColor('#212121')
                .fontWeight(FontWeight.Medium)
            }

            Blank()

            // 当日收支标签
            if (this.getSelectedDaySummary().expense > 0) {
              Text(`支 ¥${AmountUtil.fen2Display(this.getSelectedDaySummary().expense)}`)
                .fontSize(11)
                .fontColor('#F44336')
                .backgroundColor('#FFF5F5')
                .borderRadius(10)
                .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                .margin({ right: 4 })
            }
            if (this.getSelectedDaySummary().income > 0) {
              Text(`收 ¥${AmountUtil.fen2Display(this.getSelectedDaySummary().income)}`)
                .fontSize(11)
                .fontColor('#4CAF50')
                .backgroundColor('#F5FFF5')
                .borderRadius(10)
                .padding({ left: 8, right: 8, top: 3, bottom: 3 })
            }
          }
          .width('100%')
          .padding({ left: 14, right: 14, top: 12, bottom: 8 })

          Divider().color('#F5F5F5').margin({ left: 14, right: 14 })

          if (this.dayBills.length === 0) {
            Column() {
              Image($rawfile('icon_tab_bills.svg'))
                .width(40).height(40).fillColor('#E0E0E0').margin({ bottom: 8 })
              Text('当日暂无账单')
                .fontSize(13).fontColor('#757575')
            }
            .width('100%')
            .padding({ top: 30, bottom: 30 })
            .alignItems(HorizontalAlign.Center)
          } else {
            List() {
              ForEach(this.dayBills, (bill: Bill) => {
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
            .divider({ strokeWidth: 0.5, color: '#F5F5F5', startMargin: 70 })
            .nestedScroll({
              scrollForward: NestedScrollMode.PARENT_FIRST,
              scrollBackward: NestedScrollMode.SELF_FIRST
            })
          }
        }
        .width('100%')
        .margin({ left: 12, right: 12, top: 10, bottom: 16 })
        .backgroundColor('#FFFFFF')
        .borderRadius(12)
        .shadow({ radius: 4, color: '#0A000000', offsetX: 0, offsetY: 1 })
        .clip(true)
      }
      .width('100%')
    }
    .align(Alignment.Top)
    .layoutWeight(1)
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
  }
}
