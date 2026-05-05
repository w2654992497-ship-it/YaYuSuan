import { relationalStore } from '@kit.ArkData'
import { DBHelper } from './DBHelper'
import { AccountBookDao } from './AccountBookDao'
import { LogUtils } from '../utils/LogUtils'
import { PaymentAccount, PaymentAccountType, createEmptyPaymentAccount } from '../model/PaymentAccount'

const PAYMENT_ACCOUNT_TAG = 'PaymentAccountDao'

export class PaymentAccountDao {
  private static instance: PaymentAccountDao | null = null

  private constructor() {}

  static getInstance(): PaymentAccountDao {
    if (!PaymentAccountDao.instance) {
      PaymentAccountDao.instance = new PaymentAccountDao()
    }
    return PaymentAccountDao.instance
  }

  private getStore(): relationalStore.RdbStore {
    return DBHelper.getInstance().getStore()
  }

  private getCurrentUserId(): number {
    const userId = AppStorage.get<number>('currentUserId')
    if (userId !== undefined && userId > 0) {
      return userId
    }
    return 1
  }

  private getCurrentBookId(): number {
    return AccountBookDao.getInstance().getCurrentBookId()
  }

  async ensureDefaultAccountsForCurrentUser(): Promise<void> {
    const userId = this.getCurrentUserId()
    const bookId = this.getCurrentBookId()
    await this.ensureDefaultAccounts(userId, bookId)
  }

  createDraft(type: PaymentAccountType): PaymentAccount {
    const userId = this.getCurrentUserId()
    const bookId = this.getCurrentBookId()
    const now = Date.now()
    const draft = createEmptyPaymentAccount()
    draft.userId = userId
    draft.bookId = bookId
    draft.type = type
    draft.name = this.defaultNameForType(type)
    draft.bankName = type === 'bank' ? this.defaultNameForType(type) : ''
    draft.tailNumber = ''
    draft.iconMark = this.markForType(type)
    draft.color = this.colorForType(type)
    draft.manualBalance = 0
    draft.balanceUpdatedAt = now
    draft.sortOrder = now
    draft.isDefault = 0
    draft.enabled = 1
    draft.createdAt = now
    draft.updatedAt = now
    draft.deleted = 0
    return draft
  }

  async ensureDefaultAccounts(userId: number, bookId: number): Promise<void> {
    const store = this.getStore()
    const count = await this.countByUserBook(userId, bookId)
    if (count > 0) {
      return
    }
    const now = Date.now()
    await this.insertSeed(store, userId, bookId, '\u62db\u5546\u94f6\u884c', 'bank', '\u62db\u5546\u94f6\u884c', '2388', 'bank', '#D71920', 0, 1, now)
    await this.insertSeed(store, userId, bookId, '\u5de5\u5546\u94f6\u884c', 'bank', '\u5de5\u5546\u94f6\u884c', '1024', 'bank', '#C1121F', 1, 0, now)
    await this.insertSeed(store, userId, bookId, '\u652f\u4ed8\u5b9d', 'alipay', '', '', 'alipay', '#1677FF', 2, 0, now)
    await this.insertSeed(store, userId, bookId, '\u5fae\u4fe1\u652f\u4ed8', 'wechat', '', '', 'wechat', '#16A34A', 3, 0, now)
    await this.insertSeed(store, userId, bookId, '\u73b0\u91d1\u94b1\u5305', 'cash', '', '', 'cash', '#FF9500', 4, 0, now)
    LogUtils.info(PAYMENT_ACCOUNT_TAG, '已初始化默认支付账户 userId=%{public}s bookId=%{public}s',
      userId.toString(), bookId.toString())
  }

  async queryAll(): Promise<PaymentAccount[]> {
    await this.ensureDefaultAccountsForCurrentUser()
    const predicates = new relationalStore.RdbPredicates('payment_accounts')
    predicates.equalTo('userId', this.getCurrentUserId())
    predicates.equalTo('bookId', this.getCurrentBookId())
    predicates.equalTo('deleted', 0)
    predicates.orderByDesc('isDefault')
    predicates.orderByAsc('sortOrder')
    predicates.orderByAsc('id')
    const rs = await this.getStore().query(predicates)
    const result: PaymentAccount[] = []
    while (rs.goToNextRow()) {
      result.push(this.rowToAccount(rs))
    }
    rs.close()
    return result
  }

