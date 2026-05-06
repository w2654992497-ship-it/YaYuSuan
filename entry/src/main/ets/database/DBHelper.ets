import { relationalStore } from '@kit.ArkData'
import { common } from '@kit.AbilityKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { EXPENSE_CATEGORIES, INCOME_CATEGORIES, CategoryInfo } from '../model/Category'
import { DateUtil } from '../utils/DateUtil'

const DOMAIN = 0x0000
const TAG = 'A1a1'

const DB_CONFIG: relationalStore.StoreConfig = {
  name: 'yayusuan.db',
  securityLevel: relationalStore.SecurityLevel.S1
}

const CREATE_BILLS_SQL = `CREATE TABLE IF NOT EXISTS bills (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  userId INTEGER NOT NULL DEFAULT 1,
  bookId INTEGER NOT NULL DEFAULT 1,
  paymentAccountId INTEGER NOT NULL DEFAULT 0,
  paymentAccountName TEXT DEFAULT '',
  amount INTEGER NOT NULL,
  type TEXT NOT NULL,
  category TEXT NOT NULL,
  categoryId INTEGER NOT NULL DEFAULT 0,
  remark TEXT DEFAULT '',
  date TEXT NOT NULL,
  createdAt INTEGER NOT NULL
)`

const CREATE_CATEGORIES_SQL = `CREATE TABLE IF NOT EXISTS categories (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  userId INTEGER NOT NULL DEFAULT 1,
  bookId INTEGER NOT NULL DEFAULT 1,
  name TEXT NOT NULL,
  icon TEXT NOT NULL,
  color TEXT NOT NULL,
  type TEXT NOT NULL,
  sort_order INTEGER NOT NULL DEFAULT 0,
  is_default INTEGER NOT NULL DEFAULT 0
)`

const CREATE_PERIOD_RULES_SQL = `CREATE TABLE IF NOT EXISTS period_rules (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  userId INTEGER NOT NULL DEFAULT 1,
  bookId INTEGER NOT NULL DEFAULT 1,
  title TEXT NOT NULL,
  amount INTEGER NOT NULL,
  type TEXT NOT NULL,
  category TEXT NOT NULL,
  remark TEXT DEFAULT '',
  cycle TEXT NOT NULL,
  day INTEGER NOT NULL,
  month INTEGER NOT NULL DEFAULT 1,
  nextDate TEXT NOT NULL,
  enabled INTEGER NOT NULL DEFAULT 1,
  createdAt INTEGER NOT NULL
)`

const CREATE_USERS_SQL = `CREATE TABLE IF NOT EXISTS users (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  username TEXT NOT NULL UNIQUE,
  displayName TEXT NOT NULL,
  passwordHash TEXT NOT NULL,
  salt TEXT NOT NULL,
  createdAt INTEGER NOT NULL,
  lastLoginAt INTEGER NOT NULL
)`

const CREATE_ACCOUNT_BOOKS_SQL = `CREATE TABLE IF NOT EXISTS account_books (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  cloudId TEXT NOT NULL,
  ownerUserId INTEGER NOT NULL,
  name TEXT NOT NULL,
  currency TEXT NOT NULL DEFAULT 'CNY',
  createdAt INTEGER NOT NULL,
  updatedAt INTEGER NOT NULL,
  deleted INTEGER NOT NULL DEFAULT 0
)`

const CREATE_BUDGETS_SQL = `CREATE TABLE IF NOT EXISTS budgets (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  userId INTEGER NOT NULL DEFAULT 1,
  bookId INTEGER NOT NULL DEFAULT 1,
  categoryId INTEGER NOT NULL,
  amount INTEGER NOT NULL DEFAULT 0,
  updatedAt INTEGER NOT NULL,
  UNIQUE(userId, bookId, categoryId)
)`

const CREATE_BUDGET_RULES_SQL = `CREATE TABLE IF NOT EXISTS budget_rules (
  id TEXT PRIMARY KEY,
  userId INTEGER NOT NULL,
  bookId INTEGER NOT NULL,
  name TEXT NOT NULL,
  periodType TEXT NOT NULL,
  scopeType TEXT NOT NULL,
  amount INTEGER NOT NULL,
  categoryIdsJson TEXT DEFAULT '',
  categoryNamesJson TEXT DEFAULT '',
  dateMode TEXT DEFAULT 'current',
  periodValue TEXT DEFAULT '',
  startDay INTEGER DEFAULT 1,
  endDay INTEGER DEFAULT 31,
  compareMode TEXT DEFAULT 'previous',
  status TEXT DEFAULT 'active',
  enabled INTEGER NOT NULL DEFAULT 1,
  createdAt INTEGER NOT NULL,
  updatedAt INTEGER NOT NULL,
  deleted INTEGER NOT NULL DEFAULT 0
)`

