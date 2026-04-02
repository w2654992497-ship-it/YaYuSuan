import { BillListPage } from './BillList'
import { AddBillPage } from './AddBill'
import { StatisticsPage } from './Statistics'
import { SettingsPage } from './Settings'
import { window } from '@kit.ArkUI'
import { LogUtils } from '../utils/LogUtils'

interface TabItem {
  icon: string
  label: string
  index: number
}

@Entry
@Component
struct Index {
  @Watch('onActiveTabChanged')
  @Provide activeTabIndex: number = 0
  @State currentTabIndex: number = 0
  @StorageProp('navBarHeight') nbHeight: number = 0

  private tabs: TabItem[] = [
    { icon: 'icon_tab_bills',    label: '账单', index: 0 },
    { icon: 'icon_tab_add',      label: '记账', index: 1 },
    { icon: 'icon_tab_stats',    label: '统计', index: 2 },
    { icon: 'icon_tab_settings', label: '设置', index: 3 }
  ]

  // 当 activeTabIndex 被子组件（如 AddBillPage 记账成功后）修改时，同步视觉切换
  onActiveTabChanged(): void {
    this.currentTabIndex = this.activeTabIndex
    this.updateStatusBar(this.activeTabIndex)
  }

  // 切换状态栏图标颜色：记账页彩色顶部用白色图标，其余页用深色图标
  private updateStatusBar(index: number): void {
    const win = AppStorage.get<window.Window>('mainWindow')
    if (!win) return
    win.setWindowSystemBarProperties({
      statusBarContentColor: index === 1 ? '#FFFFFF' : '#000000'
    }).catch((e: Error) => {
      LogUtils.error('Index', 'setStatusBar failed: %{public}s', e.message)
    })
  }

  @Builder
  TabBarItem(item: TabItem) {
    Column() {
      // 顶部激活指示线
      Row()
        .width(24)
        .height(3)
        .borderRadius(1.5)
        .backgroundColor(
          this.currentTabIndex === item.index ? '#1976D2' : Color.Transparent
        )
        .margin({ bottom: 6 })
        .animation({ duration: 200, curve: Curve.EaseOut })

      // 图标
      Image($rawfile(item.icon + '.svg'))
        .width(24)
        .height(24)
        .fillColor(this.currentTabIndex === item.index ? '#1976D2' : '#757575')
        .animation({ duration: 200, curve: Curve.EaseOut })

      // 文字
      Text(item.label)
        .fontSize(10)
        .fontColor(this.currentTabIndex === item.index ? '#1976D2' : '#757575')
        .margin({ top: 3 })
        .animation({ duration: 200, curve: Curve.EaseOut })
    }
    .alignItems(HorizontalAlign.Center)
    .justifyContent(FlexAlign.Center)
    .padding({ top: 6, bottom: 8 + this.nbHeight })
    .width('100%')
  }

  build() {
    Tabs({ barPosition: BarPosition.End, index: this.currentTabIndex }) {
      TabContent() {
        BillListPage()
      }
      .tabBar(this.TabBarItem(this.tabs[0]))

      TabContent() {
        AddBillPage()
      }
      .tabBar(this.TabBarItem(this.tabs[1]))

      TabContent() {
        StatisticsPage()
      }
      .tabBar(this.TabBarItem(this.tabs[2]))

      TabContent() {
        SettingsPage()
      }
      .tabBar(this.TabBarItem(this.tabs[3]))
    }
    .onChange((index: number) => {
      this.currentTabIndex = index
      this.activeTabIndex = index
      this.updateStatusBar(index)
    })
    .barHeight(62 + this.nbHeight)
    .barBackgroundColor('#FFFFFF')
    .divider({ strokeWidth: 0.5, color: '#E0E0E0' })
    .scrollable(false)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}
