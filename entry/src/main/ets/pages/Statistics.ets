import { CategoryStat, MonthStat } from '../model/StatResult'
import { FilterOptions } from '../model/FilterOptions'
import { BillDao } from '../database/BillDao'
import { DateUtil } from '../utils/DateUtil'
import { AmountUtil } from '../utils/AmountUtil'
import { LogUtils } from '../utils/LogUtils'
import { SummaryCard } from '../components/SummaryCard'
import { PieChart } from '../components/PieChart'
import { BarChart } from '../components/BarChart'
import { NavBar } from '../components/NavBar'

interface PopupChangeEvent {
  isVisible: boolean
}

@Component
export struct StatisticsPage {
  @Watch('onTabChanged')
  @Consume activeTabIndex: number
  @State currentMonth: string = DateUtil.currentMonth()
  @State chartType: string = 'pie'
  @State incomeTotal: number = 0
  @State expenseTotal: number = 0
  @State categoryStats: CategoryStat[] = []
  @State monthStats: MonthStat[] = []
  @State isLoading: boolean = false
  @State showChartMenu: boolean = false
  @State slideOffsetX: number = 0

  onTabChanged(): void {
    if (this.activeTabIndex === 2) {
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
    const filter: FilterOptions = {
      month: this.currentMonth,
      type: 'all',
      category: ''
    }
    const bills = await BillDao.getInstance().queryByFilter(filter)
    let income = 0
    let expense = 0
    for (const bill of bills) {
      if (bill.type === 'income') {
        income += bill.amount
      } else {
        expense += bill.amount
      }
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

  @Builder
  ChartToggle() {
    Row({ space: 6 }) {
      Text('支出分布')
        .fontSize(13)
        .fontColor(this.chartType === 'pie' ? '#1976D2' : '#757575')
        .fontWeight(this.chartType === 'pie' ? FontWeight.Medium : FontWeight.Normal)
        .backgroundColor(this.chartType === 'pie' ? '#E3F2FD' : '#F5F5F5')
        .borderRadius(16)
        .padding({ left: 14, right: 14, top: 6, bottom: 6 })
        .onClick(() => { this.chartType = 'pie' })

      Text('收支趋势')
        .fontSize(13)
        .fontColor(this.chartType === 'bar' ? '#1976D2' : '#757575')
        .fontWeight(this.chartType === 'bar' ? FontWeight.Medium : FontWeight.Normal)
        .backgroundColor(this.chartType === 'bar' ? '#E3F2FD' : '#F5F5F5')
        .borderRadius(16)
        .padding({ left: 14, right: 14, top: 6, bottom: 6 })
        .onClick(() => { this.chartType = 'bar' })
    }
  }

  build() {
    Column() {
      // ── 页面标题 ──
      NavBar({
        title: '统计',
        showLeft: false,
        showDivider: true
      })

      // ── 月份导航（与账单页统一样式） ──
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

        // 月份标题
        Column() {
          Text(DateUtil.formatMonthDisplay(this.currentMonth))
            .fontSize(18)
            .fontColor('#212121')
            .fontWeight(FontWeight.Bold)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)
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

        // 右箭头
        Column() {
          Text('›')
            .fontSize(24)
            .fontColor(DateUtil.isCurrentMonth(this.currentMonth) ? '#E0E0E0' : '#1976D2')
            .fontWeight(FontWeight.Bold)
        }
        .width(44)
        .height(44)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .borderRadius(22)
        .backgroundColor(DateUtil.isCurrentMonth(this.currentMonth) ? '#F5F5F5' : '#E3F2FD')
        .onClick(() => {
          if (!DateUtil.isCurrentMonth(this.currentMonth)) {
            this.doMonthSwitch(-1)
          }
        })
      }
      .width('100%')
      .height(56)
      .padding({ left: 12, right: 12 })
      .alignItems(VerticalAlign.Center)
      .backgroundColor('#FFFFFF')

      // ── 内容区（跟手滑动） ──
      Scroll() {
        Column() {
          // 汇总卡片
          SummaryCard({ income: this.incomeTotal, expense: this.expenseTotal })

          // 图表类型切换
          Row() {
            Text(this.chartType === 'pie' ? '支出分布' : '收支趋势')
              .fontSize(15)
              .fontColor('#212121')
              .fontWeight(FontWeight.Medium)
              .layoutWeight(1)
            this.ChartToggle()
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 12, bottom: 8 })

          Divider()
            .color('#E0E0E0')
            .margin({ left: 16, right: 16 })

          if (this.chartType === 'pie') {
            // 饼图
            Column() {
              PieChart({ data: this.categoryStats })
                .margin({ top: 8 })

              // 分类明细
              if (this.categoryStats.length > 0) {
                Column() {
                  ForEach(this.categoryStats, (stat: CategoryStat) => {
                    Row() {
                      Column()
                        .width(10)
                        .height(10)
                        .backgroundColor(stat.color)
                        .borderRadius(2)
                        .margin({ right: 10 })

                      Text(stat.category)
                        .fontSize(14)
                        .fontColor('#212121')
                        .layoutWeight(1)

                      Text(`¥${AmountUtil.fen2Display(stat.total)}`)
                        .fontSize(14)
                        .fontColor('#212121')
                        .margin({ right: 8 })

                      Text(`${stat.percent}%`)
                        .fontSize(12)
                        .fontColor('#757575')
                        .width(40)
                        .textAlign(TextAlign.End)
                    }
                    .width('100%')
                    .padding({ top: 10, bottom: 10 })

                    Divider().color('#E0E0E0')
                  })
                }
                .width('100%')
                .padding({ left: 16, right: 16, bottom: 16 })
                .backgroundColor('#FFFFFF')
                .borderRadius(12)
                .margin({ left: 16, right: 16, top: 8, bottom: 16 })
              } else {
                Column() {
                  Text('本月暂无支出记录')
                    .fontSize(14)
                    .fontColor('#757575')
                    .padding({ top: 16, bottom: 16 })
                }
                .width('100%')
                .alignItems(HorizontalAlign.Center)
              }
            }
            .width('100%')
          } else {
            // 柱状图
            Column() {
              BarChart({ data: this.monthStats })
                .margin({ top: 8, bottom: 16 })
            }
            .width('100%')
            .padding({ left: 16, right: 16 })
            .backgroundColor('#FFFFFF')
            .borderRadius(12)
            .margin({ left: 16, right: 16, top: 8, bottom: 16 })
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
            if (event.offsetX > 80) {
              this.doMonthSwitch(1)
            } else if (event.offsetX < -80) {
              this.doMonthSwitch(-1)
            } else {
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