const CREATE_PAYMENT_ACCOUNTS_SQL = `CREATE TABLE IF NOT EXISTS payment_accounts (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  userId INTEGER NOT NULL DEFAULT 1,
  bookId INTEGER NOT NULL DEFAULT 1,
  name TEXT NOT NULL,
  type TEXT NOT NULL,
  bankName TEXT DEFAULT '',
  tailNumber TEXT DEFAULT '',
  iconMark TEXT DEFAULT '',
  color TEXT DEFAULT '',
  manualBalance INTEGER NOT NULL DEFAULT 0,
  balanceUpdatedAt INTEGER NOT NULL DEFAULT 0,
  sortOrder INTEGER NOT NULL DEFAULT 0,
  isDefault INTEGER NOT NULL DEFAULT 0,
  enabled INTEGER NOT NULL DEFAULT 1,
  createdAt INTEGER NOT NULL,
  updatedAt INTEGER NOT NULL,
  deleted INTEGER NOT NULL DEFAULT 0
)`

export class DBHelper {
  private static instance: DBHelper | null = null
  private rdbStore: relationalStore.RdbStore | null = null

  private constructor() {}

  static getInstance(): DBHelper {
    if (!DBHelper.instance) {
      DBHelper.instance = new DBHelper()
    }
    return DBHelper.instance
  }

  async init(context: common.UIAbilityContext): Promise<void> {
    try {
      const store = await relationalStore.getRdbStore(context, DB_CONFIG)
      await store.executeSql(CREATE_BILLS_SQL)
      await store.executeSql(CREATE_CATEGORIES_SQL)
      await store.executeSql(CREATE_PERIOD_RULES_SQL)
      await store.executeSql(CREATE_USERS_SQL)
      await store.executeSql(CREATE_ACCOUNT_BOOKS_SQL)
      await store.executeSql(CREATE_BUDGETS_SQL)
      await store.executeSql(CREATE_BUDGET_RULES_SQL)
      await store.executeSql(CREATE_PAYMENT_ACCOUNTS_SQL)
      await this.migrateUserColumns(store)
      this.rdbStore = store

      await this.ensureDefaultBookForUser(store, 1, '默认')
      await this.seedDefaultPaymentAccounts(store, 1)
      await this.seedDefaultCategories(store, 1)
      await this.backfillBillCategoryIds(store)
      await this.backfillBillPaymentAccounts(store)
      await this.backfillBillDates(store)
      await this.migrateLegacyBudgets(store)

      hilog.info(DOMAIN, TAG, '[DBHelper] 数据库初始化成功')
    } catch (err) {
      hilog.error(DOMAIN, TAG, '[DBHelper] 数据库初始化失败：%{public}s', JSON.stringify(err))
      throw new Error(String(err))
    }
  }

  async ensureDefaultCategoriesForUser(userId: number): Promise<void> {
    const store = this.getStore()
    await this.seedDefaultCategories(store, userId)
  }

  private async migrateUserColumns(store: relationalStore.RdbStore): Promise<void> {
    await this.addColumnIfNeeded(store, 'bills', 'userId INTEGER NOT NULL DEFAULT 1')
    await this.addColumnIfNeeded(store, 'bills', 'bookId INTEGER NOT NULL DEFAULT 1')
    await this.addColumnIfNeeded(store, 'bills', 'paymentAccountId INTEGER NOT NULL DEFAULT 0')
    await this.addColumnIfNeeded(store, 'bills', "paymentAccountName TEXT DEFAULT ''")
    await this.addColumnIfNeeded(store, 'bills', 'categoryId INTEGER NOT NULL DEFAULT 0')
    await this.addColumnIfNeeded(store, 'bills', "date TEXT NOT NULL DEFAULT ''")
    await this.addColumnIfNeeded(store, 'bills', 'createdAt INTEGER NOT NULL DEFAULT 0')
    await this.addColumnIfNeeded(store, 'categories', 'userId INTEGER NOT NULL DEFAULT 1')
    await this.addColumnIfNeeded(store, 'categories', 'bookId INTEGER NOT NULL DEFAULT 1')
    await this.addColumnIfNeeded(store, 'period_rules', 'userId INTEGER NOT NULL DEFAULT 1')
    await this.addColumnIfNeeded(store, 'period_rules', 'bookId INTEGER NOT NULL DEFAULT 1')
    await this.addColumnIfNeeded(store, 'payment_accounts', 'manualBalance INTEGER NOT NULL DEFAULT 0')
    await this.addColumnIfNeeded(store, 'payment_accounts', 'balanceUpdatedAt INTEGER NOT NULL DEFAULT 0')
  }

