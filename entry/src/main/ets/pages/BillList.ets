import { BillDao } from '../database/BillDao'
import { Bill } from '../model/Bill'
import { getCategoryColor, getCategoryInfo } from '../model/Category'
import { FilterOptions } from '../model/FilterOptions'
import { SummaryCard } from '../components/SummaryCard'
import { WaterPageBg } from '../components/WaterPageBg'
import { AmountUtil } from '../utils/AmountUtil'
import { DateUtil } from '../utils/DateUtil'
import { BudgetService } from '../services/BudgetService'
import { BudgetOverview } from '../model/BudgetRule'
import { LogUtils } from '../utils/LogUtils'

const BILL_LIST_TAG = 'BillList'

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
  @Watch('onBillDataVersionChanged')
  @StorageProp('billDataVersion') billDataVersion: number = 0
  @State allBills: Bill[] = []
  @State previewBills: Bill[] = []
  @State filter: FilterOptions = { month: DateUtil.currentMonth(), type: 'all', category: '' }
  @State totalIncome: number = 0
  @State totalExpense: number = 0
  @State dayBudgetSpent: number = 0
  @State dayBudgetLimit: number = 0
  @State monthBudgetSpent: number = 0
  @State monthBudgetLimit: number = 0
  @State yearBudgetSpent: number = 0
  @State yearBudgetLimit: number = 0
  @State budgetRenderVersion: number = 0
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

  onBillDataVersionChanged(): void {
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
    for (let i = 0; i < sortedBills.length && i < 2; i++) {
      preview.push(sortedBills[i])
    }

    await this.loadBudgetProgress()
    this.allBills = sortedBills
    this.previewBills = preview
    this.totalIncome = inc
    this.totalExpense = exp
  }

  private async loadBudgetProgress(): Promise<void> {
    const month = this.filter.month && this.filter.month.length > 0 ? this.filter.month : DateUtil.currentMonth()
    const year = this.yearFromMonth(month)
    const dayOverview = await BudgetService.getInstance().buildOverview('day')
    const monthOverview = await BudgetService.getInstance().buildMonthOverview(month)
    const yearOverview = await BudgetService.getInstance().buildYearOverview(year)
    this.dayBudgetSpent = dayOverview.usedFen
    this.dayBudgetLimit = this.displayBudgetLimit(dayOverview)
    this.monthBudgetSpent = monthOverview.usedFen
    this.monthBudgetLimit = this.displayBudgetLimit(monthOverview)
    this.yearBudgetSpent = yearOverview.usedFen
    this.yearBudgetLimit = this.displayBudgetLimit(yearOverview)
    this.budgetRenderVersion += 1
    LogUtils.info(BILL_LIST_TAG,
      '账单页预算刷新 month=%{public}s day=%{public}d/%{public}d cat=%{public}d rules=%{public}d monthValue=%{public}d/%{public}d cat=%{public}d rules=%{public}d year=%{public}d/%{public}d cat=%{public}d rules=%{public}d render=%{public}d',
      month,
      dayOverview.usedFen, dayOverview.totalFen, dayOverview.categoryBudgetFen, dayOverview.activeRuleCount,
      monthOverview.usedFen, monthOverview.totalFen, monthOverview.categoryBudgetFen, monthOverview.activeRuleCount,
      yearOverview.usedFen, yearOverview.totalFen, yearOverview.categoryBudgetFen, yearOverview.activeRuleCount,
      this.budgetRenderVersion)
  }

  private displayBudgetLimit(overview: BudgetOverview): number {
    if (overview.totalFen > 0) {
      return overview.totalFen
    }
    return overview.categoryBudgetFen
  }

  private yearFromMonth(month: string): string {
    const parts = month.split('-')
    if (parts.length < 1 || parts[0].length === 0) {
      return new Date().getFullYear().toString()
    }
    return parts[0]
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

  private two(value: number): string {
    if (value < 10) {
      return '0' + value.toString()
    }
    return value.toString()
  }

  private billDateTimeLabel(bill: Bill): string {
    const time = new Date(bill.createdAt)
    return this.billDateLabel(bill.date) + ' ' + this.two(time.getHours()) + ':' + this.two(time.getMinutes())
  }

  private recentTitle(): string {
    if (this.showAllBills) {
      return '账单明细'
    }
    if (this.filter.type === 'expense') {
      return '支出账单'
    }
    if (this.filter.type === 'income') {
      return '收入账单'
    }
    return '最近账单'
  }

  @Builder
  HomeHeader() {
    Row() {
      Text('小金鱼记账')
        .fontSize(24)
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
      .height(38)
      .padding({ left: 12, right: 14 })
      .backgroundColor($r('app.color.color_card_overlay'))
      .borderRadius(20)
      .shadow({ radius: 10, color: $r('app.color.color_shadow_blue_10'), offsetX: 0, offsetY: 4 })
      .onClick(() => {
        this.navStack.pushPathByName('billSearch', null)
      })
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .padding({ left: 16, right: 16, top: this.sbHeight + 8, bottom: 6 })
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
      .width(38)
      .height(42)
      .justifyContent(FlexAlign.Center)
      .onClick(() => {
        this.doMonthSwitch(1)
      })

      Row({ space: 8 }) {
        Image($rawfile('icon_calendar.svg'))
          .width(19)
          .height(19)
          .fillColor($r('app.color.color_primary'))
        Text(DateUtil.formatMonthDisplay(this.filter.month || DateUtil.currentMonth()))
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.color_text_deep'))
        Image($rawfile('icon_chevron_down.svg'))
          .width(13)
          .height(13)
          .fillColor($r('app.color.color_text_deep'))
      }
      .layoutWeight(1)
      .height(42)
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
      .width(38)
      .height(42)
      .justifyContent(FlexAlign.Center)
      .onClick(() => {
        if (!DateUtil.isCurrentMonth(this.filter.month || DateUtil.currentMonth())) {
          this.doMonthSwitch(-1)
        }
      })
    }
    .width('calc(100% - 32vp)')
    .height(42)
    .backgroundColor($r('app.color.color_card_overlay'))
    .borderRadius(21)
    .border({ width: 1, color: $r('app.color.color_divider') })
    .shadow({ radius: 10, color: $r('app.color.color_shadow_blue_09'), offsetX: 0, offsetY: 4 })
    .margin({ left: 16, right: 16, bottom: 6 })
  }

  @Builder
  TypeChip(label: string, chipType: 'all' | 'income' | 'expense') {
    Text(label)
      .fontSize(13)
      .fontWeight(FontWeight.Medium)
      .fontColor(this.filter.type === chipType ? $r('app.color.color_white') : $r('app.color.color_text_secondary'))
      .textAlign(TextAlign.Center)
      .width(44)
      .height(24)
      .borderRadius(12)
      .backgroundColor(this.filter.type === chipType ? $r('app.color.color_primary') : $r('app.color.color_white'))
      .border({ width: 1, color: this.filter.type === chipType ? $r('app.color.color_primary') : $r('app.color.color_divider') })
      .onClick(() => {
        this.filter = { month: this.filter.month, type: chipType, category: this.filter.category }
        this.showAllBills = false
        this.loadData()
      })
  }

  @Builder
  TopFilterChip(label: string, chipType: 'all' | 'income' | 'expense') {
    Text(label)
      .fontSize(15)
      .fontWeight(FontWeight.Medium)
      .fontColor(this.filter.type === chipType ? $r('app.color.color_white') : $r('app.color.color_text_secondary'))
      .textAlign(TextAlign.Center)
      .layoutWeight(1)
      .height(36)
      .borderRadius(18)
      .backgroundColor(this.filter.type === chipType ? $r('app.color.color_primary') : '#00000000')
      .onClick(() => {
        this.filter = { month: this.filter.month, type: chipType, category: this.filter.category }
        this.showAllBills = false
        this.loadData()
      })
  }

  @Builder
  HomeTopControls() {
    Row({ space: 12 }) {
      Row({ space: 8 }) {
        Image($rawfile('icon_calendar.svg'))
          .width(20)
          .height(20)
          .fillColor($r('app.color.color_primary'))
        Text(DateUtil.formatMonthDisplay(this.filter.month || DateUtil.currentMonth()))
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.color_text_deep'))
          .maxLines(1)
        Image($rawfile('icon_chevron_down.svg'))
          .width(13)
          .height(13)
          .fillColor($r('app.color.color_text_deep'))
      }
      .layoutWeight(1)
      .height(44)
      .justifyContent(FlexAlign.Center)
      .backgroundColor($r('app.color.color_card_overlay'))
      .borderRadius(22)
      .border({ width: 1, color: $r('app.color.color_divider') })
      .shadow({ radius: 10, color: $r('app.color.color_shadow_blue_09'), offsetX: 0, offsetY: 4 })
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
        this.TopFilterChip('全部', 'all')
        this.TopFilterChip('支出', 'expense')
        this.TopFilterChip('收入', 'income')
      }
      .layoutWeight(1.12)
      .height(44)
      .padding({ left: 4, right: 4 })
      .backgroundColor($r('app.color.color_card_overlay'))
      .borderRadius(22)
      .border({ width: 1, color: $r('app.color.color_divider') })
      .shadow({ radius: 10, color: $r('app.color.color_shadow_blue_09'), offsetX: 0, offsetY: 4 })
    }
    .width('100%')
    .padding({ left: 16, right: 16, bottom: 6 })
  }

  @Builder
  RecentBillRow(bill: Bill, showDivider: boolean) {
    Column() {
      Row() {
        Row() {
          Image($rawfile(getCategoryInfo(bill.category).icon + '.svg'))
            .width(20)
            .height(20)
            .fillColor($r('app.color.color_white'))
        }
        .width(34)
        .height(34)
        .borderRadius(17)
        .backgroundColor(getCategoryColor(bill.category))
        .justifyContent(FlexAlign.Center)
        .margin({ right: 10 })

        Column() {
          Text(bill.category)
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.color_text_deep'))
            .maxLines(1)
          Text(bill.remark.length > 0 ? bill.remark : '未填写备注')
            .fontSize(12)
            .fontColor($r('app.color.color_text_secondary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ top: 2 })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Text(this.billDateTimeLabel(bill))
          .fontSize(12)
          .fontColor($r('app.color.color_text_secondary'))
          .margin({ right: 10 })

        Text(AmountUtil.formatWithSign(bill.amount, bill.type))
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(bill.type === 'income' ? $r('app.color.color_income') : $r('app.color.color_expense'))
          .textAlign(TextAlign.End)
          .width(74)
      }
      .width('100%')
      .height(48)

      if (showDivider) {
        Divider()
          .height(1)
          .color($r('app.color.color_divider'))
          .margin({ left: 54 })
      }
    }
    .width('100%')
    .onClick(() => {
      this.navStack.pushPathByName('billDetail', bill.id)
    })
  }

  @Builder
  EmptyRecentState() {
    Column() {
      Image($rawfile('icon_tab_bills.svg'))
        .width(30)
        .height(30)
        .fillColor($r('app.color.color_divider'))
      Text('还没有账单记录')
        .fontSize(13)
        .fontColor($r('app.color.color_text_secondary'))
        .margin({ top: 8 })
    }
    .width('100%')
    .height(92)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  RecentBillsCard() {
    Column() {
      Row() {
        Text(this.showAllBills ? '账单明细' : '最近账单')
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.color_text_deep'))

        Blank()

        if (!this.showAllBills) {
          Row({ space: 8 }) {
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
      .height(28)
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

        if (this.allBills.length > this.previewBills.length) {
          Row({ space: 8 }) {
            Text('查看全部账单')
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.color_primary'))
            Image($rawfile('icon_chevron_right.svg'))
              .width(14)
              .height(14)
              .fillColor($r('app.color.color_primary'))
          }
          .width('100%')
          .height(30)
          .justifyContent(FlexAlign.Center)
          .margin({ top: 4 })
          .onClick(() => {
            this.showAllBills = true
          })
        }
      }
    }
    .width('calc(100% - 32vp)')
    .padding({ left: 14, right: 14, top: 12, bottom: 10 })
    .backgroundColor($r('app.color.color_card_overlay'))
    .borderRadius(20)
    .border({ width: 1, color: $r('app.color.color_divider') })
    .shadow({ radius: 12, color: $r('app.color.color_shadow_blue_09'), offsetX: 0, offsetY: 5 })
    .margin({ left: 16, right: 16, top: 6, bottom: 8 })
  }

  @Builder
  RecentBillsCardV2() {
    Column() {
      Row() {
        Text(this.recentTitle())
          .fontSize(19)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.color_text_deep'))

        Blank()

        if (this.showAllBills) {
          Text('收起')
            .fontSize(13)
            .fontColor($r('app.color.color_primary'))
            .onClick(() => {
              this.showAllBills = false
            })
        } else {
          Row({ space: 6 }) {
            Text('全部账单')
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.color_primary'))
            Image($rawfile('icon_chevron_right.svg'))
              .width(14)
              .height(14)
              .fillColor($r('app.color.color_primary'))
          }
          .alignItems(VerticalAlign.Center)
          .onClick(() => {
            this.showAllBills = true
          })
        }
      }
      .width('100%')
      .height(32)
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

        if (this.allBills.length > this.previewBills.length) {
          Row({ space: 8 }) {
            Text('查看全部账单')
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.color_primary'))
            Image($rawfile('icon_chevron_right.svg'))
              .width(15)
              .height(15)
              .fillColor($r('app.color.color_primary'))
          }
          .width('100%')
          .height(34)
          .justifyContent(FlexAlign.Center)
          .margin({ top: 6 })
          .onClick(() => {
            this.showAllBills = true
          })
        }
      }
    }
    .width('calc(100% - 32vp)')
    .padding({ left: 16, right: 16, top: 16, bottom: 12 })
    .backgroundColor($r('app.color.color_card_overlay'))
    .borderRadius(22)
    .border({ width: 1, color: $r('app.color.color_divider') })
    .shadow({ radius: 12, color: $r('app.color.color_shadow_blue_09'), offsetX: 0, offsetY: 5 })
    .margin({ left: 16, right: 16, top: 8, bottom: 8 })
  }

  @Builder
  ShortcutItem(title: string, icon: ResourceStr, color: ResourceColor, targetIndex: number) {
    Column() {
      Row() {
        Image(icon)
          .width(18)
          .height(18)
          .fillColor(color)
      }
      .width(36)
      .height(36)
      .borderRadius(18)
      .backgroundColor($r('app.color.color_soft_blue'))
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)

      Text(title)
        .fontSize(11)
        .fontColor($r('app.color.color_text_primary'))
        .margin({ top: 4 })
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
    .width('calc(100% - 32vp)')
    .padding({ left: 8, right: 8, top: 10, bottom: 8 })
    .backgroundColor($r('app.color.color_card_overlay'))
    .borderRadius(20)
    .border({ width: 1, color: $r('app.color.color_divider') })
    .shadow({ radius: 12, color: $r('app.color.color_shadow_blue_09'), offsetX: 0, offsetY: 5 })
    .margin({ left: 16, right: 16, top: 4, bottom: 14 })
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      WaterPageBg()

      Column() {
        this.HomeHeader()
        this.HomeTopControls()

        Scroll() {
          Column() {
            SummaryCard({
              filterType: this.filter.type,
              billCount: this.allBills.length,
              income: this.totalIncome,
              expense: this.totalExpense,
              dayBudgetSpent: this.dayBudgetSpent,
              dayBudgetLimit: this.dayBudgetLimit,
              monthBudgetSpent: this.monthBudgetSpent,
              monthBudgetLimit: this.monthBudgetLimit,
              yearBudgetSpent: this.yearBudgetSpent,
              yearBudgetLimit: this.yearBudgetLimit,
              budgetRefreshVersion: this.budgetRenderVersion
            })

            this.RecentBillsCardV2()
            if (!this.showAllBills) {
              this.ShortcutPanel()
            }
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
        .layoutWeight(1)
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
