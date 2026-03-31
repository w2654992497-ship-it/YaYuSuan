import { promptAction } from '@kit.ArkUI'
import { Bill } from '../model/Bill'
import { BillDao } from '../database/BillDao'
import { CategoryGrid } from '../components/CategoryGrid'
import { AmountUtil } from '../utils/AmountUtil'
import { DateUtil } from '../utils/DateUtil'

@Component
export struct AddBillPage {
  @Consume activeTabIndex: number
  @State billType: 'income' | 'expense' = 'expense'
  @State amountText: string = ''
  @State selectedCategory: string = ''
  @State selectedDate: string = DateUtil.today()
  @State remark: string = ''

  private resetForm(): void {
    this.billType = 'expense'
    this.amountText = ''
    this.selectedCategory = ''
    this.selectedDate = DateUtil.today()
    this.remark = ''
  }

  private async onSave(): Promise<void> {
    if (!this.amountText || this.amountText.length === 0) {
      promptAction.showToast({ message: '请输入金额' })
      return
    }
    const fen = AmountUtil.yuan2Fen(this.amountText)
    if (fen <= 0) {
      promptAction.showToast({ message: '金额必须大于0' })
      return
    }
    if (!this.selectedCategory || this.selectedCategory.length === 0) {
      promptAction.showToast({ message: '请选择分类' })
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
      promptAction.showToast({ message: '记账成功' })
      this.resetForm()
      this.activeTabIndex = 0
    } catch (err) {
      promptAction.showToast({ message: '保存失败，请重试' })
      console.error('AddBill onSave error:', JSON.stringify(err))
    }
  }

  build() {
    Scroll() {
      Column() {
        // Type toggle
        Row() {
          Button('支出')
            .layoutWeight(1)
            .height(40)
            .fontSize(15)
            .fontColor(this.billType === 'expense' ? '#FFFFFF' : '#9E9E9E')
            .backgroundColor(this.billType === 'expense' ? '#F44336' : '#F5F5F5')
            .borderRadius({ topLeft: 20, bottomLeft: 20 })
            .onClick(() => {
              this.billType = 'expense'
              this.selectedCategory = ''
            })

          Button('收入')
            .layoutWeight(1)
            .height(40)
            .fontSize(15)
            .fontColor(this.billType === 'income' ? '#FFFFFF' : '#9E9E9E')
            .backgroundColor(this.billType === 'income' ? '#4CAF50' : '#F5F5F5')
            .borderRadius({ topRight: 20, bottomRight: 20 })
            .onClick(() => {
              this.billType = 'income'
              this.selectedCategory = ''
            })
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 16, bottom: 8 })

        // Amount display
        Text(`¥ ${this.amountText.length > 0 ? this.amountText : '0.00'}`)
          .fontSize(40)
          .fontColor('#212121') // color_text_primary
          .fontWeight(FontWeight.Bold)
          .width('100%')
          .textAlign(TextAlign.Center)
          .padding({ top: 16, bottom: 8 })
          .onClick(() => {
            // Focus handled by TextInput below
          })

        // Amount input (invisible, tapped via TextInput)
        TextInput({ text: this.amountText })
          .width('80%')
          .height(1)
          .opacity(0.01)
          .type(InputType.PhoneNumber)
          .onChange((value: string) => {
            // Allow digits and one decimal point
            let filtered = value.replace(/[^0-9.]/g, '')
            const dotIndex = filtered.indexOf('.')
            if (dotIndex !== -1) {
              const afterDot = filtered.substring(dotIndex + 1).replace(/\./g, '')
              const truncated = afterDot.substring(0, 2)
              filtered = filtered.substring(0, dotIndex + 1) + truncated
            }
            this.amountText = filtered
          })

        // Category grid
        CategoryGrid({
          billType: this.billType,
          selected: this.selectedCategory,
          onSelect: (category: string) => {
            this.selectedCategory = category
          }
        })
          .margin({ top: 8, bottom: 8 })

        // Date row
        Row() {
          Text('📅')
            .fontSize(20)
            .margin({ right: 8 })
          Text(this.selectedDate)
            .fontSize(15)
            .fontColor('#212121') // color_text_primary
          Blank()
          Text('>')
            .fontSize(14)
            .fontColor('#9E9E9E') // color_text_secondary
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 12, bottom: 12 })
        .backgroundColor('#FFFFFF') // color_card
        .borderRadius(8)
        .margin({ left: 16, right: 16, bottom: 8 })
        .onClick(() => {
          const dateParts = this.selectedDate.split('-')
          const selYear = parseInt(dateParts[0], 10)
          const selMonth = parseInt(dateParts[1], 10) - 1
          const selDay = parseInt(dateParts[2], 10)
          const now = new Date()
          DatePickerDialog.show({
            start: new Date('2020-01-01'),
            end: now,
            selected: new Date(selYear, selMonth, selDay),
            lunar: false,
            onAccept: (value: DatePickerResult) => {
              const y = value.year ?? now.getFullYear()
              const m = ((value.month ?? now.getMonth()) + 1).toString().padStart(2, '0')
              const d = (value.day ?? now.getDate()).toString().padStart(2, '0')
              this.selectedDate = `${y}-${m}-${d}`
            }
          })
        })

        // Remark row
        Row() {
          Text('📝')
            .fontSize(20)
            .margin({ right: 8 })
          TextInput({ placeholder: '备注（选填）', text: this.remark })
            .layoutWeight(1)
            .fontSize(15)
            .maxLength(50)
            .backgroundColor(Color.Transparent)
            .onChange((value: string) => {
              this.remark = value
            })
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 4, bottom: 4 })
        .backgroundColor('#FFFFFF') // color_card
        .borderRadius(8)
        .margin({ left: 16, right: 16, bottom: 24 })

        // Save button
        Button('保  存')
          .width('100%')
          .height(48)
          .fontSize(16)
          .fontColor('#FFFFFF')
          .backgroundColor('#1976D2') // color_primary
          .borderRadius(24)
          .margin({ left: 16, right: 16, bottom: 24 })
          .onClick(() => {
            this.onSave()
          })
      }
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.color_bg'))
  }
}
