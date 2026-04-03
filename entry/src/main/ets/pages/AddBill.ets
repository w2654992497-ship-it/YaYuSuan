import { BillDao } from '../database/BillDao'
import { CategoryDao } from '../database/CategoryDao'
import { CategoryRecord } from '../model/Category'
import { DateUtil } from '../utils/DateUtil'
import { AmountUtil } from '../utils/AmountUtil'
import { LogUtils } from '../utils/LogUtils'
import { CategoryGrid } from '../components/CategoryGrid'
import { CommonHintDialog } from '../components/CommonHintDialog'
import { FilterOptions } from '../model/FilterOptions'
import { preferences } from '@kit.ArkData'

@Component
export struct AddBillPage {
  @State billType: 'income' | 'expense' = 'expense'
  @State amountText: string = ''
  @State selectedCategory: string = ''
  @State selectedDate: string = DateUtil.today()
  @State remark: string = ''
  @State isAmountFocused: boolean = false
  @State isRemarkFocused: boolean = false
  @State expenseCategories: CategoryRecord[] = []
  @State incomeCategories: CategoryRecord[] = []
  @Watch('onTabChanged')
  @Consume activeTabIndex: number
  @StorageProp('statusBarHeight') sbHeight: number = 0
  @StorageLink('showCategoryEditor') showCategoryEditor: boolean = false
  @StorageLink('editCategorySelected') editCategorySelected: string = ''
  @Watch('onCategoryVersionChanged')
  @StorageProp('categoryVersion') categoryVersion: number = 0

  private saveSuccessController: CustomDialogController = new CustomDialogController({
    builder: CommonHintDialog({ message: '记账成功', iconType: 'success' }),
    alignment: DialogAlignment.Center, autoCancel: false, customStyle: true, maskColor: '#60000000'
  })

  private showBudgetWarning(msg: string): void {
    const ctrl = new CustomDialogController({
      builder: CommonHintDialog({ message: msg, iconType: 'info' }),
      alignment: DialogAlignment.Center, autoCancel: false, customStyle: true, maskColor: '#60000000'
    })
    ctrl.open()
    setTimeout(() => { ctrl.close() }, 2000)
  }

  private async checkBudgetExceeded(category: string, date: string): Promise<void> {
    try {
      const catRecord = await CategoryDao.getInstance().queryByName(category, this.billType)
      if (!catRecord) return
      const pref = await preferences.getPreferences(this.getUIContext().getHostContext()!, { name: 'yayusuan_budget' })
      const budgetFen = await pref.get(`budget_id_${catRecord.id}`, 0) as number
      if (budgetFen <= 0) return
      const month = date.substring(0, 7)
      const filter: FilterOptions = { month: month, type: 'expense', category: category }
      const bills = await BillDao.getInstance().queryByFilter(filter)
      let totalFen = 0
      for (const b of bills) { totalFen += b.amount }
      if (totalFen > budgetFen) {
        const overFen = totalFen - budgetFen
        setTimeout(() => {
          this.showBudgetWarning(`「${category}」本月已超预算 ¥${AmountUtil.fen2Display(overFen)}`)
        }, 1600)
      }
    } catch (err) {
      LogUtils.error('AddBill', 'checkBudget: %{public}s', JSON.stringify(err))
    }
  }

  onTabChanged(): void {
    if (this.activeTabIndex === 2) {
      this.loadCategories()
      if (this.editCategorySelected.length > 0) {
        this.selectedCategory = this.editCategorySelected
      }
    }
  }

  onCategoryVersionChanged(): void {
    this.loadCategories()
    if (this.editCategorySelected.length > 0) {
      this.selectedCategory = this.editCategorySelected
    }
  }

  aboutToAppear(): void { this.loadCategories() }

  private async loadCategories(): Promise<void> {
    this.expenseCategories = await CategoryDao.getInstance().queryByType('expense')
    this.incomeCategories = await CategoryDao.getInstance().queryByType('income')
  }

  private showDatePicker(): void {
    const parts = this.selectedDate.split('-')
    const now = new Date()
    this.getUIContext().showDatePickerDialog({
      start: new Date('2020-01-01'), end: now,
      selected: new Date(parseInt(parts[0], 10), parseInt(parts[1], 10) - 1, parseInt(parts[2], 10)),
      lunar: false,
      onDateAccept: (value: Date) => {
        const y = value.getFullYear()
        const m = (value.getMonth() + 1).toString().padStart(2, '0')
        const d = value.getDate().toString().padStart(2, '0')
        const picked = `${y}-${m}-${d}`
        this.selectedDate = picked > DateUtil.today() ? DateUtil.today() : picked
      }
    })
  }

  private filterAmount(value: string): string {
    let filtered = value.replace(/[^0-9.]/g, '')
    const dotIndex = filtered.indexOf('.')
    if (dotIndex !== -1) {
      const afterDot = filtered.substring(dotIndex + 1).replace(/\./g, '')
      filtered = filtered.substring(0, dotIndex + 1) + afterDot.substring(0, 2)
    }
    if (filtered.length > 1 && filtered[0] === '0' && filtered[1] !== '.') {
      filtered = filtered.substring(1)
    }
    return filtered
  }