  async queryEnabled(): Promise<PaymentAccount[]> {
    const all = await this.queryAll()
    const result: PaymentAccount[] = []
    for (let i = 0; i < all.length; i++) {
      if (all[i].enabled === 1) {
        result.push(all[i])
      }
    }
    return result
  }

  async queryDefault(): Promise<PaymentAccount> {
    await this.ensureDefaultAccountsForCurrentUser()
    const predicates = new relationalStore.RdbPredicates('payment_accounts')
    predicates.equalTo('userId', this.getCurrentUserId())
    predicates.equalTo('bookId', this.getCurrentBookId())
    predicates.equalTo('deleted', 0)
    predicates.equalTo('enabled', 1)
    predicates.orderByDesc('isDefault')
    predicates.orderByAsc('sortOrder')
    predicates.limitAs(1)
    const rs = await this.getStore().query(predicates)
    let account = createEmptyPaymentAccount()
    if (rs.goToNextRow()) {
      account = this.rowToAccount(rs)
    }
    rs.close()
    return account
  }

  async queryById(id: number): Promise<PaymentAccount | null> {
    const predicates = new relationalStore.RdbPredicates('payment_accounts')
    predicates.equalTo('id', id)
    predicates.equalTo('userId', this.getCurrentUserId())
    predicates.equalTo('bookId', this.getCurrentBookId())
    predicates.equalTo('deleted', 0)
    const rs = await this.getStore().query(predicates)
    let account: PaymentAccount | null = null
    if (rs.goToNextRow()) {
      account = this.rowToAccount(rs)
    }
    rs.close()
    return account
  }

  async applyBillBalanceChange(paymentAccountId: number, billType: string, amount: number, reverse: boolean): Promise<void> {
    if (paymentAccountId <= 0 || amount <= 0) {
      return
    }
    let delta = 0
    if (billType === 'expense') {
      delta = reverse ? amount : 0 - amount
    } else if (billType === 'income') {
      delta = reverse ? 0 - amount : amount
    } else {
      return
    }
    await this.changeManualBalance(paymentAccountId, delta, reverse ? '删除账单回滚余额' : '新增账单更新余额')
  }

  async upsert(account: PaymentAccount): Promise<number> {
    const store = this.getStore()
    const now = Date.now()
    const isDefault = account.isDefault === 1 ? 1 : 0
    const nextEnabled = isDefault === 1 ? 1 : account.enabled
    if (account.name.trim().length === 0) {
      throw new Error('账户名称不能为空')
    }
    if (account.id > 0 && nextEnabled === 0) {
      const exists = await this.queryById(account.id)
      if (exists && exists.isDefault === 1) {
        throw new Error('默认账户不能停用，请先设置其他默认账户')
      }
      const enabledCount = await this.countEnabledByUserBook(account.userId, account.bookId, account.id)
      if (enabledCount <= 0) {
        throw new Error('至少保留一个启用账户')
      }
    }
    if (isDefault === 1) {
      await this.clearDefault(store, account.userId, account.bookId)
    }
    const bucket: relationalStore.ValuesBucket = {
      userId: account.userId,
      bookId: account.bookId,
      name: account.name.trim(),
      type: account.type,
      bankName: account.bankName,
      tailNumber: account.tailNumber,
      iconMark: account.iconMark,
      color: account.color,
      manualBalance: account.manualBalance,
      balanceUpdatedAt: account.balanceUpdatedAt > 0 ? account.balanceUpdatedAt : now,
      sortOrder: account.sortOrder,
      isDefault: isDefault,
      enabled: nextEnabled,
      updatedAt: now,
      deleted: account.deleted
    }
    if (account.id > 0) {
      const predicates = new relationalStore.RdbPredicates('payment_accounts')
      predicates.equalTo('id', account.id)
      predicates.equalTo('userId', account.userId)
      predicates.equalTo('bookId', account.bookId)
      await store.update(bucket, predicates)
      return account.id
    }
    bucket.createdAt = now
    const rowId = await store.insert('payment_accounts', bucket)
    return rowId
  }

