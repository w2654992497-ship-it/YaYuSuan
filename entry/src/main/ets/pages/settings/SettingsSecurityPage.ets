@Component
export struct SettingsSecurityPage {
  @Prop sbHeight: number
  securityAppLock: boolean = false
  securityAutoLock: boolean = false
  onBack: () => void = (): void => {}
  onToggleAppLock: () => void = (): void => {}
  onToggleAutoLock: () => void = (): void => {}
  onSave: () => void = (): void => {}

  @Builder
  Header() {
    Stack({ alignContent: Alignment.TopEnd }) {
      Row() {
        Image($rawfile('icon_chevron_left.svg'))
          .width(26)
          .height(26)
          .fillColor($r('app.color.color_text_primary'))
          .onClick(this.onBack)
        Text('安全与密码')
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
      Text('实现说明')
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.color_text_primary'))
        .width('100%')
      Text('真正的密码解锁需要系统认证或本地密码页配合生命周期拦截，已排为下一批高优先级开发项。')
        .fontSize(13)
        .fontColor($r('app.color.color_text_secondary'))
        .lineHeight(20)
        .width('100%')
        .margin({ top: 6, bottom: 14 })
      Button('保存安全偏好')
        .width('100%')
        .height(42)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.color_white'))
        .backgroundColor($r('app.color.color_primary'))
        .borderRadius(21)
        .onClick(this.onSave)
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
            this.SettingToggleRow('启用应用锁偏好', '保存安全偏好，后续接入系统认证或数字密码。', this.securityAppLock, this.onToggleAppLock)
            Divider().color($r('app.color.color_divider')).margin({ left: 16, right: 16 })
            this.SettingToggleRow('返回前台自动锁定', '离开应用后再次打开时按安全偏好处理。', this.securityAutoLock, this.onToggleAutoLock)
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
