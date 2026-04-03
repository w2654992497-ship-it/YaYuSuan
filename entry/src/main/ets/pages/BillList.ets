import { BillDao } from '../database/BillDao'
import { FilterOptions } from '../model/FilterOptions'
import { Bill } from '../model/Bill'
import { AmountUtil } from '../utils/AmountUtil'
import { DateUtil } from '../utils/DateUtil'
import { SummaryCard } from '../components/SummaryCard'
import { BillItem } from '../components/BillItem'

interface BillGroupData {
  date: string
  bills: Bill[]
  dayIncome: number
  dayExpense: number
}

@Component
export struct BillListPage {
  @Watch('onTabChanged')
  @Consume activeTabIndex: number
  @State billGroups: BillGroupData[] = []
  @State filter: FilterOptions = { month: DateUtil.currentMonth(), type: 'all', category: '' }
  @State totalIncome: number = 0
  @State totalExpense: number = 0
  @State slideOffsetX: number = 0

  onTabChanged(): void {
    if (this.activeTabIndex === 0) {
      this.loadData()
    }
  }

  aboutToAppear(): void {
    this.loadData()
  }

  async loadData(): Promise<void> {
    const bills = await BillDao.getInstance().queryByFilter(this.filter)
    const groupMap = new Map<string, BillGroupData>()
    let inc = 0
    let exp = 0

    for (const bill of bills) {
      if (bill.type === 'income') inc += bill.amount
      else exp += bill.amount

      if (!groupMap.has(bill.date)) {
        groupMap.set(bill.date, { date: bill.date, bills: [], dayIncome: 0, dayExpense: 0 })
      }
      const g = groupMap.get(bill.date)!
      g.bills.push(bill)
      if (bill.type === 'income') g.dayIncome += bill.amount
      else g.dayExpense += bill.amount
    }

    this.billGroups = Array.from(groupMap.values()).sort((a, b) => b.date.localeCompare(a.date))
    this.totalIncome = inc
    this.totalExpense = exp
  }

  private doMonthSwitch(direction: number): void {
    const cur = this.filter.month || DateUtil.currentMonth()
    if (direction < 0 && DateUtil.isCurrentMonth(cur)) {
      this.getUIContext().animateTo({ duration: 150, curve: Curve.EaseOut }, () => {
        this.slideOffsetX = 0
      })
      return
    }
    const next = direction > 0 ? DateUtil.getPrevMonth(cur) : DateUtil.getNextMonth(cur)
    const exitX = direction > 0 ? 360 : -360

    this.getUIContext().animateTo({
      duration: 150,
      curve: Curve.EaseIn,
      onFinish: () => {
        this.slideOffsetX = exitX * -1
        this.filter = { month: next, type: this.filter.type, category: this.filter.category }
        this.loadData()
        this.getUIContext().animateTo({ duration: 200, curve: Curve.EaseOut }, () => {
          this.slideOffsetX = 0
        })
      }
    }, () => {
      this.slideOffsetX = exitX
    })
  }

  @Builder
  TypeChip(label: string, chipType: 'all' | 'income' | 'expense') {
    Text(label)
      .fontSize(13)
      .fontColor(this.filter.type === chipType ? $r('app.color.color_surface') : $r('app.color.color_text_secondary'))
      .fontWeight(this.filter.type === chipType ? FontWeight.Medium : FontWeight.Normal)
      .backgroundColor(this.filter.type === chipType ? $r('app.color.color_primary') : $r('app.color.color_surface'))
      .borderRadius(16)
      .padding({ left: 16, right: 16, top: 5, bottom: 5 })
      .animation({ duration: 200, curve: Curve.EaseOut })
      .onClick(() => {
        this.filter = { month: this.filter.month, type: chipType, category: this.filter.category }
        this.loadData()
      })
  }

  // 日净额格式化
  private dayNetDisplay(group: BillGroupData): string {
    const net = group.dayIncome - group.dayExpense
    if (net > 0) return `+${AmountUtil.fen2Display(net)}`
    if (net < 0) return `-${AmountUtil.fen2Display(net * -1)}`
    return '0.00'
  }

