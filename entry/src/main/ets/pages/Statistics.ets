import { CategoryStat, MonthStat } from '../model/StatResult'
import { FilterOptions } from '../model/FilterOptions'
import { BillDao } from '../database/BillDao'
import { DateUtil } from '../utils/DateUtil'
import { AmountUtil } from '../utils/AmountUtil'
import { LogUtils } from '../utils/LogUtils'
import { SummaryCard } from '../components/SummaryCard'
import { StyledPieChart } from '../components/StyledPieChart'
import { StyledBarChart } from '../components/StyledBarChart'
import { MonthSelector } from '../components/MonthSelector'

@Component
export struct StatisticsPage {
  @Watch('onTabChanged')
  @Consume activeTabIndex: number
  @State currentMonth: string = DateUtil.currentMonth()
  @State chartType: 'pie' | 'bar' = 'pie'
  @State incomeTotal: number = 0
  @State expenseTotal: number = 0
  @State categoryStats: CategoryStat[] = []
  @State monthStats: MonthStat[] = []
  @State isLoading: boolean = false
  @State slideOffsetX: number = 0

  onTabChanged(): void {
    if (this.activeTabIndex === 3) {
      this.loadData()
    }
  }

  aboutToAppear(): void {
    this.loadData()
  }

  private doMonthSwitch(direction: number): void {
    if (direction < 0 && DateUtil.isCurrentMonth(this.currentMonth)) {
      this.getUIContext().animateTo({ duration: 150, curve: Curve.EaseOut }, () => {
        this.slideOffsetX = 0
      })
      return
    }
    const next = direction > 0
      ? DateUtil.getPrevMonth(this.currentMonth)
      : DateUtil.getNextMonth(this.currentMonth)
    const exitX = direction > 0 ? 360 : -360

    this.getUIContext().animateTo({
      duration: 150,
      curve: Curve.EaseIn,
      onFinish: () => {
        this.slideOffsetX = exitX * -1
        this.currentMonth = next
        this.loadData()
        this.getUIContext().animateTo({ duration: 200, curve: Curve.EaseOut }, () => {
          this.slideOffsetX = 0
        })
      }
    }, () => {
      this.slideOffsetX = exitX
    })
  }

  private async loadMonthSummary(): Promise<void> {
    const filter: FilterOptions = { month: this.currentMonth, type: 'all', category: '' }
    const bills = await BillDao.getInstance().queryByFilter(filter)
    let income = 0
    let expense = 0
    for (const bill of bills) {
      if (bill.type === 'income') income += bill.amount
      else expense += bill.amount
    }
    this.incomeTotal = income
    this.expenseTotal = expense
  }

  private async loadCategoryStats(): Promise<void> {
    this.categoryStats = await BillDao.getInstance().queryCategoryStats(this.currentMonth, 'expense')
  }

  private async loadMonthStats(): Promise<void> {
    const months = DateUtil.getLast6Months(this.currentMonth)
    this.monthStats = await BillDao.getInstance().queryMonthStats(months)
  }

  private async loadData(): Promise<void> {
    this.isLoading = true
    try {
      await this.loadMonthSummary()
      await this.loadCategoryStats()
      await this.loadMonthStats()
    } catch (err) {
      LogUtils.error('Statistics', 'loadData error: %{public}s', JSON.stringify(err))
    } finally {
      this.isLoading = false
    }
  }

  private totalCategoryAmount(): number {
    let total = 0
    for (const stat of this.categoryStats) {
      total += stat.total
    }
    return total
  }

  private topCategory(): CategoryStat | null {
    if (this.categoryStats.length === 0) {
      return null
    }
    return this.categoryStats[0]
  }

  private avgExpenseLast6Months(): number {
    if (this.monthStats.length === 0) {
      return 0
    }
    let total = 0
    for (const stat of this.monthStats) {
      total += stat.expense
    }
    return Math.round(total / this.monthStats.length)
  }

  private netBalance(): number {
    return this.incomeTotal - this.expenseTotal
  }

  private progressWidth(totalAmount: number, itemAmount: number): string {
    if (totalAmount <= 0) {
      return '4%'
    }
    const percent = Math.floor((itemAmount / totalAmount) * 100)
    return `${Math.max(4, Math.min(100, percent))}%`
  }

  @Builder
  private ChartTab(label: string, value: 'pie' | 'bar') {
    Text(label)
      .fontSize(13)
      .fontWeight(this.chartType === value ? FontWeight.Medium : FontWeight.Normal)
      .fontColor(this.chartType === value ? $r('app.color.color_surface') : $r('app.color.color_text_secondary'))
      .backgroundColor(this.chartType === value ? $r('app.color.color_text_primary') : Color.Transparent)
      .borderRadius(14)
      .padding({ left: 16, right: 16, top: 6, bottom: 6 })
      .onClick(() => { this.chartType = value })
  }

  @Builder
  private CategoryRow(stat: CategoryStat, index: number, totalAmount: number) {
    Column() {
      Row() {
        Row() {
          Text(`${index + 1}`)
            .fontSize(10)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.color_surface'))
            .backgroundColor(stat.color)
            .borderRadius(9)
            .padding({ left: 6, right: 6, top: 2, bottom: 2 })

          Text(stat.category)
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.color_text_primary'))
            .margin({ left: 8 })
            .layoutWeight(1)
        }
        .layoutWeight(1)

        Column() {
          Text(`¥${AmountUtil.fen2Display(stat.total)}`)
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.color_text_primary'))
          Text(`${stat.percent}%`)
            .fontSize(11)
            .fontColor($r('app.color.color_text_secondary'))
            .margin({ top: 2 })
        }
        .alignItems(HorizontalAlign.End)
      }
      .width('100%')

      Stack({ alignContent: Alignment.Start }) {
        Row()
          .width('100%')
          .height(6)
          .borderRadius(3)
          .backgroundColor($r('app.color.color_bg'))
        Row()
          .width(this.progressWidth(totalAmount, stat.total))
          .height(6)
          .borderRadius(3)
          .backgroundColor(stat.color)
      }
      .width('100%')
      .margin({ top: 8 })
    }
    .width('100%')
    .padding({ top: 10, bottom: 10 })
  }

