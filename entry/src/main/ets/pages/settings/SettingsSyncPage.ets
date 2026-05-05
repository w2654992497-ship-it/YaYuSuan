@Component
export struct SettingsSyncPage {
  @Prop sbHeight: number
  onBack: () => void = (): void => {}
  onExportMigration: () => void = (): void => {}
  onShowRoadmap: () => void = (): void => {}

  @Builder
  Header() {
    Stack({ alignContent: Alignment.TopEnd }) {
      Row() {
        Image($rawfile('icon_chevron_left.svg'))
          .width(26)
          .height(26)
          .fillColor($r('app.color.color_text_primary'))
          .onClick(this.onBack)
        Text('多设备同步')
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
  ActionCard(title: string, desc: string, buttonText: string, onTap: () => void) {
    Column() {
      Text(title)
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.color_text_primary'))
        .width('100%')
      Text(desc)
        .fontSize(12)
        .fontColor($r('app.color.color_text_secondary'))
        .lineHeight(18)
        .width('100%')
        .margin({ top: 5, bottom: 12 })
      Button(buttonText)
        .width('100%')
        .height(40)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.color_white'))
        .backgroundColor($r('app.color.color_primary'))
        .borderRadius(20)
        .onClick(onTap)
    }
    .width('calc(100% - 32vp)')
    .padding(15)
    .backgroundColor($r('app.color.color_surface'))
    .borderRadius(16)
    .shadow({ radius: 8, color: $r('app.color.color_shadow_blue_08'), offsetY: 3 })
    .margin({ left: 16, right: 16, bottom: 10 })
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Column() {
      this.Header()
      Scroll() {
        Column() {
          this.ActionCard('当前同步方案', '当前版本先提供本地备份文件迁移：在旧设备导出备份文件，再在新设备保留文件用于恢复开发。云同步需要账号体系和冲突合并策略，单独排期。', '立即导出迁移文件', this.onExportMigration)
          this.ActionCard('同步开发优先级', '下一步实现备份导入恢复；再接入账号同步、冲突合并和同步日志。', '查看当前状态', this.onShowRoadmap)
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
