import { Bill } from '../model/Bill'
import { BillDao } from '../database/BillDao'
import { CategoryGrid } from '../components/CategoryGrid'
import { AmountUtil } from '../utils/AmountUtil'
import { DateUtil } from '../utils/DateUtil'
import { ToastUtils } from '../utils/ToastUtils'
import { LogUtils } from '../utils/LogUtils'
import { CommonHintDialog } from '../components/CommonHintDialog'
import { FilterOptions } from '../model/FilterOptions'
import { window } from '@kit.ArkUI'
import { inputMethod } from '@kit.IMEKit'
import { preferences } from '@kit.ArkData'

@Component
export struct AddBillPage {
  @Consume activeTabIndex: number
  @StorageProp('statusBarHeight') sbHeight: number = 0
  @State billType: 'income' | 'expense' = 'expense'
  @State amountText: string = ''
  @State selectedCategory: string = ''
  @State selectedDate: string = DateUtil.today()
  @State remark: string = ''
  @State isInputFocused: boolean = false
  private amountInputId: string = 'amountInput'

  private dismissKeyboard(): void {
    try {
      inputMethod.getController().stopInputSession()
    } catch (_e) {
      // ignore
    }
  }

  private saveSuccessController: CustomDialogController = new CustomDialogController({
    builder: CommonHintDialog({ message: '记账成功', iconType: 'success' }),
    alignment: DialogAlignment.Center,
    autoCancel: false,
    customStyle: true,
    maskColor: '#60000000'
  })

  private showBudgetWarning(msg: string): void {
    const ctrl = new CustomDialogController({
      builder: CommonHintDialog({ message: msg, iconType: 'info' }),
      alignment: DialogAlignment.Center,
      autoCancel: false,
      customStyle: true,
      maskColor: '#60000000'
    })
    ctrl.open()
    setTimeout(() => { ctrl.close() }, 2000)
  }

  // 切换状态栏图标为亮色（白色，适配彩色顶部）
  private setLightStatusBar(): void {
    const win = AppStorage.get<window.Window>('mainWindow')
    if (!win) return
    win.setWindowSystemBarProperties({ statusBarContentColor: '#FFFFFF' }).catch(() => {})
  }

  aboutToAppear(): void {
    this.setLightStatusBar()
  }

