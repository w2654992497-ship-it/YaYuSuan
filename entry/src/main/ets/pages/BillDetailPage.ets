import { Bill } from '../model/Bill'
import { CategoryRecord, getCategoryColor, getCategoryInfo, getUnifiedCategoryColor } from '../model/Category'
import { PaymentAccount, PaymentAccountType } from '../model/PaymentAccount'
import { AppDataApi } from '../services/AppDataApi'
import { WaterPageBg } from '../components/WaterPageBg'
import { AmountUtil } from '../utils/AmountUtil'
import { LogUtils } from '../utils/LogUtils'
import { DateUtil } from '../utils/DateUtil'

const BILL_DETAIL_TAG = 'BillDetailPage'

@Component
export struct BillDetailPage {
  @Prop billId: number = 0
  onBack: () => void = () => {}
  onDeleted: () => void = () => {}

  @State loadedBill: Bill | null = null
  @State editMode: boolean = false
  @State billType: 'income' | 'expense' = 'expense'
  @State amountText: string = ''
  @State selectedCategory: string = ''
  @State selectedCategoryId: number = 0
  @State selectedDate: string = ''
  @State remark: string = ''
  @State selectedAccountId: number = 0
  @State selectedAccountName: string = ''
  @State selectedAccountDesc: string = ''
  @State selectedAccountType: PaymentAccountType = 'cash'
  @State selectedAccountColor: string = '#FF9500'
  @State expenseCategories: CategoryRecord[] = []
  @State incomeCategories: CategoryRecord[] = []
  @State accountOptionsList: PaymentAccount[] = []
  @State showAccountSheet: boolean = false
  @State showDeleteConfirm: boolean = false

  @StorageProp('statusBarHeight') sbHeight: number = 0
  @Watch('onCategoryVersionChanged')
  @StorageProp('categoryVersion') categoryVersion: number = 0
  @Watch('onPaymentAccountVersionChanged')
  @StorageProp('paymentAccountVersion') paymentAccountVersion: number = 0

  aboutToAppear(): void {
    this.loadPage().catch(() => {
      LogUtils.error(BILL_DETAIL_TAG, '加载账单详情失败')
    })
  }

  onCategoryVersionChanged(): void {
    this.loadCategories().catch(() => {})
  }

  onPaymentAccountVersionChanged(): void {
    this.loadAccounts().catch(() => {})
  }

  private async loadPage(): Promise<void> {
    await this.loadCategories()
    await this.loadAccounts()
    await this.loadBill()
  }

  private async loadBill(): Promise<void> {
    if (this.billId <= 0) {
      return
    }
    const bill = await AppDataApi.getInstance().queryBillById(this.billId)
    if (bill === null) {
      this.getUIContext().getPromptAction().showToast({ message: '账单不存在或已删除' })
      return
    }
    this.loadedBill = bill
    this.billType = bill.type
    this.amountText = AmountUtil.fen2Display(bill.amount)
    this.selectedCategory = bill.category
    this.selectedCategoryId = bill.categoryId
    this.selectedDate = bill.date.length > 0 ? bill.date : (bill.createdAt > 0 ? DateUtil.format(new Date(bill.createdAt)) : DateUtil.today())
    this.remark = bill.remark
    this.selectedAccountId = bill.paymentAccountId === undefined ? 0 : bill.paymentAccountId
    this.selectedAccountName = bill.paymentAccountName === undefined ? '' : bill.paymentAccountName
    this.applySelectedAccountMeta()
    LogUtils.info(BILL_DETAIL_TAG,
      '账单详情加载 id=%{public}s type=%{public}s category=%{public}s date=%{public}s accountId=%{public}s account=%{public}s createdAt=%{public}s',
      bill.id.toString(), bill.type, bill.category, this.selectedDate, this.selectedAccountId.toString(), this.selectedAccountName,
      bill.createdAt.toString())
  }

  private async loadCategories(): Promise<void> {
    this.expenseCategories = await AppDataApi.getInstance().queryCategoriesByType('expense')
    this.incomeCategories = await AppDataApi.getInstance().queryCategoriesByType('income')
  }

  private async loadAccounts(): Promise<void> {
    this.accountOptionsList = await AppDataApi.getInstance().queryEnabledPaymentAccounts()
    this.applySelectedAccountMeta()
  }

  private currentCategories(): CategoryRecord[] {
    if (this.billType === 'income') {
      return this.incomeCategories
    }
    return this.expenseCategories
  }

