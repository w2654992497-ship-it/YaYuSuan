import { BillDao } from '../database/BillDao'
import { Bill } from '../model/Bill'
import { getCategoryColor, getCategoryInfo } from '../model/Category'
import { FilterOptions } from '../model/FilterOptions'
import { SummaryCard } from '../components/SummaryCard'
import { WaterPageBg } from '../components/WaterPageBg'
import { AmountUtil } from '../utils/AmountUtil'
import { DateUtil } from '../utils/DateUtil'
import { BudgetService } from '../services/BudgetService'

@Component
export struct BillListPage {
  @Consume('appNavStack') navStack: NavPathStack
  @Watch('onTabChanged')
  @Consume activeTabIndex: number
  @Watch('onCategoryVersionChanged')
  @StorageProp('categoryVersion') categoryVersion: number = 0
  @Watch('onBudgetVersionChanged')
  @StorageProp('budgetVersion') budgetVersion: number = 0
  @Watch('onAppDataVersionChanged')
  @StorageProp('appDataVersion') appDataVersion: number = 0
  @State allBills: Bill[] = []
  @State previewBills: Bill[] = []
  @State filter: FilterOptions = { month: DateUtil.currentMonth(), type: 'all', category: '' }
  @State totalIncome: number = 0
  @State totalExpense: number = 0
  @State budgetSpent: number = 0
  @State budgetLimit: number = 0
  @State slideOffsetX: number = 0
  @State showAllBills: boolean = false
  @StorageProp('statusBarHeight') sbHeight: number = 0

  onTabChanged(): void {
    if (this.activeTabIndex === 0) {
      this.loadData()
    }
  }

  aboutToAppear(): void {
    this.loadData()
  }

  onCategoryVersionChanged(): void {
    this.loadData()
  }

  onBudgetVersionChanged(): void {
    this.loadData()
  }

  onAppDataVersionChanged(): void {
    this.loadData()
  }

  async loadData(): Promise<void> {
    const bills = await BillDao.getInstance().queryByFilter(this.filter)
    let inc = 0
    let exp = 0

    for (let i = 0; i < bills.length; i++) {
      const bill = bills[i]
      if (bill.type === 'income') {
        inc += bill.amount
      } else {
        exp += bill.amount
      }
    }

    const sortedBills = bills.sort((a: Bill, b: Bill) => {
      if (a.date === b.date) {
        return b.createdAt - a.createdAt
      }
      return b.date.localeCompare(a.date)
    })
    const preview: Bill[] = []
    for (let i = 0; i < sortedBills.length && i < 3; i++) {
      preview.push(sortedBills[i])
    }

    this.allBills = sortedBills
    this.previewBills = preview
    this.totalIncome = inc
    this.totalExpense = exp
    await this.loadBudgetProgress()
  }

