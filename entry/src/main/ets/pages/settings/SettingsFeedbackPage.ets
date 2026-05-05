@Component
export struct SettingsFeedbackPage {
  @Prop sbHeight: number
  feedbackText: string = ''
  onBack: () => void = (): void => {}
  onChangeText: (value: string) => void = (value: string): void => {}
  onSubmit: () => void = (): void => {}
  onRoadmap: () => void = (): void => {}

  @Builder
  Header() {
    Row() {
      Image($rawfile('icon_chevron_left.svg'))
        .width(26)
        .height(26)
        .fillColor($r('app.color.color_text_primary'))
        .onClick(this.onBack)
      Text('意见反馈')
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
      Text('反馈状态')
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.color_text_primary'))
        .width('100%')
      Text('当前版本先在本机完成反馈记录确认；接入服务端后会支持附带日志和设备信息。')
        .fontSize(13)
        .fontColor($r('app.color.color_text_secondary'))
        .lineHeight(20)
        .width('100%')
        .margin({ top: 6, bottom: 14 })
      Button('查看排期')
        .width('100%')
        .height(42)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.color_white'))
        .backgroundColor($r('app.color.color_primary'))
        .borderRadius(21)
        .onClick(this.onRoadmap)
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
            Text('告诉我们你的想法')
              .fontSize(17)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.color_text_primary'))
              .width('100%')
              .margin({ bottom: 10 })
            TextArea({ placeholder: '例如：哪里不好用、希望新增什么功能', text: this.feedbackText })
              .width('100%')
              .height(150)
              .fontSize(14)
              .backgroundColor($r('app.color.color_bg'))
              .borderRadius(14)
              .padding(12)
              .onChange(this.onChangeText)
            Button('提交反馈')
              .width('100%')
              .height(44)
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.color_white'))
              .backgroundColor($r('app.color.color_primary'))
              .borderRadius(22)
              .margin({ top: 14 })
              .onClick(this.onSubmit)
          }
          .width('calc(100% - 32vp)')
          .padding(16)
          .backgroundColor($r('app.color.color_surface'))
          .borderRadius(18)
          .shadow({ radius: 8, color: $r('app.color.color_shadow_blue_08'), offsetY: 3 })
          .margin({ left: 16, right: 16, bottom: 12 })
          .alignItems(HorizontalAlign.Start)

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
