import { Bill } from '../model/Bill'
import { FilterOptions, createDefaultFilter } from '../model/FilterOptions'
import { BillGroupData } from '../model/StatResult'
import { BillDao } from '../database/BillDao'
import { SummaryCard } from '../components/SummaryCard'
import { FilterBar } from '../components/FilterBar'
import { BillGroup } from '../components/BillGroup'

@Component
export struct BillListPage {
  @Watch('onTabChanged')
  @Consume activeTabIndex: number
  @State billGroups: BillGroupData[] = []
  @State filter: FilterOptions = createDefaultFilter()
  @State totalIncome: number = 0
  @State totalExpense: number = 0
  @State isLoading: boolean = false

  onTabChanged(): void {
    if (this.activeTabIndex === 0) {
      this.loadData()
    }
  }

  aboutToAppear(): void {
    this.loadData()
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
        if (b.type === 'income') {
          dayIncome += b.amount
        } else {
          dayExpense += b.amount
        }
      }
      groups.push({ date: date, bills: dateBills, dayIncome: dayIncome, dayExpense: dayExpense })
    })

    groups.sort((a, b) => {
      if (a.date > b.date) {
        return -1
      }
      if (a.date < b.date) {
        return 1
      }
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
        if (bill.type === 'income') {
          income += bill.amount
        } else {
          expense += bill.amount
        }
      }
      this.totalIncome = income
      this.totalExpense = expense
      this.billGroups = this.groupByDate(bills)
    } catch (err) {
      console.error('BillListPage loadData error:', JSON.stringify(err))
    } finally {
      this.isLoading = false
    }
  }

  private async deleteBill(id: number): Promise<void> {
    try {
      await BillDao.getInstance().deleteById(id)
      await this.loadData()
    } catch (err) {
      console.error('BillListPage deleteBill error:', JSON.stringify(err))
    }
  }

  build() {
    Column() {
      SummaryCard({ income: this.totalIncome, expense: this.totalExpense })

      FilterBar({
        filter: this.filter,
        onFilterChange: (newFilter: FilterOptions) => {
          this.filter = newFilter
          this.loadData()
        }
      })

      if (this.isLoading) {
        Column() {
          LoadingProgress()
            .width(48)
            .height(48)
            .color('#1976D2') // color_primary
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      } else if (this.billGroups.length === 0) {
        Column() {
          Text('🧾')
            .fontSize(64)
            .margin({ bottom: 16 })
          Text('暂无账单记录')
            .fontSize(16)
            .fontColor('#9E9E9E') // color_text_secondary
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      } else {
        List() {
          ForEach(this.billGroups, (group: BillGroupData) => {
            ListItem() {
              BillGroup({
                date: group.date,
                bills: group.bills,
                dayIncome: group.dayIncome,
                dayExpense: group.dayExpense,
                onDeleteBill: (id: number) => {
                  this.deleteBill(id)
                }
              })
            }
          })
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ top: 8, bottom: 8 })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.color_bg'))
  }
}
