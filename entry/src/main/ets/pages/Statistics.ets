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
  @State currentMonth: string = DateUtil.currentMonth()
  @State chartType: string = 'pie'
  @State incomeTotal: number = 0
  @State expenseTotal: number = 0
  @State categoryStats: CategoryStat[] = []
  @State monthStats: MonthStat[] = []
  @State isLoading: boolean = false
  @State showChartMenu: boolean = false

  aboutToAppear(): void {
    this.loadData()
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
      // 月份导航
      NavBar({
        title: DateUtil.formatMonthDisplay(this.currentMonth),
        leftText: '‹',
        rightText: '›',
        rightEnabled: !DateUtil.isCurrentMonth(this.currentMonth),
        showDivider: false,
        navHeight: 48,
        onLeftClick: () => {
          this.currentMonth = DateUtil.getPrevMonth(this.currentMonth)
          this.loadData()
        },
        onRightClick: () => {
          this.currentMonth = DateUtil.getNextMonth(this.currentMonth)
          this.loadData()
        }
      })

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
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.color_bg'))
  }
}
