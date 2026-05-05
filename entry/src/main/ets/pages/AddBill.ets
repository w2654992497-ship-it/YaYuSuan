import { CategoryDao } from '../database/CategoryDao'
import { CategoryRecord, getUnifiedCategoryColor } from '../model/Category'
import { PaymentAccount, PaymentAccountType } from '../model/PaymentAccount'
import { AppDataApi } from '../services/AppDataApi'
import { BudgetService } from '../services/BudgetService'
import { CommonHintDialog } from '../components/CommonHintDialog'
import { WaterPageBg } from '../components/WaterPageBg'
import { AmountUtil } from '../utils/AmountUtil'
import { DateUtil } from '../utils/DateUtil'
import { LogUtils } from '../utils/LogUtils'

interface TemplateItem {
  title: string
  category: string
  remark: string
  amount: string
}

@Component
export struct AddBillPage {
  @State billType: 'income' | 'expense' = 'expense'
  @State amountText: string = ''
  @State selectedCategory: string = ''
  @State selectedDate: string = DateUtil.today()
  @State remark: string = ''
  @State isAmountFocused: boolean = false
  @State isRemarkFocused: boolean = false
  @State selectedAccountId: number = 0
  @State selectedAccountName: string = '\u73b0\u91d1\u94b1\u5305'
  @State selectedAccountDesc: string = ''
  @State selectedAccountType: PaymentAccountType = 'cash'
  @State selectedAccountColor: string = '#FF9500'
  @State accountOptionsList: PaymentAccount[] = []
  @State showAccountSheet: boolean = false
  @State expenseCategories: CategoryRecord[] = []
  @State incomeCategories: CategoryRecord[] = []
  @Watch('onTabChanged')
  @Consume activeTabIndex: number
  @Consume('appNavStack') navStack: NavPathStack
  @StorageProp('statusBarHeight') sbHeight: number = 0
  @StorageLink('showCategoryEditor') showCategoryEditor: boolean = false
  @StorageLink('editCategorySelected') editCategorySelected: string = ''
  @Watch('onCategoryVersionChanged')
  @StorageProp('categoryVersion') categoryVersion: number = 0
  @Watch('onPaymentAccountVersionChanged')
  @StorageProp('paymentAccountVersion') paymentAccountVersion: number = 0

  private templateItems: TemplateItem[] = [
    { title: '早餐 ¥8', category: '餐饮', remark: '早餐', amount: '8' },
    { title: '午餐 ¥25', category: '餐饮', remark: '午餐', amount: '25' },
    { title: '地铁 ¥3', category: '交通', remark: '地铁', amount: '3' },
    { title: '奶茶 ¥18', category: '饮品', remark: '奶茶', amount: '18' }
  ]

  private incomeTemplateItems: TemplateItem[] = [
    { title: '工资 ¥5000', category: '工资', remark: '工资', amount: '5000' },
    { title: '兼职 ¥200', category: '兼职', remark: '兼职', amount: '200' },
    { title: '理财 ¥100', category: '理财', remark: '理财收益', amount: '100' },
    { title: '红包 ¥20', category: '红包', remark: '红包', amount: '20' }
  ]

  private accountDesc(account: PaymentAccount): string {
    if (account.tailNumber.length > 0) {
      return '\u5c3e\u53f7' + account.tailNumber
    }
    if (account.type === 'cash') {
      return '\u4f59\u989d\u8d26\u6237'
    }
    return ''
  }

  private iconForAccountType(type: PaymentAccountType): ResourceStr {
    if (type === 'bank') {
      return $rawfile('icon_account_bank.svg')
    }
    if (type === 'alipay') {
      return $rawfile('icon_account_alipay.svg')
    }
    if (type === 'wechat') {
      return $rawfile('icon_account_wechat.svg')
    }
    if (type === 'cash') {
      return $rawfile('icon_account_cash.svg')
    }
    return $rawfile('icon_account_other.svg')
  }

