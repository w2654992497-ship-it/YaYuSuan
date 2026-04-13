import { CategoryStat, MonthStat } from '../model/StatResult'
import { FilterOptions } from '../model/FilterOptions'
import { BillDao } from '../database/BillDao'
import { DateUtil } from '../utils/DateUtil'
import { AmountUtil } from '../utils/AmountUtil'
import { LogUtils } from '../utils/LogUtils'
import { SummaryCard } from '../components/SummaryCard'
import { PieChart } from '../components/PieChart'
import { BarChart } from '../components/BarChart'

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

  build() {
    Column() {
      // ── 月份导航 ──
      Row() {
        Image($rawfile('icon_chevron_left.svg'))
          .width(24).height(24)
          .fillColor($r('app.color.color_primary'))
          .padding(4)
          .onClick(() => { this.doMonthSwitch(1) })

        Text(DateUtil.formatMonthDisplay(this.currentMonth))
          .fontSize(16).fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.color_text_primary'))
          .margin({ left: 16, right: 16 })
          .onClick(() => {
            const parts = this.currentMonth.split('-')
            const now = new Date()
            this.getUIContext().showDatePickerDialog({
              start: new Date('2020-01-01'),
              end: now,
              selected: new Date(parseInt(parts[0], 10), parseInt(parts[1], 10) - 1, 1),
              lunar: false,
              onDateAccept: (value: Date) => {
                const y = value.getFullYear()
                const m = (value.getMonth() + 1).toString().padStart(2, '0')
                this.currentMonth = `${y}-${m}`
                this.loadData()
              }
            })
          })

        Image($rawfile('icon_chevron_right.svg'))
          .width(24).height(24)
          .fillColor(DateUtil.isCurrentMonth(this.currentMonth) ? $r('app.color.color_divider') : $r('app.color.color_primary'))
          .padding(4)
          .onClick(() => {
            if (!DateUtil.isCurrentMonth(this.currentMonth)) {
              this.doMonthSwitch(-1)
            }
          })
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .padding({ top: 12, bottom: 8 })
      .backgroundColor($r('app.color.color_bg'))

      // ── 内容区（跟手滑动） ──
      Scroll() {
        Column() {
          // 汇总卡片
          SummaryCard({ income: this.incomeTotal, expense: this.expenseTotal })

          // 图表切换
          Row() {
            Text('结构')
              .fontSize(14)
              .fontColor(this.chartType === 'pie' ? $r('app.color.color_surface') : $r('app.color.color_text_secondary'))
              .backgroundColor(this.chartType === 'pie' ? $r('app.color.color_primary') : $r('app.color.color_surface'))
              .borderRadius(16)
              .padding({ left: 16, right: 16, top: 4, bottom: 4 })
              .onClick(() => { this.chartType = 'pie' })

            Text('趋势')
              .fontSize(14)
              .fontColor(this.chartType === 'bar' ? $r('app.color.color_surface') : $r('app.color.color_text_secondary'))
              .backgroundColor(this.chartType === 'bar' ? $r('app.color.color_primary') : $r('app.color.color_surface'))
              .borderRadius(16)
              .padding({ left: 16, right: 16, top: 4, bottom: 4 })
              .onClick(() => { this.chartType = 'bar' })
          }
          .justifyContent(FlexAlign.Center)
          .margin({ top: 8, bottom: 16 })
          .padding(4)
          .backgroundColor($r('app.color.color_divider'))
          .borderRadius(20)

          // 图表区域
          if (this.chartType === 'pie') {
            Column() {
              PieChart({ data: this.categoryStats })
            }
            .width('calc(100% - 32vp)')
            .backgroundColor($r('app.color.color_surface'))
            .borderRadius(24)
            .margin({ left: 16, right: 16 })
            .border({ width: 1, color: 'rgba(0,0,0,0.05)', radius: 24 })
            .shadow({ radius: 0, color: 'rgba(43,45,66,0.1)', offsetX: 4, offsetY: 4 })

            // 分类明细列表
            if (this.categoryStats.length > 0) {
              Column() {
                ForEach(this.categoryStats, (stat: CategoryStat) => {
                  Row() {
                    Column()
                      .width(10).height(10)
                      .backgroundColor(stat.color)
                      .borderRadius(5)
                      .margin({ right: 10 })

                    Text(stat.category)
                      .fontSize(14)
                      .fontColor($r('app.color.color_text_primary'))
                      .layoutWeight(1)

                    Text(`¥${AmountUtil.fen2Display(stat.total)}`)
                      .fontSize(14)
                      .fontColor($r('app.color.color_text_primary'))
                      .margin({ right: 8 })

                    Text(`${stat.percent}%`)
                      .fontSize(12)
                      .fontColor($r('app.color.color_text_secondary'))
                      .width(40)
                      .textAlign(TextAlign.End)
                  }
                  .width('100%')
                  .padding({ top: 10, bottom: 10 })

                  Divider().color($r('app.color.color_divider'))
                })
              }
              .width('calc(100% - 32vp)')
              .padding({ left: 16, right: 16, top: 8, bottom: 8 })
              .backgroundColor($r('app.color.color_surface'))
              .borderRadius(24)
              .margin({ left: 16, right: 16, top: 12, bottom: 16 })
              .border({ width: 1, color: 'rgba(0,0,0,0.05)', radius: 24 })
              .shadow({ radius: 0, color: 'rgba(43,45,66,0.1)', offsetX: 4, offsetY: 4 })
            } else {
              Text('本月暂无支出记录')
                .fontSize(14)
                .fontColor($r('app.color.color_text_secondary'))
                .padding({ top: 24, bottom: 24 })
            }
          } else {
            // 柱状图
            Column() {
              BarChart({ data: this.monthStats })
                .margin({ top: 8, bottom: 16 })
            }
            .width('calc(100% - 32vp)')
            .padding({ left: 16, right: 16 })
            .backgroundColor($r('app.color.color_surface'))
            .borderRadius(24)
            .margin({ left: 16, right: 16, bottom: 16 })
            .border({ width: 1, color: 'rgba(0,0,0,0.05)', radius: 24 })
            .shadow({ radius: 0, color: 'rgba(43,45,66,0.1)', offsetX: 4, offsetY: 4 })
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