  private async submit(): Promise<void> {
    try {
      if (!this.amountText || this.amountText.length === 0) {
        this.getUIContext().getPromptAction().showToast({ message: '请输入金额' }); return
      }
      const fen = AmountUtil.yuan2Fen(this.amountText)
      if (fen <= 0) {
        this.getUIContext().getPromptAction().showToast({ message: '金额必须大于0' }); return
      }
      if (!this.selectedCategory || this.selectedCategory.length === 0) {
        this.getUIContext().getPromptAction().showToast({ message: '请选择分类' }); return
      }
      await BillDao.getInstance().insert({
        id: 0, amount: fen, type: this.billType, category: this.selectedCategory,
        remark: this.remark, date: this.selectedDate, createdAt: Date.now()
      })
      this.saveSuccessController.open()
      setTimeout(() => { this.saveSuccessController.close() }, 1400)
      if (this.billType === 'expense') {
        this.checkBudgetExceeded(this.selectedCategory, this.selectedDate).catch(() => {})
      }
      this.amountText = ''
      this.remark = ''
      this.selectedCategory = ''
      this.selectedDate = DateUtil.today()
      this.activeTabIndex = 0
    } catch (err) {
      try { this.getUIContext().getPromptAction().showToast({ message: '保存失败' }) } catch (_e) {}
      LogUtils.error('AddBill', 'submit: %{public}s', JSON.stringify(err))
    }
  }

  // 打开全屏编辑器
  private openCategoryEditor(): void {
    AppStorage.setOrCreate('editCategorySelected', this.selectedCategory)
    AppStorage.setOrCreate('editCategoryType', this.billType)
    this.getUIContext().animateTo({ duration: 300, curve: Curve.EaseOut }, () => {
      this.showCategoryEditor = true
    })
  }

