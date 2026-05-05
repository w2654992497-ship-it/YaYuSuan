import { PaymentAccount, PaymentAccountType, createEmptyPaymentAccount } from '../../model/PaymentAccount'
import { AppDataApi } from '../../services/AppDataApi'
import { WaterPageBg } from '../../components/WaterPageBg'
import { AmountUtil } from '../../utils/AmountUtil'
import { LogUtils } from '../../utils/LogUtils'

const ACCOUNT_FORM_TAG = 'AccountFormPage'

interface AccountTypeOption {
  accountType: PaymentAccountType
  title: string
  icon: ResourceStr
  color: string
}

@Component
export struct AccountFormPage {
  mode: string = 'create'
  onBack: () => void = (): void => {}
  onSaved: () => void = (): void => {}
  @StorageProp('statusBarHeight') sbHeight: number = 0
  @Prop accountEditId: number = 0
  @State draft: PaymentAccount = createEmptyPaymentAccount()
  @State originalDefault: number = 0
  @State balanceText: string = '0.00'
  @State showTypeSheet: boolean = false
  @State loading: boolean = false

  aboutToAppear(): void {
    this.loadDraft().catch((err: Error | Object) => {
      LogUtils.error(ACCOUNT_FORM_TAG, '加载账户表单失败：%{public}s', this.formatError(err))
      this.showToast('账户数据读取失败')
    })
  }

  private resolveEditId(): number {
    if (this.accountEditId > 0) {
      return this.accountEditId
    }
    const storageEditId = AppStorage.get<number>('accountEditId')
    if (storageEditId !== undefined && storageEditId > 0) {
      return storageEditId
    }
    return 0
  }

  private async loadDraft(): Promise<void> {
    const editId = this.resolveEditId()
    if (this.mode === 'edit' && editId > 0) {
      const account = await AppDataApi.getInstance().queryPaymentAccountById(editId)
      if (account) {
        this.draft = account
        this.originalDefault = account.isDefault
        this.balanceText = AmountUtil.rawFen2Display(account.manualBalance)
        return
      }
      this.showToast('账户不存在')
      this.onBack()
      return
    }
    const account = AppDataApi.getInstance().createPaymentAccountDraft('cash')
    this.draft = account
    this.originalDefault = 0
    this.balanceText = '0.00'
  }

  private titleText(): string {
    return this.mode === 'edit' ? '编辑账户' : '新增账户'
  }

