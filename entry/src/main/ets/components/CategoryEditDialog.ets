import { PRESET_ICONS, PRESET_COLORS } from '../model/Category'

@CustomDialog
export struct CategoryEditDialog {
  controller?: CustomDialogController
  @Prop mode: string = 'add'       // 'add' | 'edit'
  @Prop categoryType: string = 'expense'
  @Prop initialName: string = ''
  @Prop initialIcon: string = 'icon_other'
  @Prop initialColor: string = '#78909C'
  @Prop existingNames: string[] = []   // 已有的分类名（用于重名检测）
  onConfirm: (name: string, icon: string, color: string) => void = () => {}

  @State name: string = ''
  @State selectedIcon: string = ''
  @State selectedColor: string = ''

  aboutToAppear(): void {
    this.name = this.initialName
    this.selectedIcon = this.initialIcon
    this.selectedColor = this.initialColor
  }

  build() {
    Column() {
      // 标题
      Text(this.mode === 'add' ? '添加分类' : '编辑分类')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.color_text_primary'))
        .margin({ bottom: 16 })

      // 预览
      Row() {
        Column() {
          Image($rawfile(this.selectedIcon + '.svg'))
            .width(24).height(24)
            .fillColor($r('app.color.color_surface'))
        }
        .width(48).height(48).borderRadius(24)
        .backgroundColor(this.selectedColor)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .margin({ right: 12 })

        Text(this.name.length > 0 ? this.name : '分类名称')
          .fontSize(16)
          .fontColor(this.name.length > 0 ? $r('app.color.color_text_primary') : $r('app.color.color_text_secondary'))
          .fontWeight(FontWeight.Medium)
      }
      .width('100%')
      .padding(12)
      .backgroundColor($r('app.color.color_bg'))
      .borderRadius(12)
      .margin({ bottom: 16 })

      // 名称输入
      TextInput({ text: this.name, placeholder: '输入分类名称（1-4字）' })
        .fontSize(15)
        .maxLength(4)
        .backgroundColor($r('app.color.color_bg'))
        .borderRadius(12)
        .padding({ left: 12, right: 12, top: 10, bottom: 10 })
        .onChange((v: string) => { this.name = v })
        .margin({ bottom: 16 })

      // 选择图标
      Text('选择图标')
        .fontSize(13)
        .fontColor($r('app.color.color_text_secondary'))
        .width('100%')
        .margin({ bottom: 8 })

      Scroll() {
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(PRESET_ICONS, (icon: string) => {
            Column() {
              Image($rawfile(icon + '.svg'))
                .width(20).height(20)
                .fillColor(this.selectedIcon === icon ? $r('app.color.color_surface') : $r('app.color.color_text_secondary'))
            }
            .width(40).height(40).borderRadius(20)
            .backgroundColor(this.selectedIcon === icon ? this.selectedColor : $r('app.color.color_bg'))
            .justifyContent(FlexAlign.Center)
            .alignItems(HorizontalAlign.Center)
            .margin(4)
            .border(this.selectedIcon === icon
              ? { width: 2, color: this.selectedColor }
              : { width: 0 })
            .onClick(() => { this.selectedIcon = icon })
          })
        }
      }
      .height(140)
      .scrollBar(BarState.Off)
      .margin({ bottom: 16 })

      // 选择颜色
      Text('选择颜色')
        .fontSize(13)
        .fontColor($r('app.color.color_text_secondary'))
        .width('100%')
        .margin({ bottom: 8 })

      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(PRESET_COLORS, (color: string) => {
          Column()
            .width(32).height(32).borderRadius(16)
            .backgroundColor(color)
            .margin(4)
            .border(this.selectedColor === color
              ? { width: 2.5, color: $r('app.color.color_text_primary') }
              : { width: 0 })
            .onClick(() => { this.selectedColor = color })
        })
      }
      .margin({ bottom: 20 })

      // 按钮
      Row({ space: 12 }) {
        Button('取消')
          .layoutWeight(1)
          .height(44)
          .fontSize(15)
          .fontColor($r('app.color.color_text_secondary'))
          .backgroundColor($r('app.color.color_bg'))
          .borderRadius(22)
          .onClick(() => { this.controller?.close() })

        Button('确定')
          .layoutWeight(1)
          .height(44)
          .fontSize(15)
          .fontColor($r('app.color.color_surface'))
          .backgroundColor($r('app.color.color_primary'))
          .borderRadius(22)
          .onClick(() => {
            if (this.name.length === 0) return
            // 重名检测（编辑时允许保留原名）
            const trimmed = this.name.trim()
            const isDuplicate = this.existingNames.some((n: string): boolean =>
              n === trimmed && trimmed !== this.initialName
            )
            if (isDuplicate) {
              try { this.getUIContext().getPromptAction().showToast({ message: '分类名称已存在' }) } catch (_e) {}
              return
            }
            this.onConfirm(trimmed, this.selectedIcon, this.selectedColor)
            this.controller?.close()
          })
      }
      .width('100%')
    }
    .width('100%')
    .padding(20)
    .backgroundColor($r('app.color.color_surface'))
    .borderRadius(20)
  }
}
