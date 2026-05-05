@Component
export struct SettingsPrivacyPage {
  @Prop sbHeight: number
  privacyHideAmount: boolean = false
  privacyLocalOnly: boolean = true
  onBack: () => void = (): void => {}
  onToggleHideAmount: () => void = (): void => {}
  onToggleLocalOnly: () => void = (): void => {}
  onConfirm: () => void = (): void => {}

  @Builder
  Header() {
    Stack({ alignContent: Alignment.TopEnd }) {
      Row() {
        Image($rawfile('icon_chevron_left.svg'))
          .width(26)
          .height(26)
          .fillColor($r('app.color.color_text_primary'))
          .onClick(this.onBack)
        Text('隐私设置')
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

      Image($rawfile('illustration_fish_bowl.png'))
        .width(86)
        .height(66)
        .opacity(0.9)
        .margin({ top: this.sbHeight + 2, right: 8 })
        .hitTestBehavior(HitTestMode.None)
    }
    .width('100%')
    .margin({ bottom: 2 })
  }

  @Builder
  SwitchPill(enabled: boolean) {
    Row() {
      Circle()
        .width(16)
        .height(16)
        .fill($r('app.color.color_white'))
        .margin({ left: 2, right: 2 })
    }
    .width(36)
    .height(20)
    .borderRadius(10)
    .backgroundColor(enabled ? $r('app.color.color_primary') : $r('app.color.color_track'))
    .justifyContent(enabled ? FlexAlign.End : FlexAlign.Start)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  SettingToggleRow(title: string, desc: string, enabled: boolean, onTap: () => void) {
    Row() {
      Column() {
        Text(title)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.color_text_primary'))
        Text(desc)
          .fontSize(12)
          .fontColor($r('app.color.color_text_secondary'))
          .margin({ top: 4 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      this.SwitchPill(enabled)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .alignItems(VerticalAlign.Center)
    .onClick(onTap)
  }

  @Builder
  ActionCard() {
    Column() {
      Text('隐私说明')
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.color_text_primary'))
        .width('100%')
      Text('小金鱼记账当前核心数据保存在本地数据库；导出备份或 CSV 时，文件保存位置由系统文件选择器决定。')
        .fontSize(13)
        .fontColor($r('app.color.color_text_secondary'))
        .lineHeight(20)
        .width('100%')
        .margin({ top: 6, bottom: 14 })
      Button('我知道了')
        .width('100%')
        .height(42)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.color_white'))
        .backgroundColor($r('app.color.color_primary'))
        .borderRadius(21)
        .onClick(this.onConfirm)
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
            this.SettingToggleRow('隐藏金额偏好', '保存你的隐私偏好，后续金额组件统一接入该开关。', this.privacyHideAmount, this.onToggleHideAmount)
            Divider().color($r('app.color.color_divider')).margin({ left: 16, right: 16 })
            this.SettingToggleRow('仅本机处理数据', '记账数据默认保存在本机，不主动上传到外部服务。', this.privacyLocalOnly, this.onToggleLocalOnly)
          }
          .width('calc(100% - 32vp)')
          .backgroundColor($r('app.color.color_surface'))
          .borderRadius(18)
          .clip(true)
          .shadow({ radius: 8, color: $r('app.color.color_shadow_blue_08'), offsetY: 3 })
          .margin({ left: 16, right: 16, bottom: 12 })

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