  private selectAccount(item: PaymentAccount): void {
    this.selectedAccountId = item.id
    this.selectedAccountName = item.name
    this.selectedAccountDesc = this.accountDesc(item)
    this.selectedAccountType = item.type
    this.selectedAccountColor = item.color.length > 0 ? item.color : '#64748B'
    this.showAccountSheet = false
  }

  private openAccountSettingsFromSheet(): void {
    this.showAccountSheet = false
    this.navStack.pushPathByName('accountSettings', null)
  }

  private openAccountCreateFromSheet(): void {
    this.showAccountSheet = false
    AppStorage.setOrCreate<number>('accountEditId', 0)
    this.navStack.pushPathByName('accountCreate', null)
  }

  private async loadAccounts(): Promise<void> {
    try {
      const accounts = await AppDataApi.getInstance().queryEnabledPaymentAccounts()
      this.accountOptionsList = accounts
      if (this.selectedAccountId > 0) {
        let stillExists = false
        for (let i = 0; i < accounts.length; i++) {
          if (accounts[i].id === this.selectedAccountId) {
            stillExists = true
          }
        }
        if (stillExists) {
          return
        }
      }
      const defaultAccount = await AppDataApi.getInstance().queryDefaultPaymentAccount()
      if (defaultAccount.id > 0) {
        this.selectAccount(defaultAccount)
      } else if (accounts.length > 0) {
        this.selectAccount(accounts[0])
      }
    } catch (err) {
      LogUtils.error('AddBill', 'loadAccounts: %{public}s', JSON.stringify(err))
    }
  }

  private saveSuccessController: CustomDialogController = new CustomDialogController({
    builder: CommonHintDialog({ message: '记账成功', iconType: 'success' }),
    alignment: DialogAlignment.Center,
    autoCancel: false,
    customStyle: true,
    maskColor: $r('app.color.color_dialog_mask')
  })

  private showBudgetWarning(msg: string): void {
    const ctrl = new CustomDialogController({
      builder: CommonHintDialog({ message: msg, iconType: 'info' }),
      alignment: DialogAlignment.Center,
      autoCancel: false,
      customStyle: true,
      maskColor: $r('app.color.color_dialog_mask')
    })
    ctrl.open()
    setTimeout(() => {
      ctrl.close()
    }, 2000)
  }

  private async checkBudgetExceeded(category: string, categoryId: number, date: string): Promise<void> {
    try {
      const warning = await BudgetService.getInstance().buildExpenseBillWarning(category, categoryId, date)
      if (warning.length > 0) {
        setTimeout(() => {
          this.showBudgetWarning(warning)
        }, 1600)
      }
    } catch (err) {
      LogUtils.error('AddBill', 'checkBudget: %{public}s', JSON.stringify(err))
    }
  }

  onTabChanged(): void {
    if (this.activeTabIndex === 2) {
      this.loadCategories().catch(() => {})
      this.loadAccounts().catch(() => {})
    }
  }

  onCategoryVersionChanged(): void {
    this.loadCategories().catch(() => {})
  }

  onPaymentAccountVersionChanged(): void {
    this.loadAccounts().catch(() => {})
  }

  aboutToAppear(): void {
    this.loadCategories().catch(() => {})
    this.loadAccounts().catch(() => {})
  }

  private currentCategories(): CategoryRecord[] {
    return this.billType === 'expense' ? this.expenseCategories : this.incomeCategories
  }

  private currentTemplates(): TemplateItem[] {
    return this.billType === 'expense' ? this.templateItems : this.incomeTemplateItems
  }

