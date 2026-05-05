import { DateUtil } from '../utils/DateUtil'

@Component
export struct MonthSelector {
  @Prop currentMonth: string
  onSwitch: (direction: number) => void = () => {}
  onMonthSelect: (month: string) => void = () => {}
  onToday: () => void = () => {}

  private pickMonth(): void {
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
  }

  build() {
    Row() {
      Row() {
        Image($rawfile('icon_chevron_left.svg'))
          .width(18)
          .height(18)
          .fillColor($r('app.color.color_text_deep'))
      }
      .width(38)
      .height(40)
      .justifyContent(FlexAlign.Center)
      .onClick(() => {
        this.onSwitch(1)
      })

      Divider()
        .vertical(true)
        .height(24)
        .color($r('app.color.color_divider'))

      Row({ space: 6 }) {
        Text(DateUtil.formatMonthDisplay(this.currentMonth))
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.color_text_deep'))
        Image($rawfile('icon_chevron_down.svg'))
          .width(13)
          .height(13)
          .fillColor($r('app.color.color_icon_muted'))
      }
      .layoutWeight(1)
      .height(40)
      .justifyContent(FlexAlign.Center)
      .onClick(() => {
        this.pickMonth()
      })

      Button('今日')
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.color_primary'))
        .height(32)
        .padding({ left: 14, right: 14 })
        .type(ButtonType.Normal)
        .backgroundColor($r('app.color.color_card_overlay'))
        .borderRadius(16)
        .border({ width: 1, color: $r('app.color.color_divider') })
        .onClick(() => {
          this.onToday()
        })

      Divider()
        .vertical(true)
        .height(24)
        .color($r('app.color.color_divider'))
        .margin({ left: 8 })

      Row() {
        Image($rawfile('icon_chevron_right.svg'))
          .width(18)
          .height(18)
          .fillColor(DateUtil.isCurrentMonth(this.currentMonth) ? $r('app.color.color_divider') :
            $r('app.color.color_text_deep'))
      }
      .width(38)
      .height(40)
      .justifyContent(FlexAlign.Center)
      .onClick(() => {
        if (!DateUtil.isCurrentMonth(this.currentMonth)) {
          this.onSwitch(-1)
        }
      })
    }
    .width('calc(100% - 32vp)')
    .height(46)
    .padding({ left: 6, right: 6 })
    .backgroundColor($r('app.color.color_card_overlay'))
    .borderRadius(23)
    .border({ width: 1, color: $r('app.color.color_divider') })
    .shadow({ radius: 10, color: $r('app.color.color_shadow_blue_09'), offsetX: 0, offsetY: 4 })
    .margin({ left: 16, right: 16, top: 6, bottom: 8 })
  }
}
