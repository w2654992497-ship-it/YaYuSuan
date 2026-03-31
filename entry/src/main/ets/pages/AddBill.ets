import { Bill } from '../model/Bill'
import { BillDao } from '../database/BillDao'
import { CategoryGrid } from '../components/CategoryGrid'
import { AmountUtil } from '../utils/AmountUtil'
import { DateUtil } from '../utils/DateUtil'
import { ToastUtils } from '../utils/ToastUtils'
import { LogUtils } from '../utils/LogUtils'
import { CommonHintDialog } from '../components/CommonHintDialog'

@Component
export struct AddBillPage {
  @Consume activeTabIndex: number
  @State billType: 'income' | 'expense' = 'expense'
  @State amountText: string = ''
  @State selectedCategory: string = ''
  @State selectedDate: string = DateUtil.today()
  @State remark: string = ''

  private saveSuccessController: CustomDialogController = new CustomDialogController({
    builder: CommonHintDialog({ message: '记账成功', iconType: 'success' }),
    alignment: DialogAlignment.Center,
    autoCancel: false,
    customStyle: true,
    maskColor: '#60000000'
  })

  private resetForm(): void {
    this.billType = 'expense'
    this.amountText = ''
    this.selectedCategory = ''
    this.selectedDate = DateUtil.today()
    this.remark = ''
  }

  private async onSave(): Promise<void> {
    if (!this.amountText || this.amountText.length === 0) {
      ToastUtils.warning('请输入金额')
      return
    }
    const fen = AmountUtil.yuan2Fen(this.amountText)
    if (fen <= 0) {
      ToastUtils.warning('金额必须大于0')
      return
    }
    if (!this.selectedCategory || this.selectedCategory.length === 0) {
      ToastUtils.warning('请选择分类')
      return
    }

    const bill: Bill = {
      id: 0,
      amount: fen,
      type: this.billType,
      category: this.selectedCategory,
      remark: this.remark,
      date: this.selectedDate,
      createdAt: Date.now()
    }

    try {
      await BillDao.getInstance().insert(bill)
      AppStorage.set('needRefresh', true)
      this.saveSuccessController.open()
      setTimeout(() => {
        this.saveSuccessController.close()
      }, 1400)
      this.resetForm()
      this.activeTabIndex = 0
    } catch (err) {
      ToastUtils.error('保存失败，请重试')
      LogUtils.error('AddBill', 'onSave error: %{public}s', JSON.stringify(err))
    }
  }

