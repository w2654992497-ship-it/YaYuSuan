@Component
export struct SettingsAboutPage {
  @Prop sbHeight: number
  onBack: () => void = (): void => {}
  onCheckVersion: () => void = (): void => {}

  @Builder
  Header() {
    Row() {
      Image($rawfile('icon_chevron_left.svg'))
        .width(26)
        .height(26)
        .fillColor($r('app.color.color_text_primary'))
        .onClick(this.onBack)
      Text('关于小金鱼记账')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.color_text_primary'))
        .layoutWeight(1)
        .textAlign(TextAlign.Center)
      Blank().width(26).height(26)
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: this.sbHeight + 8, bottom: 9 })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  ActionCard() {
    Column() {
      Text('应用说明')
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.color_text_primary'))
        .width('100%')
      Text('小金鱼记账专注本地记账、分类管理、预算提醒、日历回顾、统计分析和周期账单。')
        .fontSize(13)
        .fontColor($r('app.color.color_text_secondary'))
        .lineHeight(20)
        .width('100%')
        .margin({ top: 6, bottom: 14 })
      Button('检查版本信息')
        .width('100%')
        .height(42)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.color_white'))
        .backgroundColor($r('app.color.color_primary'))
        .borderRadius(21)
        .onClick(this.onCheckVersion)
    }
    .width('calc(100% - 32vp)')
    .padding(16)
    .backgroundColor($r('app.color.color_surface'))
    .borderRadius(18)
    .shadow({ radius: 8, color: $r('app.color.color_shadow_blue_08'), offsetY: 3 })
    .margin({ left: 16, right: 16, bottom: 12 })
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Column() {
      this.Header()
      Scroll() {
        Column() {
          Column() {
            Image($rawfile('illustration_fish_bowl.png'))
              .width(120)
              .height(90)
              .objectFit(ImageFit.Contain)
            Text('小金鱼记账')
              .fontSize(24)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.color_text_primary'))
              .margin({ top: 8 })
            Text('版本 1.0.0')
              .fontSize(14)
              .fontColor($r('app.color.color_text_secondary'))
              .margin({ top: 6 })
          }
          .width('calc(100% - 32vp)')
          .padding({ top: 24, bottom: 24 })
          .backgroundColor($r('app.color.color_surface'))
          .borderRadius(18)
          .shadow({ radius: 8, color: $r('app.color.color_shadow_blue_08'), offsetY: 3 })
          .margin({ left: 16, right: 16, bottom: 12 })
          .alignItems(HorizontalAlign.Center)

          this.ActionCard()
        }
        .width('100%')
        .constraintSize({ minHeight: '100%' })
        .padding({ bottom: 24 })
        .alignItems(HorizontalAlign.Center)
        .justifyContent(FlexAlign.Start)
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
  }
}
