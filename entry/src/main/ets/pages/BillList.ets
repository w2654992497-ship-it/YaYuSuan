import { Bill } from '../model/Bill'
import { FilterOptions, createDefaultFilter } from '../model/FilterOptions'
import { BillGroupData } from '../model/StatResult'
import { BillDao } from '../database/BillDao'
import { SummaryCard } from '../components/SummaryCard'
import { BillGroup } from '../components/BillGroup'
import { CalendarView } from '../components/CalendarView'
import { NavBar } from '../components/NavBar'
import { LazyForEachDataSource } from '../utils/LazyForEachDataSource'
import { DateUtil } from '../utils/DateUtil'
import { AmountUtil } from '../utils/AmountUtil'
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
export struct BillListPage {
  @Watch('onTabChanged')
  @Consume activeTabIndex: number
  @State filter: FilterOptions = createDefaultFilter()
  @State totalIncome: number = 0
  @State totalExpense: number = 0
  @State isLoading: boolean = false
  @State budgetList: BudgetProgress[] = []
  @State viewMode: 'list' | 'calendar' = 'list'
  @State calendarMonth: string = DateUtil.currentMonth()
  @State calendarRefreshKey: number = 0
  @State slideOffsetX: number = 0
  private billGroupsDS: LazyForEachDataSource<BillGroupData> = new LazyForEachDataSource<BillGroupData>([])

  onTabChanged(): void {
    if (this.activeTabIndex === 0) {
      if (this.viewMode === 'list') {
        this.loadData()
      } else {
        this.refreshCalendar()
      }
    }
  }

  aboutToAppear(): void {
    this.loadData()
  }

  @Builder
  TypeChip(label: string, chipType: 'all' | 'income' | 'expense') {
    Text(label)
      .fontSize(13)
      .fontColor(this.filter.type === chipType ? '#1976D2' : '#757575')
      .fontWeight(this.filter.type === chipType ? FontWeight.Medium : FontWeight.Normal)
      .backgroundColor(this.filter.type === chipType ? '#E3F2FD' : '#F5F5F5')
      .borderRadius(16)
      .padding({ left: 16, right: 16, top: 6, bottom: 6 })
      .onClick(() => {
        this.filter = {
          month: this.filter.month,
          type: chipType,
          category: this.filter.category
        }
        this.loadData()
      })
  }

  private groupByDate(bills: Bill[]): BillGroupData[] {
    const dateMap: Map<string, Bill[]> = new Map()
    for (const bill of bills) {
      const existing = dateMap.get(bill.date)
      if (existing) {
        existing.push(bill)
      } else {
        dateMap.set(bill.date, [bill])
      }
    }
    const groups: BillGroupData[] = []
    dateMap.forEach((dateBills, date) => {
      let dayIncome = 0
      let dayExpense = 0
      for (const b of dateBills) {
        if (b.type === 'income') { dayIncome += b.amount }
        else { dayExpense += b.amount }
      }
      groups.push({ date: date, bills: dateBills, dayIncome: dayIncome, dayExpense: dayExpense })
    })
    groups.sort((a, b) => {
      if (a.date > b.date) return -1
      if (a.date < b.date) return 1
      return 0
    })
    return groups
  }

  private async loadData(): Promise<void> {
    this.isLoading = true
    try {
      const bills = await BillDao.getInstance().queryByFilter(this.filter)
      let income = 0
      let expense = 0
      for (const bill of bills) {
        if (bill.type === 'income') { income += bill.amount }
        else { expense += bill.amount }
      }
      this.totalIncome = income
      this.totalExpense = expense
      const newGroups = this.groupByDate(bills)
      this.billGroupsDS.smartUpdate(
        newGroups,
        (g: BillGroupData) => g.date,
        (g: BillGroupData) => `${g.date}:${g.bills.map((b: Bill) => b.id.toString()).join(',')}`
      )
      await this.loadBudgetProgress(bills)
    } catch (err) {
      LogUtils.error('BillList', 'loadData error: %{public}s', JSON.stringify(err))
    } finally {
      this.isLoading = false
    }
  }

