import { DateUtil } from '../utils/DateUtil'
import { BillDao } from '../database/BillDao'
import { CalendarView } from '../components/CalendarView'

@Component
export struct CalendarPage {
  @Watch('onTabChanged')
  @Consume activeTabIndex: number
  @State currentMonth: string = DateUtil.currentMonth()
  @State slideOffsetX: number = 0
  @State refreshKey: number = 0

  onTabChanged(): void {
    if (this.activeTabIndex === 1) {
      this.refreshKey++
    }
  }

  private doMonthSwitch(direction: number): void {
    if (direction < 0 && DateUtil.isCurrentMonth(this.currentMonth)) {
      this.getUIContext().animateTo({ duration: 150, curve: Curve.EaseOut }, () => {
        this.slideOffsetX = 0
      })
      return
    }
    const next = direction > 0
      ? DateUtil.getPrevMonth(this.currentMonth)
      : DateUtil.getNextMonth(this.currentMonth)
    const exitX = direction > 0 ? 360 : -360

    this.getUIContext().animateTo({
      duration: 150,
      curve: Curve.EaseIn,
      onFinish: () => {
        this.slideOffsetX = exitX * -1
        this.currentMonth = next
        this.getUIContext().animateTo({ duration: 200, curve: Curve.EaseOut }, () => {
          this.slideOffsetX = 0
        })
      }
    }, () => {
      this.slideOffsetX = exitX
    })
  }

  private async deleteBill(id: number): Promise<void> {
    await BillDao.getInstance().deleteById(id)
    this.refreshKey++
  }

  build() {
    Column() {
      // 月份导航
      Row() {
        Image($rawfile('icon_chevron_left.svg'))
          .width(24).height(24)
          .fillColor($r('app.color.color_primary'))
          .padding(4)
          .onClick(() => { this.doMonthSwitch(1) })

        Text(DateUtil.formatMonthDisplay(this.currentMonth))
          .fontSize(16).fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.color_text_primary'))
          .margin({ left: 16, right: 16 })
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
                this.currentMonth = `${y}-${m}`
              }
            })
          })

        Image($rawfile('icon_chevron_right.svg'))
          .width(24).height(24)
          .fillColor(DateUtil.isCurrentMonth(this.currentMonth) ? $r('app.color.color_divider') : $r('app.color.color_primary'))
          .padding(4)
          .onClick(() => {
            if (!DateUtil.isCurrentMonth(this.currentMonth)) {
              this.doMonthSwitch(-1)
            }
          })
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .padding({ top: 12, bottom: 8 })

      // 日历视图
      Column() {
        CalendarView({
          currentMonth: this.currentMonth,
          refreshKey: this.refreshKey,
          onDeleteBill: (id: number) => { this.deleteBill(id) }
        })
      }
      .layoutWeight(1)
      .clip(true)
      .translate({ x: this.slideOffsetX })
      .gesture(
        PanGesture({ direction: PanDirection.Horizontal, distance: 5 })
          .onActionUpdate((event: GestureEvent) => {
            if (event) { this.slideOffsetX = event.offsetX }
          })
          .onActionEnd((event: GestureEvent) => {
            if (!event) { this.slideOffsetX = 0; return }
            if (event.offsetX > 80) { this.doMonthSwitch(1) }
            else if (event.offsetX < -80) { this.doMonthSwitch(-1) }
            else {
              this.getUIContext().animateTo(
                { duration: 150, curve: Curve.EaseOut },
                () => { this.slideOffsetX = 0 }
              )
            }
          })
      )
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.color_bg'))
  }
}