  build() {
    Column() {
      // ── 月份导航 ──
      MonthSelector({
        currentMonth: this.currentMonth,
        onSwitch: (dir) => { this.doMonthSwitch(dir) },
        onMonthSelect: (m) => {
          this.currentMonth = m
          this.loadData()
        }
      })

      // ── 内容区（跟手滑动） ──
      Scroll() {
        Column() {
          // 汇总卡片
          SummaryCard({ income: this.incomeTotal, expense: this.expenseTotal })

          Row() {
            Column() {
              Text('本月结余')
                .fontSize(12)
                .fontColor($r('app.color.color_text_secondary'))
              Text(`¥${AmountUtil.fen2Display(Math.abs(this.netBalance()))}`)
                .fontSize(18)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.netBalance() >= 0 ? $r('app.color.color_income') : $r('app.color.color_expense'))
                .margin({ top: 4 })
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)

            Column() {
              Text('近6月月均支出')
                .fontSize(12)
                .fontColor($r('app.color.color_text_secondary'))
              Text(`¥${AmountUtil.fen2Display(this.avgExpenseLast6Months())}`)
                .fontSize(18)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.color_text_primary'))
                .margin({ top: 4 })
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.End)
          }
          .width('calc(100% - 32vp)')
          .padding({ left: 16, right: 16, top: 14, bottom: 14 })
          .backgroundColor($r('app.color.color_surface'))
          .borderRadius(16)
          .margin({ left: 16, right: 16, bottom: 8 })

          // 图表切换
          Row() {
            this.ChartTab('结构', 'pie')
            this.ChartTab('趋势', 'bar')
          }
          .justifyContent(FlexAlign.Center)
          .margin({ top: 8, bottom: 12 })
          .padding({ top: 4, bottom: 4, left: 6, right: 6 })
          .backgroundColor($r('app.color.color_surface'))
          .borderRadius(18)
          .border({ width: 1, color: $r('app.color.color_divider') })

          // 图表区域
          if (this.chartType === 'pie') {
            Column() {
              Row() {
                Column() {
                  Text('分类支出占比')
                    .fontSize(16)
                    .fontWeight(FontWeight.Bold)
                    .fontColor($r('app.color.color_text_primary'))
                  Text(`共 ${this.categoryStats.length} 类，总支出 ¥${AmountUtil.fen2Display(this.totalCategoryAmount())}`)
                    .fontSize(12)
                    .fontColor($r('app.color.color_text_secondary'))
                    .margin({ top: 2 })
                }
                .layoutWeight(1)

                if (this.topCategory()) {
                  Text(`TOP: ${this.topCategory()!.category}`)
                    .fontSize(12)
                    .fontColor($r('app.color.color_text_secondary'))
                }
              }
              .width('100%')
              .padding({ left: 16, right: 16, top: 14, bottom: 2 })

              StyledPieChart({ data: this.categoryStats })
            }
            .width('calc(100% - 32vp)')
            .backgroundColor($r('app.color.color_surface'))
            .borderRadius(20)
            .margin({ left: 16, right: 16 })
            .border({ width: 1, color: 'rgba(0,0,0,0.05)', radius: 20 })
            .shadow({ radius: 10, color: 'rgba(43,45,66,0.08)', offsetX: 0, offsetY: 4 })

            // 分类明细列表
            if (this.categoryStats.length > 0) {
              Column() {
                ForEach(this.categoryStats, (stat: CategoryStat, index: number) => {
                  this.CategoryRow(stat, index, this.totalCategoryAmount())
                  if (index < this.categoryStats.length - 1) {
                    Divider().color($r('app.color.color_divider'))
                  }
                })
              }
              .width('calc(100% - 32vp)')
              .padding({ left: 16, right: 16, top: 6, bottom: 6 })
              .backgroundColor($r('app.color.color_surface'))
              .borderRadius(20)
              .margin({ left: 16, right: 16, top: 12, bottom: 16 })
              .border({ width: 1, color: 'rgba(0,0,0,0.05)', radius: 20 })
              .shadow({ radius: 10, color: 'rgba(43,45,66,0.08)', offsetX: 0, offsetY: 4 })
            } else {
              Text('本月暂无支出记录')
                .fontSize(14)
                .fontColor($r('app.color.color_text_secondary'))
                .padding({ top: 24, bottom: 24 })
            }
          } else {
            // 柱状图
            Column() {
              Row() {
                Text('最近 6 个月收支趋势')
                  .fontSize(16)
                  .fontWeight(FontWeight.Bold)
                  .fontColor($r('app.color.color_text_primary'))
              }
              .width('100%')
              .padding({ top: 14, bottom: 6 })

              StyledBarChart({ data: this.monthStats })
                .margin({ bottom: 12 })
            }
            .width('calc(100% - 32vp)')
            .padding({ left: 16, right: 16 })
            .backgroundColor($r('app.color.color_surface'))
            .borderRadius(20)
            .margin({ left: 16, right: 16, bottom: 16 })
            .border({ width: 1, color: 'rgba(0,0,0,0.05)', radius: 20 })
            .shadow({ radius: 10, color: 'rgba(43,45,66,0.08)', offsetX: 0, offsetY: 4 })
          }
        }
        .width('100%')
      }
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
