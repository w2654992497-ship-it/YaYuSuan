import { DateUtil } from '../utils/DateUtil'

@Component
export struct MonthSelector {
  @Prop currentMonth: string
  onSwitch: (direction: number) => void = () => {}
  onMonthSelect: (month: string) => void = () => {}

  build() {
    Row() {
      // 左侧按钮（上个月）
      Row() {
        Image($rawfile('icon_chevron_left.svg'))
          .width(20).height(20)
          .fillColor($r('app.color.color_text_primary'))
      }
      .width(44)
      .height(44)
      .justifyContent(FlexAlign.Center)
      .onClick(() => {
        this.onSwitch(1)
      })

      // 分割线
      Divider().vertical(true).height(24).color('rgba(0,0,0,0.1)')

      // 中间月份切换
      Row() {
        Text(DateUtil.formatMonthDisplay(this.currentMonth))
          .fontSize(16).fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.color_text_primary'))
      }
      .layoutWeight(1)
      .height(44)
      .justifyContent(FlexAlign.Center)
      .onClick(() => {
        const parts = this.currentMonth.split('-')
        const now = new Date()
        this.getUIContext().showDatePickerDialog({
          start: new Date('2020-01-01'),
          end: now,
          selected: new Date(parseInt(parts[0], 10), parseInt(parts[1], 10) - 1, 1),
          lunar: false,
          onDateAccept: (value: Date) => {
            const y = value.getFullYear()
            const m = (value.getMonth() + 1).toString().padStart(2, '0')
            this.onMonthSelect(`${y}-${m}`)
          }
        })
      })

      // 分割线
      Divider().vertical(true).height(24).color('rgba(0,0,0,0.1)')

      // 右侧按钮（下个月）
      Row() {
        Image($rawfile('icon_chevron_right.svg'))
          .width(20).height(20)
          .fillColor(DateUtil.isCurrentMonth(this.currentMonth)
            ? $r('app.color.color_divider') : $r('app.color.color_text_primary'))
      }
      .width(44)
      .height(44)
      .justifyContent(FlexAlign.Center)
      .onClick(() => {
        if (!DateUtil.isCurrentMonth(this.currentMonth)) {
          this.onSwitch(-1)
        }
      })
    }
    .width('90%')
    .height(44)
    .backgroundColor($r('app.color.color_surface'))
    .borderRadius(22)
    .border({ width: 2, color: '#1A202C' }) // Neobrutalism 风格粗边框
    .shadow({ radius: 0, color: '#1A202C', offsetX: 4, offsetY: 4 }) // Neo-brutalism 偏移阴影
    .margin({ top: 12, bottom: 12 })
  }
}