  private resetForm(): void {
    this.billType = 'expense'
    this.amountText = ''
    this.selectedCategory = ''
    this.selectedDate = DateUtil.today()
    this.remark = ''
    this.isInputFocused = false
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
      // 记账后异步检查预算（不阻塞主流程）
      if (bill.type === 'expense') {
        this.checkBudgetExceeded(bill.category, bill.date).catch(() => {})
      }
    } catch (err) {
      ToastUtils.error('保存失败，请重试')
      LogUtils.error('AddBill', 'onSave error: %{public}s', JSON.stringify(err))
    }
  }

  // 检查指定分类本月是否超预算，超出则 Toast 提醒
  private async checkBudgetExceeded(category: string, date: string): Promise<void> {
    try {
      const pref = await preferences.getPreferences(
        this.getUIContext().getHostContext()!,
        { name: 'yayusuan_budget' }
      )
      const budgetFen = await pref.get(`budget_${category}`, 0) as number
      if (budgetFen <= 0) { return }   // 未设置预算则跳过

      const month = date.substring(0, 7)   // YYYY-MM
      const filter: FilterOptions = { month: month, type: 'expense', category: category }
      const bills = await BillDao.getInstance().queryByFilter(filter)
      let totalFen = 0
      for (const b of bills) { totalFen += b.amount }

      if (totalFen > budgetFen) {
        const overFen = totalFen - budgetFen
        const msg = `「${category}」本月已超预算 ¥${AmountUtil.fen2Display(overFen)}`
        // 等保存成功弹窗关闭后再显示预算警告
        setTimeout(() => {
          this.showBudgetWarning(msg)
        }, 1600)
      }
    } catch (err) {
      LogUtils.error('AddBill', 'checkBudget error: %{public}s', JSON.stringify(err))
    }
  }

  build() {
    Column() {
      // ── 顶部彩色区：状态栏占位 + 收支切换 + 金额输入 ──
      Column() {
        // 状态栏安全区域（背景色延伸至此）
        Row().width('100%').height(this.sbHeight)

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
        .margin({ top: 8, bottom: 6 })

        // 金额输入：¥ 标签 + 真实 TextInput（支持拍照/粘贴/系统光标）
        Column({ space: 0 }) {
          Row({ space: 4 }) {
            Text('¥')
              .fontSize(36)
              .fontColor(this.isInputFocused || this.amountText.length > 0
                ? '#FFFFFF'
                : 'rgba(255,255,255,0.5)')
              .fontWeight(FontWeight.Bold)
              .alignSelf(ItemAlign.Center)
              .animation({ duration: 150 })

            TextInput({ placeholder: '0.00', text: this.amountText })
              .fontSize(44)
              .fontColor('#FFFFFF')
              .fontWeight(FontWeight.Bold)
              .placeholderColor('rgba(255,255,255,0.5)')
              .caretColor('#FFFFFF')
              .backgroundColor(Color.Transparent)
              .border({ width: 0 })
              .borderRadius(0)
              .padding({ top: 0, bottom: 0, left: 0, right: 0 })
              .type(InputType.NUMBER_DECIMAL)
              .width(180)
              .textAlign(TextAlign.Start)
              .enterKeyType(EnterKeyType.Done)
              .id(this.amountInputId)
              .onEditChange((isEditing: boolean) => {
                this.isInputFocused = isEditing
              })
              .onChange((value: string) => {
                let filtered = value.replace(/[^0-9.]/g, '')
                const dotIndex = filtered.indexOf('.')
                if (dotIndex !== -1) {
                  const afterDot = filtered.substring(dotIndex + 1).replace(/\./g, '')
                  filtered = filtered.substring(0, dotIndex + 1) + afterDot.substring(0, 2)
                }
                // 去除多余前导零（如 "07" → "7"）
                if (filtered.length > 1 && filtered[0] === '0' && filtered[1] !== '.') {
                  filtered = filtered.substring(1)
                }
                this.amountText = filtered
              })
          }
          .justifyContent(FlexAlign.Center)
          .width('100%')
          .height(64)

          // 焦点指示线（聚焦时扩展变亮）
          Row()
            .width(this.isInputFocused ? 160 : 60)
            .height(2)
            .backgroundColor(this.isInputFocused ? '#FFFFFF' : 'rgba(255,255,255,0.3)')
            .borderRadius(0)
            .margin({ top: 4 })
            .animation({ duration: 200, curve: Curve.EaseOut })
        }
        .alignItems(HorizontalAlign.Center)
        .margin({ bottom: 6 })
        .onClick(() => {
          focusControl.requestFocus(this.amountInputId)
        })

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
        .margin({ bottom: 20 })
        .onClick(() => {
          const parts = this.selectedDate.split('-')
          const now = new Date()
          this.getUIContext().showDatePickerDialog({
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
              const picked = `${y}-${m}-${d}`
              // 防止选到未来日期
              const todayStr = DateUtil.today()
              this.selectedDate = picked > todayStr ? todayStr : picked
            }
          })
        })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)

      // ── 白色卡片区 ────────────────────────────────────
      Column() {
        // 把手指示器
        Row()
          .width(32)
          .height(4)
          .backgroundColor('#E0E0E0')
          .borderRadius(2)
          .margin({ top: 10, bottom: 4 })

        // 分类 + 备注 + 保存（Scroll 包裹，键盘压缩时仍可滚动）
        Scroll() {
          Column() {
            // 分类选择
            CategoryGrid({
              billType: this.billType,
              selected: this.selectedCategory,
              onSelect: (category: string) => {
                this.selectedCategory = category
              }
            })

            Divider().color('#E0E0E0')

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
                .border({ width: 0 })
                .borderRadius(0)
                .placeholderColor('#757575')
                .onChange((value: string) => {
                  this.remark = value
                })
            }
            .width('100%')
            .padding({ top: 4, bottom: 4 })

            // 保存按钮
            Button('保  存')
              .width('100%')
              .height(48)
              .fontSize(16)
              .fontColor('#FFFFFF')
              .backgroundColor('#1976D2')
              .borderRadius(24)
              .margin({ top: 12, bottom: 20 })
              .onClick(() => { this.onSave() })
          }
          .width('100%')
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.None)
      }
      .width('100%')
      .layoutWeight(1)
      .backgroundColor('#FFFFFF')
      .borderRadius({ topLeft: 24, topRight: 24 })
      .padding({ left: 16, right: 16 })
      .clip(true)
      .onClick(() => {
        this.dismissKeyboard()
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.billType === 'expense' ? '#E53935' : '#43A047')
    .animation({ duration: 300, curve: Curve.EaseInOut })
  }
}
