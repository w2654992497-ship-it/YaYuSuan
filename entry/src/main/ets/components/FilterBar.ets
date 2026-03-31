import { FilterOptions } from '../model/FilterOptions'
import { DateUtil } from '../utils/DateUtil'

@Component
export struct FilterBar {
  @Prop filter: FilterOptions = { month: '', type: 'all', category: '' }
  onFilterChange: (filter: FilterOptions) => void = () => {}

  private getMonthDisplay(): string {
    if (!this.filter.month || this.filter.month.length === 0) return '全部时间'
    return DateUtil.formatMonthDisplay(this.filter.month)
  }

  private showMonthPicker(): void {
    const parts = this.filter.month
      ? this.filter.month.split('-')
      : DateUtil.currentMonth().split('-')
    const year = parseInt(parts[0], 10)
    const month = parseInt(parts[1], 10) - 1
    const now = new Date()
    DatePickerDialog.show({
      start: new Date('2020-01-01'),
      end: now,
      selected: new Date(year, month, 1),
      lunar: false,
      onAccept: (value: DatePickerResult) => {
        const y = value.year ?? now.getFullYear()
        const m = ((value.month ?? now.getMonth()) + 1).toString().padStart(2, '0')
        this.onFilterChange({
          month: `${y}-${m}`,
          type: this.filter.type,
          category: this.filter.category
        })
      }
    })
  }

  @Builder
  Chip(label: string, type: 'all' | 'income' | 'expense') {
    Text(label)
      .fontSize(12)
      .fontColor(this.filter.type === type ? '#FFFFFF' : '#757575')
      .backgroundColor(this.filter.type === type ? '#1976D2' : '#EEEEEE')
      .borderRadius(14)
      .padding({ left: 14, right: 14, top: 6, bottom: 6 })
      .onClick(() => {
        this.onFilterChange({
          month: this.filter.month,
          type: type,
          category: this.filter.category
        })
      })
  }

  build() {
    Row() {
      // 月份按钮
      Row() {
        Image($rawfile('icon_tab_stats.svg'))
          .width(14)
          .height(14)
          .fillColor('#1976D2')
          .margin({ right: 5 })
        Text(this.getMonthDisplay())
          .fontSize(13)
          .fontColor('#1976D2')
          .fontWeight(FontWeight.Medium)
      }
      .padding({ left: 12, right: 12, top: 6, bottom: 6 })
      .backgroundColor('#E3F2FD')
      .borderRadius(16)
      .onClick(() => { this.showMonthPicker() })

      Blank()

      // 类型 Chip
      Row({ space: 6 }) {
        this.Chip('全部', 'all')
        this.Chip('收入', 'income')
        this.Chip('支出', 'expense')
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 10, bottom: 10 })
    .backgroundColor('#FAFAFA')
  }
}