  private showToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message })
    } catch (err) {
      LogUtils.error(ACCOUNT_FORM_TAG, '显示提示失败：%{public}s', this.formatError(err))
    }
  }

  private formatError(err: Error | Object): string {
    if (err instanceof Error) {
      return err.message
    }
    const text = JSON.stringify(err)
    if (text.length > 0 && text !== '{}') {
      return text
    }
    return String(err)
  }

  private typeOptions(): AccountTypeOption[] {
    return [
      { accountType: 'bank', title: '银行卡', icon: $rawfile('icon_account_bank.svg'), color: '#D71920' },
      { accountType: 'alipay', title: '支付宝', icon: $rawfile('icon_account_alipay.svg'), color: '#1677FF' },
      { accountType: 'wechat', title: '微信支付', icon: $rawfile('icon_account_wechat.svg'), color: '#16A34A' },
      { accountType: 'cash', title: '现金钱包', icon: $rawfile('icon_account_cash.svg'), color: '#FF9500' },
      { accountType: 'other', title: '其他账户', icon: $rawfile('icon_account_other.svg'), color: '#64748B' }
    ]
  }

  private typeLabel(type: PaymentAccountType): string {
    if (type === 'bank') {
      return '银行卡'
    }
    if (type === 'alipay') {
      return '支付宝'
    }
    if (type === 'wechat') {
      return '微信支付'
    }
    if (type === 'cash') {
      return '现金钱包'
    }
    return '其他账户'
  }

  private defaultNameForType(type: PaymentAccountType): string {
    if (type === 'bank') {
      return '银行卡'
    }
    if (type === 'alipay') {
      return '支付宝'
    }
    if (type === 'wechat') {
      return '微信支付'
    }
    if (type === 'cash') {
      return '现金钱包'
    }
    return '其他账户'
  }

  private colorForType(type: PaymentAccountType): string {
    if (type === 'bank') {
      return '#D71920'
    }
    if (type === 'alipay') {
      return '#1677FF'
    }
    if (type === 'wechat') {
      return '#16A34A'
    }
    if (type === 'cash') {
      return '#FF9500'
    }
    return '#64748B'
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

  private markForType(type: PaymentAccountType): string {
    if (type === 'bank') {
      return 'bank'
    }
    if (type === 'alipay') {
      return 'alipay'
    }
    if (type === 'wechat') {
      return 'wechat'
    }
    if (type === 'cash') {
      return 'cash'
    }
    return 'other'
  }

  private selectType(type: PaymentAccountType): void {
    const currentName = this.draft.name.trim()
    const oldDefaultName = this.defaultNameForType(this.draft.type)
    let nextName = this.draft.name
    if (currentName.length === 0 || currentName === oldDefaultName) {
      nextName = this.defaultNameForType(type)
    }
    this.draft = {
      id: this.draft.id,
      userId: this.draft.userId,
      bookId: this.draft.bookId,
      name: nextName,
      type: type,
      bankName: type === 'bank' ? this.draft.bankName : '',
      tailNumber: type === 'bank' ? this.draft.tailNumber : '',
      iconMark: this.markForType(type),
      color: this.colorForType(type),
      manualBalance: this.draft.manualBalance,
      balanceUpdatedAt: this.draft.balanceUpdatedAt,
      sortOrder: this.draft.sortOrder,
      isDefault: this.draft.isDefault,
      enabled: this.draft.enabled,
      createdAt: this.draft.createdAt,
      updatedAt: Date.now(),
      deleted: this.draft.deleted
    }
    this.showTypeSheet = false
  }

  private updateName(value: string): void {
    this.draft = this.copyWithText('name', value)
  }

  private updateBankName(value: string): void {
    this.draft = this.copyWithText('bankName', value)
  }

  private updateTailNumber(value: string): void {
    this.draft = this.copyWithText('tailNumber', value)
  }

  private copyWithText(fieldName: string, value: string): PaymentAccount {
    const next = this.copyDraft()
    if (fieldName === 'name') {
      next.name = value
    } else if (fieldName === 'bankName') {
      next.bankName = value
    } else if (fieldName === 'tailNumber') {
      next.tailNumber = value
    }
    next.updatedAt = Date.now()
    return next
  }

  private copyDraft(): PaymentAccount {
    return {
      id: this.draft.id,
      userId: this.draft.userId,
      bookId: this.draft.bookId,
      name: this.draft.name,
      type: this.draft.type,
      bankName: this.draft.bankName,
      tailNumber: this.draft.tailNumber,
      iconMark: this.draft.iconMark,
      color: this.draft.color,
      manualBalance: this.draft.manualBalance,
      balanceUpdatedAt: this.draft.balanceUpdatedAt,
      sortOrder: this.draft.sortOrder,
      isDefault: this.draft.isDefault,
      enabled: this.draft.enabled,
      createdAt: this.draft.createdAt,
      updatedAt: this.draft.updatedAt,
      deleted: this.draft.deleted
    }
  }

  private setDefault(isOn: boolean): void {
    if (!isOn && this.originalDefault === 1) {
      this.showToast('默认账户不能直接取消，请设置其他账户为默认账户')
      this.draft = this.copyDraft()
      return
    }
    const next = this.copyDraft()
    next.isDefault = isOn ? 1 : 0
    if (next.isDefault === 1) {
      next.enabled = 1
    }
    next.updatedAt = Date.now()
    this.draft = next
  }

  private setEnabled(isOn: boolean): void {
    if (!isOn && this.draft.isDefault === 1) {
      this.showToast('默认账户不能停用')
      this.draft = this.copyDraft()
      return
    }
    const next = this.copyDraft()
    next.enabled = isOn ? 1 : 0
    next.updatedAt = Date.now()
    this.draft = next
  }

  private async save(): Promise<void> {
    if (this.loading) {
      return
    }
    const name = this.draft.name.trim()
    if (name.length === 0) {
      this.showToast('请输入账户名称')
      return
    }
    const balance = AmountUtil.yuan2Fen(this.balanceText)
    this.loading = true
    try {
      const now = Date.now()
      const next = this.copyDraft()
      next.name = name
      next.bankName = next.type === 'bank' ? next.bankName.trim() : ''
      next.tailNumber = next.type === 'bank' ? next.tailNumber.trim() : ''
      next.manualBalance = balance
      next.balanceUpdatedAt = now
      next.updatedAt = now
      if (this.mode === 'edit' && this.originalDefault === 1) {
        next.isDefault = 1
      }
      if (next.isDefault === 1) {
        next.enabled = 1
      }
      const hostContext = this.getUIContext().getHostContext()
      await AppDataApi.getInstance().savePaymentAccount(hostContext ? hostContext : null, next, true)
      this.showToast(this.mode === 'edit' ? '账户已保存' : '账户已新增')
      this.onSaved()
    } catch (err) {
      LogUtils.error(ACCOUNT_FORM_TAG, '保存账户失败：%{public}s', this.formatError(err))
      this.showToast(this.formatError(err))
    } finally {
      this.loading = false
    }
  }

  @Builder
  Header() {
    Stack({ alignContent: Alignment.TopEnd }) {
      Image($rawfile('illustration_fish_bowl.png'))
        .width(78)
        .height(50)
        .objectFit(ImageFit.Contain)
        .opacity(0.7)
        .margin({ top: this.sbHeight + 4, right: 12 })
        .hitTestBehavior(HitTestMode.None)

      Row() {
        Row() {
          Image($rawfile('icon_chevron_left.svg'))
            .width(21)
            .height(21)
            .fillColor($r('app.color.color_text_deep'))
        }
        .width(38)
        .height(38)
        .borderRadius(19)
        .justifyContent(FlexAlign.Center)
        .onClick(this.onBack)

        Text(this.titleText())
          .fontSize(23)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.color_text_deep'))
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
        Blank().width(38)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: this.sbHeight + 4 })
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .height(this.sbHeight + 74)
  }

  @Builder
  MainFormCard() {
    Column() {
      Row() {
        Text('账户类型')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.color_text_deep'))
          .layoutWeight(1)
        Text(this.typeLabel(this.draft.type))
          .fontSize(15)
          .fontColor($r('app.color.color_text_secondary'))
        Image($rawfile('icon_chevron_right.svg'))
          .width(15)
          .height(15)
          .fillColor($r('app.color.color_text_muted'))
          .margin({ left: 8 })
      }
      .width('100%')
      .height(50)
      .alignItems(VerticalAlign.Center)
      .onClick(() => {
        this.showTypeSheet = true
      })
      Divider().color($r('app.color.color_divider'))
      Row() {
        Text('账户名称')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.color_text_deep'))
          .width(92)
        TextInput({ placeholder: '请输入账户名称', text: this.draft.name })
          .fontSize(15)
          .fontColor($r('app.color.color_text_deep'))
          .placeholderColor($r('app.color.color_text_muted'))
          .backgroundColor(Color.Transparent)
          .textAlign(TextAlign.End)
          .layoutWeight(1)
          .onChange((next: string) => {
            this.updateName(next)
          })
      }
      .width('100%')
      .height(50)
      .alignItems(VerticalAlign.Center)
      if (this.draft.type === 'bank') {
        Divider().color($r('app.color.color_divider'))
        Row() {
          Text('银行名称')
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.color_text_deep'))
            .width(92)
          TextInput({ placeholder: '例如：招商银行', text: this.draft.bankName })
            .fontSize(15)
            .fontColor($r('app.color.color_text_deep'))
            .placeholderColor($r('app.color.color_text_muted'))
            .backgroundColor(Color.Transparent)
            .textAlign(TextAlign.End)
            .layoutWeight(1)
            .onChange((next: string) => {
              this.updateBankName(next)
            })
        }
        .width('100%')
        .height(50)
        .alignItems(VerticalAlign.Center)
        Divider().color($r('app.color.color_divider'))
        Row() {
          Text('卡号尾号')
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.color_text_deep'))
            .width(92)
          TextInput({ placeholder: '可选', text: this.draft.tailNumber })
            .fontSize(15)
            .fontColor($r('app.color.color_text_deep'))
            .placeholderColor($r('app.color.color_text_muted'))
            .backgroundColor(Color.Transparent)
            .textAlign(TextAlign.End)
            .layoutWeight(1)
            .onChange((next: string) => {
              this.updateTailNumber(next)
            })
        }
        .width('100%')
        .height(50)
        .alignItems(VerticalAlign.Center)
      }
      Divider().color($r('app.color.color_divider'))
      Row() {
        Text('手动余额')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.color_text_deep'))
          .width(92)
        TextInput({ placeholder: '0.00', text: this.balanceText })
          .type(InputType.NUMBER_DECIMAL)
          .fontSize(15)
          .fontColor($r('app.color.color_text_deep'))
          .placeholderColor($r('app.color.color_text_muted'))
          .backgroundColor(Color.Transparent)
          .textAlign(TextAlign.End)
          .layoutWeight(1)
          .onChange((next: string) => {
            this.balanceText = next
          })
      }
      .width('100%')
      .height(50)
      .alignItems(VerticalAlign.Center)
      Divider().color($r('app.color.color_divider'))
      Row() {
        Text('账户图标/颜色')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.color_text_deep'))
          .layoutWeight(1)
        Row() {
          Image(this.iconForType(this.draft.type))
            .width(19)
            .height(19)
            .fillColor($r('app.color.color_white'))
        }
        .width(34)
        .height(34)
        .borderRadius(17)
        .justifyContent(FlexAlign.Center)
        .backgroundColor(this.draft.color)
      }
      .width('100%')
      .height(50)
      .alignItems(VerticalAlign.Center)
      Divider().color($r('app.color.color_divider'))
      Row() {
        Text('设为默认账户')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.color_text_deep'))
          .layoutWeight(1)
        Toggle({ type: ToggleType.Switch, isOn: this.draft.isDefault === 1 })
          .selectedColor($r('app.color.color_primary'))
          .onChange((isOn: boolean) => {
            this.setDefault(isOn)
          })
      }
      .width('100%')
      .height(50)
      .alignItems(VerticalAlign.Center)
      Divider().color($r('app.color.color_divider'))
      Row() {
        Text('账户启用')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.color_text_deep'))
          .layoutWeight(1)
        Toggle({ type: ToggleType.Switch, isOn: this.draft.enabled === 1 })
          .selectedColor($r('app.color.color_primary'))
          .onChange((isOn: boolean) => {
            this.setEnabled(isOn)
          })
      }
      .width('100%')
      .height(50)
      .alignItems(VerticalAlign.Center)
    }
    .width('calc(100% - 32vp)')
    .padding({ left: 16, right: 16, top: 8, bottom: 8 })
    .backgroundColor($r('app.color.color_card_overlay'))
    .borderRadius(16)
    .border({ width: 1, color: $r('app.color.color_divider') })
    .shadow({ radius: 5, color: $r('app.color.color_shadow_blue_08'), offsetY: 2 })
    .margin({ left: 16, right: 16, bottom: 12 })
  }

  @Builder
  TipsCard() {
    Column({ space: 8 }) {
      Text('余额说明')
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.color_text_deep'))
        .width('100%')
      Text('账户余额由手动设置作为初始值，保存支出账单会扣减余额，保存收入账单会增加余额；不会读取银行卡、支付宝或微信真实余额。')
        .fontSize(12)
        .lineHeight(18)
        .fontColor($r('app.color.color_text_secondary'))
        .width('100%')
    }
    .width('calc(100% - 32vp)')
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .backgroundColor($r('app.color.color_card_overlay'))
    .borderRadius(16)
    .border({ width: 1, color: $r('app.color.color_divider') })
    .margin({ left: 16, right: 16, bottom: 12 })
  }

  @Builder
  TypeSheet() {
    Stack({ alignContent: Alignment.Bottom }) {
      Row()
        .width('100%')
        .height('100%')
        .backgroundColor('#66000000')
        .onClick(() => {
          this.showTypeSheet = false
        })

      Column() {
        Row()
          .width(42)
          .height(5)
          .borderRadius(3)
          .backgroundColor($r('app.color.color_divider'))
          .margin({ top: 10, bottom: 14 })
        Text('选择账户类型')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.color_text_deep'))
        Row({ space: 8 }) {
          ForEach(this.typeOptions(), (item: AccountTypeOption) => {
            Column({ space: 8 }) {
              Image(item.icon)
                .width(32)
                .height(32)
                .fillColor(item.color)
              Text(item.title)
                .fontSize(13)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.color_text_deep'))
            }
            .layoutWeight(1)
            .height(100)
            .justifyContent(FlexAlign.Center)
            .alignItems(HorizontalAlign.Center)
            .border({ width: this.draft.type === item.accountType ? 1.5 : 1, color: this.draft.type === item.accountType ? $r('app.color.color_primary') : $r('app.color.color_divider') })
            .borderRadius(14)
            .backgroundColor(this.draft.type === item.accountType ? $r('app.color.color_soft_blue') : $r('app.color.color_card_overlay'))
            .onClick(() => {
              this.selectType(item.accountType)
            })
          }, (item: AccountTypeOption) => item.title)
        }
        .width('100%')
        .margin({ top: 18, bottom: 16 })

        Button('取消')
          .width('100%')
          .height(44)
          .fontSize(16)
          .fontColor($r('app.color.color_primary'))
          .backgroundColor($r('app.color.color_card_overlay'))
          .borderRadius(12)
          .border({ width: 1, color: $r('app.color.color_divider') })
          .onClick(() => {
            this.showTypeSheet = false
          })
      }
      .width('100%')
      .padding({ left: 18, right: 18, bottom: 18 })
      .backgroundColor($r('app.color.color_surface'))
      .borderRadius({ topLeft: 22, topRight: 22 })
    }
    .width('100%')
    .height('100%')
    .transition(
      TransitionEffect.asymmetric(
        TransitionEffect.OPACITY.combine(TransitionEffect.translate({ y: 300 }))
          .animation({ duration: 260, curve: Curve.EaseOut }),
        TransitionEffect.OPACITY.combine(TransitionEffect.translate({ y: 300 }))
          .animation({ duration: 210, curve: Curve.EaseIn })
      )
    )
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      WaterPageBg()
      Column() {
        this.Header()
        Scroll() {
          Column() {
            this.MainFormCard()
            this.TipsCard()
            Button(this.loading ? '保存中...' : (this.mode === 'edit' ? '保存修改' : '保存账户'))
              .width('calc(100% - 32vp)')
              .height(46)
              .fontSize(17)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.color_white'))
              .backgroundColor($r('app.color.color_primary'))
              .borderRadius(14)
              .margin({ left: 16, right: 16, bottom: 18 })
              .enabled(!this.loading)
              .onClick(() => {
                this.save()
              })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)
          .padding({ top: 0, bottom: 12 })
        }
        .align(Alignment.Top)
        .width('100%')
        .scrollBar(BarState.Off)
      }
      .width('100%')
      .height('100%')
      .alignItems(HorizontalAlign.Center)

      if (this.showTypeSheet) {
        this.TypeSheet()
      }
    }
    .width('100%')
    .height('100%')
  }
}