  async setDefault(id: number): Promise<void> {
    const account = await this.queryById(id)
    if (!account) {
      return
    }
    const store = this.getStore()
    await this.clearDefault(store, account.userId, account.bookId)
    const bucket: relationalStore.ValuesBucket = {
      isDefault: 1,
      enabled: 1,
      updatedAt: Date.now()
    }
    const predicates = new relationalStore.RdbPredicates('payment_accounts')
    predicates.equalTo('id', id)
    await store.update(bucket, predicates)
    LogUtils.info(PAYMENT_ACCOUNT_TAG, '已设置默认支付账户 id=%{public}s name=%{public}s', id.toString(), account.name)
  }

  async setEnabled(id: number, enabled: number): Promise<void> {
    const account = await this.queryById(id)
    if (!account) {
      return
    }
    if (enabled === 0 && account.isDefault === 1) {
      throw new Error('默认账户不能停用，请先设置其他默认账户')
    }
    if (enabled === 0) {
      const enabledCount = await this.countEnabledByUserBook(account.userId, account.bookId, id)
      if (enabledCount <= 0) {
        throw new Error('至少保留一个启用账户')
      }
    }
    const bucket: relationalStore.ValuesBucket = {
      enabled: enabled,
      updatedAt: Date.now()
    }
    const predicates = new relationalStore.RdbPredicates('payment_accounts')
    predicates.equalTo('id', id)
    predicates.equalTo('userId', this.getCurrentUserId())
    predicates.equalTo('bookId', this.getCurrentBookId())
    await this.getStore().update(bucket, predicates)
  }

  async softDelete(id: number): Promise<void> {
    const account = await this.queryById(id)
    if (!account) {
      return
    }
    const enabledCount = await this.countEnabledByUserBook(account.userId, account.bookId, id)
    if (enabledCount <= 0) {
      throw new Error('至少保留一个启用账户')
    }
    const bucket: relationalStore.ValuesBucket = {
      deleted: 1,
      isDefault: 0,
      updatedAt: Date.now()
    }
    const predicates = new relationalStore.RdbPredicates('payment_accounts')
    predicates.equalTo('id', id)
    predicates.equalTo('userId', this.getCurrentUserId())
    predicates.equalTo('bookId', this.getCurrentBookId())
    await this.getStore().update(bucket, predicates)
    const all = await this.queryEnabled()
    let hasDefault = false
    for (let i = 0; i < all.length; i++) {
      if (all[i].isDefault === 1) {
        hasDefault = true
      }
    }
    if (!hasDefault && all.length > 0) {
      await this.setDefault(all[0].id)
    }
  }

  async replaceAllForUserBook(userId: number, bookId: number, accounts: PaymentAccount[]): Promise<number> {
    const store = this.getStore()
    const deletePredicates = new relationalStore.RdbPredicates('payment_accounts')
    deletePredicates.equalTo('userId', userId)
    deletePredicates.equalTo('bookId', bookId)
    await store.delete(deletePredicates)
    for (let i = 0; i < accounts.length; i++) {
      const source = accounts[i]
      const bucket: relationalStore.ValuesBucket = {
        userId: userId,
        bookId: bookId,
        name: source.name,
        type: source.type,
        bankName: source.bankName,
        tailNumber: source.tailNumber,
        iconMark: source.iconMark,
        color: source.color,
        manualBalance: source.manualBalance,
        balanceUpdatedAt: source.balanceUpdatedAt,
        sortOrder: source.sortOrder,
        isDefault: source.isDefault,
        enabled: source.enabled,
        createdAt: source.createdAt,
        updatedAt: source.updatedAt,
        deleted: source.deleted
      }
      await store.insert('payment_accounts', bucket)
    }
    await this.ensureDefaultAccounts(userId, bookId)
    return accounts.length
  }

  private async countByUserBook(userId: number, bookId: number): Promise<number> {
    const rs = await this.getStore().querySql('SELECT COUNT(*) as cnt FROM payment_accounts WHERE userId = ' +
      userId.toString() + ' AND bookId = ' + bookId.toString() + ' AND deleted = 0')
    let count = 0
    if (rs.goToNextRow()) {
      count = rs.getLong(rs.getColumnIndex('cnt'))
    }
    rs.close()
    return count
  }

