@CustomDialog
export struct ConfirmActionDialog {
  controller?: CustomDialogController
  @Prop title: string = ''
  @Prop message: string = ''
  @Prop confirmText: string = '确定'
  @Prop danger: boolean = false
  onConfirm: () => void = (): void => {}

  build() {
    Column() {
      Text(this.title)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.color_text_primary'))
        .textAlign(TextAlign.Center)
        .width('100%')
        .margin({ bottom: 12 })

      Text(this.message)
        .fontSize(14)
        .fontColor($r('app.color.color_text_secondary'))
        .lineHeight(22)
        .textAlign(TextAlign.Center)
        .width('100%')
        .margin({ bottom: 20 })

      Row({ space: 12 }) {
        Button('取消')
          .layoutWeight(1)
          .height(44)
          .fontSize(15)
          .fontColor($r('app.color.color_primary'))
          .backgroundColor($r('app.color.color_card_overlay'))
          .border({ width: 1, color: $r('app.color.color_primary') })
          .borderRadius(22)
          .onClick(() => {
            this.controller?.close()
          })

        Button(this.confirmText)
          .layoutWeight(1)
          .height(44)
          .fontSize(15)
          .fontColor($r('app.color.color_white'))
          .backgroundColor(this.danger ? $r('app.color.color_expense') : $r('app.color.color_primary'))
          .borderRadius(22)
          .onClick(() => {
            this.onConfirm()
            this.controller?.close()
          })
      }
      .width('100%')
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 22, bottom: 20 })
    .backgroundColor($r('app.color.color_surface'))
    .borderRadius(20)
  }
}
