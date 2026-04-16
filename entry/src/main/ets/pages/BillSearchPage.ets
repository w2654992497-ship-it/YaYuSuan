import { Bill } from '../model/Bill'
import { SearchFilterOptions, createDefaultSearchFilter } from '../model/SearchFilterOptions'
import { BillDao } from '../database/BillDao'
import { CategoryDao } from '../database/CategoryDao'
import { AmountUtil } from '../utils/AmountUtil'
import { DateUtil } from '../utils/DateUtil'
import { SearchResultItem } from '../components/SearchResultItem'

interface SearchResultData {
  bill: Bill
  hitRemark: boolean
  hitCategory: boolean
  hitAmount: boolean
}

interface SearchGroupData {
  date: string
  items: SearchResultData[]
  dayIncome: number
  dayExpense: number
}

interface DateRange {
  startDate: string
  endDate: string
}

interface CategoryOption {
  label: string
  value: string
  selected: boolean
}

@Component
export struct BillSearchPage {
  onClose: () => void = () => {}
  @StorageProp('statusBarHeight') sbHeight: number = 0
  @State keyword: string = ''
  @State filter: SearchFilterOptions = createDefaultSearchFilter()
  @State expenseCategories: string[] = []
  @State incomeCategories: string[] = []
  @State resultGroups: SearchGroupData[] = []
  @State resultCount: number = 0
  @State totalIncome: number = 0
  @State totalExpense: number = 0
  @State selectedType: 'all' | 'income' | 'expense' = 'all'
  @State showCategoryMenu: boolean = false

  aboutToAppear(): void {
    this.selectedType = this.filter.type
    this.loadCategories().catch(() => {})
    this.runSearch().catch(() => {})
  }

  private async loadCategories(): Promise<void> {
    const expense = await CategoryDao.getInstance().queryByType('expense')
    const income = await CategoryDao.getInstance().queryByType('income')
    const e: string[] = []
    const i: string[] = []
    for (const c of expense) {
      e.push(c.name)
    }
    for (const c of income) {
      i.push(c.name)
    }
    this.expenseCategories = e
    this.incomeCategories = i
    if (!this.currentCategoryOptions().some((name: string): boolean => name === this.filter.category)) {
      const next = this.copyFilter()
      next.category = ''
      this.filter = next
    }
  }

  private copyFilter(): SearchFilterOptions {
    return {
      keyword: this.filter.keyword,
      type: this.filter.type,
      category: this.filter.category,
      startDate: this.filter.startDate,
      endDate: this.filter.endDate
    }
  }

  private currentCategoryOptions(): string[] {
    if (this.selectedType === 'income') {
      return this.incomeCategories
    }
    if (this.selectedType === 'expense') {
      return this.expenseCategories
    }
    const all = new Set<string>()
    for (const c of this.expenseCategories) {
      all.add(c)
    }
    for (const c of this.incomeCategories) {
      all.add(c)
    }
    return Array.from(all.values())
  }

  private categoryOptionsForMenu(): CategoryOption[] {
    const options: CategoryOption[] = []
    options.push({
      label: this.filter.category.length === 0 ? '全部分类（已选）' : '全部分类',
      value: '',
      selected: this.filter.category.length === 0
    })
    for (const name of this.currentCategoryOptions()) {
      options.push({
        label: this.filter.category === name ? `${name}（已选）` : name,
        value: name,
        selected: this.filter.category === name
      })
    }
    return options
  }

  private normalize(text: string): string {
    return text.toLowerCase().replace(/[\s￥¥,]/g, '').trim()
  }

  private normalizedRange(): DateRange {
    const startDate = this.filter.startDate
    const endDate = this.filter.endDate
    if (startDate.length > 0 && endDate.length > 0 && startDate.localeCompare(endDate) > 0) {
      return { startDate: endDate, endDate: startDate }
    }
    return { startDate: startDate, endDate: endDate }
  }

