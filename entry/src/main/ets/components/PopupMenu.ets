export interface PopupMenuItem {
  text: string
  color?: string        // 默认白色，危险操作传 '#FF5252'
  onClick: () => void
}

/**
 * 深色弹出菜单（绑定到 bindPopup 的 @Builder 函数）
 *
 * 用法：
 *   @State showMenu: boolean = false
 *
 *   Image($rawfile('icon_more.svg'))
 *     .bindPopup(this.showMenu, {
 *       builder: this.MenuBuilder,
 *       placement: Placement.BottomRight,
 *       onStateChange: (e) => { this.showMenu = e.isVisible }
 *     })
 *     .onClick(() => { this.showMenu = true })
 *
 *   @Builder MenuBuilder() {
 *     PopupMenuContent({
 *       items: [
 *         { text: '支出分布', onClick: () => { this.chartType = 'pie'; this.showMenu = false } },
 *         { text: '收支趋势', onClick: () => { this.chartType = 'bar'; this.showMenu = false } }
 *       ]
 *     })
 *   }
 */
@Component
export struct PopupMenuContent {
  @Prop items: PopupMenuItem[] = []

  build() {
    Column() {
      ForEach(this.items, (item: PopupMenuItem, index: number) => {
        Text(item.text)
          .width(120)
          .height(44)
          .fontSize(14)
          .fontColor(item.color ?? '#FFFFFF')
          .textAlign(TextAlign.Center)
          .onClick(() => { item.onClick() })

        if (index < this.items.length - 1) {
          Divider()
            .color('#55FFFFFF')
            .margin({ left: 12, right: 12 })
        }
      }, (item: PopupMenuItem, index: number) => item.text + index)
    }
    .backgroundColor('#2C2C2C')
    .borderRadius(8)
    .clip(true)
  }
}
