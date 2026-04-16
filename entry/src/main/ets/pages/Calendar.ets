import { DateUtil } from '../utils/DateUtil'
import { BillDao } from '../database/BillDao'
import { CalendarView } from '../components/CalendarView'
import { MonthSelector } from '../components/MonthSelector'

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
      MonthSelector({
        currentMonth: this.currentMonth,
        onSwitch: (dir) => { this.doMonthSwitch(dir) },
        onMonthSelect: (m) => { this.currentMonth = m }
      })

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