  private hasAnyFilter(): boolean {
    return this.filter.type !== 'all' ||
      this.filter.category.length > 0 ||
      this.filter.startDate.length > 0 ||
      this.filter.endDate.length > 0
  }

  private dayNetDisplay(group: SearchGroupData): string {
    const net = group.dayIncome - group.dayExpense
    if (net > 0) {
      return `+${AmountUtil.fen2Display(net)}`
    }
    if (net < 0) {
      return `-${AmountUtil.fen2Display(net * -1)}`
    }
    return '0.00'
  }

  private clearFilters(): void {
    const next = this.copyFilter()
    next.type = 'all'
    next.category = ''
    next.startDate = ''
    next.endDate = ''
    this.filter = next
    this.selectedType = 'all'
    this.showCategoryMenu = false
    this.runSearch().catch(() => {})
  }

  private clearKeyword(): void {
    this.keyword = ''
    const next = this.copyFilter()
    next.keyword = ''
    this.filter = next
    this.runSearch().catch(() => {})
  }

  private setTypeFilter(type: 'all' | 'income' | 'expense'): void {
    this.selectedType = type
    const next = this.copyFilter()
    next.type = type
    next.category = ''
    this.filter = next
    this.showCategoryMenu = false
    this.runSearch().catch(() => {})
  }

  private setCategoryFilter(category: string): void {
    const next = this.copyFilter()
    next.category = category
    this.filter = next
    this.showCategoryMenu = false
    this.runSearch().catch(() => {})
  }

  private pickDate(isStart: boolean): void {
    const selectedDate = isStart
      ? (this.filter.startDate.length > 0 ? this.filter.startDate : DateUtil.today())
      : (this.filter.endDate.length > 0 ? this.filter.endDate : DateUtil.today())
    const parts = selectedDate.split('-')
    const now = new Date()
    this.getUIContext().showDatePickerDialog({
      start: new Date('2020-01-01'),
      end: now,
      selected: new Date(parseInt(parts[0], 10), parseInt(parts[1], 10) - 1, parseInt(parts[2], 10)),
      lunar: false,
      onDateAccept: (value: Date) => {
        const y = value.getFullYear()
        const m = (value.getMonth() + 1).toString().padStart(2, '0')
        const d = value.getDate().toString().padStart(2, '0')
        const date = `${y}-${m}-${d}`
        const next = this.copyFilter()
        if (isStart) {
          next.startDate = date
        } else {
          next.endDate = date
        }
        this.filter = next
        this.runSearch().catch(() => {})
      }
    })
  }

  private async runSearch(): Promise<void> {
    const range = this.normalizedRange()
    const queryFilter: SearchFilterOptions = {
      keyword: this.keyword,
      type: this.selectedType,
      category: this.filter.category,
      startDate: range.startDate,
      endDate: range.endDate
    }
    const bills = await BillDao.getInstance().queryBySearchFilter(queryFilter)
    const keywordNormalized = this.normalize(this.keyword)
    const matched: SearchResultData[] = []

    for (const bill of bills) {
      if (keywordNormalized.length === 0) {
        matched.push({ bill: bill, hitRemark: false, hitCategory: false, hitAmount: false })
        continue
      }
      const hitRemark = this.normalize(bill.remark ?? '').includes(keywordNormalized)
      const hitCategory = this.normalize(bill.category).includes(keywordNormalized)
      const hitAmount = this.normalize(AmountUtil.fen2Display(bill.amount)).includes(keywordNormalized)
      if (hitRemark || hitCategory || hitAmount) {
        matched.push({ bill: bill, hitRemark: hitRemark, hitCategory: hitCategory, hitAmount: hitAmount })
      }
    }

    const groupMap = new Map<string, SearchGroupData>()
    let income = 0
    let expense = 0
    for (const item of matched) {
      if (!groupMap.has(item.bill.date)) {
        groupMap.set(item.bill.date, { date: item.bill.date, items: [], dayIncome: 0, dayExpense: 0 })
      }
      const group = groupMap.get(item.bill.date)!
      group.items.push(item)
      if (item.bill.type === 'income') {
        income += item.bill.amount
        group.dayIncome += item.bill.amount
      } else {
        expense += item.bill.amount
        group.dayExpense += item.bill.amount
      }
    }

    this.resultGroups = Array.from(groupMap.values()).sort((a, b) => b.date.localeCompare(a.date))
    this.resultCount = matched.length
    this.totalIncome = income
    this.totalExpense = expense
  }

