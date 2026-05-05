@Component
export struct SettingsUserDataPage {
  @Prop sbHeight: number
  @Prop currentUserName: string
  onBack: () => void = (): void => {}
  onExportBackup: () => void = (): void => {}
  onUploadCloudBackup: () => void = (): void => {}
  onClearCache: () => void = (): void => {}
  onExportCsv: () => void = (): void => {}

  @Builder
  Header() {
    Stack({ alignContent: Alignment.TopEnd }) {
      Row() {
        Image($rawfile('icon_chevron_left.svg'))
          .width(26)
          .height(26)
          .fillColor($r('app.color.color_text_primary'))
          .onClick(this.onBack)
        Text('用户数据')
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
  UserCard() {
    Row() {
      Image($rawfile('illustration_fish_bowl.png'))
        .width(46)
        .height(46)
        .borderRadius(23)
        .objectFit(ImageFit.Cover)
        .backgroundColor($r('app.color.color_soft_blue'))
        .margin({ right: 12 })
      Column() {
        Text(this.currentUserName.length > 0 ? '小金鱼用户' : '未登录用户')
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.color_text_deep'))
        Text(this.currentUserName.length > 0 ? `已登录：${this.currentUserName}` : '登录后同步用户信息')
          .fontSize(11)
          .fontColor($r('app.color.color_text_secondary'))
          .margin({ top: 4 })
        Text('本地数据已保存')
          .fontSize(11)
          .fontColor($r('app.color.color_primary'))
          .height(18)
          .padding({ left: 8, right: 8 })
          .backgroundColor($r('app.color.color_selected_bg'))
          .borderRadius(9)
          .margin({ top: 5 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('calc(100% - 32vp)')
    .height(76)
    .padding({ left: 14, right: 14 })
    .backgroundColor($r('app.color.color_card_overlay'))
    .borderRadius(16)
    .border({ width: 1, color: $r('app.color.color_divider') })
    .shadow({ radius: 8, color: $r('app.color.color_shadow_blue_08'), offsetY: 2 })
    .margin({ left: 16, right: 16, bottom: 8 })
    .alignItems(VerticalAlign.Center)
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
  DataSection() {
    Column() {
      this.SectionTitle('数据管理')
      this.MenuRow($rawfile('icon_tab_home.svg'), '#EEF3FF', $r('app.color.color_primary'), '数据备份', '导出账单、分类、预算与周期记账', this.onExportBackup)
      Divider().color($r('app.color.color_divider')).margin({ left: 66, right: 16 })
      this.MenuRow($rawfile('icon_phone.svg'), '#E4F7F6', $r('app.color.color_primary'), '云端备份', '上传当前登录用户的数据快照', this.onUploadCloudBackup)
      Divider().color($r('app.color.color_divider')).margin({ left: 66, right: 16 })
      this.MenuRow($rawfile('icon_other.svg'), '#FFF4E4', $r('app.color.color_accent'), '数据清理', '清理缓存与页面临时状态', this.onClearCache)
    }
    .width('calc(100% - 32vp)')
    .backgroundColor($r('app.color.color_card_overlay'))
    .borderRadius(18)
    .border({ width: 1, color: $r('app.color.color_divider') })
    .clip(true)
    .shadow({ radius: 9, color: $r('app.color.color_shadow_blue_08'), offsetY: 3 })
    .margin({ left: 16, right: 16, bottom: 10 })
  }

  @Builder
  ExportButton() {
    Button('导出 CSV')
      .width('calc(100% - 32vp)')
      .height(42)
      .fontSize(15)
      .fontColor($r('app.color.color_primary'))
      .backgroundColor($r('app.color.color_card_overlay'))
      .borderRadius(16)
      .border({ width: 1, color: $r('app.color.color_primary') })
      .margin({ left: 16, right: 16, bottom: 14 })
      .onClick(this.onExportCsv)
  }

  build() {
    Column() {
      this.Header()
      Scroll() {
        Column() {
          this.UserCard()
          this.DataSection()
          this.ExportButton()
        }
        .width('100%')
        .padding({ bottom: 16 })
      }
      .align(Alignment.Top)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
  }
}
