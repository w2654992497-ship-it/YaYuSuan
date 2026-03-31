import { CategoryStat, MonthStat } from '../model/StatResult'
import { FilterOptions } from '../model/FilterOptions'
import { BillDao } from '../database/BillDao'
import { DateUtil } from '../utils/DateUtil'
import { AmountUtil } from '../utils/AmountUtil'
import { SummaryCard } from '../components/SummaryCard'
import { PieChart } from '../components/PieChart'
import { BarChart } from '../components/BarChart'

@Component
export struct StatisticsPage {
  @State currentMonth: string = DateUtil.currentMonth()
  @State chartType: string = 'pie'
  @State incomeTotal: number = 0
  @State expenseTotal: number = 0
  @State categoryStats: CategoryStat[] = []
  @State monthStats: MonthStat[] = []
  @State isLoading: boolean = false

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
      console.error('StatisticsPage loadData error:', JSON.stringify(err))
    } finally {
      this.isLoading = false
    }
  }

  build() {
    Scroll() {
      Column() {
        // Month navigation
        Row() {
          Button('<')
            .fontSize(16)
            .fontColor('#1976D2') // color_primary
            .backgroundColor(Color.Transparent)
            .width(44)
            .height(44)
            .onClick(() => {
              this.currentMonth = DateUtil.getPrevMonth(this.currentMonth)
              this.loadData()
            })

          Text(DateUtil.formatMonthDisplay(this.currentMonth))
            .fontSize(16)
            .fontColor('#212121') // color_text_primary
            .fontWeight(FontWeight.Medium)
            .layoutWeight(1)
            .textAlign(TextAlign.Center)

          Button('>')
            .fontSize(16)
            .fontColor(DateUtil.isCurrentMonth(this.currentMonth) ? '#9E9E9E' : '#1976D2')
            .backgroundColor(Color.Transparent)
            .width(44)
            .height(44)
            .enabled(!DateUtil.isCurrentMonth(this.currentMonth))
            .onClick(() => {
              if (!DateUtil.isCurrentMonth(this.currentMonth)) {
                this.currentMonth = DateUtil.getNextMonth(this.currentMonth)
                this.loadData()
              }
            })
        }
        .width('100%')
        .padding({ left: 8, right: 8, top: 8, bottom: 4 })

        // Summary card
        SummaryCard({ income: this.incomeTotal, expense: this.expenseTotal })

        // Chart type toggle
        Row() {
          Button('支出分布')
            .layoutWeight(1)
            .height(36)
            .fontSize(14)
            .fontColor(this.chartType === 'pie' ? '#FFFFFF' : '#9E9E9E')
            .backgroundColor(this.chartType === 'pie' ? '#1976D2' : '#F5F5F5')
            .borderRadius({ topLeft: 18, bottomLeft: 18 })
            .onClick(() => {
              this.chartType = 'pie'
            })

          Button('收支趋势')
            .layoutWeight(1)
            .height(36)
            .fontSize(14)
            .fontColor(this.chartType === 'bar' ? '#FFFFFF' : '#9E9E9E')
            .backgroundColor(this.chartType === 'bar' ? '#1976D2' : '#F5F5F5')
            .borderRadius({ topRight: 18, bottomRight: 18 })
            .onClick(() => {
              this.chartType = 'bar'
            })
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 8, bottom: 8 })

        Divider()
          .color('#E0E0E0') // color_divider
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
                    // Colored square
                    Column()
                      .width(12)
                      .height(12)
                      .backgroundColor(stat.color)
                      .borderRadius(2)
                      .margin({ right: 8 })

                    Text(stat.category)
                      .fontSize(14)
                      .fontColor('#212121') // color_text_primary
                      .layoutWeight(1)

                    Text(`¥${AmountUtil.fen2Display(stat.total)}`)
                      .fontSize(14)
                      .fontColor('#212121') // color_text_primary
                      .margin({ right: 8 })

                    Text(`${stat.percent}%`)
                      .fontSize(12)
                      .fontColor('#9E9E9E') // color_text_secondary
                      .width(40)
                      .textAlign(TextAlign.End)
                  }
                  .width('100%')
                  .padding({ top: 8, bottom: 8 })

                  Divider()
                    .color('#E0E0E0') // color_divider
                })
              }
              .width('100%')
              .padding({ left: 16, right: 16, bottom: 16 })
              .backgroundColor('#FFFFFF') // color_card
              .borderRadius(12)
              .margin({ left: 16, right: 16, top: 8, bottom: 16 })
            } else {
              Column() {
                Text('本月暂无支出记录')
                  .fontSize(14)
                  .fontColor('#9E9E9E') // color_text_secondary
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
          .backgroundColor('#FFFFFF') // color_card
          .borderRadius(12)
          .margin({ left: 16, right: 16, top: 8, bottom: 16 })
        }
      }
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.color_bg'))
  }
}
