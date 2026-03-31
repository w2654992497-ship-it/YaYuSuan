export type HintIconType = 'success' | 'error' | 'info'

/**
 * 操作结果提示弹窗（居中半透明卡片，配合 CustomDialogController 使用）
 * 调用方负责在适当时机调用 controller.close()（一般配合 setTimeout 1500ms）
 */
@CustomDialog
export struct CommonHintDialog {
  controller?: CustomDialogController
  @Prop message: string = ''
  @Prop iconType: HintIconType = 'success'

  private getIconText(): string {
    if (this.iconType === 'success') return '✓'
    if (this.iconType === 'error') return '✕'
    return '!'
  }

  private getIconColor(): string {
    if (this.iconType === 'success') return '#4CAF50'
    if (this.iconType === 'error') return '#F44336'
    return '#FF9800'
  }

  build() {
    Column() {
      // 图标圆圈
      Column() {
        Text(this.getIconText())
          .fontSize(26)
          .fontColor(Color.White)
          .fontWeight(FontWeight.Bold)
      }
      .width(54)
      .height(54)
      .borderRadius(27)
      .backgroundColor(this.getIconColor())
      .alignItems(HorizontalAlign.Center)
      .justifyContent(FlexAlign.Center)
      .margin({ bottom: 14 })

      Text(this.message)
        .fontSize(15)
        .fontColor('#FFFFFF')
        .textAlign(TextAlign.Center)
        .maxLines(2)
    }
    .padding({ left: 32, right: 32, top: 24, bottom: 24 })
    .alignItems(HorizontalAlign.Center)
    .backgroundColor('#CC333333')
    .borderRadius(14)
  }
}