  private async loadBudgetProgress(bills: Bill[]): Promise<void> {
    try {
      const pref = await preferences.getPreferences(this.getUIContext().getHostContext()!, { name: 'yayusuan_budget' })
      const usageMap: Map<string, number> = new Map()
      for (const b of bills) {
        if (b.type === 'expense') {
          usageMap.set(b.category, (usageMap.get(b.category) ?? 0) + b.amount)
        }
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

  private async deleteBill(id: number): Promise<void> {
    try {
      await BillDao.getInstance().deleteById(id)
      if (this.viewMode === 'list') { await this.loadData() }
      else { this.refreshCalendar() }
    } catch (err) {
      LogUtils.error('BillList', 'deleteBill error: %{public}s', JSON.stringify(err))
    }
  }

  private refreshCalendar(): void { this.calendarRefreshKey++ }

  private getCurrentMonth(): string {
    return this.viewMode === 'list' ? this.filter.month : this.calendarMonth
  }

  private setCurrentMonth(month: string): void {
    if (this.viewMode === 'list') {
      this.filter = { month: month, type: this.filter.type, category: this.filter.category }
      this.loadData()
    } else {
      this.calendarMonth = month
    }
  }

  /**
   * 无缝月份切换：滑出 → 换数据 → 滑入
   * direction: 1=上月（右滑），-1=下月（左滑）
   */
  private doMonthSwitch(direction: number): void {
    const cur = this.getCurrentMonth()
    if (direction < 0 && DateUtil.isCurrentMonth(cur)) {
      this.getUIContext().animateTo({ duration: 150, curve: Curve.EaseOut }, () => {
        this.slideOffsetX = 0
      })
      return
    }
    const next = direction > 0 ? DateUtil.getPrevMonth(cur) : DateUtil.getNextMonth(cur)
    // 滑出方向：右滑→内容向右飞出(+360)，左滑→内容向左飞出(-360)
    const exitX = direction > 0 ? 360 : -360

    // 滑出屏幕，onFinish 时精确衔接
    this.getUIContext().animateTo({
      duration: 150,
      curve: Curve.EaseIn,
      onFinish: () => {
        // 此时内容在屏幕外(exitX)，用户看不到
        // 瞬间跳到另一侧（也在屏幕外），不会闪烁
        this.slideOffsetX = exitX * -1
        this.setCurrentMonth(next)
        // 从另一侧滑入
        this.getUIContext().animateTo({ duration: 200, curve: Curve.EaseOut }, () => {
          this.slideOffsetX = 0
        })
      }
    }, () => {
      this.slideOffsetX = exitX
    })
  }

  build() {
    Column() {
        // ── 页面标题 ──
        NavBar({
          title: '账单',
          showLeft: false,
          showDivider: true
        })

        // ── 月份导航 + 模式切换 ──
        Row() {
          // 左箭头
          Column() {
            Text('‹')
              .fontSize(24)
              .fontColor('#1976D2')
              .fontWeight(FontWeight.Bold)
          }
          .width(44)
          .height(44)
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
          .borderRadius(22)
          .backgroundColor('#E3F2FD')
          .onClick(() => { this.doMonthSwitch(1) })

          // 月份标题（点击快速跳转）
          Column() {
            Text(DateUtil.formatMonthDisplay(this.getCurrentMonth()))
              .fontSize(18)
              .fontColor('#212121')
              .fontWeight(FontWeight.Bold)
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Center)
          .onClick(() => {
            const parts = this.getCurrentMonth().split('-')
            const now = new Date()
            this.getUIContext().showDatePickerDialog({
              start: new Date('2020-01-01'),
              end: now,
              selected: new Date(parseInt(parts[0], 10), parseInt(parts[1], 10) - 1, 1),
              lunar: false,
              onDateAccept: (value: Date) => {
                const y = value.getFullYear()
                const m = (value.getMonth() + 1).toString().padStart(2, '0')
                this.setCurrentMonth(`${y}-${m}`)
              }
            })
          })

          // 右箭头
          Column() {
            Text('›')
              .fontSize(24)
              .fontColor(DateUtil.isCurrentMonth(this.getCurrentMonth()) ? '#E0E0E0' : '#1976D2')
              .fontWeight(FontWeight.Bold)
          }
          .width(44)
          .height(44)
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
          .borderRadius(22)
          .backgroundColor(DateUtil.isCurrentMonth(this.getCurrentMonth()) ? '#F5F5F5' : '#E3F2FD')
          .onClick(() => {
            if (!DateUtil.isCurrentMonth(this.getCurrentMonth())) {
              this.doMonthSwitch(-1)
            }
          })

          // 分隔线
          Divider()
            .vertical(true)
            .height(24)
            .color('#E0E0E0')
            .margin({ left: 12, right: 8 })

          // 模式切换按钮
          Column() {
            Image($rawfile(this.viewMode === 'list' ? 'icon_calendar' + '.svg' : 'icon_list' + '.svg'))
              .width(20)
              .height(20)
              .fillColor('#1976D2')
          }
          .width(44)
          .height(44)
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
          .borderRadius(22)
          .backgroundColor('#E3F2FD')
          .onClick(() => {
            if (this.viewMode === 'list') {
              this.viewMode = 'calendar'
              this.calendarMonth = this.filter.month
            } else {
              this.viewMode = 'list'
              this.filter = { month: this.calendarMonth, type: this.filter.type, category: this.filter.category }
              this.loadData()
            }
          })
        }
        .width('100%')
        .height(56)
        .padding({ left: 12, right: 12 })
        .alignItems(VerticalAlign.Center)
        .backgroundColor('#FFFFFF')

        // ── 内容区（跟手滑动） ──
        Column() {
          if (this.viewMode === 'calendar') {
            CalendarView({
              currentMonth: this.calendarMonth,
              refreshKey: this.calendarRefreshKey,
              onDeleteBill: (id: number) => { this.deleteBill(id) }
            })

          } else {
            Column() {
              SummaryCard({ income: this.totalIncome, expense: this.totalExpense })

              if (this.budgetList.length > 0) {
                Column({ space: 6 }) {
                  ForEach(this.budgetList, (bp: BudgetProgress) => {
                    Row() {
                      Text(bp.name).fontSize(12).fontColor('#212121').width(42)
                      Column() {
                        Stack({ alignContent: Alignment.Start }) {
                          Row().width('100%').height(6).borderRadius(3).backgroundColor('#E0E0E0')
                          Row()
                            .width(`${Math.min(bp.usedFen / bp.budgetFen * 100, 100)}%`)
                            .height(6).borderRadius(3)
                            .backgroundColor(bp.usedFen > bp.budgetFen ? '#F44336' : bp.color)
                        }.width('100%').height(6)
                      }.layoutWeight(1)
                      Text(`${AmountUtil.fen2Display(bp.usedFen)}/${AmountUtil.fen2Display(bp.budgetFen)}`)
                        .fontSize(10)
                        .fontColor(bp.usedFen > bp.budgetFen ? '#F44336' : '#757575')
                        .width(90).textAlign(TextAlign.End)
                    }.width('100%').alignItems(VerticalAlign.Center)
                  }, (bp: BudgetProgress) => bp.name)
                }
                .width('100%')
                .padding({ left: 16, right: 16, top: 4, bottom: 4 })
                .backgroundColor('#FFFFFF')
                .borderRadius(10)
                .margin({ left: 16, right: 16, bottom: 4 })
                .shadow({ radius: 4, color: '#0D000000', offsetX: 0, offsetY: 1 })
              }

              Row({ space: 8 }) {
                this.TypeChip('全部', 'all')
                this.TypeChip('收入', 'income')
                this.TypeChip('支出', 'expense')
              }
              .width('100%').justifyContent(FlexAlign.Center)
              .padding({ left: 16, right: 16, top: 10, bottom: 10 })

              Divider().color('#E0E0E0').margin({ left: 16, right: 16 })

              if (this.isLoading) {
                Column() {
                  LoadingProgress().width(48).height(48).color('#1976D2')
                }.width('100%').layoutWeight(1)
                .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
              } else if (this.billGroupsDS.totalCount() === 0) {
                Column() {
                  Image($rawfile('icon_tab_bills.svg'))
                    .width(64).height(64).fillColor('#E0E0E0').margin({ bottom: 12 })
                  Text('暂无账单记录').fontSize(15).fontColor('#757575')
                }.width('100%').layoutWeight(1)
                .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
              } else {
                List() {
                  LazyForEach(this.billGroupsDS, (group: BillGroupData) => {
                    ListItem() {
                      BillGroup({
                        date: group.date, bills: group.bills,
                        dayIncome: group.dayIncome, dayExpense: group.dayExpense,
                        onDeleteBill: (id: number) => { this.deleteBill(id) }
                      })
                    }
                  }, (group: BillGroupData) => group.date)
                }
                .width('100%').layoutWeight(1)
                .padding({ left: 16, right: 16, top: 8, bottom: 8 })
              }
            }.width('100%').layoutWeight(1)
          }
        }
        .width('100%')
        .layoutWeight(1)
        .clip(true)
        .translate({ x: this.slideOffsetX })
        .gesture(
          PanGesture({ direction: PanDirection.Horizontal, distance: 5 })
            .onActionUpdate((event: GestureEvent) => {
              // 跟手：实时跟随手指位移
              if (event) {
                this.slideOffsetX = event.offsetX
              }
            })
            .onActionEnd((event: GestureEvent) => {
              if (!event) {
                this.slideOffsetX = 0
                return
              }
              const threshold = 80
              if (event.offsetX > threshold) {
                this.doMonthSwitch(1)   // 右滑 → 上一月
              } else if (event.offsetX < -threshold) {
                this.doMonthSwitch(-1)  // 左滑 → 下一月
              } else {
                // 没过阈值，弹回原位
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
