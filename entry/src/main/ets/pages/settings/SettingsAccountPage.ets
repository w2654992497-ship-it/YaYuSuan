import { createEmptyPaymentAccount, PaymentAccount, PaymentAccountType } from '../../model/PaymentAccount'
import { FilterOptions } from '../../model/FilterOptions'
import { WaterPageBg } from '../../components/WaterPageBg'
import { AppDataApi } from '../../services/AppDataApi'
import { AmountUtil } from '../../utils/AmountUtil'
import { DateUtil } from '../../utils/DateUtil'
import { LogUtils } from '../../utils/LogUtils'

const ACCOUNT_PAGE_TAG = 'SettingsAccountPage'

@Component
export struct SettingsAccountPage {
  @Consume('appNavStack') navStack: NavPathStack
  @Prop sbHeight: number
  onBack: () => void = (): void => {}
  @State accounts: PaymentAccount[] = []
  @State accountFilter: string = 'all'
  @State monthOutflow: number = 0
  @State showActionSheet: boolean = false
  @State selectedAccountId: number = -1
  @StorageProp('paymentAccountVersion') @Watch('onPaymentAccountVersionChanged') paymentAccountVersion: number = 0

  async aboutToAppear(): Promise<void> {
    await this.loadAccounts()
  }

  onPaymentAccountVersionChanged(): void {
    this.loadAccounts()
  }

  private async loadAccounts(): Promise<void> {
    try {
      this.accounts = await AppDataApi.getInstance().queryPaymentAccounts()
      await this.loadMonthOutflow()
      LogUtils.info(ACCOUNT_PAGE_TAG, `账户页面加载完成 count=${this.accounts.length}`)
    } catch (err) {
      LogUtils.error(ACCOUNT_PAGE_TAG, `账户页面加载失败：${this.formatError(err)}`)
      this.showToast('账户数据加载失败')
    }
  }

  private async loadMonthOutflow(): Promise<void> {
    try {
      const filter: FilterOptions = {
        month: DateUtil.currentMonth(),
        type: 'expense',
        category: ''
      }
      const bills = await AppDataApi.getInstance().queryBills(filter)
      let total = 0
      for (let i = 0; i < bills.length; i++) {
        total += bills[i].amount
      }
      this.monthOutflow = total
    } catch (err) {
      LogUtils.error(ACCOUNT_PAGE_TAG, `账户页读取本月流出失败：${this.formatError(err)}`)
      this.monthOutflow = 0
    }
  }

