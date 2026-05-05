import { DateUtil } from '../utils/DateUtil'
import { CalendarView } from '../components/CalendarView'
import { MonthSelector } from '../components/MonthSelector'
import { WaterPageBg } from '../components/WaterPageBg'
import { AppDataApi } from '../services/AppDataApi'

@Component
export struct CalendarPage {
  @Consume('appNavStack') navStack: NavPathStack
  @StorageProp('statusBarHeight') sbHeight: number = 0
  @Watch('onTabChanged')
  @Consume activeTabIndex: number
  @State currentMonth: string = DateUtil.currentMonth()
  @State slideOffsetX: number = 0
  @State refreshKey: number = 0
  @State todaySignal: number = 0

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
    const next = direction > 0 ? DateUtil.getPrevMonth(this.currentMonth) : DateUtil.getNextMonth(this.currentMonth)
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

  private goToday(): void {
    this.currentMonth = DateUtil.currentMonth()
    this.todaySignal++
    this.refreshKey++
  }

  private async deleteBill(id: number): Promise<void> {
    const hostContext = this.getUIContext().getHostContext()
    await AppDataApi.getInstance().deleteBill(id, hostContext ? hostContext : null, true)
    this.refreshKey++
  }

  private openSearch(): void {
    this.navStack.pushPathByName('billSearch', null)
  }

  @Builder
  Header() {
    Stack({ alignContent: Alignment.TopEnd }) {
      Image($rawfile('illustration_fish_bowl.png'))
        .width(96)
        .height(58)
        .objectFit(ImageFit.Contain)
        .opacity(0.82)
        .margin({ top: this.sbHeight, right: 44 })
        .hitTestBehavior(HitTestMode.None)

      Row() {
        Text('日历')
          .fontSize(25)
          .fontWeight(FontWeight.Bolder)
          .fontColor($r('app.color.color_text_deep'))

        Blank()

        Row() {
          Image($rawfile('icon_search.svg'))
            .width(22)
            .height(22)
            .fillColor($r('app.color.color_text_deep'))
        }
        .width(44)
        .height(44)
        .borderRadius(22)
        .backgroundColor($r('app.color.color_card_overlay'))
        .border({ width: 1, color: $r('app.color.color_divider') })
        .shadow({ radius: 12, color: $r('app.color.color_shadow_blue_09'), offsetX: 0, offsetY: 6 })
        .justifyContent(FlexAlign.Center)
        .onClick(() => {
          this.openSearch()
        })
      }
      .width('100%')
      .padding({ left: 22, right: 22, top: this.sbHeight + 2 })
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .height(this.sbHeight + 58)
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      WaterPageBg()

      Column() {
        this.Header()

        MonthSelector({
          currentMonth: this.currentMonth,
          onSwitch: (dir: number) => {
            this.doMonthSwitch(dir)
          },
          onMonthSelect: (month: string) => {
            this.currentMonth = month
            this.refreshKey++
          },
          onToday: () => {
            this.goToday()
          }
        })

        Column() {
          CalendarView({
            currentMonth: this.currentMonth,
            refreshKey: this.refreshKey,
            todaySignal: this.todaySignal,
            onDeleteBill: (id: number) => {
              this.deleteBill(id)
            }
          })
        }
        .layoutWeight(1)
        .clip(true)
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
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Start)
      .alignItems(HorizontalAlign.Center)
      .backgroundColor(Color.Transparent)

    }
    .width('100%')
    .height('100%')
  }
}
