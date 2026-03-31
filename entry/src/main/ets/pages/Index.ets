import { BillListPage } from './BillList'
import { AddBillPage } from './AddBill'
import { StatisticsPage } from './Statistics'

interface TabItem {
  icon: string
  label: string
  index: number
}

@Entry
@Component
struct Index {
  @Provide activeTabIndex: number = 0
  @State currentTabIndex: number = 0

  private tabs: TabItem[] = [
    { icon: 'icon_tab_bills', label: '账单',  index: 0 },
    { icon: 'icon_tab_add',   label: '记账',  index: 1 },
    { icon: 'icon_tab_stats', label: '统计',  index: 2 }
  ]

  @Builder
  TabBarItem(item: TabItem) {
    Column() {
      // 顶部激活指示线
      Row()
        .width(28)
        .height(3)
        .borderRadius(1.5)
        .backgroundColor(
          this.currentTabIndex === item.index ? '#1976D2' : Color.Transparent
        )
        .margin({ bottom: 7 })
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
        .margin({ top: 4 })
        .animation({ duration: 200, curve: Curve.EaseOut })
    }
    .alignItems(HorizontalAlign.Center)
    .padding({ bottom: 8 })
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
    }
    .onChange((index: number) => {
      this.currentTabIndex = index
      this.activeTabIndex = index
    })
    .barHeight(62)
    .barBackgroundColor('#FFFFFF')
    .divider({ strokeWidth: 0.5, color: '#E0E0E0' })
  }
}