  private async loadBudgetProgress(): Promise<void> {
    const month = this.filter.month && this.filter.month.length > 0 ? this.filter.month : DateUtil.currentMonth()
    const overview = await BudgetService.getInstance().buildMonthOverview(month)
    this.budgetSpent = overview.usedFen
    this.budgetLimit = overview.totalFen
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
        this.showAllBills = false
        this.loadData()
        this.getUIContext().animateTo({ duration: 200, curve: Curve.EaseOut }, () => {
          this.slideOffsetX = 0
        })
      }
    }, () => {
      this.slideOffsetX = exitX
    })
  }

  private billDateLabel(date: string): string {
    const parts = date.split('-')
    if (parts.length !== 3) {
      return date
    }
    return `${parts[1]}-${parts[2]}`
  }

  @Builder
  HomeHeader() {
    Row() {
      Text('小金鱼记账')
        .fontSize(22)
        .fontWeight(FontWeight.Bolder)
        .fontColor($r('app.color.color_text_deep'))

      Blank()

      Row({ space: 7 }) {
        Image($rawfile('icon_search.svg'))
          .width(17)
          .height(17)
          .fillColor($r('app.color.color_primary'))
        Text('搜索')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.color_primary'))
      }
      .height(40)
      .padding({ left: 12, right: 14 })
      .backgroundColor($r('app.color.color_card_overlay'))
      .borderRadius(22)
      .shadow({ radius: 12, color: $r('app.color.color_shadow_blue_10'), offsetX: 0, offsetY: 4 })
      .onClick(() => {
        this.navStack.pushPathByName('billSearch', null)
      })
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .padding({ left: 24, right: 24, top: this.sbHeight + 8, bottom: 8 })
  }

  @Builder
  HomeMonthSelector() {
    Row() {
      Row() {
        Image($rawfile('icon_chevron_left.svg'))
          .width(18)
          .height(18)
          .fillColor($r('app.color.color_text_deep'))
      }
      .width(42)
      .height(44)
      .justifyContent(FlexAlign.Center)
      .onClick(() => {
        this.doMonthSwitch(1)
      })

      Row({ space: 10 }) {
        Image($rawfile('icon_calendar.svg'))
          .width(20)
          .height(20)
          .fillColor($r('app.color.color_primary'))
        Text(DateUtil.formatMonthDisplay(this.filter.month || DateUtil.currentMonth()))
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.color_text_deep'))
        Text('▼')
          .fontSize(10)
          .fontColor($r('app.color.color_text_deep'))
          .margin({ left: 2, top: 2 })
      }
      .layoutWeight(1)
      .height(44)
      .justifyContent(FlexAlign.Center)
      .onClick(() => {
        const month = this.filter.month || DateUtil.currentMonth()
        const parts = month.split('-')
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
            this.showAllBills = false
            this.loadData()
          }
        })
      })

      Row() {
        Image($rawfile('icon_chevron_right.svg'))
          .width(18)
          .height(18)
          .fillColor(DateUtil.isCurrentMonth(this.filter.month || DateUtil.currentMonth())
            ? $r('app.color.color_divider') : $r('app.color.color_text_deep'))
      }
      .width(42)
      .height(44)
      .justifyContent(FlexAlign.Center)
      .onClick(() => {
        if (!DateUtil.isCurrentMonth(this.filter.month || DateUtil.currentMonth())) {
          this.doMonthSwitch(-1)
        }
      })
    }
    .width('calc(100% - 48vp)')
    .height(44)
    .backgroundColor($r('app.color.color_card_overlay'))
    .borderRadius(22)
    .border({ width: 1, color: $r('app.color.color_divider') })
    .shadow({ radius: 12, color: $r('app.color.color_shadow_blue_09'), offsetX: 0, offsetY: 4 })
    .margin({ left: 24, right: 24, bottom: 8 })
  }

  @Builder
  TypeChip(label: string, chipType: 'all' | 'income' | 'expense') {
    Text(label)
      .fontSize(15)
      .fontWeight(FontWeight.Medium)
      .fontColor(this.filter.type === chipType ? $r('app.color.color_white') : $r('app.color.color_text_secondary'))
      .textAlign(TextAlign.Center)
      .width(48)
      .height(26)
      .borderRadius(13)
      .backgroundColor(this.filter.type === chipType ? $r('app.color.color_primary') : $r('app.color.color_white'))
      .border({ width: 1, color: this.filter.type === chipType ? $r('app.color.color_primary') : $r('app.color.color_divider') })
      .onClick(() => {
        this.filter = { month: this.filter.month, type: chipType, category: this.filter.category }
        this.showAllBills = false
        this.loadData()
      })
  }

  @Builder
  RecentBillRow(bill: Bill, showDivider: boolean) {
    Column() {
      Row() {
        Row() {
          Image($rawfile(getCategoryInfo(bill.category).icon + '.svg'))
          .width(22)
          .height(22)
            .fillColor($r('app.color.color_white'))
        }
        .width(36)
        .height(36)
        .borderRadius(18)
        .backgroundColor(getCategoryColor(bill.category))
        .justifyContent(FlexAlign.Center)
        .margin({ right: 12 })

        Column() {
          Text(bill.category)
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.color_text_deep'))
          Text(bill.remark.length > 0 ? bill.remark : '未填写备注')
            .fontSize(13)
            .fontColor($r('app.color.color_text_secondary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ top: 3 })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Text(this.billDateLabel(bill.date))
          .fontSize(12)
          .fontColor($r('app.color.color_text_secondary'))
          .margin({ right: 14 })

        Text(`${bill.type === 'income' ? '+' : '-'}¥${AmountUtil.fen2Display(bill.amount)}`)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(bill.type === 'income' ? $r('app.color.color_income') : $r('app.color.color_expense'))
          .textAlign(TextAlign.End)
          .width(76)
      }
      .width('100%')
      .height(54)

      if (showDivider) {
        Divider()
          .height(1)
          .color($r('app.color.color_divider'))
          .margin({ left: 60 })
      }
    }
    .width('100%')
  }

  @Builder
  EmptyRecentState() {
    Column() {
      Image($rawfile('icon_tab_bills.svg'))
        .width(34)
        .height(34)
        .fillColor($r('app.color.color_divider'))
      Text('还没有账单记录')
        .fontSize(14)
        .fontColor($r('app.color.color_text_secondary'))
        .margin({ top: 8 })
    }
    .width('100%')
    .height(112)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  RecentBillsCard() {
    Column() {
      Row() {
      Text(this.showAllBills ? '账单明细' : '最近账单')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.color_text_deep'))

        Blank()

        if (!this.showAllBills) {
          Row({ space: 10 }) {
            this.TypeChip('全部', 'all')
            this.TypeChip('收入', 'income')
            this.TypeChip('支出', 'expense')
          }
        } else {
          Text('收起')
            .fontSize(13)
            .fontColor($r('app.color.color_primary'))
            .onClick(() => {
              this.showAllBills = false
            })
        }
      }
      .width('100%')
      .height(30)
      .alignItems(VerticalAlign.Center)

      if (this.allBills.length === 0) {
        this.EmptyRecentState()
      } else if (this.showAllBills) {
        ForEach(this.allBills, (bill: Bill, index: number) => {
          this.RecentBillRow(bill, index < this.allBills.length - 1)
        }, (bill: Bill) => bill.id.toString())
      } else {
        ForEach(this.previewBills, (bill: Bill, index: number) => {
          this.RecentBillRow(bill, index < this.previewBills.length - 1)
        }, (bill: Bill) => bill.id.toString())

        Row({ space: 10 }) {
          Text('查看全部账单')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.color_primary'))
          Image($rawfile('icon_chevron_right.svg'))
            .width(16)
            .height(16)
            .fillColor($r('app.color.color_primary'))
        }
        .width('100%')
        .height(36)
        .justifyContent(FlexAlign.Center)
        .margin({ top: 8 })
        .onClick(() => {
          this.showAllBills = true
        })
      }
    }
    .width('calc(100% - 48vp)')
    .padding({ left: 18, right: 18, top: 16, bottom: 14 })
    .backgroundColor($r('app.color.color_card_overlay'))
    .borderRadius(22)
    .border({ width: 1, color: $r('app.color.color_divider') })
    .shadow({ radius: 14, color: $r('app.color.color_shadow_blue_09'), offsetX: 0, offsetY: 6 })
    .margin({ left: 24, right: 24, top: 8, bottom: 10 })
  }

  @Builder
  ShortcutItem(title: string, icon: ResourceStr, color: ResourceColor, targetIndex: number) {
    Column() {
      Row() {
        Image(icon)
          .width(20)
          .height(20)
          .fillColor(color)
      }
      .width(42)
      .height(42)
      .borderRadius(21)
      .backgroundColor($r('app.color.color_soft_blue'))
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)

      Text(title)
        .fontSize(12)
        .fontColor($r('app.color.color_text_primary'))
        .margin({ top: 6 })
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
    .onClick(() => {
      if (title === '分类') {
        AppStorage.setOrCreate('showCategoryEditor', true)
      } else {
        this.activeTabIndex = targetIndex
      }
    })
  }

  @Builder
  ShortcutPanel() {
    Row() {
      this.ShortcutItem('记一笔', $rawfile('icon_edit.svg'), $r('app.color.color_primary'), 2)
      this.ShortcutItem('日历', $rawfile('icon_calendar.svg'), $r('app.color.color_primary'), 1)
      this.ShortcutItem('统计', $rawfile('icon_tab_stats.svg'), $r('app.color.color_accent'), 3)
      this.ShortcutItem('分类', $rawfile('icon_list.svg'), $r('app.color.color_primary'), 0)
      this.ShortcutItem('预算', $rawfile('icon_tab_bills.svg'), $r('app.color.color_primary'), 4)
    }
    .width('calc(100% - 48vp)')
    .padding({ left: 10, right: 10, top: 14, bottom: 12 })
    .backgroundColor($r('app.color.color_card_overlay'))
    .borderRadius(22)
    .border({ width: 1, color: $r('app.color.color_divider') })
    .shadow({ radius: 14, color: $r('app.color.color_shadow_blue_09'), offsetX: 0, offsetY: 6 })
    .margin({ left: 24, right: 24, top: 8, bottom: 16 })
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      WaterPageBg()

      Column() {
        this.HomeHeader()
        this.HomeMonthSelector()

        Scroll() {
          Column() {
            SummaryCard({
              income: this.totalIncome,
              expense: this.totalExpense,
              budgetSpent: this.budgetSpent,
              budgetLimit: this.budgetLimit
            })

            this.RecentBillsCard()
            this.ShortcutPanel()
          }
          .width('100%')
          .translate({ x: this.slideOffsetX })
          .gesture(
            PanGesture({ direction: PanDirection.Horizontal, distance: 5 })
              .onActionUpdate((event: GestureEvent) => {
                if (event) {
                  this.slideOffsetX = event.offsetX
                }
              })
              .onActionEnd((event: GestureEvent) => {
                if (!event) {
                  this.slideOffsetX = 0
                  return
                }
                if (event.offsetX > 80) {
                  this.doMonthSwitch(1)
                } else if (event.offsetX < -80) {
                  this.doMonthSwitch(-1)
                } else {
                  this.getUIContext().animateTo({ duration: 150, curve: Curve.EaseOut }, () => {
                    this.slideOffsetX = 0
                  })
                }
              })
          )
        }
        .align(Alignment.Top)
        .width('100%')
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Start)
      .alignItems(HorizontalAlign.Center)
      .backgroundColor(Color.Transparent)

    }
  }
}