  build() {
    Column() {
      Row() {
        Row() {
          Image($rawfile('icon_chevron_left.svg'))
            .width(20)
            .height(20)
            .fillColor($r('app.color.color_text_primary'))
        }
        .width(32)
        .height(32)
        .borderRadius(16)
        .justifyContent(FlexAlign.Center)
        .backgroundColor($r('app.color.color_bg'))
        .onClick(() => { this.onClose() })

        Row() {
          Image($rawfile('icon_list.svg'))
            .width(16)
            .height(16)
            .fillColor($r('app.color.color_text_secondary'))
            .margin({ right: 8 })
          TextInput({ text: this.keyword, placeholder: '搜索备注 / 分类 / 金额' })
            .layoutWeight(1)
            .fontSize(14)
            .backgroundColor(Color.Transparent)
            .border({ width: 0 })
            .borderRadius(0)
            .fontColor($r('app.color.color_text_primary'))
            .placeholderColor($r('app.color.color_text_secondary'))
            .onChange((value: string) => {
              this.keyword = value
              const next = this.copyFilter()
              next.keyword = value
              this.filter = next
              this.runSearch().catch(() => {})
            })
        }
        .layoutWeight(1)
        .height(36)
        .padding({ left: 10, right: 10 })
        .backgroundColor($r('app.color.color_bg'))
        .borderRadius(18)
        .margin({ left: 10, right: 10 })

        Text('清空')
          .fontSize(13)
          .fontColor($r('app.color.color_primary'))
          .onClick(() => { this.clearKeyword() })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: this.sbHeight + 10, bottom: 10 })

      Column({ space: 10 }) {
        Row() {
          Text('筛选条件')
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.color_text_primary'))
          Blank()
          if (this.hasAnyFilter()) {
            Text('重置')
              .fontSize(12)
              .fontColor($r('app.color.color_primary'))
              .onClick(() => { this.clearFilters() })
          }
        }
        .width('100%')

        Column({ space: 8 }) {
          Text('分类')
            .fontSize(11)
            .fontColor($r('app.color.color_text_secondary'))

          Row() {
            Text(this.filter.category.length > 0 ? this.filter.category : '全部分类')
              .fontSize(13)
              .fontColor(this.filter.category.length > 0 ? $r('app.color.color_text_primary') : $r('app.color.color_text_secondary'))
            Blank()
            Image($rawfile('icon_chevron_right.svg'))
              .width(12)
              .height(12)
              .fillColor($r('app.color.color_text_secondary'))
              .rotate({ angle: this.showCategoryMenu ? 90 : 0 })
          }
          .width('100%')
          .height(36)
          .padding({ left: 12, right: 10 })
          .backgroundColor(this.filter.category.length > 0 ? 'rgba(255,209,102,0.18)' : $r('app.color.color_surface'))
          .borderRadius(18)
          .border({ width: 1, color: this.filter.category.length > 0 ? $r('app.color.color_primary') : $r('app.color.color_divider') })
          .onClick(() => { this.showCategoryMenu = !this.showCategoryMenu })

          if (this.showCategoryMenu) {
            Scroll() {
              Column() {
                ForEach(this.categoryOptionsForMenu(), (item: CategoryOption) => {
                  Row() {
                    Text(item.label)
                      .fontSize(13)
                      .fontColor(item.selected ? $r('app.color.color_primary') : $r('app.color.color_text_primary'))
                      .fontWeight(item.selected ? FontWeight.Medium : FontWeight.Normal)
                    Blank()
                    if (item.selected) {
                      Text('✓')
                        .fontSize(13)
                        .fontColor($r('app.color.color_primary'))
                    }
                  }
                  .width('100%')
                  .padding({ left: 12, right: 12, top: 10, bottom: 10 })
                  .backgroundColor(item.selected ? 'rgba(255,209,102,0.18)' : $r('app.color.color_surface'))
                  .onClick(() => { this.setCategoryFilter(item.value) })
                }, (item: CategoryOption) => item.value + item.label)
              }
            }
            .height(160)
            .backgroundColor($r('app.color.color_surface'))
            .borderRadius(12)
            .border({ width: 1, color: $r('app.color.color_divider') })
            .scrollBar(BarState.Auto)
          }
        }
        .padding({ left: 12, right: 12, top: 10, bottom: 10 })
        .backgroundColor($r('app.color.color_surface'))
        .borderRadius(12)
        .border({ width: 1, color: $r('app.color.color_divider') })

        Column({ space: 8 }) {
          Text('时间范围')
            .fontSize(11)
            .fontColor($r('app.color.color_text_secondary'))

          Row({ space: 8 }) {
            Text(this.filter.startDate.length > 0 ? this.filter.startDate : '开始日期')
              .layoutWeight(1)
              .height(34)
              .textAlign(TextAlign.Center)
              .fontSize(12)
              .fontColor(this.filter.startDate.length > 0 ? $r('app.color.color_text_primary') : $r('app.color.color_text_secondary'))
              .backgroundColor($r('app.color.color_surface'))
              .borderRadius(17)
              .border({ width: 1, color: $r('app.color.color_divider') })
              .onClick(() => { this.pickDate(true) })

            Text(this.filter.endDate.length > 0 ? this.filter.endDate : '结束日期')
              .layoutWeight(1)
              .height(34)
              .textAlign(TextAlign.Center)
              .fontSize(12)
              .fontColor(this.filter.endDate.length > 0 ? $r('app.color.color_text_primary') : $r('app.color.color_text_secondary'))
              .backgroundColor($r('app.color.color_surface'))
              .borderRadius(17)
              .border({ width: 1, color: $r('app.color.color_divider') })
              .onClick(() => { this.pickDate(false) })
          }
          .width('100%')
        }
        .padding({ left: 12, right: 12, top: 10, bottom: 10 })
        .backgroundColor($r('app.color.color_surface'))
        .borderRadius(12)
        .border({ width: 1, color: $r('app.color.color_divider') })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 4, bottom: 10 })
      .backgroundColor($r('app.color.color_bg'))

