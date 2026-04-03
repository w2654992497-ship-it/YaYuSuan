import { BillListPage } from './BillList'
import { CalendarPage } from './Calendar'
import { AddBillPage } from './AddBill'
import { StatisticsPage } from './Statistics'
import { SettingsPage } from './Settings'
import { CategoryEditor } from '../components/CategoryEditor'
import { window } from '@kit.ArkUI'
import { LogUtils } from '../utils/LogUtils'

class BottomTabModel {
  title: string
  selectImage: ResourceStr
  defaultImage: ResourceStr
  middleMode: boolean

  constructor(title: string, selectImage: ResourceStr, defaultImage: ResourceStr, middleMode: boolean) {
    this.title = title
    this.selectImage = selectImage
    this.defaultImage = defaultImage
    this.middleMode = middleMode
  }
}

@Entry
@Component
struct Index {
  @Watch('onActiveTabChanged')
  @Provide activeTabIndex: number = 0
  @State currentTabIndex: number = 0
  @StorageProp('navBarHeight') nbHeight: number = 0
  @StorageProp('statusBarHeight') sbHeight: number = 0
  @StorageLink('showCategoryEditor') showCategoryEditor: boolean = false

  private tabController: TabsController = new TabsController()
  private tabArray: BottomTabModel[] = [
    new BottomTabModel('账单', $rawfile('icon_tab_bills.svg'), $rawfile('icon_tab_bills.svg'), false),
    new BottomTabModel('日历', $rawfile('icon_calendar.svg'), $rawfile('icon_calendar.svg'), false),
    new BottomTabModel('记账', $rawfile('icon_tab_add.svg'), $rawfile('icon_tab_add.svg'), true),
    new BottomTabModel('统计', $rawfile('icon_tab_stats.svg'), $rawfile('icon_tab_stats.svg'), false),
    new BottomTabModel('设置', $rawfile('icon_tab_settings.svg'), $rawfile('icon_tab_settings.svg'), false)
  ]

  onActiveTabChanged(): void {
    this.currentTabIndex = this.activeTabIndex
    this.tabController.changeIndex(this.activeTabIndex)
    this.updateStatusBar(this.activeTabIndex)
  }

  private updateStatusBar(index: number): void {
    const win = AppStorage.get<window.Window>('mainWindow')
    if (!win) return
    win.setWindowSystemBarProperties({
      statusBarContentColor: index === 2 ? '#FFFFFF' : '#1A202C' // 沉浸式与文字颜色匹配 (index 2 为记账)
    }).catch((e: Error) => {
      LogUtils.error('Index', 'setStatusBar failed: %{public}s', e.message)
    })
  }

  private onTabClick(index: number) {
    this.currentTabIndex = index
    this.activeTabIndex = index
    this.tabController.changeIndex(index)
    this.updateStatusBar(index)
  }

  @Builder
  Tab(item: BottomTabModel, index: number) {
    Column() {
      if (item.middleMode) { // 中间"记账"大按钮 (舵式)
        Column() {
          Circle()
            .width(52)
            .height(52)
            .fill($r('app.color.color_primary'))
            .shadow({ radius: 10, color: 'rgba(44, 122, 123, 0.4)', offsetY: 4 })

          Image(item.defaultImage)
            .width(24)
            .height(24)
            .fillColor('#FFFFFF')
            .objectFit(ImageFit.Contain)
            .position({ x: 14, y: 14 })
        }
        .width(52)
        .height(52)
        .clip(true)
        .borderRadius(26)
        .offset({ y: -15 })
        .scale(this.currentTabIndex === index ? { x: 1.1, y: 1.1 } : { x: 1, y: 1 })
        .animation({ duration: 300, curve: Curve.Friction })

        Text(item.title)
          .fontSize(10)
          .margin({ top: -10 })
          .fontColor(this.currentTabIndex === index ? $r('app.color.color_primary') : $r('app.color.color_tab_inactive'))
          .animation({ duration: 300, curve: Curve.Ease })
      } else { // 常规侧边按钮
        Image(item.defaultImage)
          .width(24)
          .height(24)
          .fillColor(this.currentTabIndex === index ? $r('app.color.color_primary') : $r('app.color.color_tab_inactive'))
          .offset({ y: this.currentTabIndex === index ? -4 : 0 })
          .scale(this.currentTabIndex === index ? { x: 1.1, y: 1.1 } : { x: 1, y: 1 })
          .animation({ duration: 300, curve: Curve.Ease })

        Text(item.title)
          .fontSize(10)
          .margin({ top: 4 })
          .fontColor(this.currentTabIndex === index ? $r('app.color.color_primary') : $r('app.color.color_tab_inactive'))
          .animation({ duration: 300, curve: Curve.Ease })
      }
    }
    .layoutWeight(item.middleMode ? 1.2 : 1)
    .height('100%')
    .padding({ top: item.middleMode ? 0 : 12 })
    .alignItems(HorizontalAlign.Center)
    .onClick(() => this.onTabClick(index))
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Tabs({ barPosition: BarPosition.End, controller: this.tabController, index: this.currentTabIndex }) {
        ForEach(this.tabArray, (item: BottomTabModel, index: number) => {
          if (index === 0) {
            TabContent() { BillListPage().padding({ top: this.sbHeight }) }.backgroundColor($r('app.color.start_window_background'))
          } else if (index === 1) {
            TabContent() { CalendarPage().padding({ top: this.sbHeight }) }.backgroundColor($r('app.color.start_window_background'))
          } else if (index === 2) {
            TabContent() { AddBillPage() }.backgroundColor($r('app.color.start_window_background'))
          } else if (index === 3) {
            TabContent() { StatisticsPage().padding({ top: this.sbHeight }) }.backgroundColor($r('app.color.start_window_background'))
          } else if (index === 4) {
            TabContent() { SettingsPage().padding({ top: this.sbHeight }) }.backgroundColor($r('app.color.start_window_background'))
          }
        }, (item: BottomTabModel, index: number) => JSON.stringify(item) + index)
      }
      .barHeight(0) // 完全隐藏自带的TabBar
      .scrollable(false)
      .onChange((index: number) => this.onTabClick(index))
      .padding({ bottom: 64 + this.nbHeight })

      // 舵式导航条自定义布局
      Flex({ justifyContent: FlexAlign.SpaceAround, alignItems: ItemAlign.Center }) {
        ForEach(this.tabArray, (item: BottomTabModel, index: number) => {
          this.Tab(item, index)
        }, (item: BottomTabModel, index: number) => JSON.stringify(item) + index)
      }
      .width('100%')
      .height(64 + this.nbHeight)
      .padding({ bottom: this.nbHeight })
      .backgroundColor($r('app.color.color_surface'))
      .border({ width: { top: 0.5 }, color: 'rgba(0,0,0,0.05)' })
      .shadow({ radius: 12, color: 'rgba(0,0,0,0.04)', offsetY: -4 })

      // 全屏分类编辑（覆盖在 Tab + 导航栏之上）
      if (this.showCategoryEditor) {
        CategoryEditor({
          onClose: () => {
            this.getUIContext().animateTo({ duration: 250, curve: Curve.EaseIn }, () => {
              this.showCategoryEditor = false
            })
          }
        })
        .transition(
          TransitionEffect.asymmetric(
            TransitionEffect.OPACITY.combine(TransitionEffect.translate({ y: 800 }))
              .animation({ duration: 300, curve: Curve.EaseOut }),
            TransitionEffect.OPACITY.combine(TransitionEffect.translate({ y: 800 }))
              .animation({ duration: 250, curve: Curve.EaseIn })
          )
        )
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.start_window_background'))
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}