  private async addColumnIfNeeded(store: relationalStore.RdbStore, tableName: string, columnSql: string): Promise<void> {
    try {
      await store.executeSql('ALTER TABLE ' + tableName + ' ADD COLUMN ' + columnSql)
      hilog.info(DOMAIN, TAG, '[DBHelper] 已为表添加用户字段：%{public}s', tableName)
    } catch (err) {
      hilog.info(DOMAIN, TAG, '[DBHelper] 用户字段已存在或无需迁移：%{public}s error=%{public}s', tableName, JSON.stringify(err))
    }
  }

  private async backfillBillCategoryIds(store: relationalStore.RdbStore): Promise<void> {
    try {
      await store.executeSql(
        'UPDATE bills SET categoryId = COALESCE((' +
          'SELECT categories.id FROM categories ' +
          'WHERE categories.userId = bills.userId ' +
          'AND categories.bookId = bills.bookId ' +
          'AND categories.name = bills.category ' +
          'AND categories.type = bills.type LIMIT 1' +
        '), 0) WHERE categoryId = 0'
      )
      hilog.info(DOMAIN, TAG, '[DBHelper] 已按分类名称回填账单 categoryId')
    } catch (err) {
      hilog.error(DOMAIN, TAG, '[DBHelper] 回填账单 categoryId 失败：%{public}s', JSON.stringify(err))
    }
  }

  private async backfillBillPaymentAccounts(store: relationalStore.RdbStore): Promise<void> {
    try {
      await store.executeSql(
        'UPDATE bills SET paymentAccountId = COALESCE((' +
          'SELECT payment_accounts.id FROM payment_accounts ' +
          'WHERE payment_accounts.userId = bills.userId ' +
          'AND payment_accounts.bookId = bills.bookId ' +
          'AND payment_accounts.deleted = 0 ' +
          'ORDER BY payment_accounts.isDefault DESC, payment_accounts.sortOrder ASC, payment_accounts.id ASC LIMIT 1' +
        '), 0) WHERE paymentAccountId = 0'
      )
      await store.executeSql(
        'UPDATE bills SET paymentAccountName = COALESCE((' +
          'SELECT payment_accounts.name FROM payment_accounts ' +
          'WHERE payment_accounts.id = bills.paymentAccountId LIMIT 1' +
        '), paymentAccountName) WHERE paymentAccountName = ""'
      )
      hilog.info(DOMAIN, TAG, '[DBHelper] 已回填账单支付账户字段')
    } catch (err) {
      hilog.error(DOMAIN, TAG, '[DBHelper] 回填账单支付账户字段失败：%{public}s', JSON.stringify(err))
    }
  }

  private async backfillBillDates(store: relationalStore.RdbStore): Promise<void> {
    try {
      const rs = await store.querySql('SELECT id, createdAt FROM bills WHERE date = "" OR date IS NULL')
      let count = 0
      while (rs.goToNextRow()) {
        const id = rs.getLong(rs.getColumnIndex('id'))
        const createdAt = rs.getLong(rs.getColumnIndex('createdAt'))
        const dateText = createdAt > 0 ? DateUtil.format(new Date(createdAt)) : DateUtil.today()
        await store.executeSql('UPDATE bills SET date = "' + dateText + '" WHERE id = ' + id.toString())
        count += 1
      }
      rs.close()
      const now = Date.now()
      await store.executeSql('UPDATE bills SET createdAt = ' + now.toString() + ' WHERE createdAt <= 0')
      hilog.info(DOMAIN, TAG, '[DBHelper] 已修复空账单日期 count=%{public}d', count)
    } catch (err) {
      hilog.error(DOMAIN, TAG, '[DBHelper] 修复空账单日期失败：%{public}s', JSON.stringify(err))
    }
  }

