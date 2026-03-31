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
import { PopupMenuContent } from '../components/PopupMenu'
import { PopupMenuItem } from '../components/PopupMenu'

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
  ChartMenuBuilder() {
    PopupMenuContent({
      items: [
        {
          text: '支出分布',
          color: this.chartType === 'pie' ? '#64B5F6' : '#FFFFFF',
          onClick: () => {
            this.chartType = 'pie'
            this.showChartMenu = false
          }
        } as PopupMenuItem,
        {
          text: '收支趋势',
          color: this.chartType === 'bar' ? '#64B5F6' : '#FFFFFF',
          onClick: () => {
            this.chartType = 'bar'
            this.showChartMenu = false
          }
        } as PopupMenuItem
      ]
    })
  }

  build() {
    Column() {
      // 月份导航栏（NavBar 复用）
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
          // Summary card
          SummaryCard({ income: this.incomeTotal, expense: this.expenseTotal })

          // 图表类型切换行（PopupMenu）
          Row() {
            Text(this.chartType === 'pie' ? '支出分布' : '收支趋势')
              .fontSize(15)
              .fontColor('#212121')
              .fontWeight(FontWeight.Medium)
              .layoutWeight(1)

            // "切换图表" 按钮 + PopupMenu
            Row() {
              Text('切换')
                .fontSize(13)
                .fontColor('#1976D2')
              Text(' ▾')
                .fontSize(11)
                .fontColor('#1976D2')
            }
            .padding({ left: 10, right: 10, top: 5, bottom: 5 })
            .backgroundColor('#E3F2FD')
            .borderRadius(12)
            .bindPopup(this.showChartMenu, {
              builder: this.ChartMenuBuilder,
              placement: Placement.BottomRight,
              popupColor: Color.Transparent,
              enableArrow: false,
              onStateChange: (e: PopupChangeEvent) => {
                this.showChartMenu = e.isVisible
              }
            })
            .onClick(() => { this.showChartMenu = true })
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 10, bottom: 6 })

          Divider()
            .color('#E0E0E0')
            .margin({ left: 16, right: 16 })

          if (this.chartType === 'pie') {
            // Pie chart
            Column() {
              PieChart({ data: this.categoryStats })
                .margin({ top: 8 })

              // Legend
              if (this.categoryStats.length > 0) {
                Column() {
                  ForEach(this.categoryStats, (stat: CategoryStat) => {
                    Row() {
                      Column()
                        .width(12)
                        .height(12)
                        .backgroundColor(stat.color)
                        .borderRadius(2)
                        .margin({ right: 8 })

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
                        .fontColor('#9E9E9E')
                        .width(40)
                        .textAlign(TextAlign.End)
                    }
                    .width('100%')
                    .padding({ top: 8, bottom: 8 })

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
                    .fontColor('#9E9E9E')
                    .padding({ top: 16, bottom: 16 })
                }
                .width('100%')
                .alignItems(HorizontalAlign.Center)
              }
            }
            .width('100%')
          } else {
            // Bar chart
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