  private async countEnabledByUserBook(userId: number, bookId: number, excludeId: number): Promise<number> {
    let sql = 'SELECT COUNT(*) as cnt FROM payment_accounts WHERE userId = ' +
      userId.toString() + ' AND bookId = ' + bookId.toString() + ' AND deleted = 0 AND enabled = 1'
    if (excludeId > 0) {
      sql += ' AND id <> ' + excludeId.toString()
    }
    const rs = await this.getStore().querySql(sql)
    let count = 0
    if (rs.goToNextRow()) {
      count = rs.getLong(rs.getColumnIndex('cnt'))
    }
    rs.close()
    return count
  }

  private async clearDefault(store: relationalStore.RdbStore, userId: number, bookId: number): Promise<void> {
    const bucket: relationalStore.ValuesBucket = {
      isDefault: 0,
      updatedAt: Date.now()
    }
    const predicates = new relationalStore.RdbPredicates('payment_accounts')
    predicates.equalTo('userId', userId)
    predicates.equalTo('bookId', bookId)
    await store.update(bucket, predicates)
  }

  private async changeManualBalance(id: number, amountDelta: number, reason: string): Promise<void> {
    const account = await this.queryById(id)
    if (!account) {
      LogUtils.info(PAYMENT_ACCOUNT_TAG, '账户余额变更跳过 reason=%{public}s id=%{public}s cause=账户不存在',
        reason, id.toString())
      return
    }
    const now = Date.now()
    const nextBalance = account.manualBalance + amountDelta
    const bucket: relationalStore.ValuesBucket = {
      manualBalance: nextBalance,
      balanceUpdatedAt: now,
      updatedAt: now
    }
    const predicates = new relationalStore.RdbPredicates('payment_accounts')
    predicates.equalTo('id', id)
    predicates.equalTo('userId', account.userId)
    predicates.equalTo('bookId', account.bookId)
    predicates.equalTo('deleted', 0)
    await this.getStore().update(bucket, predicates)
    LogUtils.info(PAYMENT_ACCOUNT_TAG,
      '账户余额已变更 reason=%{public}s id=%{public}s name=%{public}s old=%{public}s delta=%{public}s next=%{public}s',
      reason, id.toString(), account.name, account.manualBalance.toString(), amountDelta.toString(), nextBalance.toString())
  }

  private async insertSeed(
    store: relationalStore.RdbStore,
    userId: number,
    bookId: number,
    name: string,
    type: PaymentAccountType,
    bankName: string,
    tailNumber: string,
    iconMark: string,
    color: string,
    sortOrder: number,
    isDefault: number,
    now: number
  ): Promise<void> {
    const bucket: relationalStore.ValuesBucket = {
      userId: userId,
      bookId: bookId,
      name: name,
      type: type,
      bankName: bankName,
      tailNumber: tailNumber,
      iconMark: iconMark,
      color: color,
      manualBalance: 0,
      balanceUpdatedAt: now,
      sortOrder: sortOrder,
      isDefault: isDefault,
      enabled: 1,
      createdAt: now,
      updatedAt: now,
      deleted: 0
    }
    await store.insert('payment_accounts', bucket)
  }

  private rowToAccount(rs: relationalStore.ResultSet): PaymentAccount {
    return {
      id: rs.getLong(rs.getColumnIndex('id')),
      userId: rs.getLong(rs.getColumnIndex('userId')),
      bookId: rs.getLong(rs.getColumnIndex('bookId')),
      name: rs.getString(rs.getColumnIndex('name')),
      type: rs.getString(rs.getColumnIndex('type')) as PaymentAccountType,
      bankName: rs.getString(rs.getColumnIndex('bankName')),
      tailNumber: rs.getString(rs.getColumnIndex('tailNumber')),
      iconMark: rs.getString(rs.getColumnIndex('iconMark')),
      color: rs.getString(rs.getColumnIndex('color')),
      manualBalance: rs.getLong(rs.getColumnIndex('manualBalance')),
      balanceUpdatedAt: rs.getLong(rs.getColumnIndex('balanceUpdatedAt')),
      sortOrder: rs.getLong(rs.getColumnIndex('sortOrder')),
      isDefault: rs.getLong(rs.getColumnIndex('isDefault')),
      enabled: rs.getLong(rs.getColumnIndex('enabled')),
      createdAt: rs.getLong(rs.getColumnIndex('createdAt')),
      updatedAt: rs.getLong(rs.getColumnIndex('updatedAt')),
      deleted: rs.getLong(rs.getColumnIndex('deleted'))
    }
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
}