  private async migrateLegacyBudgets(store: relationalStore.RdbStore): Promise<void> {
    try {
      const sql = 'SELECT b.userId as userId, b.bookId as bookId, b.categoryId as categoryId, ' +
        'b.amount as amount, b.updatedAt as updatedAt, COALESCE(c.name, "") as categoryName ' +
        'FROM budgets b LEFT JOIN categories c ON c.userId = b.userId AND c.bookId = b.bookId AND c.id = b.categoryId ' +
        'WHERE b.amount > 0'
      const rs = await store.querySql(sql)
      let count = 0
      while (rs.goToNextRow()) {
        const userId = rs.getLong(rs.getColumnIndex('userId'))
        const bookId = rs.getLong(rs.getColumnIndex('bookId'))
        const categoryId = rs.getLong(rs.getColumnIndex('categoryId'))
        const amount = rs.getLong(rs.getColumnIndex('amount'))
        const updatedAt = rs.getLong(rs.getColumnIndex('updatedAt'))
        const categoryName = rs.getString(rs.getColumnIndex('categoryName'))
        const ruleId = 'budget_migrated_' + userId.toString() + '_' + bookId.toString() + '_' + categoryId.toString()
        const exists = await this.existsBudgetRule(store, ruleId)
        if (!exists) {
          const name = categoryName.length > 0 ? categoryName + '月预算' : '分类月预算'
          const bucket: relationalStore.ValuesBucket = {
            id: ruleId,
            userId: userId,
            bookId: bookId,
            name: name,
            periodType: 'month',
            scopeType: 'categories',
            amount: amount,
            categoryIdsJson: JSON.stringify([categoryId]),
            categoryNamesJson: JSON.stringify([categoryName]),
            dateMode: 'current',
            periodValue: '',
            startDay: 1,
            endDay: 31,
            compareMode: 'previous',
            status: 'active',
            enabled: 1,
            createdAt: updatedAt,
            updatedAt: updatedAt,
            deleted: 0
          }
          await store.insert('budget_rules', bucket)
          count += 1
        }
      }
      rs.close()
      hilog.info(DOMAIN, TAG, '[DBHelper] 旧预算迁移完成 count=%{public}d', count)
    } catch (err) {
      hilog.error(DOMAIN, TAG, '[DBHelper] 旧预算迁移失败：%{public}s', JSON.stringify(err))
    }
  }

  private async existsBudgetRule(store: relationalStore.RdbStore, ruleId: string): Promise<boolean> {
    const predicates = new relationalStore.RdbPredicates('budget_rules')
    predicates.equalTo('id', ruleId)
    predicates.limitAs(1)
    const rs = await store.query(predicates, ['id'])
    let exists = false
    if (rs.goToNextRow()) {
      exists = true
    }
    rs.close()
    return exists
  }

  private async seedDefaultPaymentAccounts(store: relationalStore.RdbStore, userId: number): Promise<void> {
    try {
      const bookId = await this.ensureDefaultBookForUser(store, userId, '默认')
      await this.deleteLegacyBankSeedAccounts(store)
      const countResult = await store.querySql('SELECT COUNT(*) as cnt FROM payment_accounts WHERE userId = ' +
        userId.toString() + ' AND bookId = ' + bookId.toString() + ' AND deleted = 0')
      let count = 0
      if (countResult.goToNextRow()) {
        count = countResult.getLong(countResult.getColumnIndex('cnt'))
      }
      countResult.close()
      if (count > 0) {
        return
      }
      const now = Date.now()
      await this.insertPaymentAccountSeed(store, userId, bookId, '现金钱包', 'cash', 'cash', '#FF9500', 0, 1, now)
      await this.insertPaymentAccountSeed(store, userId, bookId, '支付宝', 'alipay', 'alipay', '#1677FF', 1, 0, now)
      await this.insertPaymentAccountSeed(store, userId, bookId, '微信支付', 'wechat', 'wechat', '#16A34A', 2, 0, now)
      hilog.info(DOMAIN, TAG, '[DBHelper] 已初始化基础支付账户 userId=%{public}d bookId=%{public}d', userId, bookId)
    } catch (err) {
      hilog.error(DOMAIN, TAG, '[DBHelper] 初始化基础支付账户失败：%{public}s', JSON.stringify(err))
    }
  }

  private async deleteLegacyBankSeedAccounts(store: relationalStore.RdbStore): Promise<void> {
    await this.deleteLegacyBankSeedAccount(store, '招商银行', '2388', 0)
    await this.deleteLegacyBankSeedAccount(store, '工商银行', '1024', 1)
  }

