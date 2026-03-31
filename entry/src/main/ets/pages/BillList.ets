import { Bill } from '../model/Bill'
import { FilterOptions, createDefaultFilter } from '../model/FilterOptions'
import { BillGroupData } from '../model/StatResult'
import { BillDao } from '../database/BillDao'
import { SummaryCard } from '../components/SummaryCard'
import { BillGroup } from '../components/BillGroup'
import { NavBar } from '../components/NavBar'
import { LazyForEachDataSource } from '../utils/LazyForEachDataSource'
import { DateUtil } from '../utils/DateUtil'
import { LogUtils } from '../utils/LogUtils'

@Component
export struct BillListPage {
  @Watch('onTabChanged')
  @Consume activeTabIndex: number
  @State filter: FilterOptions = createDefaultFilter()
  @State totalIncome: number = 0
  @State totalExpense: number = 0
  @State isLoading: boolean = false
  private billGroupsDS: LazyForEachDataSource<BillGroupData> = new LazyForEachDataSource<BillGroupData>([])

  onTabChanged(): void {
    if (this.activeTabIndex === 0) {
      this.loadData()
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
        if (b.type === 'income') {
          dayIncome += b.amount
        } else {
          dayExpense += b.amount
        }
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
        if (bill.type === 'income') {
          income += bill.amount
        } else {
          expense += bill.amount
        }
      }
      this.totalIncome = income
      this.totalExpense = expense

      const newGroups = this.groupByDate(bills)
      this.billGroupsDS.smartUpdate(
        newGroups,
        (g: BillGroupData) => g.date,
        (g: BillGroupData) => `${g.date}:${g.bills.map((b: Bill) => b.id.toString()).join(',')}`
      )
    } catch (err) {
      LogUtils.error('BillList', 'loadData error: %{public}s', JSON.stringify(err))
    } finally {
      this.isLoading = false
    }
  }

  private async deleteBill(id: number): Promise<void> {
    try {
      await BillDao.getInstance().deleteById(id)
      await this.loadData()
    } catch (err) {
      LogUtils.error('BillList', 'deleteBill error: %{public}s', JSON.stringify(err))
    }
  }

  build() {
    Column() {
      // 月份导航
      NavBar({
        title: DateUtil.formatMonthDisplay(this.filter.month),
        leftText: '‹',
        rightText: '›',
        rightEnabled: !DateUtil.isCurrentMonth(this.filter.month),
        showDivider: false,
        navHeight: 48,
        onLeftClick: () => {
          this.filter = {
            month: DateUtil.getPrevMonth(this.filter.month),
            type: this.filter.type,
            category: this.filter.category
          }
          this.loadData()
        },
        onRightClick: () => {
          this.filter = {
            month: DateUtil.getNextMonth(this.filter.month),
            type: this.filter.type,
            category: this.filter.category
          }
          this.loadData()
        }
      })

      // 汇总卡片
      SummaryCard({ income: this.totalIncome, expense: this.totalExpense })

      // 收支筛选
      Row({ space: 8 }) {
        this.TypeChip('全部', 'all')
        this.TypeChip('收入', 'income')
        this.TypeChip('支出', 'expense')
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 10, bottom: 10 })

      Divider()
        .color('#E0E0E0')
        .margin({ left: 16, right: 16 })

      // 内容区
      if (this.isLoading) {
        Column() {
          LoadingProgress()
            .width(48)
            .height(48)
            .color('#1976D2')
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      } else if (this.billGroupsDS.totalCount() === 0) {
        Column() {
          Image($rawfile('icon_tab_bills.svg'))
            .width(64)
            .height(64)
            .fillColor('#E0E0E0')
            .margin({ bottom: 12 })
          Text('暂无账单记录')
            .fontSize(15)
            .fontColor('#757575')
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      } else {
        List() {
          LazyForEach(this.billGroupsDS, (group: BillGroupData) => {
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
          }, (group: BillGroupData) => group.date)
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