  private syncSelectedCategory(): void {
    const nextSelected = this.editCategorySelected.length > 0 ? this.editCategorySelected : this.selectedCategory
    const categories = this.currentCategories()
    let hasNext = false
    let hasCurrent = false
    for (let i = 0; i < categories.length; i++) {
      if (categories[i].name === nextSelected) {
        hasNext = true
      }
      if (categories[i].name === this.selectedCategory) {
        hasCurrent = true
      }
    }
    if (nextSelected.length > 0 && hasNext) {
      this.selectedCategory = nextSelected
      return
    }
    if (this.selectedCategory.length > 0 && !hasCurrent) {
      this.selectedCategory = ''
    }
  }

  private async loadCategories(): Promise<void> {
    const expense = await CategoryDao.getInstance().queryByType('expense')
    const income = await CategoryDao.getInstance().queryByType('income')
    const nextExpense: CategoryRecord[] = []
    const nextIncome: CategoryRecord[] = []
    for (let i = 0; i < expense.length; i++) {
      const c = expense[i]
      nextExpense.push({
        id: c.id,
        name: c.name,
        icon: c.icon,
        color: c.color,
        type: c.type,
        sort_order: c.sort_order,
        is_default: c.is_default
      })
    }
    for (let i = 0; i < income.length; i++) {
      const c = income[i]
      nextIncome.push({
        id: c.id,
        name: c.name,
        icon: c.icon,
        color: c.color,
        type: c.type,
        sort_order: c.sort_order,
        is_default: c.is_default
      })
    }
    this.expenseCategories = nextExpense
    this.incomeCategories = nextIncome
    this.syncSelectedCategory()
  }

  private showDatePicker(): void {
    const parts = this.selectedDate.split('-')
    const now = new Date()
    this.getUIContext().showDatePickerDialog({
      start: new Date('2020-01-01'),
      end: now,
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
        this.getUIContext().getPromptAction().showToast({ message: '请输入金额' })
        return
      }
      const fen = AmountUtil.yuan2Fen(this.amountText)
      if (fen <= 0) {
        this.getUIContext().getPromptAction().showToast({ message: '金额必须大于0' })
        return
      }
      if (!this.selectedCategory || this.selectedCategory.length === 0) {
        this.getUIContext().getPromptAction().showToast({ message: '请选择分类' })
        return
      }
      if (this.selectedAccountId <= 0) {
        await this.loadAccounts()
        if (this.selectedAccountId <= 0) {
          this.getUIContext().getPromptAction().showToast({ message: '请选择付款账户' })
          return
        }
      }
      const categoryRecord = await CategoryDao.getInstance().queryByName(this.selectedCategory, this.billType)
      const categoryId = categoryRecord ? categoryRecord.id : 0
      const hostContext = this.getUIContext().getHostContext()
      await AppDataApi.getInstance().addBill(hostContext ? hostContext : null, {
        id: 0,
        amount: fen,
        type: this.billType,
        category: this.selectedCategory,
        categoryId: categoryId,
        paymentAccountId: this.selectedAccountId,
        paymentAccountName: this.selectedAccountName,
        remark: this.remark,
        date: this.selectedDate,
        createdAt: Date.now()
      }, true)
      this.saveSuccessController.open()
      setTimeout(() => {
        this.saveSuccessController.close()
      }, 1400)
      if (this.billType === 'expense') {
        this.checkBudgetExceeded(this.selectedCategory, categoryId, this.selectedDate).catch(() => {})
      }
      this.amountText = ''
      this.remark = ''
      this.selectedCategory = ''
      this.selectedDate = DateUtil.today()
      this.activeTabIndex = 0
    } catch (err) {
      try {
        this.getUIContext().getPromptAction().showToast({ message: '保存失败' })
      } catch (_e) {
      }
      LogUtils.error('AddBill', 'submit: %{public}s', JSON.stringify(err))
    }
  }

  private openCategoryEditor(): void {
    AppStorage.setOrCreate('editCategorySelected', this.selectedCategory)
    AppStorage.setOrCreate('editCategoryType', this.billType)
    this.getUIContext().animateTo({ duration: 300, curve: Curve.EaseOut }, () => {
      this.showCategoryEditor = true
    })
  }

