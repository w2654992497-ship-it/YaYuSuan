/**
 * 通用导航栏组件
 *
 * 用法示例（月份导航）：
 *   NavBar({
 *     title: '2026年3月',
 *     leftText: '<',
 *     rightText: '>',
 *     rightEnabled: false,
 *     onLeftClick: () => { ... },
 *     onRightClick: () => { ... }
 *   })
 *
 * 用法示例（页面标题）：
 *   NavBar({ title: '记账' })
 */
@Component
export struct NavBar {
  @Prop title: string = ''
  // 左侧：文字 或 图标（二选一）
  @Prop leftText: string = ''
  leftIcon?: Resource
  onLeftClick?: () => void
  @Prop showLeft: boolean = true
  // 右侧：文字 或 图标（二选一）
  @Prop rightText: string = ''
  rightIcon?: Resource
  onRightClick?: () => void
  @Prop rightEnabled: boolean = true
  // 样式
  @Prop bgColor: string = '#FFFFFF'
  @Prop titleColor: string = '#212121'
  @Prop accentColor: string = '#1976D2'
  @Prop showDivider: boolean = true
  @Prop navHeight: number = 48

  build() {
    Column() {
      Row() {
        // 左侧按钮
        if (this.showLeft) {
          Row() {
            if (this.leftIcon !== undefined) {
              Image(this.leftIcon)
                .width(20).height(20)
                .fillColor(this.accentColor)
            } else if (this.leftText.length > 0) {
              Text(this.leftText)
                .fontSize(18)
                .fontColor(this.accentColor)
                .fontWeight(FontWeight.Medium)
            }
          }
          .width(48)
          .height(this.navHeight)
          .justifyContent(FlexAlign.Center)
          .onClick(() => { this.onLeftClick?.() })
        } else {
          Row().width(48)
        }

        // 中间标题
        Text(this.title)
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.titleColor)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        // 右侧按钮
        Row() {
          if (this.rightIcon !== undefined) {
            Image(this.rightIcon)
              .width(20).height(20)
              .fillColor(this.rightEnabled ? this.accentColor : '#757575')
          } else if (this.rightText.length > 0) {
            Text(this.rightText)
              .fontSize(18)
              .fontColor(this.rightEnabled ? this.accentColor : '#757575')
              .fontWeight(FontWeight.Medium)
          }
        }
        .width(48)
        .height(this.navHeight)
        .justifyContent(FlexAlign.Center)
        .onClick(() => {
          if (this.rightEnabled) {
            this.onRightClick?.()
          }
        })
      }
      .width('100%')
      .height(this.navHeight)
      .backgroundColor(this.bgColor)
      .padding({ left: 4, right: 4 })

      if (this.showDivider) {
        Divider()
          .color('#E0E0E0')
      }
    }
    .width('100%')
    .backgroundColor(this.bgColor)
  }
}