  private categoryLimit(): number {
    const count = this.currentCategories().length
    return Math.min(count, 8)
  }

  private accountDesc(account: PaymentAccount): string {
    if (account.tailNumber.length > 0) {
      return '尾号' + account.tailNumber
    }
    if (account.type === 'cash') {
      return '余额账户'
    }
    if (account.type === 'bank') {
      return '银行卡'
    }
    if (account.type === 'alipay' || account.type === 'wechat') {
      return '电子账户'
    }
    return '其他账户'
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

  private applySelectedAccountMeta(): void {
    for (let i = 0; i < this.accountOptionsList.length; i++) {
      const item = this.accountOptionsList[i]
      if (item.id === this.selectedAccountId) {
        this.selectedAccountName = item.name
        this.selectedAccountDesc = this.accountDesc(item)
        this.selectedAccountType = item.type
        this.selectedAccountColor = item.color.length > 0 ? item.color : '#64748B'
        return
      }
    }
  }

  private selectedAccountDisplayText(): string {
    if (this.selectedAccountName.length <= 0) {
      return '未选择账户'
    }
    if (this.selectedAccountDesc.length > 0) {
      return this.selectedAccountName + ' · ' + this.selectedAccountDesc
    }
    return this.selectedAccountName
  }

  private detailDateText(): string {
    if (this.selectedDate.length > 0) {
      return this.selectedDate
    }
    const bill = this.loadedBill
    if (bill !== null && bill.createdAt > 0) {
      return DateUtil.format(new Date(bill.createdAt))
    }
    return ''
  }

  private detailAccountText(): string {
    if (this.selectedAccountName.length > 0) {
      return this.selectedAccountDisplayText()
    }
    const bill = this.loadedBill
    if (bill !== null) {
      const accountName = bill.paymentAccountName === undefined ? '' : bill.paymentAccountName
      if (accountName.length > 0) {
        return accountName
      }
    }
    return '未选择账户'
  }

  private filterAmount(value: string): string {
    let filtered = value.replace(/[^0-9.]/g, '')
    const dotIndex = filtered.indexOf('.')
    if (dotIndex !== -1) {
      const beforeDot = filtered.substring(0, dotIndex + 1)
      const afterDot = filtered.substring(dotIndex + 1).replace(/\./g, '')
      filtered = beforeDot + afterDot.substring(0, 2)
    }
    if (filtered.length > 1 && filtered.startsWith('0') && !filtered.startsWith('0.')) {
      filtered = filtered.replace(/^0+/, '')
    }
    return filtered
  }

  private createdAtText(): string {
    const bill = this.loadedBill
    if (bill === null || bill.createdAt <= 0) {
      return '--'
    }
    const date = new Date(bill.createdAt)
    const y = date.getFullYear().toString()
    const m = (date.getMonth() + 1).toString().padStart(2, '0')
    const d = date.getDate().toString().padStart(2, '0')
    const h = date.getHours().toString().padStart(2, '0')
    const min = date.getMinutes().toString().padStart(2, '0')
    return y + '-' + m + '-' + d + ' ' + h + ':' + min
  }

  private displayAmountFen(): number {
    if (this.editMode) {
      return AmountUtil.yuan2Fen(this.amountText)
    }
    const bill = this.loadedBill
    if (bill === null) {
      return 0
    }
    return bill.amount
  }

  private async saveEdit(): Promise<void> {
    try {
      const oldBill = this.loadedBill
      if (oldBill === null) {
        this.getUIContext().getPromptAction().showToast({ message: '账单不存在' })
        return
      }
      const fen = AmountUtil.yuan2Fen(this.amountText)
      if (fen <= 0) {
        this.getUIContext().getPromptAction().showToast({ message: '金额必须大于0' })
        return
      }
      if (this.selectedCategory.length === 0) {
        this.getUIContext().getPromptAction().showToast({ message: '请选择分类' })
        return
      }
      if (this.selectedAccountId <= 0) {
        this.getUIContext().getPromptAction().showToast({ message: '请选择账户' })
        return
      }
      let categoryId = this.selectedCategoryId
      if (categoryId <= 0) {
        const categoryRecord = await AppDataApi.getInstance().queryCategoryByName(this.selectedCategory, this.billType)
        categoryId = categoryRecord === null ? 0 : categoryRecord.id
      }
      let nextDate = this.selectedDate
      if (nextDate.length <= 0) {
        nextDate = DateUtil.today()
      }
      const hostContext = this.getUIContext().getHostContext()
      const nextBill: Bill = {
        id: oldBill.id,
        amount: fen,
        type: this.billType,
        category: this.selectedCategory,
        categoryId: categoryId,
        paymentAccountId: this.selectedAccountId,
        paymentAccountName: this.selectedAccountName,
        remark: this.remark,
        date: nextDate,
        createdAt: oldBill.createdAt > 0 ? oldBill.createdAt : Date.now()
      }
      await AppDataApi.getInstance().updateBill(hostContext ? hostContext : null, nextBill, true)
      this.getUIContext().getPromptAction().showToast({ message: '账单已更新' })
      this.editMode = false
      await this.loadBill()
    } catch (err) {
      LogUtils.error(BILL_DETAIL_TAG, '保存账单编辑失败 error=%{public}s', JSON.stringify(err))
      this.getUIContext().getPromptAction().showToast({ message: '保存失败，请查看日志' })
    }
  }

  private async deleteBill(): Promise<void> {
    const bill = this.loadedBill
    if (bill === null) {
      return
    }
    try {
      const hostContext = this.getUIContext().getHostContext()
      await AppDataApi.getInstance().deleteBill(bill.id, hostContext ? hostContext : null, true)
      this.getUIContext().getPromptAction().showToast({ message: '账单已删除' })
      this.showDeleteConfirm = false
      this.onDeleted()
    } catch (err) {
      LogUtils.error(BILL_DETAIL_TAG, '删除账单失败 error=%{public}s', JSON.stringify(err))
      this.getUIContext().getPromptAction().showToast({ message: '删除失败，请查看日志' })
    }
  }

  private showDatePicker(): void {
    const parts = this.selectedDate.split('-')
    const selectedYear = parts.length === 3 ? parseInt(parts[0], 10) : new Date().getFullYear()
    const selectedMonth = parts.length === 3 ? parseInt(parts[1], 10) - 1 : new Date().getMonth()
    const selectedDay = parts.length === 3 ? parseInt(parts[2], 10) : new Date().getDate()
    this.getUIContext().showDatePickerDialog({
      start: new Date('2020-01-01'),
      end: new Date('2035-12-31'),
      selected: new Date(selectedYear, selectedMonth, selectedDay),
      lunar: false,
      onDateAccept: (value: Date) => {
        const y = value.getFullYear()
        const m = (value.getMonth() + 1).toString().padStart(2, '0')
        const d = value.getDate().toString().padStart(2, '0')
        this.selectedDate = y.toString() + '-' + m + '-' + d
      }
    })
  }

  @Builder
  Header() {
    Row() {
      Row() {
        Image($rawfile('icon_chevron_left.svg'))
          .width(22)
          .height(22)
          .fillColor($r('app.color.color_text_deep'))
      }
      .width(42)
      .height(42)
      .justifyContent(FlexAlign.Center)
      .onClick(() => {
        if (this.editMode) {
          this.editMode = false
          this.loadBill().catch(() => {})
        } else {
          this.onBack()
        }
      })

      Blank()

      Text(this.editMode ? '编辑账单' : '账单详情')
        .fontSize(23)
        .fontWeight(FontWeight.Bolder)
        .fontColor($r('app.color.color_text_deep'))

      Blank()

      Text(this.editMode ? '保存' : '编辑')
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.color_primary'))
        .width(42)
        .textAlign(TextAlign.Center)
        .onClick(() => {
          if (this.editMode) {
            this.saveEdit().catch(() => {})
          } else {
            this.editMode = true
          }
        })
    }
    .width('100%')
    .height(52)
    .padding({ left: 12, right: 12 })
    .margin({ top: this.sbHeight + 4, bottom: 6 })
  }

  @Builder
  SummaryCard() {
    Column() {
      Row() {
        Row() {
          Image($rawfile(getCategoryInfo(this.selectedCategory).icon + '.svg'))
            .width(24)
            .height(24)
            .fillColor($r('app.color.color_white'))
        }
        .width(46)
        .height(46)
        .borderRadius(23)
        .backgroundColor(getCategoryColor(this.selectedCategory))
        .justifyContent(FlexAlign.Center)
        .margin({ right: 12 })

        Column() {
          Text(this.selectedCategory.length > 0 ? this.selectedCategory : '未选择分类')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.color_text_deep'))
          Text(this.remark.length > 0 ? this.remark : '未填写备注')
            .fontSize(12)
            .fontColor($r('app.color.color_text_secondary'))
            .margin({ top: 3 })
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Text(this.billType === 'income' ? '收入' : '支出')
          .fontSize(12)
          .fontColor(this.billType === 'income' ? $r('app.color.color_income') : $r('app.color.color_expense'))
          .height(24)
          .padding({ left: 10, right: 10 })
          .borderRadius(12)
          .backgroundColor($r('app.color.color_soft_blue'))
      }
      .width('100%')

      Text((this.billType === 'income' ? '+¥' : '-¥') + AmountUtil.fen2Display(this.displayAmountFen()))
        .fontSize(34)
        .fontWeight(FontWeight.Bolder)
        .fontColor(this.billType === 'income' ? $r('app.color.color_income') : $r('app.color.color_expense'))
        .width('100%')
        .margin({ top: 14 })

      Row() {
        this.MiniInfo('日期', this.detailDateText().length > 0 ? this.detailDateText() : '--')
        Divider().vertical(true).height(30).color($r('app.color.color_divider'))
        this.MiniInfo('账户', this.detailAccountText())
      }
      .width('100%')
      .margin({ top: 12 })
    }
    .width('calc(100% - 32vp)')
    .padding({ left: 16, right: 16, top: 16, bottom: 14 })
    .backgroundColor($r('app.color.color_card_overlay'))
    .borderRadius(20)
    .border({ width: 1, color: $r('app.color.color_divider') })
    .shadow({ radius: 10, color: $r('app.color.color_shadow_blue_09'), offsetX: 0, offsetY: 4 })
  }

  @Builder
  MiniInfo(label: string, value: string) {
    Column() {
      Text(label)
        .fontSize(11)
        .fontColor($r('app.color.color_text_secondary'))
      Text(value)
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.color_text_deep'))
        .margin({ top: 3 })
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  DetailRow(label: string, value: string, icon: ResourceStr) {
    Row() {
      Image(icon)
        .width(18)
        .height(18)
        .fillColor($r('app.color.color_primary'))
        .margin({ right: 12 })
      Text(label)
        .fontSize(15)
        .fontColor($r('app.color.color_text_deep'))
      Blank()
      Text(value)
        .fontSize(14)
        .fontColor($r('app.color.color_text_secondary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .height(46)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  DetailCard() {
    Column() {
      Text('账单信息')
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.color_text_deep'))
        .width('100%')
        .margin({ bottom: 6 })
      this.DetailRow('类型', this.billType === 'income' ? '收入' : '支出', $rawfile('icon_tab_stats.svg'))
      Divider().color($r('app.color.color_divider'))
      this.DetailRow('分类', this.selectedCategory, $rawfile('icon_list.svg'))
      Divider().color($r('app.color.color_divider'))
      this.DetailRow('账户', this.detailAccountText(), this.iconForAccountType(this.selectedAccountType))
      Divider().color($r('app.color.color_divider'))
      this.DetailRow('日期', this.detailDateText().length > 0 ? this.detailDateText() : '--', $rawfile('icon_calendar.svg'))
      Divider().color($r('app.color.color_divider'))
      this.DetailRow('创建时间', this.createdAtText(), $rawfile('icon_calendar.svg'))
      Divider().color($r('app.color.color_divider'))
      this.DetailRow('备注', this.remark.length > 0 ? this.remark : '未填写备注', $rawfile('icon_edit.svg'))
    }
    .width('calc(100% - 32vp)')
    .padding({ left: 16, right: 16, top: 14, bottom: 12 })
    .backgroundColor($r('app.color.color_card_overlay'))
    .borderRadius(20)
    .border({ width: 1, color: $r('app.color.color_divider') })
    .shadow({ radius: 10, color: $r('app.color.color_shadow_blue_09'), offsetX: 0, offsetY: 4 })
    .margin({ top: 12 })
  }

  @Builder
  TypeButton(label: string, type: 'income' | 'expense') {
    Text(label)
      .fontSize(15)
      .fontWeight(FontWeight.Medium)
      .fontColor(this.billType === type ? $r('app.color.color_white') : $r('app.color.color_text_secondary'))
      .textAlign(TextAlign.Center)
      .layoutWeight(1)
      .height(38)
      .borderRadius(19)
      .backgroundColor(this.billType === type ? $r('app.color.color_primary') : Color.Transparent)
      .onClick(() => {
        if (this.billType !== type) {
          this.billType = type
          this.selectedCategory = ''
          this.selectedCategoryId = 0
        }
      })
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
      this.selectedCategoryId = item.id
    })
  }

  @Builder
  EditFormCard() {
    Column() {
      Row() {
        this.TypeButton('支出', 'expense')
        this.TypeButton('收入', 'income')
      }
      .width('100%')
      .height(42)
      .padding(2)
      .borderRadius(21)
      .backgroundColor($r('app.color.color_soft_blue'))

      Row() {
        Text('¥')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.color_text_deep'))
          .margin({ right: 8 })
        TextInput({ text: this.amountText, placeholder: '0.00' })
          .type(InputType.NUMBER_DECIMAL)
          .fontSize(26)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.color_text_deep'))
          .backgroundColor(Color.Transparent)
          .border({ width: 0 })
          .padding(0)
          .layoutWeight(1)
          .caretColor($r('app.color.color_primary'))
          .onChange((value: string) => {
            this.amountText = this.filterAmount(value)
          })
      }
      .width('100%')
      .height(54)
      .margin({ top: 12 })

      this.EditLine('账户', this.selectedAccountDisplayText(), this.iconForAccountType(this.selectedAccountType), () => {
        this.showAccountSheet = true
      })
      this.EditLine('日期', this.selectedDate.length > 0 ? this.selectedDate : '选择日期', $rawfile('icon_calendar.svg'), () => {
        this.showDatePicker()
      })

      Row() {
        Image($rawfile('icon_edit.svg'))
          .width(18)
          .height(18)
          .fillColor($r('app.color.color_icon_muted'))
          .margin({ right: 12 })
        Text('备注')
          .fontSize(15)
          .fontColor($r('app.color.color_text_deep'))
          .width(48)
        TextInput({ text: this.remark, placeholder: '请输入备注' })
          .layoutWeight(1)
          .fontSize(14)
          .fontColor($r('app.color.color_text_deep'))
          .placeholderColor($r('app.color.color_text_muted'))
          .backgroundColor(Color.Transparent)
          .border({ width: 0 })
          .padding(0)
          .maxLength(50)
          .onChange((value: string) => {
            this.remark = value
          })
      }
      .width('100%')
      .height(46)
      .alignItems(VerticalAlign.Center)

      Text('分类')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.color_text_deep'))
        .width('100%')
        .margin({ top: 8, bottom: 8 })

      Grid() {
        ForEach(this.currentCategories(), (item: CategoryRecord, index: number) => {
          if (index < this.categoryLimit()) {
            GridItem() {
              this.CategoryTile(item)
            }
          }
        }, (item: CategoryRecord) => item.id.toString())
      }
      .columnsTemplate('1fr 1fr 1fr 1fr')
      .rowsGap(8)
      .columnsGap(6)
      .width('100%')
      .height(116)
    }
    .width('calc(100% - 32vp)')
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .backgroundColor($r('app.color.color_card_overlay'))
    .borderRadius(20)
    .border({ width: 1, color: $r('app.color.color_divider') })
    .shadow({ radius: 10, color: $r('app.color.color_shadow_blue_09'), offsetX: 0, offsetY: 4 })
    .margin({ top: 12 })
  }

  @Builder
  EditLine(label: string, value: string, icon: ResourceStr, action: () => void) {
    Row() {
      Image(icon)
        .width(18)
        .height(18)
        .fillColor($r('app.color.color_primary'))
        .margin({ right: 12 })
      Text(label)
        .fontSize(15)
        .fontColor($r('app.color.color_text_deep'))
      Blank()
      Text(value)
        .fontSize(14)
        .fontColor($r('app.color.color_text_secondary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .margin({ left: 12, right: 6 })
      Image($rawfile('icon_chevron_right.svg'))
        .width(14)
        .height(14)
        .fillColor($r('app.color.color_text_muted'))
    }
    .width('100%')
    .height(46)
    .alignItems(VerticalAlign.Center)
    .onClick(action)
  }

  @Builder
  ActionButtons() {
    Column({ space: 10 }) {
      if (this.editMode) {
        Button('保存修改')
          .width('100%')
          .height(46)
          .fontSize(16)
          .fontColor($r('app.color.color_white'))
          .backgroundColor($r('app.color.color_primary'))
          .borderRadius(16)
          .onClick(() => {
            this.saveEdit().catch(() => {})
          })
      } else {
        Button('编辑账单')
          .width('100%')
          .height(46)
          .fontSize(16)
          .fontColor($r('app.color.color_white'))
          .backgroundColor($r('app.color.color_primary'))
          .borderRadius(16)
          .onClick(() => {
            this.editMode = true
          })
      }

      Button('删除账单')
        .width('100%')
        .height(44)
        .fontSize(15)
        .fontColor($r('app.color.color_expense'))
        .backgroundColor(Color.Transparent)
        .border({ width: 1, color: $r('app.color.color_expense') })
        .borderRadius(16)
        .onClick(() => {
          this.showDeleteConfirm = true
        })
    }
    .width('calc(100% - 32vp)')
    .margin({ top: 12, bottom: 24 })
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
      Column() {
        Text(item.name)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.color_text_deep'))
          .maxLines(1)
        Text(this.accountDesc(item) + ' · ¥' + AmountUtil.fen2Display(item.manualBalance))
          .fontSize(11)
          .fontColor($r('app.color.color_text_secondary'))
          .margin({ top: 2 })
          .maxLines(1)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .margin({ left: 12 })

      if (this.selectedAccountId === item.id) {
        Image($rawfile('icon_check.svg'))
          .width(20)
          .height(20)
          .fillColor($r('app.color.color_primary'))
      } else {
        Row()
          .width(20)
          .height(20)
          .borderRadius(10)
          .border({ width: 1, color: $r('app.color.color_divider') })
      }
    }
    .width('100%')
    .height(56)
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
          .margin({ top: 10, bottom: 14 })

        Text('选择账户')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.color_text_deep'))
        Text('编辑后会自动回滚旧账户余额并写入新账户余额')
          .fontSize(12)
          .fontColor($r('app.color.color_text_secondary'))
          .margin({ top: 5, bottom: 12 })

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

        Button('关闭')
          .width('100%')
          .height(46)
          .fontSize(16)
          .fontColor($r('app.color.color_primary'))
          .backgroundColor(Color.Transparent)
          .border({ width: 1, color: $r('app.color.color_divider') })
          .borderRadius(16)
          .margin({ top: 12 })
          .onClick(() => {
            this.showAccountSheet = false
          })
      }
      .width('100%')
      .padding({ left: 22, right: 22, bottom: 18 })
      .backgroundColor($r('app.color.color_surface'))
      .borderRadius({ topLeft: 26, topRight: 26 })
    }
    .width('100%')
    .height('100%')
    .transition(
      TransitionEffect.asymmetric(
        TransitionEffect.OPACITY.combine(TransitionEffect.translate({ y: 360 }))
          .animation({ duration: 260, curve: Curve.EaseOut }),
        TransitionEffect.OPACITY.combine(TransitionEffect.translate({ y: 360 }))
          .animation({ duration: 200, curve: Curve.EaseIn })
      )
    )
  }

  @Builder
  DeleteConfirmDialog() {
    Stack({ alignContent: Alignment.Center }) {
      Row()
        .width('100%')
        .height('100%')
        .backgroundColor('#66000000')
        .onClick(() => {
          this.showDeleteConfirm = false
        })

      Column() {
        Text('删除账单')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.color_text_deep'))
        Text('删除后会同步回滚账户余额，并尝试删除云端账单。')
          .fontSize(13)
          .fontColor($r('app.color.color_text_secondary'))
          .textAlign(TextAlign.Center)
          .margin({ top: 8, bottom: 18 })
        Row({ space: 12 }) {
          Button('取消')
            .height(42)
            .layoutWeight(1)
            .fontColor($r('app.color.color_primary'))
            .backgroundColor(Color.Transparent)
            .border({ width: 1, color: $r('app.color.color_divider') })
            .borderRadius(14)
            .onClick(() => {
              this.showDeleteConfirm = false
            })
          Button('确认删除')
            .height(42)
            .layoutWeight(1)
            .fontColor($r('app.color.color_white'))
            .backgroundColor($r('app.color.color_expense'))
            .borderRadius(14)
            .onClick(() => {
              this.deleteBill().catch(() => {})
            })
        }
        .width('100%')
      }
      .width('calc(100% - 64vp)')
      .padding({ left: 18, right: 18, top: 22, bottom: 18 })
      .backgroundColor($r('app.color.color_surface'))
      .borderRadius(22)
    }
    .width('100%')
    .height('100%')
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      WaterPageBg()

      Column() {
        this.Header()

        Scroll() {
          Column() {
            this.SummaryCard()
            if (this.editMode) {
              this.EditFormCard()
            } else {
              this.DetailCard()
            }
            this.ActionButtons()
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
      }
      .width('100%')
      .height('100%')

      if (this.showAccountSheet) {
        this.AccountSheet()
      }
      if (this.showDeleteConfirm) {
        this.DeleteConfirmDialog()
      }
    }
    .width('100%')
    .height('100%')
  }
}
