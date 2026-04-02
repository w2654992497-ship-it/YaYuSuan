/**
 * 通用导航栏组件，自动适配沉浸式状态栏安全区域。
 *
 * 用法示例（月份导航）：
 *   NavBar({
 *     title: '2026年3月',
 *     leftText: '‹',
 *     rightText: '›',
 *     rightEnabled: false,
 *     onLeftClick: () => { ... },
 *     onRightClick: () => { ... }
 *   })
 */
@Component
export struct NavBar {
  // 状态栏安全区域高度（px），由 EntryAbility 写入 AppStorage
  @StorageProp('statusBarHeight') sbHeight: number = 0

  @Prop title: string = ''
  @Prop leftText: string = ''
  leftIcon?: Resource
  onLeftClick?: () => void
  @Prop showLeft: boolean = true
  @Prop rightText: string = ''
  rightIcon?: Resource
  onRightClick?: () => void
  onTitleClick?: () => void
  // 额外右侧图标（如视图切换）
  extraRightIcon?: string       // rawfile 图标名（不含 .svg）
  onExtraRightClick?: () => void
  @Prop rightEnabled: boolean = true
  @Prop bgColor: string = '#FFFFFF'
  @Prop titleColor: string = '#212121'
  @Prop accentColor: string = '#1976D2'
  @Prop showDivider: boolean = true
  @Prop navHeight: number = 48

  build() {
    Column() {
      // 状态栏占位（背景色延伸进状态栏区域）
      Row()
        .width('100%')
        .height(this.sbHeight)

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
                .fontSize(22)
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
          .decoration(this.onTitleClick ? { type: TextDecorationType.Underline, color: '#E0E0E0' } : { type: TextDecorationType.None })
          .onClick(() => { this.onTitleClick?.() })

        // 右侧按钮
        Row() {
          if (this.rightIcon !== undefined) {
            Image(this.rightIcon)
              .width(20).height(20)
              .fillColor(this.rightEnabled ? this.accentColor : '#757575')
          } else if (this.rightText.length > 0) {
            Text(this.rightText)
              .fontSize(22)
              .fontColor(this.rightEnabled ? this.accentColor : '#757575')
              .fontWeight(FontWeight.Medium)
          }
        }
        .width(40)
        .height(this.navHeight)
        .justifyContent(FlexAlign.Center)
        .onClick(() => {
          if (this.rightEnabled) {
            this.onRightClick?.()
          }
        })

        // 额外右侧图标
        if (this.extraRightIcon !== undefined && this.extraRightIcon!.length > 0) {
          Row() {
            Image($rawfile(this.extraRightIcon! + '.svg'))
              .width(20)
              .height(20)
              .fillColor(this.accentColor)
          }
          .width(40)
          .height(this.navHeight)
          .justifyContent(FlexAlign.Center)
          .onClick(() => { this.onExtraRightClick?.() })
        }
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