  private showToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message, duration: 1800 })
    } catch (err) {
      LogUtils.error(ACCOUNT_PAGE_TAG, `Toast显示失败：${this.formatError(err)}`)
    }
  }

  private formatError(err: Error | Object): string {
    try {
      return JSON.stringify(err)
    } catch (jsonErr) {
      return `${err}`
    }
  }

  private headerTopPadding(): number {
    if (this.sbHeight > 0) {
      return this.sbHeight + 2
    }
    return 18
  }

  private headerHeight(): number {
    return this.headerTopPadding() + 48
  }

  private totalManualBalance(): number {
    let total = 0
    for (let i = 0; i < this.accounts.length; i++) {
      if (this.accounts[i].enabled === 1) {
        total += this.accounts[i].manualBalance
      }
    }
    return total
  }

  private enabledAccountCount(): number {
    let count = 0
    for (let i = 0; i < this.accounts.length; i++) {
      if (this.accounts[i].enabled === 1) {
        count++
      }
    }
    return count
  }

  private visibleAccounts(): PaymentAccount[] {
    const result: PaymentAccount[] = []
    for (let i = 0; i < this.accounts.length; i++) {
      const account = this.accounts[i]
      if (this.accountFilter === 'asset') {
        if (this.isAssetAccount(account.type)) {
          result.push(account)
        }
      } else if (this.accountFilter === 'payment') {
        if (this.isPaymentAccount(account.type)) {
          result.push(account)
        }
      } else {
        result.push(account)
      }
    }
    return result
  }

  private isAssetAccount(type: PaymentAccountType): boolean {
    return type === 'bank' || type === 'cash' || type === 'other'
  }

  private isPaymentAccount(type: PaymentAccountType): boolean {
    return type === 'alipay' || type === 'wechat'
  }

  private accountTitle(account: PaymentAccount): string {
    if (account.tailNumber.length > 0) {
      return `${account.name}  ****${account.tailNumber}`
    }
    return account.name
  }

  private accountSubtitle(account: PaymentAccount): string {
    let text = '其他账户'
    if (account.type === 'bank') {
      text = '银行卡'
    } else if (account.type === 'cash') {
      text = '现金账户'
    } else if (account.type === 'alipay' || account.type === 'wechat') {
      text = '电子账户'
    }
    if (account.enabled === 0) {
      return `${text} · 已停用`
    }
    return text
  }

  private accountIcon(account: PaymentAccount): Resource {
    if (account.type === 'bank') {
      return $rawfile('icon_account_bank.svg')
    }
    if (account.type === 'alipay') {
      return $rawfile('icon_account_alipay.svg')
    }
    if (account.type === 'wechat') {
      return $rawfile('icon_account_wechat.svg')
    }
    if (account.type === 'cash') {
      return $rawfile('icon_account_cash.svg')
    }
    return $rawfile('icon_account_other.svg')
  }

  private accountColor(account: PaymentAccount): ResourceColor {
    if (account.color.length > 0) {
      return account.color
    }
    if (account.type === 'bank') {
      return '#D7272F'
    }
    if (account.type === 'alipay') {
      return '#1769FF'
    }
    if (account.type === 'wechat') {
      return '#15B954'
    }
    if (account.type === 'cash') {
      return '#FF970E'
    }
    return $r('app.color.color_text_secondary')
  }

  private moneyText(amount: number): string {
    if (amount < 0) {
      return `-¥${AmountUtil.rawFen2Display(0 - amount)}`
    }
    return `¥${AmountUtil.rawFen2Display(amount)}`
  }

  private findAccountById(id: number): PaymentAccount {
    for (let i = 0; i < this.accounts.length; i++) {
      if (this.accounts[i].id === id) {
        return this.accounts[i]
      }
    }
    return createEmptyPaymentAccount()
  }

  private copyAccount(account: PaymentAccount): PaymentAccount {
    return {
      id: account.id,
      userId: account.userId,
      bookId: account.bookId,
      name: account.name,
      type: account.type,
      bankName: account.bankName,
      tailNumber: account.tailNumber,
      iconMark: account.iconMark,
      color: account.color,
      manualBalance: account.manualBalance,
      balanceUpdatedAt: account.balanceUpdatedAt,
      sortOrder: account.sortOrder,
      isDefault: account.isDefault,
      enabled: account.enabled,
      createdAt: account.createdAt,
      updatedAt: account.updatedAt,
      deleted: account.deleted
    }
  }

  private openAction(account: PaymentAccount): void {
    this.selectedAccountId = account.id
    this.showActionSheet = true
  }

  private openAddAccount(): void {
    AppStorage.setOrCreate<number>('accountEditId', 0)
    this.navStack.pushPathByName('accountCreate', null)
  }

  private openEditAccount(account: PaymentAccount): void {
    AppStorage.setOrCreate<number>('accountEditId', account.id)
    this.navStack.pushPathByName('accountEdit', account.id)
  }

  private async setDefaultSelected(): Promise<void> {
    const account = this.findAccountById(this.selectedAccountId)
    if (account.id <= 0) {
      return
    }
    try {
      const hostContext = this.getUIContext().getHostContext()
      await AppDataApi.getInstance().setDefaultPaymentAccount(hostContext ? hostContext : null, account.id, true)
      this.showToast('已设为默认账户')
    } catch (err) {
      LogUtils.error(ACCOUNT_PAGE_TAG, `设置默认账户失败：${this.formatError(err)}`)
      this.showToast('设置默认账户失败')
    }
  }

  private async toggleEnabledSelected(): Promise<void> {
    const account = this.findAccountById(this.selectedAccountId)
    if (account.id <= 0) {
      return
    }
    if (account.isDefault === 1 && account.enabled === 1) {
      this.showToast('默认账户不能停用')
      return
    }
    try {
      const hostContext = this.getUIContext().getHostContext()
      await AppDataApi.getInstance().setPaymentAccountEnabled(hostContext ? hostContext : null, account.id,
        account.enabled === 1 ? 0 : 1, true)
      this.showToast(account.enabled === 1 ? '已停用账户' : '已启用账户')
    } catch (err) {
      LogUtils.error(ACCOUNT_PAGE_TAG, `账户启停失败：${this.formatError(err)}`)
      this.showToast('账户状态更新失败')
    }
  }

  private async moveSelectedTop(): Promise<void> {
    const account = this.findAccountById(this.selectedAccountId)
    if (account.id <= 0) {
      return
    }
    try {
      const hostContext = this.getUIContext().getHostContext()
      const next = this.copyAccount(account)
      next.sortOrder = 0 - Date.now()
      next.updatedAt = Date.now()
      await AppDataApi.getInstance().savePaymentAccount(hostContext ? hostContext : null, next, true)
      this.showToast('已置顶账户')
    } catch (err) {
      LogUtils.error(ACCOUNT_PAGE_TAG, `账户置顶失败：${this.formatError(err)}`)
      this.showToast('账户置顶失败')
    }
  }

  private async deleteSelected(): Promise<void> {
    const account = this.findAccountById(this.selectedAccountId)
    if (account.id <= 0) {
      return
    }
    if (this.enabledAccountCount() <= 1 && account.enabled === 1) {
      this.showToast('至少保留一个启用账户')
      return
    }
    try {
      const hostContext = this.getUIContext().getHostContext()
      await AppDataApi.getInstance().deletePaymentAccount(hostContext ? hostContext : null, account.id, true)
      this.showToast('账户已删除')
    } catch (err) {
      LogUtils.error(ACCOUNT_PAGE_TAG, `删除账户失败：${this.formatError(err)}`)
      this.showToast('删除账户失败')
    }
  }

  @Builder
  Header() {
    Stack({ alignContent: Alignment.TopEnd }) {
      Image($rawfile('illustration_fish_bowl.png'))
        .width(74)
        .height(46)
        .objectFit(ImageFit.Contain)
        .opacity(0.62)
        .margin({ top: this.headerTopPadding() - 8, right: 16 })
        .hitTestBehavior(HitTestMode.None)

      Row() {
        Image($rawfile('icon_chevron_left.svg'))
          .width(21)
          .height(21)
          .fillColor($r('app.color.color_text_primary'))
          .onClick(() => {
            this.onBack()
          })

        Text('账户管理')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.color_text_primary'))
          .layoutWeight(1)
          .textAlign(TextAlign.Center)

        Blank()
          .width(21)
      }
      .width('100%')
      .height(40)
      .padding({ left: 22, right: 22 })
      .position({ x: 0, y: this.headerTopPadding() })
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .height(this.headerHeight())
  }

  @Builder
  SummaryOverviewCard() {
    Column() {
      Row() {
        Text('账户总览')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.color_text_secondary'))

        Image($rawfile('icon_help_circle.svg'))
          .width(15)
          .height(15)
          .fillColor($r('app.color.color_text_secondary'))
          .margin({ left: 6 })

        Blank()
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Row() {
        Text(this.moneyText(this.totalManualBalance()))
          .fontSize(30)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.color_text_primary'))
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Image($rawfile('illustration_account_wallet.svg'))
          .width(58)
          .height(42)
          .objectFit(ImageFit.Contain)
          .margin({ left: 6 })
      }
      .width('100%')
      .height(48)
      .alignItems(VerticalAlign.Center)
      .margin({ top: 2 })

      Divider()
        .strokeWidth(1)
        .color($r('app.color.color_divider'))
        .margin({ top: 2, bottom: 6 })

      Row() {
        Row() {
          Image($rawfile('icon_account_cash.svg'))
            .width(20)
            .height(20)
            .fillColor($r('app.color.color_primary'))
            .margin({ right: 10 })

          Column() {
            Text('账户数')
              .fontSize(12)
              .fontColor($r('app.color.color_text_secondary'))
            Text(`${this.enabledAccountCount()}`)
              .fontSize(19)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.color_text_primary'))
              .margin({ top: 4 })
          }
          .alignItems(HorizontalAlign.Start)
        }
        .layoutWeight(1)
        .alignItems(VerticalAlign.Center)

        Divider()
          .vertical(true)
          .height(34)
          .color($r('app.color.color_divider'))

        Row() {
          Image($rawfile('icon_chevron_down.svg'))
            .width(20)
            .height(20)
            .fillColor($r('app.color.color_income'))
            .margin({ right: 10 })

          Column() {
            Text('本月流出')
              .fontSize(12)
              .fontColor($r('app.color.color_text_secondary'))
            Text(this.moneyText(this.monthOutflow))
              .fontSize(17)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.color_text_primary'))
              .margin({ top: 4 })
          }
          .alignItems(HorizontalAlign.Start)
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
      }
      .width('100%')
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 12, bottom: 10 })
    .backgroundColor($r('app.color.color_surface'))
    .borderRadius(18)
    .shadow({
      radius: 10,
      color: $r('app.color.color_shadow_blue_09'),
      offsetX: 0,
      offsetY: 4
    })
  }

  @Builder
  FilterTabs() {
    Row() {
      this.FilterTab('全部', 'all')
      this.FilterTab('资产', 'asset')
      this.FilterTab('支付', 'payment')
    }
    .width('60%')
    .height(36)
    .padding(3)
    .backgroundColor($r('app.color.color_surface'))
    .borderRadius(26)
    .shadow({
      radius: 8,
      color: $r('app.color.color_shadow_blue_09'),
      offsetX: 0,
      offsetY: 6
    })
  }

  @Builder
  FilterTab(title: string, key: string) {
    Text(title)
      .fontSize(14)
      .fontWeight(FontWeight.Medium)
      .fontColor(this.accountFilter === key ? Color.White : $r('app.color.color_text_secondary'))
      .textAlign(TextAlign.Center)
      .layoutWeight(1)
      .height('100%')
      .borderRadius(22)
      .backgroundColor(this.accountFilter === key ? $r('app.color.color_primary') : Color.Transparent)
      .onClick(() => {
        this.accountFilter = key
      })
  }

  @Builder
  AccountLogo(account: PaymentAccount) {
    Stack() {
      Image(this.accountIcon(account))
        .width(24)
        .height(24)
        .fillColor(Color.White)
    }
    .width(38)
    .height(38)
    .borderRadius(10)
    .backgroundColor(this.accountColor(account))
    .opacity(account.enabled === 1 ? 1 : 0.45)
    .alignContent(Alignment.Center)
  }

  @Builder
  AccountRow(account: PaymentAccount, showDivider: boolean) {
    Column() {
      Row() {
        this.AccountLogo(account)

        Column() {
          Row() {
            Text(this.accountTitle(account))
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.color_text_primary'))
              .layoutWeight(1)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })

            if (account.isDefault === 1) {
              Text('默认')
                .fontSize(11)
                .fontColor(Color.White)
                .padding({ left: 7, right: 7, top: 2, bottom: 2 })
                .backgroundColor($r('app.color.color_primary'))
                .borderRadius(10)
                .margin({ left: 6 })
            }
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)

          Text(this.accountSubtitle(account))
            .fontSize(12)
            .fontColor($r('app.color.color_text_secondary'))
            .margin({ top: 4 })
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        .margin({ left: 10, right: 5 })

        Text(this.moneyText(account.manualBalance))
          .width(84)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.color_text_primary'))
          .textAlign(TextAlign.End)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ right: 8 })

        Image($rawfile('icon_chevron_right.svg'))
          .width(14)
          .height(14)
          .fillColor($r('app.color.color_text_secondary'))
      }
      .width('100%')
      .height(58)
      .alignItems(VerticalAlign.Center)
      .onClick(() => {
        this.openAction(account)
      })

      if (showDivider) {
        Divider()
          .strokeWidth(1)
          .color($r('app.color.color_divider'))
          .margin({ left: 48 })
      }
    }
    .width('100%')
  }

  @Builder
  EmptyAccountCard() {
    Column() {
      Text('暂无账户')
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.color_text_primary'))
      Text('点击下方按钮新增一个账户')
        .fontSize(14)
        .fontColor($r('app.color.color_text_secondary'))
        .margin({ top: 6 })
    }
    .width('100%')
    .height(120)
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  AccountListCard() {
    Column() {
      if (this.visibleAccounts().length === 0) {
        this.EmptyAccountCard()
      } else {
        ForEach(this.visibleAccounts(), (account: PaymentAccount, index: number) => {
          this.AccountRow(account, index < this.visibleAccounts().length - 1)
        }, (account: PaymentAccount) => `${account.id}_${account.updatedAt}`)
      }
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 6, bottom: 6 })
    .backgroundColor($r('app.color.color_surface'))
    .borderRadius(18)
    .shadow({
      radius: 10,
      color: $r('app.color.color_shadow_blue_09'),
      offsetX: 0,
      offsetY: 6
    })
  }

  @Builder
  AddAccountButton() {
    Button('+ 新增账户')
      .width('100%')
      .height(46)
      .fontSize(17)
      .fontWeight(FontWeight.Bold)
      .fontColor(Color.White)
      .backgroundColor($r('app.color.color_primary'))
      .borderRadius(18)
      .onClick(() => {
        this.openAddAccount()
      })
  }

  @Builder
  ActionSheet() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#66000000')
        .onClick(() => {
          this.showActionSheet = false
        })

      Column() {
        Blank()
          .width(42)
          .height(5)
          .backgroundColor('#D8DEE8')
          .borderRadius(3)
          .margin({ top: 10, bottom: 16 })

        Text('账户操作')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.color_text_primary'))

        this.ActionAccountPreview(this.findAccountById(this.selectedAccountId))

        this.ActionRow('设为默认账户', $rawfile('icon_action_star.svg'), $r('app.color.color_primary'), async (): Promise<void> => {
          await this.setDefaultSelected()
        })
        this.ActionRow('编辑账户', $rawfile('icon_edit.svg'), $r('app.color.color_primary'), (): void => {
          this.openEditAccount(this.findAccountById(this.selectedAccountId))
        })
        this.ActionRow('排序到顶部', $rawfile('icon_action_sort_top.svg'), $r('app.color.color_text_secondary'), async (): Promise<void> => {
          await this.moveSelectedTop()
        })
        this.ActionRow(this.findAccountById(this.selectedAccountId).enabled === 1 ? '停用账户' : '启用账户',
          $rawfile('icon_action_hide.svg'), $r('app.color.color_text_secondary'), async (): Promise<void> => {
            await this.toggleEnabledSelected()
          })
        this.ActionRow('删除账户', $rawfile('icon_action_delete.svg'), $r('app.color.color_expense'), async (): Promise<void> => {
          await this.deleteSelected()
        })

        Button('取消')
          .width('100%')
          .height(48)
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.color_primary'))
          .backgroundColor($r('app.color.color_surface'))
          .borderRadius(16)
          .margin({ top: 14, bottom: 18 })
          .onClick(() => {
            this.showActionSheet = false
          })
      }
      .width('100%')
      .padding({ left: 24, right: 24 })
      .backgroundColor(Color.White)
      .borderRadius({ topLeft: 28, topRight: 28 })
    }
    .width('100%')
    .height('100%')
    .transition(TransitionEffect.opacity(0.18))
  }

  @Builder
  ActionAccountPreview(account: PaymentAccount) {
    Row() {
      this.AccountLogo(account)
      Column() {
        Text(this.accountTitle(account))
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.color_text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.accountSubtitle(account))
          .fontSize(14)
          .fontColor($r('app.color.color_text_secondary'))
          .margin({ top: 4 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .margin({ left: 14 })
    }
    .width('100%')
    .padding(12)
    .backgroundColor($r('app.color.color_bg'))
    .borderRadius(14)
    .margin({ top: 18, bottom: 8 })
  }

  @Builder
  ActionRow(title: string, icon: Resource, color: ResourceColor, handler: () => void | Promise<void>) {
    Row() {
      Image(icon)
        .width(22)
        .height(22)
        .fillColor(color)
        .margin({ right: 16 })
      Text(title)
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor(color)
        .layoutWeight(1)
    }
    .width('100%')
    .height(52)
    .onClick(() => {
      this.showActionSheet = false
      handler()
    })
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      WaterPageBg()

      Column() {
        this.Header()

        Scroll() {
          Column({ space: 8 }) {
            this.SummaryOverviewCard()
            this.FilterTabs()
            this.AccountListCard()
            this.AddAccountButton()
          }
          .width('100%')
          .padding({ left: 16, right: 16, bottom: 22 })
          .alignItems(HorizontalAlign.Center)
        }
        .width('100%')
        .align(Alignment.Top)
      }
      .width('100%')
      .height('100%')
      .alignItems(HorizontalAlign.Center)

      if (this.showActionSheet) {
        this.ActionSheet()
      }
    }
    .width('100%')
    .height('100%')
  }
}
