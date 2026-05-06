import { AmountUtil } from '../../utils/AmountUtil'
import { PaymentAccount, PaymentAccountType } from '../../model/PaymentAccount'
import { AppDataApi } from '../../services/AppDataApi'
import { LogUtils } from '../../utils/LogUtils'
import { BudgetOverview, createEmptyBudgetOverview } from '../../model/BudgetRule'

const SETTINGS_MAIN_TAG = 'SettingsMainPage'

@Component
struct SettingsBudgetMiniCard {
  @Prop title: string
  @Prop periodType: string
  @Prop totalFen: number = 0
  @Prop usedFen: number = 0
  @Prop remainFen: number = 0
  @Prop percent: number = 0
  @Prop activeRuleCount: number = 0
  @Prop categoryBudgetFen: number = 0

  private money(fen: number): string {
    return '¥' + AmountUtil.rawFen2Display(fen)
  }

  private hasBudget(): boolean {
    return this.totalFen > 0 || this.categoryBudgetFen > 0 || this.activeRuleCount > 0
  }

  private displayTotalFen(): number {
    if (this.totalFen > 0) {
      return this.totalFen
    }
    if (this.categoryBudgetFen > 0) {
      return this.categoryBudgetFen
    }
    return 0
  }

  private amountText(): string {
    const totalFen = this.displayTotalFen()
    if (totalFen <= 0) {
      return '未设置'
    }
    return this.money(totalFen)
  }

  private remainText(): string {
    if (this.displayTotalFen() <= 0) {
      return '--'
    }
    return this.money(this.remainFen)
  }

  private percentText(): string {
    if (this.displayTotalFen() <= 0) {
      return '--'
    }
    return this.percent.toString() + '%'
  }

  private progressWidth(): string {
    if (this.displayTotalFen() <= 0 || this.percent <= 0) {
      return '0%'
    }
    if (this.percent >= 100) {
      return '100%'
    }
    return this.percent.toString() + '%'
  }

  private color(): ResourceColor {
    if (this.periodType === 'month') {
      return '#FF8A00'
    }
    if (this.periodType === 'year') {
      return '#7C3AED'
    }
    return '#1765F5'
  }