      Row() {
        Text(`结果 ${this.resultCount} 条`)
          .fontSize(13)
          .fontColor($r('app.color.color_text_secondary'))
        Blank()
        Text(`收入 ¥${AmountUtil.fen2Display(this.totalIncome)}`)
          .fontSize(13)
          .fontColor($r('app.color.color_income'))
          .margin({ right: 8 })
        Text(`支出 ¥${AmountUtil.fen2Display(this.totalExpense)}`)
          .fontSize(13)
          .fontColor($r('app.color.color_expense'))
          .margin({ right: 8 })
        Text(`净额 ¥${AmountUtil.fen2Display(this.totalIncome - this.totalExpense)}`)
          .fontSize(13)
          .fontColor((this.totalIncome - this.totalExpense) >= 0 ? $r('app.color.color_income') : $r('app.color.color_expense'))
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 10, bottom: 8 })
      .backgroundColor($r('app.color.color_surface'))

      Row({ space: 6 }) {
        Blank()
        Text('全部')
          .width(50)
          .height(26)
          .textAlign(TextAlign.Center)
          .fontSize(11)
          .fontColor(this.selectedType === 'all' ? $r('app.color.color_surface') : $r('app.color.color_text_secondary'))
          .backgroundColor(this.selectedType === 'all' ? $r('app.color.color_primary') : $r('app.color.color_surface'))
          .borderRadius(13)
          .border({ width: 1, color: this.selectedType === 'all' ? $r('app.color.color_primary') : $r('app.color.color_divider') })
          .onClick(() => { this.setTypeFilter('all') })

        Text('收入')
          .width(50)
          .height(26)
          .textAlign(TextAlign.Center)
          .fontSize(11)
          .fontColor(this.selectedType === 'income' ? $r('app.color.color_surface') : $r('app.color.color_text_secondary'))
          .backgroundColor(this.selectedType === 'income' ? $r('app.color.color_primary') : $r('app.color.color_surface'))
          .borderRadius(13)
          .border({ width: 1, color: this.selectedType === 'income' ? $r('app.color.color_primary') : $r('app.color.color_divider') })
          .onClick(() => { this.setTypeFilter('income') })

        Text('支出')
          .width(50)
          .height(26)
          .textAlign(TextAlign.Center)
          .fontSize(11)
          .fontColor(this.selectedType === 'expense' ? $r('app.color.color_surface') : $r('app.color.color_text_secondary'))
          .backgroundColor(this.selectedType === 'expense' ? $r('app.color.color_primary') : $r('app.color.color_surface'))
          .borderRadius(13)
          .border({ width: 1, color: this.selectedType === 'expense' ? $r('app.color.color_primary') : $r('app.color.color_divider') })
          .onClick(() => { this.setTypeFilter('expense') })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 6, bottom: 6 })

      if (this.resultGroups.length === 0) {
        Column({ space: 10 }) {
          Text('暂无搜索结果')
            .fontSize(15)
            .fontColor($r('app.color.color_text_secondary'))
          Row({ space: 10 }) {
            if (this.keyword.length > 0) {
              Button('清空关键词')
                .height(36)
                .fontSize(13)
                .fontColor($r('app.color.color_primary'))
                .backgroundColor($r('app.color.color_surface'))
                .borderRadius(18)
                .border({ width: 1, color: $r('app.color.color_primary') })
                .onClick(() => { this.clearKeyword() })
            }
            if (this.hasAnyFilter()) {
              Button('清空筛选')
                .height(36)
                .fontSize(13)
                .fontColor($r('app.color.color_primary'))
                .backgroundColor($r('app.color.color_surface'))
                .borderRadius(18)
                .border({ width: 1, color: $r('app.color.color_primary') })
                .onClick(() => { this.clearFilters() })
            }
          }
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      } else {
        List() {
          ForEach(this.resultGroups, (group: SearchGroupData) => {
            ListItem() {
              Row() {
                Text(DateUtil.friendlyDate(group.date))
                  .fontSize(12)
                  .fontColor($r('app.color.color_text_secondary'))
                  .fontWeight(FontWeight.Medium)
                Blank()
                Text(this.dayNetDisplay(group))
                  .fontSize(12)
                  .fontColor(group.dayIncome >= group.dayExpense ? $r('app.color.color_income') : $r('app.color.color_expense'))
                  .fontWeight(FontWeight.Medium)
              }
              .width('100%')
              .padding({ left: 20, right: 20, top: 14, bottom: 6 })
            }
            .selectable(false)

            ForEach(group.items, (item: SearchResultData) => {
              SearchResultItem({
                bill: item.bill,
                hitRemark: item.hitRemark,
                hitCategory: item.hitCategory,
                hitAmount: item.hitAmount
              })
            }, (item: SearchResultData) => `${item.bill.id}_${item.hitRemark}_${item.hitCategory}_${item.hitAmount}`)
          }, (group: SearchGroupData) => `${group.date}_${group.items.length}_${group.dayIncome}_${group.dayExpense}`)
        }
        .layoutWeight(1)
        .width('100%')
        .scrollBar(BarState.Off)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.color_bg'))
  }
}