  build() {
    Column() {
      // ── 顶部彩色区：收支切换 + 金额输入 ────────────
      Column() {
        // 收支切换
        Row({ space: 4 }) {
          Text('支出')
            .fontSize(14)
            .fontColor(this.billType === 'expense' ? '#FFFFFF' : 'rgba(255,255,255,0.45)')
            .fontWeight(this.billType === 'expense' ? FontWeight.Bold : FontWeight.Normal)
            .padding({ left: 28, right: 28, top: 8, bottom: 8 })
            .backgroundColor(
              this.billType === 'expense' ? 'rgba(0,0,0,0.18)' : Color.Transparent
            )
            .borderRadius(20)
            .onClick(() => {
              this.billType = 'expense'
              this.selectedCategory = ''
            })

          Text('收入')
            .fontSize(14)
            .fontColor(this.billType === 'income' ? '#FFFFFF' : 'rgba(255,255,255,0.45)')
            .fontWeight(this.billType === 'income' ? FontWeight.Bold : FontWeight.Normal)
            .padding({ left: 28, right: 28, top: 8, bottom: 8 })
            .backgroundColor(
              this.billType === 'income' ? 'rgba(0,0,0,0.18)' : Color.Transparent
            )
            .borderRadius(20)
            .onClick(() => {
              this.billType = 'income'
              this.selectedCategory = ''
            })
        }
        .margin({ top: 20, bottom: 6 })

        // 金额显示 + 透明输入框叠加
        Stack({ alignContent: Alignment.Center }) {
          Column() {
            Text(`¥ ${this.amountText.length > 0 ? this.amountText : '0.00'}`)
              .fontSize(46)
              .fontColor('#FFFFFF')
              .fontWeight(FontWeight.Bold)
              .textAlign(TextAlign.Center)
              .width('100%')
            // 输入指示下划线
            Row()
              .width(100)
              .height(2)
              .backgroundColor('rgba(255,255,255,0.45)')
              .borderRadius(1)
              .margin({ top: 6 })
          }
          .alignItems(HorizontalAlign.Center)

          TextInput({ text: this.amountText })
            .width('100%')
            .height(80)
            .opacity(0.01)
            .caretColor(Color.Transparent)
            .type(InputType.PhoneNumber)
            .onChange((value: string) => {
              let filtered = value.replace(/[^0-9.]/g, '')
              const dotIndex = filtered.indexOf('.')
              if (dotIndex !== -1) {
                const afterDot = filtered.substring(dotIndex + 1).replace(/\./g, '')
                filtered = filtered.substring(0, dotIndex + 1) + afterDot.substring(0, 2)
              }
              this.amountText = filtered
            })
        }
        .width('100%')
        .height(80)

        // 日期胶囊（点击修改）
        Row() {
          Image($rawfile('icon_calendar.svg'))
            .width(13)
            .height(13)
            .fillColor('rgba(255,255,255,0.75)')
            .margin({ right: 5 })
          Text(this.selectedDate)
            .fontSize(12)
            .fontColor('rgba(255,255,255,0.75)')
        }
        .padding({ left: 12, right: 12, top: 6, bottom: 6 })
        .backgroundColor('rgba(0,0,0,0.14)')
        .borderRadius(16)
        .margin({ bottom: 22 })
        .onClick(() => {
          const parts = this.selectedDate.split('-')
          const now = new Date()
          DatePickerDialog.show({
            start: new Date('2020-01-01'),
            end: now,
            selected: new Date(
              parseInt(parts[0], 10),
              parseInt(parts[1], 10) - 1,
              parseInt(parts[2], 10)
            ),
            lunar: false,
            onAccept: (value: DatePickerResult) => {
              const y = value.year ?? now.getFullYear()
              const m = ((value.month ?? now.getMonth()) + 1).toString().padStart(2, '0')
              const d = (value.day ?? now.getDate()).toString().padStart(2, '0')
              this.selectedDate = `${y}-${m}-${d}`
            }
          })
        })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)

      // ── 白色卡片区 ────────────────────────────────
      Column() {
        // 把手指示器
        Row()
          .width(32)
          .height(4)
          .backgroundColor('#E0E0E0')
          .borderRadius(2)
          .margin({ top: 10, bottom: 4 })

        // 分类选择
        CategoryGrid({
          billType: this.billType,
          selected: this.selectedCategory,
          onSelect: (category: string) => {
            this.selectedCategory = category
          }
        })

        Divider()
          .color('#E0E0E0')

        // 备注行
        Row() {
          Image($rawfile('icon_edit.svg'))
            .width(17)
            .height(17)
            .fillColor('#757575')
            .margin({ right: 10 })
          TextInput({ placeholder: '备注（选填）', text: this.remark })
            .layoutWeight(1)
            .fontSize(14)
            .maxLength(50)
            .backgroundColor(Color.Transparent)
            .placeholderColor('#757575')
            .onChange((value: string) => {
              this.remark = value
            })
        }
        .width('100%')
        .padding({ top: 4, bottom: 4 })

        Blank()

        // 保存按钮
        Button('保  存')
          .width('100%')
          .height(48)
          .fontSize(16)
          .fontColor('#FFFFFF')
          .backgroundColor('#1976D2')
          .borderRadius(24)
          .margin({ bottom: 20 })
          .onClick(() => { this.onSave() })
      }
      .width('100%')
      .layoutWeight(1)
      .backgroundColor('#FFFFFF')
      .borderRadius({ topLeft: 24, topRight: 24 })
      .padding({ left: 16, right: 16 })
      .clip(true)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.billType === 'expense' ? '#E53935' : '#43A047')
    .animation({ duration: 300, curve: Curve.EaseInOut })
  }
}
