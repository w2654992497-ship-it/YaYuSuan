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

  private buildCells(): CalendarCell[] {
    const parts = this.currentMonth.split('-')
    const year = parseInt(parts[0], 10)
    const month = parseInt(parts[1], 10)
    const firstDay = new Date(year, month - 1, 1)
    let startWeekday = firstDay.getDay() - 1
    if (startWeekday < 0) startWeekday = 6
    const daysInMonth = new Date(year, month, 0).getDate()

    const summaryMap: Map<string, DaySummary> = new Map()
    for (const s of this.daySummaries) { summaryMap.set(s.date, s) }

    const todayStr = DateUtil.today()
    const cells: CalendarCell[] = []

    for (let i = 0; i < startWeekday; i++) {
      cells.push({ day: 0, dateStr: '', isToday: false, isWeekend: false, income: 0, expense: 0 })
    }
    for (let d = 1; d <= daysInMonth; d++) {
      const dateStr = `${this.currentMonth}-${d.toString().padStart(2, '0')}`
      const summary = summaryMap.get(dateStr)
      const colIndex = (startWeekday + d - 1) % 7
      cells.push({
        day: d, dateStr: dateStr,
        isToday: dateStr === todayStr,
        isWeekend: colIndex >= 5,
        income: summary ? summary.income : 0,
        expense: summary ? summary.expense : 0
      })
    }
    return cells
  }

  private cellKey(cell: CalendarCell, index: number): string {
    return `${this.currentMonth}_${index}_${cell.income}_${cell.expense}`
  }

  build() {
    Column() {
      // 星期头
      Row() {
        ForEach(this.weekLabels, (label: string, idx: number) => {
          Text(label)
            .fontSize(12)
            .fontColor(idx >= 5 ? '#1976D2' : '#757575')
            .fontWeight(FontWeight.Medium)
            .textAlign(TextAlign.Center)
            .layoutWeight(1)
        })
      }
      .width('100%')
      .height(24)
      .padding({ left: 4, right: 4 })

      // 日历格子 — Flex wrap，每格固定 14.28% × 52vp
      Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start, alignContent: FlexAlign.Start }) {
        ForEach(this.buildCells(), (cell: CalendarCell, index: number) => {
          // 每个格子
          Column() {
            if (cell.day > 0) {
              // 日期圆圈
              Column() {
                Text(`${cell.day}`)
                  .fontSize(14)
                  .fontColor(
                    cell.dateStr === this.selectedDate ? '#FFFFFF' :
                      cell.isToday ? '#1976D2' :
                        cell.isWeekend ? '#1976D2' : '#212121'
                  )
                  .fontWeight(cell.isToday || cell.dateStr === this.selectedDate ? FontWeight.Bold : FontWeight.Normal)
              }
              .width(28)
              .height(28)
              .borderRadius(14)
              .justifyContent(FlexAlign.Center)
              .alignItems(HorizontalAlign.Center)
              .backgroundColor(cell.dateStr === this.selectedDate ? '#1976D2' : Color.Transparent)
              .border(cell.isToday && cell.dateStr !== this.selectedDate
                ? { width: 1, color: '#1976D2', style: BorderStyle.Solid }
                : { width: 0 })

              // 收支金额
              if (cell.expense > 0 || cell.income > 0) {
                if (cell.expense > 0) {
                  Text(AmountUtil.shortYuan(cell.expense))
                    .fontSize(8)
                    .fontColor('#F44336')
                    .maxLines(1)
                    .margin({ top: 1 })
                }
                if (cell.income > 0) {
                  Text(AmountUtil.shortYuan(cell.income))
                    .fontSize(8)
                    .fontColor('#4CAF50')
                    .maxLines(1)
                }
              } else {
                Blank().height(10)
              }
            }
          }
          .width('14.28%')
          .height(52)
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
          .borderRadius(8)
          .onClick(() => {
            if (cell.day > 0) { this.onSelectDate(cell.dateStr) }
          })
        }, (cell: CalendarCell, index: number) => this.cellKey(cell, index))
      }
      .width('100%')
      .padding({ left: 2, right: 2 })
    }
    .width('100%')
  }
}