  build() {
    Column() {
      // ── 沉浸式彩色头部 ──
      Column() {
        Row().width('100%').height(this.sbHeight)

        // 收支切换
        Row() {
          Row() {
            Text('支出').fontSize(15)
              .fontWeight(this.billType === 'expense' ? FontWeight.Bold : FontWeight.Normal)
              .fontColor(this.billType === 'expense' ? $r('app.color.color_duck') : $r('app.color.color_surface'))
              .backgroundColor(this.billType === 'expense' ? $r('app.color.color_surface') : Color.Transparent)
              .borderRadius(16).padding({ left: 28, right: 28, top: 6, bottom: 6 })
              .animation({ duration: 250, curve: Curve.FastOutSlowIn })
              .onClick(() => { this.billType = 'expense'; this.selectedCategory = '' })

            Text('收入').fontSize(15)
              .fontWeight(this.billType === 'income' ? FontWeight.Bold : FontWeight.Normal)
              .fontColor(this.billType === 'income' ? $r('app.color.color_primary') : $r('app.color.color_surface'))
              .backgroundColor(this.billType === 'income' ? $r('app.color.color_surface') : Color.Transparent)
              .borderRadius(16).padding({ left: 28, right: 28, top: 6, bottom: 6 })
              .animation({ duration: 250, curve: Curve.FastOutSlowIn })
              .onClick(() => { this.billType = 'income'; this.selectedCategory = '' })
          }
          .backgroundColor('rgba(255,255,255,0.2)').borderRadius(20).padding(4)
        }
        .width('100%').justifyContent(FlexAlign.Center).padding({ top: 12, bottom: 16 })

        // 金额输入
        Column() {
          Text('金额').fontSize(13)
            .fontColor(this.isAmountFocused ? 'rgba(255,255,255,0.95)' : 'rgba(255,255,255,0.6)')
            .width('100%').padding({ left: 24, bottom: 4 }).animation({ duration: 200 })

          Row() {
            Text('¥').fontSize(40).fontWeight(FontWeight.Bold)
              .fontColor(this.isAmountFocused || this.amountText.length > 0
                ? $r('app.color.color_surface') : 'rgba(255,255,255,0.45)')
              .margin({ right: 4 }).animation({ duration: 200, curve: Curve.EaseOut })

            TextInput({ text: this.amountText, placeholder: '0.00' })
              .type(InputType.NUMBER_DECIMAL).fontSize(40).fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.color_surface')).placeholderColor('rgba(255,255,255,0.35)')
              .backgroundColor(Color.Transparent).caretColor($r('app.color.color_surface'))
              .caretStyle({ width: 2.5 }).border({ width: 0 }).borderRadius(0).padding(0)
              .layoutWeight(1).maxLength(10).enterKeyType(EnterKeyType.Done)
              .onEditChange((isEditing: boolean) => { this.isAmountFocused = isEditing })
              .onChange((value: string) => { this.amountText = this.filterAmount(value) })
          }
          .width('100%').padding({ left: 24, right: 24 }).alignItems(VerticalAlign.Center)

          Row().width(this.isAmountFocused ? 140 : 50).height(2.5)
            .backgroundColor(this.isAmountFocused ? '#FFFFFF' : 'rgba(255,255,255,0.25)')
            .borderRadius(1.5).margin({ top: 6 }).animation({ duration: 250, curve: Curve.EaseOut })
        }
        .alignItems(HorizontalAlign.Center).padding({ bottom: 16 })

        // 日期胶囊
        Row() {
          Image($rawfile('icon_calendar.svg')).width(14).height(14)
            .fillColor('rgba(255,255,255,0.8)').margin({ right: 6 })
          Text(this.selectedDate).fontSize(13).fontColor('rgba(255,255,255,0.8)')
        }
        .padding({ left: 14, right: 14, top: 6, bottom: 6 })
        .backgroundColor('rgba(0,0,0,0.12)').borderRadius(16)
        .margin({ bottom: 24 }).onClick(() => this.showDatePicker())
      }
      .width('100%').alignItems(HorizontalAlign.Center)
      .backgroundColor(this.billType === 'expense' ? $r('app.color.color_duck') : $r('app.color.color_primary'))
      .animation({ duration: 300, curve: Curve.FastOutSlowIn })
      .borderRadius({ bottomLeft: 28, bottomRight: 28 })
      .shadow({ radius: 12, color: 'rgba(0,0,0,0.1)', offsetY: 6 }).zIndex(1)

      // ── 白色内容区 ──
      Scroll() {
        Column() {
          // 分类卡片
          Column() {
            Row() {
              Text('选择分类').fontSize(14).fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.color_text_primary'))
              Blank()
              Text('编辑').fontSize(13).fontColor($r('app.color.color_primary'))
                .onClick(() => { this.openCategoryEditor() })
            }
            .width('100%').padding({ left: 16, right: 16, top: 16, bottom: 8 })

            CategoryGrid({
              billType: this.billType,
              selected: this.selectedCategory,
              categories: this.billType === 'expense' ? this.expenseCategories : this.incomeCategories,
              onSelect: (cat: string) => { this.selectedCategory = cat }
            }).padding({ bottom: 8 })
          }
          .backgroundColor($r('app.color.color_surface')).borderRadius(20)
          .margin({ left: 16, right: 16, top: -16 })
          .shadow({ radius: 12, color: 'rgba(0,0,0,0.04)', offsetY: 4 })

          // 备注卡片
          Column() {
            Row() {
              Image($rawfile('icon_edit.svg')).width(18).height(18)
                .fillColor(this.isRemarkFocused
                  ? (this.billType === 'expense' ? $r('app.color.color_duck') : $r('app.color.color_primary'))
                  : $r('app.color.color_text_secondary'))
                .margin({ right: 10 }).animation({ duration: 200 })
              TextInput({ text: this.remark, placeholder: '添加备注（选填）' })
                .layoutWeight(1).fontSize(15).fontColor($r('app.color.color_text_primary'))
                .maxLength(50).backgroundColor(Color.Transparent).border({ width: 0 }).borderRadius(0)
                .caretColor(this.billType === 'expense' ? $r('app.color.color_duck') : $r('app.color.color_primary'))
                .caretStyle({ width: 2 }).placeholderColor($r('app.color.color_text_secondary'))
                .onEditChange((isEditing: boolean) => { this.isRemarkFocused = isEditing })
                .onChange((v: string) => { this.remark = v })
            }
            .width('100%').padding({ left: 16, right: 16, top: 12, bottom: 12 })
          }
          .backgroundColor($r('app.color.color_surface')).borderRadius(20)
          .margin({ left: 16, right: 16, top: 12 })
          .border({
            width: this.isRemarkFocused ? 1.5 : 0,
            color: this.billType === 'expense' ? $r('app.color.color_duck') : $r('app.color.color_primary')
          })
          .animation({ duration: 200, curve: Curve.EaseOut })
          .shadow({ radius: 12, color: 'rgba(0,0,0,0.04)', offsetY: 4 })

          // 保存按钮
          Button('保存账单')
            .width('calc(100% - 32vp)').height(52)
            .backgroundColor(this.billType === 'expense' ? $r('app.color.color_duck') : $r('app.color.color_primary'))
            .fontColor($r('app.color.color_surface')).fontSize(17).fontWeight(FontWeight.Bold).borderRadius(26)
            .animation({ duration: 300 })
            .shadow({
              radius: 10,
              color: this.billType === 'expense' ? 'rgba(245,158,11,0.35)' : 'rgba(44,122,123,0.35)',
              offsetY: 5
            })
            .margin({ left: 16, right: 16, top: 24, bottom: 32 })
            .onClick(() => this.submit())
        }
      }
      .scrollBar(BarState.Off).edgeEffect(EdgeEffect.Spring)
      .width('100%').layoutWeight(1)
    }
    .width('100%').height('100%').backgroundColor($r('app.color.color_bg'))
  }
}
