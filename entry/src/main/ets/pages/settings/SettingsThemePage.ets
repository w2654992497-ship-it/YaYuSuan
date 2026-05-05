@Component
export struct SettingsThemePage {
  @Prop sbHeight: number
  selectedTheme: string = 'light'
  selectedThemeColor: string = '#21A7A8'
  themeModeLabel: string = '浅色模式'
  onBack: () => void = (): void => {}
  onSelectMode: (mode: string) => void = (mode: string): void => {}
  onSelectColor: (color: string) => void = (color: string): void => {}

  @Builder
  Header() {
    Stack({ alignContent: Alignment.TopEnd }) {
      Row() {
        Image($rawfile('icon_chevron_left.svg'))
          .width(26)
          .height(26)
          .fillColor($r('app.color.color_text_primary'))
          .onClick(this.onBack)
        Text('主题模式')
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
  ThemeModeListRow(mode: string, title: string, desc: string) {
    Row() {
      Column() {
        Text(title)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.color_text_primary'))
        Text(desc)
          .fontSize(12)
          .fontColor($r('app.color.color_text_secondary'))
          .margin({ top: 4 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      if (this.selectedTheme === mode) {
        Text('已选')
          .fontSize(12)
          .fontColor($r('app.color.color_white'))
          .padding({ left: 10, right: 10, top: 4, bottom: 4 })
          .backgroundColor($r('app.color.color_primary'))
          .borderRadius(12)
      } else {
        Circle()
          .width(18)
          .height(18)
          .fill(Color.Transparent)
          .border({ width: 1, color: $r('app.color.color_text_muted') })
      }
    }
    .width('100%')
    .height(60)
    .padding({ left: 16, right: 16 })
    .alignItems(VerticalAlign.Center)
    .onClick(() => {
      this.onSelectMode(mode)
    })
  }

  @Builder
  ThemeColorSwatch(color: string, label: string) {
    Column() {
      Stack({ alignContent: Alignment.Center }) {
        Circle()
          .width(36)
          .height(36)
          .fill(color)
        if (this.selectedThemeColor === color) {
          Text('✓')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.color_white'))
        }
      }
      .width(46)
      .height(46)
      .border({ width: this.selectedThemeColor === color ? 2 : 0, color: color })
      .borderRadius(23)

      Text(label)
        .fontSize(11)
        .fontColor($r('app.color.color_text_secondary'))
        .margin({ top: 4 })
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
    .onClick(() => {
      this.onSelectColor(color)
    })
  }

  @Builder
  SectionTitle(title: string) {
    Text(title)
      .fontSize(16)
      .fontWeight(FontWeight.Bold)
      .fontColor($r('app.color.color_text_primary'))
      .width('100%')
      .padding({ left: 16, right: 16, top: 14, bottom: 6 })
  }

  build() {
    Column() {
      this.Header()
      Scroll() {
        Column() {
          Column() {
            this.SectionTitle('显示模式')
            this.ThemeModeListRow('light', '浅色模式', '明亮清晰，适合日常记账')
            Divider().color($r('app.color.color_divider')).margin({ left: 16, right: 16 })
            this.ThemeModeListRow('dark', '深色模式', '降低夜间亮度刺激')
            Divider().color($r('app.color.color_divider')).margin({ left: 16, right: 16 })
            this.ThemeModeListRow('system', '跟随系统', '随系统外观自动切换')
          }
          .width('calc(100% - 32vp)')
          .backgroundColor($r('app.color.color_surface'))
          .borderRadius(16)
          .clip(true)
          .shadow({ radius: 8, color: $r('app.color.color_shadow_blue_08'), offsetY: 3 })
          .margin({ left: 16, right: 16, bottom: 10 })

          Column() {
            Text('主题色')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.color_text_primary'))
              .width('100%')
              .margin({ bottom: 12 })
            Row() {
              this.ThemeColorSwatch('#21A7A8', '湖蓝')
              this.ThemeColorSwatch('#3B82F6', '蓝色')
              this.ThemeColorSwatch('#7C3AED', '紫色')
              this.ThemeColorSwatch('#FF9F1C', '橙色')
              this.ThemeColorSwatch('#31B46B', '绿色')
            }
            .width('100%')
            .alignItems(VerticalAlign.Center)
          }
          .width('calc(100% - 32vp)')
          .padding(15)
          .backgroundColor($r('app.color.color_surface'))
          .borderRadius(16)
          .shadow({ radius: 8, color: $r('app.color.color_shadow_blue_08'), offsetY: 3 })
          .margin({ left: 16, right: 16, bottom: 10 })

          Column() {
            Text('当前选择')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.color_text_primary'))
              .width('100%')
            Row() {
              Text(this.themeModeLabel)
                .fontSize(14)
                .fontColor($r('app.color.color_text_primary'))
                .layoutWeight(1)
              Circle()
                .width(24)
                .height(24)
                .fill(this.selectedThemeColor)
            }
            .width('100%')
            .margin({ top: 10 })
          }
          .width('calc(100% - 32vp)')
          .padding(15)
          .backgroundColor($r('app.color.color_surface'))
          .borderRadius(16)
          .margin({ left: 16, right: 16, bottom: 24 })
        }
        .width('100%')
        .constraintSize({ minHeight: '100%' })
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