  private categoryLimit(): number {
    const count = this.currentCategories().length
    return Math.min(count, 8)
  }

  private todayLabel(): string {
    if (this.selectedDate === DateUtil.today()) {
      return '今天'
    }
    return ''
  }

  private selectedDateDisplay(): string {
    const parts = this.selectedDate.split('-')
    if (parts.length !== 3) {
      return this.selectedDate
    }
    return `${parseInt(parts[0], 10)}年${parseInt(parts[1], 10)}月${parseInt(parts[2], 10)}日`
  }

  @Builder
  Header() {
    Stack({ alignContent: Alignment.TopEnd }) {
      Image($rawfile('illustration_fish_bowl.png'))
        .width(80)
        .height(54)
        .opacity(0.9)
        .objectFit(ImageFit.Contain)
        .margin({ top: this.sbHeight + 6, right: 16 })
        .hitTestBehavior(HitTestMode.None)

      Row() {
        Image($rawfile('icon_chevron_left.svg'))
          .width(22)
          .height(22)
          .fillColor($r('app.color.color_text_deep'))
          .rotate({ angle: -90 })
          .onClick(() => {
            this.activeTabIndex = 0
          })
        Blank()
        Text('记一笔')
          .fontSize(22)
          .fontWeight(FontWeight.Bolder)
          .fontColor($r('app.color.color_text_deep'))
        Blank()
        Row().width(22)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .padding({ left: 24, right: 24, top: this.sbHeight + 8, bottom: 6 })
    }
    .width('100%')
  }

  @Builder
  TypeSwitch() {
    Row() {
      Row({ space: 6 }) {
        Text('↓')
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.billType === 'expense' ? $r('app.color.color_white') : $r('app.color.color_icon_muted'))
        Text('支出')
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.billType === 'expense' ? $r('app.color.color_white') : $r('app.color.color_icon_muted'))
      }
      .width('50%')
      .height(34)
      .borderRadius(17)
      .justifyContent(FlexAlign.Center)
      .backgroundColor(this.billType === 'expense' ? $r('app.color.color_primary') : Color.Transparent)
      .onClick(() => {
        this.billType = 'expense'
        this.selectedCategory = ''
      })

      Row({ space: 6 }) {
        Text('↑')
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.billType === 'income' ? $r('app.color.color_white') : $r('app.color.color_icon_muted'))
        Text('收入')
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.billType === 'income' ? $r('app.color.color_white') : $r('app.color.color_icon_muted'))
      }
      .width('50%')
      .height(34)
      .borderRadius(17)
      .justifyContent(FlexAlign.Center)
      .backgroundColor(this.billType === 'income' ? $r('app.color.color_primary') : Color.Transparent)
      .onClick(() => {
        this.billType = 'income'
        this.selectedCategory = ''
      })
    }
    .width('calc(100% - 160vp)')
    .height(38)
    .padding(2)
    .backgroundColor($r('app.color.color_card_overlay'))
    .borderRadius(19)
    .border({ width: 1, color: $r('app.color.color_divider') })
    .shadow({ radius: 10, color: $r('app.color.color_shadow_blue_09'), offsetX: 0, offsetY: 4 })
    .margin({ left: 80, right: 80, bottom: 8 })
  }

  @Builder
  AmountCard() {
    Column() {
      Row() {
        Text('金额')
          .fontSize(14)
          .fontColor($r('app.color.color_text_secondary'))
        Text('?')
          .fontSize(10)
          .fontColor($r('app.color.color_icon_muted'))
          .textAlign(TextAlign.Center)
          .width(15)
          .height(15)
          .borderRadius(7.5)
          .border({ width: 1, color: $r('app.color.color_text_muted') })
          .margin({ left: 6 })
        Blank()
        Row({ space: 8 }) {
          Text('复制上次')
            .fontSize(12)
            .fontColor($r('app.color.color_text_secondary'))
            .height(24)
            .padding({ left: 10, right: 10 })
            .borderRadius(12)
            .border({ width: 1, color: $r('app.color.color_divider') })
          Text('计算器')
            .fontSize(12)
            .fontColor($r('app.color.color_primary'))
            .height(24)
            .padding({ left: 10, right: 10 })
            .borderRadius(12)
            .border({ width: 1, color: $r('app.color.color_primary') })
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Row() {
        Text('¥')
          .fontSize(30)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.color_text_deep'))
          .margin({ right: 8 })

        TextInput({ text: this.amountText, placeholder: '0.00' })
          .type(InputType.NUMBER_DECIMAL)
          .fontSize(34)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.color_text_deep'))
          .placeholderColor($r('app.color.color_text_deep'))
          .backgroundColor(Color.Transparent)
          .caretColor($r('app.color.color_primary'))
          .caretStyle({ width: 2.5 })
          .border({ width: 0 })
          .borderRadius(0)
          .padding(0)
          .layoutWeight(1)
          .maxLength(10)
          .enterKeyType(EnterKeyType.Done)
          .onEditChange((isEditing: boolean) => {
            this.isAmountFocused = isEditing
          })
          .onChange((value: string) => {
            this.amountText = this.filterAmount(value)
          })
      }
      .width('100%')
      .height(54)
      .alignItems(VerticalAlign.Center)
      .margin({ top: 8 })

      Divider()
        .height(1)
        .color($r('app.color.color_divider'))
        .margin({ top: 2, bottom: 10 })

      Row() {
        Row() {
          Text('账户：')
            .fontSize(13)
            .fontColor($r('app.color.color_text_secondary'))
          Text(this.selectedAccountDesc.length > 0 ? this.selectedAccountName + ' \u00b7 ' + this.selectedAccountDesc : this.selectedAccountName)
            .fontSize(14)
            .fontColor($r('app.color.color_text_deep'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Image($rawfile('icon_chevron_down.svg'))
            .width(13)
            .height(13)
            .fillColor($r('app.color.color_icon_muted'))
            .margin({ left: 4 })
        }
        .width('50%')
        .alignItems(VerticalAlign.Center)
        .onClick(() => {
          this.showAccountSheet = true
        })

        Row() {
          Text('日期：')
            .fontSize(13)
            .fontColor($r('app.color.color_text_secondary'))
          Text(this.todayLabel().length > 0 ? '今天' : this.selectedDateDisplay())
            .fontSize(14)
            .fontColor($r('app.color.color_text_deep'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Image($rawfile('icon_chevron_right.svg'))
            .width(14)
            .height(14)
            .fillColor($r('app.color.color_icon_muted'))
            .margin({ left: 4 })
        }
        .width('50%')
        .justifyContent(FlexAlign.End)
        .alignItems(VerticalAlign.Center)
        .onClick(() => {
          this.showDatePicker()
        })
      }
      .width('100%')
      .height(26)
      .alignItems(VerticalAlign.Center)
    }
    .width('calc(100% - 48vp)')
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .backgroundColor($r('app.color.color_card_overlay'))
    .borderRadius(18)
    .border({ width: 1, color: $r('app.color.color_divider') })
    .shadow({ radius: 10, color: $r('app.color.color_shadow_blue_09'), offsetX: 0, offsetY: 4 })
    .margin({ left: 24, right: 24, bottom: 8 })
  }

  @Builder
  CategoryTile(item: CategoryRecord) {
    Column() {
      Image($rawfile(item.icon + '.svg'))
        .width(21)
        .height(21)
        .fillColor(getUnifiedCategoryColor(item.name))
      Text(item.name)
        .fontSize(11)
        .fontColor($r('app.color.color_text_deep'))
        .margin({ top: 5 })
    }
    .width(46)
    .height(54)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(this.selectedCategory === item.name ? $r('app.color.color_soft_blue') : $r('app.color.color_white'))
    .borderRadius(10)
    .border({ width: this.selectedCategory === item.name ? 1.5 : 1, color: this.selectedCategory === item.name ? $r('app.color.color_primary') : $r('app.color.color_divider') })
    .onClick(() => {
      this.selectedCategory = item.name
    })
  }

  @Builder
  CategoryCard() {
    Column() {
      Row() {
        Text('分类')
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.color_text_deep'))
        Blank()
        Text('更多')
          .fontSize(12)
          .fontColor($r('app.color.color_text_secondary'))
        Image($rawfile('icon_chevron_right.svg'))
          .width(14)
          .height(14)
          .fillColor($r('app.color.color_text_muted'))
          .margin({ left: 4 })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .margin({ bottom: 10 })
      .onClick(() => {
        this.openCategoryEditor()
      })

      Grid() {
        ForEach(this.currentCategories(), (item: CategoryRecord, index: number) => {
          if (index < this.categoryLimit()) {
            GridItem() {
              this.CategoryTile(item)
            }
          }
        }, (item: CategoryRecord) => `${item.id}_${item.name}_${item.icon}`)
      }
      .columnsTemplate('1fr 1fr 1fr 1fr')
      .rowsGap(8)
      .columnsGap(6)
      .width('100%')
      .height(116)
    }
    .width('calc(100% - 48vp)')
    .padding({ left: 14, right: 14, top: 14, bottom: 10 })
    .backgroundColor($r('app.color.color_card_overlay'))
    .borderRadius(18)
    .border({ width: 1, color: $r('app.color.color_divider') })
    .shadow({ radius: 10, color: $r('app.color.color_shadow_blue_09'), offsetX: 0, offsetY: 4 })
    .margin({ left: 24, right: 24, top: 0, bottom: 8 })
  }

  @Builder
  InfoCard() {
    Column() {
      Row() {
        Image($rawfile('icon_list.svg'))
          .width(16)
          .height(16)
          .fillColor($r('app.color.color_icon_muted'))
          .margin({ right: 8 })
        Text('备注')
          .fontSize(14)
          .fontColor($r('app.color.color_text_deep'))
          .width(48)
        TextInput({ text: this.remark, placeholder: '添加备注，例如：猪脚饭' })
          .layoutWeight(1)
          .fontSize(13)
          .fontColor($r('app.color.color_text_deep'))
          .placeholderColor($r('app.color.color_text_muted'))
          .backgroundColor(Color.Transparent)
          .border({ width: 0 })
          .borderRadius(0)
          .padding(0)
          .maxLength(50)
          .caretColor($r('app.color.color_primary'))
          .caretStyle({ width: 2 })
          .onEditChange((isEditing: boolean) => {
            this.isRemarkFocused = isEditing
          })
          .onChange((v: string) => {
            this.remark = v
          })
      }
      .width('100%')
      .height(36)
      .alignItems(VerticalAlign.Center)
    }
    .width('calc(100% - 48vp)')
    .padding({ left: 14, right: 14, top: 8, bottom: 8 })
    .backgroundColor($r('app.color.color_card_overlay'))
    .borderRadius(16)
    .border({ width: 1, color: $r('app.color.color_divider') })
    .shadow({ radius: 10, color: $r('app.color.color_shadow_blue_08'), offsetX: 0, offsetY: 4 })
    .margin({ left: 24, right: 24, bottom: 8 })
  }

  @Builder
  TemplateChip(item: TemplateItem) {
    Text(item.title)
      .fontSize(12)
      .fontColor($r('app.color.color_text_deep'))
      .height(26)
      .padding({ left: 12, right: 12 })
      .backgroundColor($r('app.color.color_white'))
      .borderRadius(13)
      .border({ width: 1, color: $r('app.color.color_divider') })
      .onClick(() => {
        this.selectedCategory = item.category
        this.remark = item.remark
        if (item.amount.length > 0) {
          this.amountText = item.amount
        }
      })
  }

  @Builder
  TemplateCard() {
    Column() {
      Row() {
        Text('常用模板')
          .fontSize(14)
          .fontColor($r('app.color.color_text_deep'))
        Blank()
        Text('管理')
          .fontSize(12)
          .fontColor($r('app.color.color_text_secondary'))
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .margin({ bottom: 8 })

      Scroll() {
        Row({ space: 8 }) {
          ForEach(this.currentTemplates(), (item: TemplateItem) => {
            this.TemplateChip(item)
          }, (item: TemplateItem) => item.title)
        }
      }
      .width('100%')
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
    }
    .width('calc(100% - 48vp)')
    .padding({ left: 14, right: 14, top: 10, bottom: 10 })
    .backgroundColor($r('app.color.color_card_overlay'))
    .borderRadius(18)
    .border({ width: 1, color: $r('app.color.color_divider') })
    .shadow({ radius: 10, color: $r('app.color.color_shadow_blue_08'), offsetX: 0, offsetY: 4 })
    .margin({ left: 24, right: 24, bottom: 8 })
  }

  @Builder
  AccountLogo(accountType: PaymentAccountType, color: string) {
    Row() {
      Image(this.iconForAccountType(accountType))
        .width(18)
        .height(18)
        .fillColor($r('app.color.color_white'))
    }
    .width(34)
    .height(34)
    .borderRadius(17)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(color)
  }

  @Builder
  AccountPickerRow(item: PaymentAccount) {
    Row() {
      this.AccountLogo(item.type, item.color)
      Text(this.accountDesc(item).length > 0 ? item.name + ' \u00b7 ' + this.accountDesc(item) : item.name)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.color_text_deep'))
        .layoutWeight(1)
        .margin({ left: 14 })
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      if (item.isDefault === 1) {
        Text('\u9ed8\u8ba4')
          .fontSize(12)
          .fontColor($r('app.color.color_primary'))
          .height(22)
          .padding({ left: 8, right: 8 })
          .borderRadius(7)
          .backgroundColor($r('app.color.color_selected_bg'))
          .margin({ right: 10 })
      }
      if (this.selectedAccountId === item.id) {
        Image($rawfile('icon_check.svg'))
          .width(20)
          .height(20)
          .fillColor($r('app.color.color_primary'))
      } else {
        Row()
          .width(22)
          .height(22)
          .borderRadius(11)
          .border({ width: 1, color: $r('app.color.color_divider') })
      }
    }
    .width('100%')
    .height(54)
    .padding({ left: 14, right: 14 })
    .alignItems(VerticalAlign.Center)
    .onClick(() => {
      this.selectAccount(item)
    })
  }

  @Builder
  AccountSheet() {
    Stack({ alignContent: Alignment.Bottom }) {
      Row()
        .width('100%')
        .height('100%')
        .backgroundColor('#66000000')
        .onClick(() => {
          this.showAccountSheet = false
        })

      Column() {
        Row()
          .width(42)
          .height(5)
          .borderRadius(3)
          .backgroundColor($r('app.color.color_divider'))
          .margin({ top: 12, bottom: 16 })

        Text('\u9009\u62e9\u8d26\u6237')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.color_text_deep'))
        Text('\u8bb0\u8d26\u65f6\u53ef\u5feb\u901f\u5207\u6362\u4ed8\u6b3e\u8d26\u6237')
          .fontSize(13)
          .fontColor($r('app.color.color_text_secondary'))
          .margin({ top: 6, bottom: 14 })

        Column() {
          ForEach(this.accountOptionsList, (item: PaymentAccount, index: number) => {
            this.AccountPickerRow(item)
            if (index < this.accountOptionsList.length - 1) {
              Divider().color($r('app.color.color_divider')).margin({ left: 62, right: 14 })
            }
          }, (item: PaymentAccount) => item.id.toString())
        }
        .width('100%')
        .padding({ top: 4, bottom: 4 })
        .borderRadius(14)
        .border({ width: 1, color: $r('app.color.color_divider') })
        .backgroundColor($r('app.color.color_card_overlay'))

        Row() {
          Row({ space: 4 }) {
            Text('+')
              .fontSize(20)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.color_primary'))
            Text('\u65b0\u589e\u8d26\u6237')
              .fontSize(15)
              .fontColor($r('app.color.color_primary'))
          }
          .height(42)
          .padding({ right: 14 })
          .alignItems(VerticalAlign.Center)
          .onClick(() => {
            this.openAccountCreateFromSheet()
          })
          Blank()
          Row({ space: 4 }) {
            Text('\u7ba1\u7406\u8d26\u6237')
              .fontSize(15)
              .fontColor($r('app.color.color_primary'))
            Image($rawfile('icon_chevron_right.svg'))
              .width(14)
              .height(14)
              .fillColor($r('app.color.color_primary'))
          }
          .height(42)
          .padding({ left: 14 })
          .alignItems(VerticalAlign.Center)
          .onClick(() => {
            this.openAccountSettingsFromSheet()
          })
        }
        .width('100%')
        .height(42)
        .alignItems(VerticalAlign.Center)
        .margin({ top: 12 })

        Row({ space: 16 }) {
          Button('\u53d6\u6d88')
            .height(50)
            .layoutWeight(1)
            .fontSize(16)
            .fontColor($r('app.color.color_primary'))
            .backgroundColor(Color.Transparent)
            .border({ width: 1, color: $r('app.color.color_divider') })
            .borderRadius(16)
            .onClick(() => {
              this.showAccountSheet = false
            })
          Button('\u786e\u8ba4\u9009\u62e9')
            .height(50)
            .layoutWeight(1)
            .fontSize(16)
            .fontColor($r('app.color.color_white'))
            .backgroundColor($r('app.color.color_primary'))
            .borderRadius(16)
            .onClick(() => {
              this.showAccountSheet = false
            })
        }
        .width('100%')
        .margin({ top: 12 })
      }
      .width('100%')
      .padding({ left: 22, right: 22, bottom: 20 })
      .backgroundColor($r('app.color.color_surface'))
      .borderRadius({ topLeft: 28, topRight: 28 })
    }
    .width('100%')
    .height('100%')
    .transition(
      TransitionEffect.asymmetric(
        TransitionEffect.OPACITY.combine(TransitionEffect.translate({ y: 360 }))
          .animation({ duration: 280, curve: Curve.EaseOut }),
        TransitionEffect.OPACITY.combine(TransitionEffect.translate({ y: 360 }))
          .animation({ duration: 220, curve: Curve.EaseIn })
      )
    )
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      WaterPageBg()

      Column() {
        this.Header()
        this.TypeSwitch()

        Scroll() {
          Column() {
            this.AmountCard()
            this.TemplateCard()
            this.CategoryCard()
            this.InfoCard()

            Button('保存账单')
              .width('calc(100% - 48vp)')
              .height(42)
              .backgroundColor($r('app.color.color_primary'))
              .fontColor($r('app.color.color_white'))
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .borderRadius(12)
              .shadow({ radius: 10, color: $r('app.color.color_shadow_blue_10'), offsetX: 0, offsetY: 4 })
              .margin({ left: 24, right: 24, bottom: 14 })
              .onClick(() => {
                this.submit()
              })
          }
          .width('100%')
        }
        .layoutWeight(1)
        .width('100%')
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Start)
      .alignItems(HorizontalAlign.Center)
      .backgroundColor(Color.Transparent)

      if (this.showAccountSheet) {
        this.AccountSheet()
      }
    }
    .width('100%')
    .height('100%')
  }
}
