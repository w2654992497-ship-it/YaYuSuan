import { DaySummary } from '../model/StatResult'
import { AmountUtil } from '../utils/AmountUtil'
import { DateUtil } from '../utils/DateUtil'

interface CalendarCell {
  day: number
  dateStr: string
  isToday: boolean
  isWeekend: boolean
  income: number
  expense: number
}

@Component
export struct CalendarGrid {
  @Prop currentMonth: string = ''
  @Prop selectedDate: string = ''
  @Prop daySummaries: DaySummary[] = []
  onSelectDate: (date: string) => void = () => {}

  private readonly weekLabels: string[] = ['一', '二', '三', '四', '五', '六', '日']

  private summaryAt(dateStr: string): DaySummary | null {
    for (let i = 0; i < this.daySummaries.length; i++) {
      if (this.daySummaries[i].date === dateStr) {
        return this.daySummaries[i]
      }
    }
    return null
  }

  private buildCells(): CalendarCell[] {
    const parts = this.currentMonth.split('-')
    const year = parseInt(parts[0], 10)
    const month = parseInt(parts[1], 10)
    const firstDay = new Date(year, month - 1, 1)
    let startWeekday = firstDay.getDay() - 1
    if (startWeekday < 0) {
      startWeekday = 6
    }
    const daysInMonth = new Date(year, month, 0).getDate()
    const todayStr = DateUtil.today()
    const cells: CalendarCell[] = []

    for (let i = 0; i < startWeekday; i++) {
      cells.push({ day: 0, dateStr: '', isToday: false, isWeekend: false, income: 0, expense: 0 })
    }
    for (let d = 1; d <= daysInMonth; d++) {
      const dateStr = `${this.currentMonth}-${d.toString().padStart(2, '0')}`
      const summary = this.summaryAt(dateStr)
      const colIndex = (startWeekday + d - 1) % 7
      cells.push({
        day: d,
        dateStr: dateStr,
        isToday: dateStr === todayStr,
        isWeekend: colIndex >= 5,
        income: summary ? summary.income : 0,
        expense: summary ? summary.expense : 0
      })
    }
    return cells
  }

  private cellKey(cell: CalendarCell, index: number): string {
    return `${this.currentMonth}_${this.selectedDate}_${index}_${cell.income}_${cell.expense}`
  }

  build() {
    Column() {
      Row() {
        ForEach(this.weekLabels, (label: string, index: number) => {
          Text(label)
            .fontSize(13)
            .fontColor(index >= 5 ? $r('app.color.color_primary') : $r('app.color.color_text_secondary'))
            .fontWeight(FontWeight.Medium)
            .textAlign(TextAlign.Center)
            .layoutWeight(1)
        }, (label: string) => label)
      }
      .width('100%')
      .height(24)
      .padding({ left: 4, right: 4 })

      Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start, alignContent: FlexAlign.Start }) {
        ForEach(this.buildCells(), (cell: CalendarCell, index: number) => {
          Column() {
            if (cell.day > 0) {
              Column() {
                Text(`${cell.day}`)
                  .fontSize(15)
                  .fontWeight(cell.dateStr === this.selectedDate ? FontWeight.Bold : FontWeight.Normal)
                  .fontColor(cell.dateStr === this.selectedDate ? $r('app.color.color_white') :
                    cell.isWeekend ? $r('app.color.color_primary') : $r('app.color.color_text_primary'))
              }
              .width(28)
              .height(28)
              .borderRadius(14)
              .justifyContent(FlexAlign.Center)
              .alignItems(HorizontalAlign.Center)
              .backgroundColor(cell.dateStr === this.selectedDate ? $r('app.color.color_primary') : Color.Transparent)
              .border(cell.isToday && cell.dateStr !== this.selectedDate ?
                { width: 1, color: $r('app.color.color_primary'), style: BorderStyle.Solid } : { width: 0 })

              if (cell.expense > 0) {
                Text(AmountUtil.shortYuan(cell.expense))
                  .fontSize(10)
                  .fontColor($r('app.color.color_expense'))
                  .maxLines(1)
                  .margin({ top: 2 })
              } else if (cell.income > 0) {
                Text(AmountUtil.shortYuan(cell.income))
                  .fontSize(10)
                  .fontColor($r('app.color.color_income'))
                  .maxLines(1)
                  .margin({ top: 2 })
              } else {
                Blank()
                  .height(10)
              }
            }
          }
          .width('14.28%')
          .height(46)
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
          .onClick(() => {
            if (cell.day > 0) {
              this.onSelectDate(cell.dateStr)
            }
          })
        }, (cell: CalendarCell, index: number) => this.cellKey(cell, index))
      }
      .width('100%')
      .padding({ left: 2, right: 2, bottom: 4 })
    }
    .width('100%')
  }
}
