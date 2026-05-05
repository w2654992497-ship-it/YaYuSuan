@Component
export struct SettingsGeneralPage {
  @Prop sbHeight: number
  themeModeLabel: string = ''
  notificationEnabled: boolean = true
  onBack: () => void = (): void => {}
  onOpenTheme: () => void = (): void => {}
  onOpenSecurity: () => void = (): void => {}
  onOpenPrivacy: () => void = (): void => {}
  onToggleNotification: () => void = (): void => {}
  onClearCache: () => void = (): void => {}
  onOpenFeedback: () => void = (): void => {}
  onOpenAbout: () => void = (): void => {}
  onReminder: () => void = (): void => {}
  onWeekStart: () => void = (): void => {}

  @Builder
  Header() {
    Stack({ alignContent: Alignment.TopEnd }) {
      Row() {
        Image($rawfile('icon_chevron_left.svg'))
          .width(26)
          .height(26)
          .fillColor($r('app.color.color_text_primary'))
          .onClick(this.onBack)
        Text('通用设置')
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
  SectionTitle(title: string) {
    Text(title)
      .fontSize(15)
      .fontWeight(FontWeight.Bold)
      .fontColor($r('app.color.color_text_primary'))
      .width('100%')
      .padding({ left: 16, right: 16, top: 14, bottom: 2 })
  }

  @Builder
  MenuRow(icon: ResourceStr, iconBg: ResourceColor, iconColor: ResourceColor, title: string, desc: string, onTap: () => void) {
    Row() {
      Column() {
        Image(icon)
          .width(20)
          .height(20)
          .fillColor(iconColor)
      }
      .width(38)
      .height(38)
      .borderRadius(19)
      .backgroundColor(iconBg)
      .alignItems(HorizontalAlign.Center)
      .justifyContent(FlexAlign.Center)
      .margin({ right: 12 })

      Column() {
        Text(title)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.color_text_primary'))
        Text(desc)
          .fontSize(12)
          .fontColor($r('app.color.color_text_secondary'))
          .margin({ top: 3 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Image($rawfile('icon_chevron_right.svg'))
        .width(16)
        .height(16)
        .fillColor($r('app.color.color_text_muted'))
    }
    .width('100%')
    .height(62)
    .padding({ left: 16, right: 12 })
    .alignItems(VerticalAlign.Center)
    .onClick(onTap)
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
  NotificationRow() {
    Row() {
      Column() {
        Image($rawfile('icon_baby.svg'))
          .width(20)
          .height(20)
          .fillColor($r('app.color.color_primary'))
      }
      .width(38)
      .height(38)
      .borderRadius(19)
      .backgroundColor($r('app.color.color_soft_blue'))
      .alignItems(HorizontalAlign.Center)
      .justifyContent(FlexAlign.Center)
      .margin({ right: 12 })

      Column() {
        Text('通知权限')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.color_text_primary'))
        Text(this.notificationEnabled ? '已开启' : '已关闭')
          .fontSize(12)
          .fontColor($r('app.color.color_text_secondary'))
          .margin({ top: 3 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      this.SwitchPill(this.notificationEnabled)
    }
    .width('100%')
    .height(62)
    .padding({ left: 16, right: 12 })
    .alignItems(VerticalAlign.Center)
    .onClick(this.onToggleNotification)
  }

  @Builder
  Section(content: string) {
    Column() {
      if (content === 'appearance') {
        this.SectionTitle('外观与提醒')
        this.MenuRow($rawfile('icon_tab_stats.svg'), '#EEF3FF', $r('app.color.color_primary_dark'), '主题模式', this.themeModeLabel, this.onOpenTheme)
        Divider().color($r('app.color.color_divider')).margin({ left: 66, right: 16 })
        this.MenuRow($rawfile('icon_baby.svg'), '#FFF4E4', $r('app.color.color_accent'), '记账提醒', '每日 20:00', this.onReminder)
        Divider().color($r('app.color.color_divider')).margin({ left: 66, right: 16 })
        this.MenuRow($rawfile('icon_calendar.svg'), '#E4F7F6', $r('app.color.color_primary'), '日历周起始日', '周一', this.onWeekStart)
      } else if (content === 'security') {
        this.SectionTitle('安全与隐私')
        this.MenuRow($rawfile('icon_insurance.svg'), '#EEF3FF', $r('app.color.color_primary'), '安全与密码', '设置解锁密码', this.onOpenSecurity)
        Divider().color($r('app.color.color_divider')).margin({ left: 66, right: 16 })
        this.MenuRow($rawfile('icon_phone.svg'), '#F1EDFF', $r('app.color.color_purple'), '隐私设置', '数据权限与隐私说明', this.onOpenPrivacy)
        Divider().color($r('app.color.color_divider')).margin({ left: 66, right: 16 })
        this.NotificationRow()
      } else {
        this.SectionTitle('应用与支持')
        this.MenuRow($rawfile('icon_other.svg'), '#E4F7F6', $r('app.color.color_primary'), '清理缓存', '当前 12.6 MB', this.onClearCache)
        Divider().color($r('app.color.color_divider')).margin({ left: 66, right: 16 })
        this.MenuRow($rawfile('icon_list.svg'), '#EEF3FF', $r('app.color.color_primary_light'), '意见反馈', '告诉我们你的想法', this.onOpenFeedback)
        Divider().color($r('app.color.color_divider')).margin({ left: 66, right: 16 })
        this.MenuRow($rawfile('icon_search.svg'), '#EEF3FF', $r('app.color.color_primary'), '关于小金鱼记账', '版本 1.0.0', this.onOpenAbout)
      }
    }
    .width('calc(100% - 32vp)')
    .backgroundColor($r('app.color.color_card_overlay'))
    .borderRadius(18)
    .border({ width: 1, color: $r('app.color.color_divider') })
    .clip(true)
    .shadow({ radius: 9, color: $r('app.color.color_shadow_blue_08'), offsetY: 3 })
    .margin({ left: 16, right: 16, bottom: content === 'support' ? 14 : 10 })
  }

  build() {
    Column() {
      this.Header()
      Scroll() {
        Column() {
          this.Section('appearance')
          this.Section('security')
          this.Section('support')
          Text('让记账更轻松')
            .fontSize(12)
            .fontColor($r('app.color.color_text_muted'))
            .margin({ bottom: 14 })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
  }
}
