@Component
export struct SettingsDataToolsPage {
  @Prop sbHeight: number
  activeUsername: string = ''
  cloudRegisterPassword: string = ''
  cloudRegisterBusy: boolean = false
  onBack: () => void = (): void => {}
  onPasswordChange: (value: string) => void = (value: string): void => {}
  onExportBackup: () => void = (): void => {}
  onUploadCloudBackup: () => void = (): void => {}
  onCheckCloudBackups: () => void = (): void => {}
  onRegisterCloudAccount: () => void = (): void => {}
  onUploadCloudDatabase: () => void = (): void => {}
  onCheckCloudDatabase: () => void = (): void => {}
  onExportCsv: () => void = (): void => {}
  onClearCache: () => void = (): void => {}

  @Builder
  Header() {
    Stack({ alignContent: Alignment.TopEnd }) {
      Row() {
        Image($rawfile('icon_chevron_left.svg'))
          .width(26)
          .height(26)
          .fillColor($r('app.color.color_text_primary'))
          .onClick(this.onBack)
        Text('数据与备份')
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

  @Builder
  CloudAccountCard() {
    Column() {
      Text('注册云账号')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.color_text_primary'))
        .width('100%')
      Text('使用当前本地用户名 ' + this.activeUsername + ' 创建云账号。注册成功后会自动上传当前用户的本地数据。')
        .fontSize(12)
        .fontColor($r('app.color.color_text_secondary'))
        .lineHeight(18)
        .width('100%')
        .margin({ top: 5, bottom: 10 })
      TextInput({ placeholder: '设置云账号密码，至少 6 位', text: this.cloudRegisterPassword })
        .width('100%')
        .height(40)
        .fontSize(13)
        .type(InputType.Password)
        .backgroundColor($r('app.color.color_bg'))
        .borderRadius(14)
        .padding({ left: 12, right: 12 })
        .margin({ bottom: 12 })
        .onChange((value: string) => {
          this.onPasswordChange(value)
        })
      Button(this.cloudRegisterBusy ? '注册上传中...' : '注册云账号并上传')
        .width('100%')
        .height(40)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.color_white'))
        .backgroundColor($r('app.color.color_primary'))
        .borderRadius(20)
        .onClick(this.onRegisterCloudAccount)
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
          this.ActionCard('完整数据备份', '导出账单、分类和周期记账规则，适合换机前保存。', '导出备份文件', this.onExportBackup)
          this.ActionCard('云端备份', '将当前账单、分类和周期记账规则上传到云存储，按当前登录用户隔离保存。', '上传云备份', this.onUploadCloudBackup)
          this.ActionCard('云端备份检查', '查看当前登录用户在云存储 backups 目录下是否已有备份文件。', '检查云备份', this.onCheckCloudBackups)
          this.CloudAccountCard()
          this.ActionCard('云数据库同步', '将当前本地账单、分类和周期规则写入云数据库存储区。', '同步到云数据库', this.onUploadCloudDatabase)
          this.ActionCard('云数据库检查', '查询当前账号的云端记录数量，用于确认 Cloud DB 是否连通。', '检查云数据库', this.onCheckCloudDatabase)
          this.ActionCard('CSV 账单导出', '导出全部账单明细，方便在表格软件中查看和整理。', '导出 CSV', this.onExportCsv)
          this.ActionCard('清理临时缓存', '清理页面临时状态，不会删除账单、分类和预算。', '清理缓存', this.onClearCache)
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