  build() {
    Column() {
      Row() {
        Image($rawfile('icon_calendar.svg'))
          .width(13)
          .height(13)
          .fillColor(this.color())
        Text(this.title)
          .fontSize(11)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.color_text_primary'))
          .margin({ left: 4 })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Text(this.amountText())
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.hasBudget() ? $r('app.color.color_text_deep') : $r('app.color.color_text_secondary'))
        .width('100%')
        .margin({ top: 9, bottom: 8 })
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Row() {
        Text('已用')
          .fontSize(10)
          .fontColor($r('app.color.color_text_secondary'))
        Blank()
        Text(this.money(this.usedFen))
          .fontSize(10)
          .fontColor($r('app.color.color_text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .margin({ bottom: 4 })

      Row() {
        Text('剩余')
          .fontSize(10)
          .fontColor($r('app.color.color_text_secondary'))
        Blank()
        Text(this.remainText())
          .fontSize(10)
          .fontColor(this.color())
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .margin({ bottom: 7 })

      Row() {
        Stack({ alignContent: Alignment.Start }) {
          Row()
            .width('100%')
            .height(5)
            .borderRadius(3)
            .backgroundColor($r('app.color.color_track'))
          Row()
            .width(this.progressWidth())
            .height(5)
            .borderRadius(3)
            .backgroundColor(this.color())
        }
        .width('100%')
        .height(5)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
    .layoutWeight(1)
    .height(118)
    .padding({ left: 8, right: 8, top: 10, bottom: 9 })
    .backgroundColor($r('app.color.color_surface'))
    .borderRadius(12)
    .border({ width: 1, color: $r('app.color.color_divider') })
    .alignItems(HorizontalAlign.Start)
  }
}

@Component
export struct SettingsMainPage {
  @Prop sbHeight: number
  @Prop currentUserName: string
  @Prop totalBudgetFen: number = 0
  @Prop usedBudgetFen: number = 0
  @Prop remainBudgetFen: number = 0
  @Prop progressWidth: string = '0%'
  @Prop budgetUsagePercent: number = 0
  @Prop setBudgetCount: number = 0
  @Prop expenseCategoryCount: number = 0
  @Prop dayBudgetOverview: BudgetOverview = createEmptyBudgetOverview()
  @Prop monthBudgetOverview: BudgetOverview = createEmptyBudgetOverview()
  @Prop yearBudgetOverview: BudgetOverview = createEmptyBudgetOverview()
  @Prop budgetRefreshVersion: number = 0
  onOpenUserData: () => void = (): void => {}
  onOpenAccount: () => void = (): void => {}
  onOpenBudget: () => void = (): void => {}
  onOpenCategory: () => void = (): void => {}
  onOpenPeriod: () => void = (): void => {}
  onOpenGeneral: () => void = (): void => {}
  onExportCsv: () => void = (): void => {}
  onLogout: () => void = (): void => {}
  @State paymentAccounts: PaymentAccount[] = []
  @Watch('onPaymentAccountVersionChanged')
  @StorageProp('paymentAccountVersion') paymentAccountVersion: number = 0

  aboutToAppear(): void {
    this.loadPaymentAccounts()
  }

  onPaymentAccountVersionChanged(): void {
    this.loadPaymentAccounts()
  }

  private async loadPaymentAccounts(): Promise<void> {
    try {
      this.paymentAccounts = await AppDataApi.getInstance().queryPaymentAccounts()
    } catch (err) {
      LogUtils.error(SETTINGS_MAIN_TAG, '\u8d26\u6237\u6570\u636e\u52a0\u8f7d\u5931\u8d25\uff1a%{public}s', JSON.stringify(err))
      this.paymentAccounts = []
    }
  }

  private accountDesc(account: PaymentAccount): string {
    if (account.tailNumber.length > 0) {
      return '\u5c3e\u53f7' + account.tailNumber
    }
    if (account.type === 'cash') {
      return '\u4f59\u989d\u8d26\u6237'
    }
    return ''
  }

  private accountDisplayName(account: PaymentAccount): string {
    const desc = this.accountDesc(account)
    if (desc.length > 0) {
      return account.name + ' \u00b7 ' + desc
    }
    return account.name
  }

  private defaultAccountName(): string {
    for (let i = 0; i < this.paymentAccounts.length; i++) {
      const item = this.paymentAccounts[i]
      if (item.isDefault === 1 && item.enabled === 1) {
        return this.accountDisplayName(item)
      }
    }
    for (let i = 0; i < this.paymentAccounts.length; i++) {
      if (this.paymentAccounts[i].enabled === 1) {
        return this.accountDisplayName(this.paymentAccounts[i])
      }
    }
    return '\u672a\u8bbe\u7f6e'
  }

  private enabledAccountCount(): number {
    let count = 0
    for (let i = 0; i < this.paymentAccounts.length; i++) {
      if (this.paymentAccounts[i].enabled === 1) {
        count += 1
      }
    }
    return count
  }

  private totalManualBalance(): number {
    let total = 0
    for (let i = 0; i < this.paymentAccounts.length; i++) {
      if (this.paymentAccounts[i].enabled === 1) {
        total += this.paymentAccounts[i].manualBalance
      }
    }
    return total
  }

  private iconForType(type: PaymentAccountType): ResourceStr {
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

  private money(fen: number): string {
    return '¥' + AmountUtil.rawFen2Display(fen)
  }

  private hasBudget(overview: BudgetOverview): boolean {
    return overview.totalFen > 0 || overview.categoryBudgetFen > 0 || overview.activeRuleCount > 0
  }

  private displayBudgetTotalFen(overview: BudgetOverview): number {
    if (overview.totalFen > 0) {
      return overview.totalFen
    }
    if (overview.categoryBudgetFen > 0) {
      return overview.categoryBudgetFen
    }
    return 0
  }

  private budgetAmountText(overview: BudgetOverview): string {
    const totalFen = this.displayBudgetTotalFen(overview)
    if (totalFen <= 0) {
      return '未设置'
    }
    return this.money(totalFen)
  }

  private budgetRemainText(overview: BudgetOverview): string {
    if (this.displayBudgetTotalFen(overview) <= 0) {
      return '--'
    }
    return this.money(overview.remainFen)
  }

  private budgetPercentText(overview: BudgetOverview): string {
    if (this.displayBudgetTotalFen(overview) <= 0) {
      return '--'
    }
    return overview.percent.toString() + '%'
  }

  private budgetProgressWidth(overview: BudgetOverview): string {
    if (this.displayBudgetTotalFen(overview) <= 0 || overview.percent <= 0) {
      return '0%'
    }
    if (overview.percent >= 100) {
      return '100%'
    }
    return overview.percent.toString() + '%'
  }

  private budgetColor(periodType: string): ResourceColor {
    if (periodType === 'month') {
      return '#FF8A00'
    }
    if (periodType === 'year') {
      return '#7C3AED'
    }
    return '#1765F5'
  }

  @Builder
  Header() {
    Stack({ alignContent: Alignment.TopEnd }) {
      Row() {
        Blank().width(24).height(24)
        Text('我的')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.color_text_primary'))
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
        Blank().width(24).height(24)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: this.sbHeight + 10, bottom: 2 })
      .alignItems(VerticalAlign.Center)

      Image($rawfile('illustration_fish_bowl.png'))
        .width(92)
        .height(60)
        .opacity(0.78)
        .margin({ top: this.sbHeight + 10, right: 10 })
        .hitTestBehavior(HitTestMode.None)
    }
    .width('100%')
  }

  @Builder
  SectionTitle(title: string) {
    Text(title)
      .fontSize(15)
      .fontWeight(FontWeight.Bold)
      .fontColor($r('app.color.color_text_primary'))
      .width('100%')
      .padding({ left: 16, right: 16, top: 10, bottom: 2 })
  }

  @Builder
  MenuRow(icon: ResourceStr, iconBg: ResourceColor, iconColor: ResourceColor, title: string, desc: string, onTap: () => void) {
    Row() {
      Column() {
        Image(icon)
          .width(18)
          .height(18)
          .fillColor(iconColor)
      }
      .width(34)
      .height(34)
      .borderRadius(17)
      .backgroundColor(iconBg)
      .alignItems(HorizontalAlign.Center)
      .justifyContent(FlexAlign.Center)
      .margin({ right: 10 })

      Column() {
        Text(title)
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.color_text_primary'))
          .maxLines(1)
        Text(desc)
          .fontSize(11)
          .fontColor($r('app.color.color_text_secondary'))
          .margin({ top: 2 })
          .maxLines(1)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Image($rawfile('icon_chevron_right.svg'))
        .width(16)
        .height(16)
        .fillColor($r('app.color.color_text_muted'))
    }
    .width('100%')
    .height(58)
    .padding({ left: 16, right: 10 })
    .alignItems(VerticalAlign.Center)
    .onClick(onTap)
  }

  @Builder
  UserCard() {
    Row() {
      Image($rawfile('illustration_fish_bowl.png'))
        .width(56)
        .height(56)
        .borderRadius(28)
        .objectFit(ImageFit.Cover)
        .backgroundColor($r('app.color.color_soft_blue'))
        .margin({ right: 14 })

      Column() {
        Row({ space: 8 }) {
          Text('小金鱼用户')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.color_text_deep'))
          Text(this.currentUserName.length > 0 ? '已登录' : '本地')
            .fontSize(11)
            .fontColor($r('app.color.color_primary'))
            .height(20)
            .padding({ left: 8, right: 8 })
            .borderRadius(10)
            .border({ width: 1, color: $r('app.color.color_primary') })
        }
        .alignItems(VerticalAlign.Center)
        Text(this.currentUserName.length > 0 ? '欢迎回来，继续记录美好生活' : '创建用户名后可本地记账')
          .fontSize(12)
          .fontColor($r('app.color.color_text_secondary'))
          .margin({ top: 6 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Image($rawfile('icon_chevron_right.svg'))
        .width(16)
        .height(16)
        .fillColor($r('app.color.color_text_muted'))
    }
    .width('calc(100% - 32vp)')
    .height(92)
    .padding({ left: 16, right: 16 })
    .backgroundColor($r('app.color.color_card_overlay'))
    .borderRadius(16)
    .border({ width: 1, color: $r('app.color.color_divider') })
    .shadow({ radius: 6, color: $r('app.color.color_shadow_blue_08'), offsetY: 2 })
    .margin({ left: 16, right: 16, bottom: 8 })
    .alignItems(VerticalAlign.Center)
    .onClick(this.onOpenUserData)
  }

  @Builder
  BudgetCard() {
    Column() {
      Text(this.budgetRefreshVersion.toString())
        .fontSize(1)
        .fontColor(Color.Transparent)
        .opacity(0)
        .width('100%')
        .height(1)
      Row() {
        Row() {
          Text('预算概览')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.color_text_deep'))
          Image($rawfile('icon_help_circle.svg'))
            .width(15)
            .height(15)
            .fillColor($r('app.color.color_text_secondary'))
            .margin({ left: 6 })
        }
        .alignItems(VerticalAlign.Center)

        Blank()

        Row() {
          Text('预算设置')
            .fontSize(12)
            .fontColor($r('app.color.color_text_secondary'))
          Image($rawfile('icon_chevron_right.svg'))
            .width(15)
            .height(15)
            .fillColor($r('app.color.color_text_muted'))
            .margin({ left: 4 })
        }
        .alignItems(VerticalAlign.Center)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Row({ space: 8 }) {
        SettingsBudgetMiniCard({
          title: '今日预算',
          periodType: 'day',
          totalFen: this.dayBudgetOverview.totalFen,
          usedFen: this.dayBudgetOverview.usedFen,
          remainFen: this.dayBudgetOverview.remainFen,
          percent: this.dayBudgetOverview.percent,
          activeRuleCount: this.dayBudgetOverview.activeRuleCount,
          categoryBudgetFen: this.dayBudgetOverview.categoryBudgetFen
        })
        SettingsBudgetMiniCard({
          title: '本月预算',
          periodType: 'month',
          totalFen: this.monthBudgetOverview.totalFen,
          usedFen: this.monthBudgetOverview.usedFen,
          remainFen: this.monthBudgetOverview.remainFen,
          percent: this.monthBudgetOverview.percent,
          activeRuleCount: this.monthBudgetOverview.activeRuleCount,
          categoryBudgetFen: this.monthBudgetOverview.categoryBudgetFen
        })
        SettingsBudgetMiniCard({
          title: '本年预算',
          periodType: 'year',
          totalFen: this.yearBudgetOverview.totalFen,
          usedFen: this.yearBudgetOverview.usedFen,
          remainFen: this.yearBudgetOverview.remainFen,
          percent: this.yearBudgetOverview.percent,
          activeRuleCount: this.yearBudgetOverview.activeRuleCount,
          categoryBudgetFen: this.yearBudgetOverview.categoryBudgetFen
        })
      }
      .width('100%')
      .margin({ top: 12 })
    }
    .width('calc(100% - 32vp)')
    .padding({ left: 14, right: 14, top: 12, bottom: 14 })
    .backgroundColor($r('app.color.color_card_overlay'))
    .borderRadius(16)
    .border({ width: 1, color: $r('app.color.color_divider') })
    .shadow({ radius: 6, color: $r('app.color.color_shadow_blue_08'), offsetY: 2 })
    .margin({ left: 16, right: 16, bottom: 8 })
    .onClick(this.onOpenBudget)
  }

  @Builder
  PaymentLogo(icon: ResourceStr, bgColor: ResourceColor) {
    Row() {
      Image(icon)
        .width(18)
        .height(18)
        .fillColor($r('app.color.color_white'))
    }
    .width(32)
    .height(32)
    .borderRadius(16)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(bgColor)
  }

  @Builder
  PaymentTile(label: string, icon: ResourceStr, bgColor: ResourceColor) {
    Column({ space: 6 }) {
      this.PaymentLogo(icon, bgColor)
      Text(label)
        .fontSize(11)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.color_text_deep'))
        .maxLines(1)
    }
    .layoutWeight(1)
    .height(54)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .borderRadius(10)
    .border({ width: 1, color: $r('app.color.color_divider') })
    .backgroundColor($r('app.color.color_surface'))
  }

  @Builder
  AccountSummaryRow() {
    Row() {
      Column() {
        Text('\u9ed8\u8ba4\u8d26\u6237')
          .fontSize(11)
          .fontColor($r('app.color.color_text_secondary'))
        Text(this.defaultAccountName())
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.color_text_deep'))
          .margin({ top: 4 })
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Divider().vertical(true).height(30).color($r('app.color.color_divider'))

      Column() {
        Text('\u8d26\u6237\u603b\u6570')
          .fontSize(11)
          .fontColor($r('app.color.color_text_secondary'))
        Text(this.enabledAccountCount().toString() + '\u4e2a')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.color_text_deep'))
          .margin({ top: 4 })
      }
      .width(72)
      .alignItems(HorizontalAlign.Center)

      Divider().vertical(true).height(30).color($r('app.color.color_divider'))

      Row({ space: 4 }) {
        Text('\u7ba1\u7406')
          .fontSize(13)
          .fontColor($r('app.color.color_primary'))
        Image($rawfile('icon_chevron_right.svg'))
          .width(14)
          .height(14)
          .fillColor($r('app.color.color_text_muted'))
      }
      .width(52)
      .justifyContent(FlexAlign.End)
    }
    .width('100%')
    .height(52)
    .padding({ left: 10, right: 10 })
    .borderRadius(10)
    .border({ width: 1, color: $r('app.color.color_divider') })
    .margin({ top: 10 })
    .onClick(this.onOpenAccount)
  }

  @Builder
  AccountSection() {
    Column() {
      Row() {
        Image($rawfile('icon_insurance.svg'))
          .width(19)
          .height(19)
          .fillColor($r('app.color.color_icon_muted'))
          .margin({ right: 8 })
        Column() {
          Text('\u8d26\u6237\u4e0e\u652f\u4ed8\u65b9\u5f0f')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.color_text_deep'))
          Text('\u94f6\u884c\u5361 / \u652f\u4ed8\u5b9d / \u5fae\u4fe1 / \u73b0\u91d1\u94b1\u5305')
            .fontSize(11)
            .fontColor($r('app.color.color_text_secondary'))
            .margin({ top: 2 })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        Image($rawfile('icon_chevron_right.svg'))
          .width(15)
          .height(15)
          .fillColor($r('app.color.color_text_muted'))
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .onClick(this.onOpenAccount)

      this.AccountSummaryRow()

      Row() {
        Text('手动余额')
          .fontSize(11)
          .fontColor($r('app.color.color_text_secondary'))
        Text('¥' + AmountUtil.rawFen2Display(this.totalManualBalance()))
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.color_primary'))
          .margin({ left: 8 })
      }
      .width('100%')
      .margin({ top: 8 })
    }
    .width('calc(100% - 32vp)')
    .padding({ left: 14, right: 14, top: 12, bottom: 10 })
    .backgroundColor($r('app.color.color_card_overlay'))
    .borderRadius(16)
    .border({ width: 1, color: $r('app.color.color_divider') })
    .shadow({ radius: 5, color: $r('app.color.color_shadow_blue_08'), offsetY: 2 })
    .margin({ left: 16, right: 16, bottom: 8 })
  }

  @Builder
  BookkeepingSection() {
    Column() {
      this.SectionTitle('记账与预算')
      this.MenuRow($rawfile('icon_list.svg'), '#FFF4E4', $r('app.color.color_accent'), '分类管理', '自定义分类、排序', this.onOpenCategory)
      Divider().color($r('app.color.color_divider')).margin({ left: 66, right: 16 })
      this.MenuRow($rawfile('chart_donut_preview.svg'), '#E4F7F6', $r('app.color.color_primary'), '预算设置', '日/月/年预算', this.onOpenBudget)
      Divider().color($r('app.color.color_divider')).margin({ left: 66, right: 16 })
      this.MenuRow($rawfile('icon_calendar.svg'), '#EEF3FF', $r('app.color.color_primary_light'), '周期记账', '管理固定支出与收入', this.onOpenPeriod)
    }
    .width('calc(100% - 32vp)')
    .backgroundColor($r('app.color.color_card_overlay'))
    .borderRadius(16)
    .border({ width: 1, color: $r('app.color.color_divider') })
    .clip(true)
    .shadow({ radius: 6, color: $r('app.color.color_shadow_blue_08'), offsetY: 2 })
    .margin({ left: 16, right: 16, bottom: 8 })
  }

  @Builder
  OtherSection() {
    Column() {
      this.SectionTitle('其他')
      this.MenuRow($rawfile('icon_tab_settings.svg'), '#EEF3FF', $r('app.color.color_icon_muted'), '通用设置', '主题、提醒、安全与隐私', this.onOpenGeneral)
    }
    .width('calc(100% - 32vp)')
    .backgroundColor($r('app.color.color_card_overlay'))
    .borderRadius(16)
    .border({ width: 1, color: $r('app.color.color_divider') })
    .clip(true)
    .shadow({ radius: 6, color: $r('app.color.color_shadow_blue_08'), offsetY: 2 })
    .margin({ left: 16, right: 16, bottom: 8 })
  }

  @Builder
  ExportButton() {
    Row({ space: 8 }) {
      Image($rawfile('icon_tab_home.svg'))
        .width(18)
        .height(18)
        .fillColor($r('app.color.color_white'))
      Text('导出 CSV')
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.color_white'))
    }
    .width('calc(100% - 32vp)')
    .height(42)
    .justifyContent(FlexAlign.Center)
    .backgroundColor($r('app.color.color_primary'))
    .borderRadius(16)
    .margin({ left: 16, right: 16, bottom: 12 })
    .onClick(this.onExportCsv)
  }

  @Builder
  LogoutButton() {
    Button('退出登录')
      .width('calc(100% - 32vp)')
      .height(42)
      .fontSize(15)
      .fontWeight(FontWeight.Medium)
      .fontColor($r('app.color.color_text_secondary'))
      .backgroundColor($r('app.color.color_card_overlay'))
      .borderRadius(16)
      .border({ width: 1, color: $r('app.color.color_divider') })
      .margin({ left: 16, right: 16, bottom: 14 })
      .onClick(this.onLogout)
  }

  build() {
    Column() {
      this.Header()
      Scroll() {
        Column() {
          this.UserCard()
          this.BudgetCard()
          this.AccountSection()
          this.BookkeepingSection()
          this.ExportButton()
          this.LogoutButton()
        }
        .width('100%')
        .padding({ bottom: 10 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
    .alignItems(HorizontalAlign.Center)
  }
}