  private async deleteLegacyBankSeedAccount(
    store: relationalStore.RdbStore,
    name: string,
    tailNumber: string,
    sortOrder: number
  ): Promise<void> {
    const sql = 'UPDATE payment_accounts SET deleted = 1, isDefault = 0, updatedAt = ' + Date.now().toString() +
      ' WHERE deleted = 0' +
      ' AND manualBalance = 0' +
      ' AND sortOrder = ' + sortOrder.toString() +
      " AND name = '" + name + "'" +
      " AND type = 'bank'" +
      " AND tailNumber = '" + tailNumber + "'" +
      ' AND id NOT IN (SELECT paymentAccountId FROM bills WHERE paymentAccountId > 0)'
    await store.executeSql(sql)
  }

  private async insertPaymentAccountSeed(
    store: relationalStore.RdbStore,
    userId: number,
    bookId: number,
    name: string,
    type: string,
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
      bankName: '',
      tailNumber: '',
      iconMark: iconMark,
      color: color,
      manualBalance: 0,
      balanceUpdatedAt: 0,
      sortOrder: sortOrder,
      isDefault: isDefault,
      enabled: 1,
      createdAt: now,
      updatedAt: now,
      deleted: 0
    }
    await store.insert('payment_accounts', bucket)
  }

  private async seedDefaultCategories(store: relationalStore.RdbStore, userId: number): Promise<void> {
    try {
      const bookId = await this.ensureDefaultBookForUser(store, userId, '默认')
      const countResult = await store.querySql('SELECT COUNT(*) as cnt FROM categories WHERE userId = ' +
        userId.toString() + ' AND bookId = ' + bookId.toString())
      let count = 0
      if (countResult.goToNextRow()) {
        count = countResult.getLong(countResult.getColumnIndex('cnt'))
      }
      countResult.close()

      if (count > 0) {
        return
      }

      for (let i = 0; i < EXPENSE_CATEGORIES.length; i++) {
        await this.insertCategory(store, userId, bookId, EXPENSE_CATEGORIES[i], 'expense', i, 1)
      }
      for (let i = 0; i < INCOME_CATEGORIES.length; i++) {
        await this.insertCategory(store, userId, bookId, INCOME_CATEGORIES[i], 'income', i, 1)
      }
      hilog.info(DOMAIN, TAG, '[DBHelper] 已为用户初始化默认分类 userId=%{public}d', userId)
    } catch (err) {
      hilog.error(DOMAIN, TAG, '[DBHelper] 初始化默认分类失败：%{public}s', JSON.stringify(err))
    }
  }

  private async insertCategory(
    store: relationalStore.RdbStore,
    userId: number,
    bookId: number,
    cat: CategoryInfo,
    type: string,
    sortOrder: number,
    isDefault: number
  ): Promise<void> {
    try {
      const bucket: relationalStore.ValuesBucket = {
        userId: userId,
        bookId: bookId,
        name: cat.name,
        icon: cat.icon,
        color: cat.color,
        type: type,
        sort_order: sortOrder,
        is_default: isDefault
      }
      await store.insert('categories', bucket)
    } catch (err) {
      hilog.error(DOMAIN, TAG, '[DBHelper] 写入默认分类失败：%{public}s', JSON.stringify(err))
    }
  }

  private async ensureDefaultBookForUser(store: relationalStore.RdbStore, userId: number, displayName: string): Promise<number> {
    const predicates = new relationalStore.RdbPredicates('account_books')
    predicates.equalTo('ownerUserId', userId)
    predicates.equalTo('deleted', 0)
    predicates.orderByAsc('id')
    predicates.limitAs(1)
    const rs = await store.query(predicates, ['id'])
    let bookId = 0
    if (rs.goToNextRow()) {
      bookId = rs.getLong(rs.getColumnIndex('id'))
    }
    rs.close()
    if (bookId > 0) {
      return bookId
    }
    const now = Date.now()
    const bookName = displayName.length > 0 ? displayName + '的账本' : '默认账本'
    const bucket: relationalStore.ValuesBucket = {
      cloudId: 'book_' + userId.toString() + '_default',
      ownerUserId: userId,
      name: bookName,
      currency: 'CNY',
      createdAt: now,
      updatedAt: now,
      deleted: 0
    }
    const rowId = await store.insert('account_books', bucket)
    hilog.info(DOMAIN, TAG, '[DBHelper] 已创建默认账本 userId=%{public}d bookId=%{public}d', userId, rowId)
    return rowId
  }

  getStore(): relationalStore.RdbStore {
    if (!this.rdbStore) {
      throw new Error('数据库尚未初始化，请先调用 init()')
    }
    return this.rdbStore
  }
}
