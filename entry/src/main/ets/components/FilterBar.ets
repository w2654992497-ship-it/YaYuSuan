import { FilterOptions } from '../model/FilterOptions'
import { DateUtil } from '../utils/DateUtil'

@Component
export struct FilterBar {
  @Prop filter: FilterOptions = { month: '', type: 'all', category: '' }
  onFilterChange: (filter: FilterOptions) => void = () => {}

  private getMonthDisplay(): string {
    if (!this.filter.month || this.filter.month.length === 0) {
      return '全部'
    }
    return DateUtil.formatMonthDisplay(this.filter.month)
  }

  private showMonthPicker(): void {
    const parts = this.filter.month ? this.filter.month.split('-') : DateUtil.currentMonth().split('-')
    const year = parseInt(parts[0], 10)
    const month = parseInt(parts[1], 10) - 1

    const now = new Date()
    DatePickerDialog.show({
      start: new Date('2020-01-01'),
      end: now,
      selected: new Date(year, month, 1),
      lunar: false,
      onAccept: (value: DatePickerResult) => {
        const selectedYear = value.year ?? now.getFullYear()
        const selectedMonth = ((value.month ?? now.getMonth()) + 1).toString().padStart(2, '0')
        const newMonth = `${selectedYear}-${selectedMonth}`
        const newFilter: FilterOptions = {
          month: newMonth,
          type: this.filter.type,
          category: this.filter.category
        }
        this.onFilterChange(newFilter)
      }
    })
  }

  build() {
    Row() {
      // Month selector button
      Button(this.getMonthDisplay())
        .fontSize(14)
        .fontColor('#1976D2') // color_primary
        .backgroundColor('#E3F2FD')
        .borderRadius(16)
        .height(32)
        .padding({ left: 12, right: 12 })
        .onClick(() => {
          this.showMonthPicker()
        })

      Blank()

      // Type chips
      Row({ space: 6 }) {
        ForEach(['all', 'income', 'expense'], (type: string) => {
          Text(type === 'all' ? '全部' : type === 'income' ? '收入' : '支出')
            .fontSize(12)
            .fontColor(this.filter.type === type ? '#FFFFFF' : '#9E9E9E')
            .backgroundColor(this.filter.type === type ? '#1976D2' : '#FFFFFF')
            .borderRadius(14)
            .padding({ left: 12, right: 12, top: 6, bottom: 6 })
            .border(this.filter.type === type
              ? { width: 0 }
              : { width: 1, color: '#9E9E9E' })
            .onClick(() => {
              const newFilter: FilterOptions = {
                month: this.filter.month,
                type: type as 'all' | 'income' | 'expense',
                category: this.filter.category
              }
              this.onFilterChange(newFilter)
            })
        })
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 8, bottom: 8 })
    .backgroundColor('#FAFAFA') // color_bg
  }
}