  build() {
    Column() {
      // ── 月份导航栏 ──
      Row() {
        Row() {
          Image($rawfile('icon_chevron_left.svg'))
            .width(20).height(20)
            .fillColor($r('app.color.color_primary'))
        }
        .width(36).height(36).borderRadius(18)
        .justifyContent(FlexAlign.Center)
        .backgroundColor('rgba(44,122,123,0.08)')
        .onClick(() => { this.doMonthSwitch(1) })

        Row() {
          Text(DateUtil.formatMonthDisplay(this.filter.month || DateUtil.currentMonth()))
            .fontSize(17).fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.color_text_primary'))
          Image($rawfile('icon_other.svg'))
            .width(12).height(12)
            .fillColor($r('app.color.color_text_secondary'))
            .margin({ left: 4 })
        }
        .margin({ left: 20, right: 20 })
        .onClick(() => {
          const parts = (this.filter.month || DateUtil.currentMonth()).split('-')
          const now = new Date()
          this.getUIContext().showDatePickerDialog({
            start: new Date('2020-01-01'),
            end: now,
            selected: new Date(parseInt(parts[0], 10), parseInt(parts[1], 10) - 1, 1),
            lunar: false,
            onDateAccept: (value: Date) => {
              const y = value.getFullYear()
              const m = (value.getMonth() + 1).toString().padStart(2, '0')
              this.filter = { month: `${y}-${m}`, type: this.filter.type, category: this.filter.category }
              this.loadData()
            }
          })
        })

        Row() {
          Image($rawfile('icon_chevron_right.svg'))
            .width(20).height(20)
            .fillColor(DateUtil.isCurrentMonth(this.filter.month || DateUtil.currentMonth())
              ? $r('app.color.color_divider') : $r('app.color.color_primary'))
        }
        .width(36).height(36).borderRadius(18)
        .justifyContent(FlexAlign.Center)
        .backgroundColor(DateUtil.isCurrentMonth(this.filter.month || DateUtil.currentMonth())
          ? 'rgba(0,0,0,0.03)' : 'rgba(44,122,123,0.08)')
        .onClick(() => {
          if (!DateUtil.isCurrentMonth(this.filter.month || DateUtil.currentMonth())) {
            this.doMonthSwitch(-1)
          }
        })
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .padding({ top: 10, bottom: 6 })

      // ── 内容区（跟手滑动切月） ──
      Column() {
        // 汇总卡片
        SummaryCard({ income: this.totalIncome, expense: this.totalExpense })

        // 筛选 Chip
        Row({ space: 6 }) {
          this.TypeChip('全部', 'all')
          this.TypeChip('收入', 'income')
          this.TypeChip('支出', 'expense')
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .padding({ top: 6, bottom: 8 })

        // ── 账单列表 / 空状态 ──
        if (this.billGroups.length === 0) {
          Column() {
            Image($rawfile('icon_tab_bills.svg'))
              .width(56).height(56)
              .fillColor($r('app.color.color_divider'))
              .margin({ bottom: 12 })
            Text('还没有账单记录')
              .fontSize(15).fontColor($r('app.color.color_text_secondary'))
            Text('点击下方「记账」开始记录')
              .fontSize(12).fontColor($r('app.color.color_tab_inactive'))
              .margin({ top: 4 })
          }
          .width('100%').layoutWeight(1)
          .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
        } else {
          List() {
            ForEach(this.billGroups, (group: BillGroupData) => {
              // 日期分组头
              ListItem() {
                Row() {
                  // 日期标签
                  Row() {
                    Text(DateUtil.friendlyDate(group.date))
                      .fontSize(12)
                      .fontColor($r('app.color.color_text_secondary'))
                      .fontWeight(FontWeight.Medium)
                  }
                  .padding({ left: 10, right: 10, top: 3, bottom: 3 })
                  .backgroundColor($r('app.color.color_surface'))
                  .borderRadius(10)

                  Blank()

                  // 当日净额
                  Text(this.dayNetDisplay(group))
                    .fontSize(12)
                    .fontColor(group.dayIncome >= group.dayExpense
                      ? $r('app.color.color_income') : $r('app.color.color_expense'))
                    .fontWeight(FontWeight.Medium)
                }
                .width('100%')
                .padding({ left: 20, right: 20, top: 14, bottom: 6 })
              }
              .selectable(false)

              // 该日期下的账单条目
              ForEach(group.bills, (bill: Bill) => {
                BillItem({
                  bill: bill,
                  onDelete: async () => {
                    await BillDao.getInstance().deleteById(bill.id)
                    this.loadData()
                  }
                })
              }, (bill: Bill) => bill.id.toString())
            }, (group: BillGroupData) => `${group.date}_${group.bills.length}_${group.dayIncome}_${group.dayExpense}`)
          }
          .layoutWeight(1)
          .width('100%')
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)
        }
      }
      .width('100%')
      .layoutWeight(1)
      .clip(true)
      .translate({ x: this.slideOffsetX })
      .gesture(
        PanGesture({ direction: PanDirection.Horizontal, distance: 5 })
          .onActionUpdate((event: GestureEvent) => {
            if (event) { this.slideOffsetX = event.offsetX }
          })
          .onActionEnd((event: GestureEvent) => {
            if (!event) { this.slideOffsetX = 0; return }
            if (event.offsetX > 80) { this.doMonthSwitch(1) }
            else if (event.offsetX < -80) { this.doMonthSwitch(-1) }
            else {
              this.getUIContext().animateTo(
                { duration: 150, curve: Curve.EaseOut },
                () => { this.slideOffsetX = 0 }
              )
            }
          })
      )
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.color_bg'))
  }
}
