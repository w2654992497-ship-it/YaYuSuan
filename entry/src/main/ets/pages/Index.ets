import { BillListPage } from './BillList'
import { AddBillPage } from './AddBill'
import { StatisticsPage } from './Statistics'

@Entry
@Component
struct Index {
  @Provide activeTabIndex: number = 0
  @State currentTabIndex: number = 0

  @Builder
  TabBarItem(emoji: string, label: string, index: number) {
    Column() {
      Text(emoji)
        .fontSize(22)
      Text(label)
        .fontSize(10)
        .fontColor(this.currentTabIndex === index ? '#1976D2' : '#9E9E9E')
        .margin({ top: 2 })
    }
    .padding({ top: 6, bottom: 6 })
  }

  build() {
    Tabs({ barPosition: BarPosition.End, index: this.currentTabIndex }) {
      TabContent() {
        BillListPage()
      }
      .tabBar(this.TabBarItem('📋', '账单', 0))

      TabContent() {
        AddBillPage()
      }
      .tabBar(this.TabBarItem('➕', '记账', 1))

      TabContent() {
        StatisticsPage()
      }
      .tabBar(this.TabBarItem('📊', '统计', 2))
    }
    .onChange((index: number) => {
      this.currentTabIndex = index
      this.activeTabIndex = index
    })
    .barHeight(60)
    .barBackgroundColor('#FFFFFF')
  }
}
