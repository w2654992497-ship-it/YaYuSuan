import { cloudDatabase } from '@kit.CloudFoundationKit'
import { relationalStore } from '@kit.ArkData'
import { BillDao } from '../database/BillDao'
import { CategoryDao } from '../database/CategoryDao'
import { PeriodRuleDao } from '../database/PeriodRuleDao'
import { AccountBookDao } from '../database/AccountBookDao'
import { BudgetRuleDao } from '../database/BudgetRuleDao'
import { PaymentAccountDao } from '../database/PaymentAccountDao'
import { DBHelper } from '../database/DBHelper'
import { Bill } from '../model/Bill'
import { CategoryRecord } from '../model/Category'
import { FilterOptions } from '../model/FilterOptions'
import { PeriodRule } from '../model/PeriodRule'
import { AccountBook } from '../model/AccountBook'
import { BudgetRule, createEmptyBudgetRule } from '../model/BudgetRule'
import { PaymentAccount, PaymentAccountType } from '../model/PaymentAccount'
import { CloudAccountBook } from '../CloudAccountBook'
import { CloudBill } from '../CloudBill'
import { CloudCategory } from '../CloudCategory'
import { CloudPeriodRule } from '../CloudPeriodRule'
import { CloudBudgetRule } from '../CloudBudgetRule'
import { CloudUserDataBundle } from '../CloudUserDataBundle'
import { UserInfo } from '../UserInfo'
import { LogUtils } from '../utils/LogUtils'

const CLOUD_DB_TAG = 'CloudDatabaseService'
const CLOUD_DB_ZONE_NAME = 'XiaoJinYu'
const CLOUD_DB_OBJECT_USER = 'UserInfo'
const CLOUD_DB_OBJECT_BOOK = 'CloudAccountBook'
const CLOUD_DB_OBJECT_BILL = 'CloudBill'
const CLOUD_DB_OBJECT_CATEGORY = 'CloudCategory'
const CLOUD_DB_OBJECT_PERIOD_RULE = 'CloudPeriodRule'
const CLOUD_DB_OBJECT_BUDGET = 'CloudBudgetRule'
const CLOUD_DB_OBJECT_USER_DATA_BUNDLE = 'CloudUserDataBundle'
const CLOUD_DB_QUERY_TIMEOUT_MS = 12000

interface CloudRuntimeError {
  code?: number
  message?: string
  name?: string
}

interface BudgetJsonItem {
  id?: string
  userId?: number
  bookId?: number
  categoryId?: number
  name?: string
  periodType?: string
  scopeType?: string
  amount?: number
  categoryIdsJson?: string
  categoryNamesJson?: string
  dateMode?: string
  periodValue?: string
  startDay?: number
  endDay?: number
  compareMode?: string
  status?: string
  enabled?: number
  createdAt?: number
  updatedAt?: number
  deleted?: number
}

interface CategoryIdMapping {
  sourceId: number
  restoredId: number
  name: string
  type: string
}

interface PaymentAccountIdMapping {
  sourceId: number
  restoredId: number
  name: string
}

export interface CloudDatabaseSyncResult {
  userCount: number
  bookCount: number
  billCount: number
  categoryCount: number
  accountCount: number
  periodRuleCount: number
  budgetCount: number
  bundleCount: number
}

export interface CloudDatabaseCompletenessResult {
  localUserCount: number
  localBookCount: number
  localBillCount: number
  localCategoryCount: number
  localAccountCount: number
  localPeriodRuleCount: number
  localBudgetCount: number
  cloudUserCount: number
  cloudBookCount: number
  cloudBillCount: number
  cloudCategoryCount: number
  cloudAccountCount: number
  cloudPeriodRuleCount: number
  cloudBudgetCount: number
  completionPercent: number
  completed: boolean
}

export interface CloudDatabaseRestoreResult {
  bundleCount: number
  billCount: number
  categoryCount: number
  accountCount: number
  periodRuleCount: number
  budgetCount: number
}

export class CloudDatabaseService {
  private static instance: CloudDatabaseService | null = null
  private zone: cloudDatabase.DatabaseZone

  private constructor() {
    try {
      LogUtils.info(CLOUD_DB_TAG, '云数据库初始化开始 zone=%{public}s', CLOUD_DB_ZONE_NAME)
      this.zone = cloudDatabase.zone(CLOUD_DB_ZONE_NAME)
      LogUtils.info(CLOUD_DB_TAG, '云数据库初始化成功 zone=%{public}s', CLOUD_DB_ZONE_NAME)
    } catch (err) {
      LogUtils.error(CLOUD_DB_TAG, '云数据库初始化失败 zone=%{public}s error=%{public}s',
        CLOUD_DB_ZONE_NAME, this.formatError(err))
      throw new Error(this.formatError(err))
    }
  }

  static getInstance(): CloudDatabaseService {
    if (!CloudDatabaseService.instance) {
      CloudDatabaseService.instance = new CloudDatabaseService()
    }
    return CloudDatabaseService.instance
  }

  async upsertLocalData(userLocalId: number, username: string, displayName: string): Promise<CloudDatabaseSyncResult> {
    const traceId = this.buildTraceId('upsertLocalData')
    const startAt = Date.now()
    let userKey = this.buildUserKey(userLocalId)
    const book = await AccountBookDao.getInstance().ensureDefaultBookForUser(userLocalId, displayName)
    const bookKey = book.cloudId
    const filter: FilterOptions = { month: '', type: 'all', category: '' }
    const bills = await BillDao.getInstance().queryByFilter(filter)
    const categories = await CategoryDao.getInstance().queryAll()
    const paymentAccounts = await PaymentAccountDao.getInstance().queryAll()
    const periodRules = await PeriodRuleDao.getInstance().queryAll()
    const budgetRules = await BudgetRuleDao.getInstance().queryAll()
    LogUtils.info(CLOUD_DB_TAG,
      '云数据库同步开始 trace=%{public}s userKey=%{public}s bookKey=%{public}s bill=%{public}s category=%{public}s account=%{public}s periodRule=%{public}s budget=%{public}s',
      traceId, userKey, bookKey, bills.length.toString(), categories.length.toString(),
      paymentAccounts.length.toString(), periodRules.length.toString(), budgetRules.length.toString())

    const user = this.buildUserInfo(userLocalId, username, displayName)
    const existingUser = await this.queryUserByUsername(username)
    if (existingUser) {
      user.cloudId = existingUser.cloudId
      user.accountId = this.safeAccountId(existingUser, user.cloudId)
      userKey = user.accountId
      user.createdAt = existingUser.createdAt
      user.passwordHash = this.safeString(existingUser.passwordHash)
      user.salt = this.safeString(existingUser.salt)
      LogUtils.info(CLOUD_DB_TAG,
        '云数据库同步保留账号密码字段 trace=%{public}s username=%{public}s hasPassword=%{public}s',
        traceId, username, (user.passwordHash.length > 0 && user.salt.length > 0).toString())
    }
    const cloudBook = this.buildCloudAccountBook(userKey, book)
    const cloudBills = this.buildCloudBills(userKey, bookKey, bills)
    const cloudCategories = this.buildCloudCategories(userKey, bookKey, categories)
    const cloudPeriodRules = this.buildCloudPeriodRules(userKey, bookKey, periodRules)
    const cloudBudgetRules = this.buildCloudBudgetRules(userKey, bookKey, budgetRules)
    const dataBundle = this.buildCloudUserDataBundle(userKey, bookKey, book, categories, paymentAccounts, periodRules, budgetRules)

    try {
      const userCount = await this.traceUpsertUser(traceId, user)
      const bundleCount = await this.traceUpsertUserDataBundle(traceId, dataBundle)
      const billCount = cloudBills.length > 0 ? await this.traceUpsertBills(traceId, cloudBills) : 0
      const bookCount = dataBundle.bookCount
      const categoryCount = dataBundle.categoryCount
      const accountCount = dataBundle.accountCount
      const periodRuleCount = dataBundle.periodRuleCount
      let budgetCount = dataBundle.budgetCount
      try {
        if (cloudBudgetRules.length > 0) {
          budgetCount = await this.traceUpsertBudgetRules(traceId, cloudBudgetRules)
        } else {
          this.logSkipEmpty(traceId, CLOUD_DB_OBJECT_BUDGET, cloudBudgetRules.length)
        }
      } catch (budgetErr) {
        LogUtils.error(CLOUD_DB_TAG,
          '云数据库预算规则独立表同步失败，已保留数据包预算快照 trace=%{public}s error=%{public}s',
          traceId, this.formatError(budgetErr))
      }
      this.logSkipEmpty(traceId, CLOUD_DB_OBJECT_BILL, cloudBills.length)
      this.logBundleMode(traceId, CLOUD_DB_OBJECT_BOOK, cloudBook.cloudId)
      this.logBundleMode(traceId, CLOUD_DB_OBJECT_CATEGORY, cloudCategories.length.toString())
      this.logBundleMode(traceId, 'PaymentAccount', paymentAccounts.length.toString())
      this.logBundleMode(traceId, CLOUD_DB_OBJECT_PERIOD_RULE, cloudPeriodRules.length.toString())
      this.logBundleMode(traceId, 'BudgetRuleJson', budgetRules.length.toString())
      LogUtils.info(CLOUD_DB_TAG,
        '云数据库同步完成 trace=%{public}s costMs=%{public}s user=%{public}s book=%{public}s bill=%{public}s category=%{public}s account=%{public}s periodRule=%{public}s budget=%{public}s',
        traceId, (Date.now() - startAt).toString(), userCount.toString(), bookCount.toString(),
        billCount.toString(), categoryCount.toString(), accountCount.toString(), periodRuleCount.toString(), budgetCount.toString())
      return {
        userCount: userCount,
        bookCount: bookCount,
        billCount: billCount,
        categoryCount: categoryCount,
        accountCount: accountCount,
        periodRuleCount: periodRuleCount,
        budgetCount: budgetCount,
        bundleCount: bundleCount
      }
    } catch (err) {
      LogUtils.error(CLOUD_DB_TAG,
        '云数据库同步失败 trace=%{public}s costMs=%{public}s error=%{public}s',
        traceId, (Date.now() - startAt).toString(), this.formatError(err))
      throw new Error(this.formatError(err))
    }
  }

  async syncAndCheckLocalData(userLocalId: number, username: string, displayName: string): Promise<CloudDatabaseCompletenessResult> {
    const traceId = this.buildTraceId('syncAndCheckLocalData')
    await this.upsertLocalData(userLocalId, username, displayName)
    const result = await this.checkCompleteness(userLocalId)
    LogUtils.info(CLOUD_DB_TAG,
      '云数据库同步检查完成 trace=%{public}s percent=%{public}s completed=%{public}s',
      traceId, result.completionPercent.toString(), result.completed.toString())
    return result
  }

  async ensureUserInfo(userLocalId: number, username: string, displayName: string): Promise<number> {
    const traceId = this.buildTraceId('ensureUserInfo')
    const cloudUser = await this.queryUserByUsername(username)
    const user = this.buildUserInfo(userLocalId, username, displayName)
    if (cloudUser) {
      user.cloudId = cloudUser.cloudId
      user.accountId = this.safeAccountId(cloudUser, user.cloudId)
      user.createdAt = cloudUser.createdAt
      user.passwordHash = cloudUser.passwordHash
      user.salt = cloudUser.salt
    }
    return await this.traceUpsertUser(traceId, user)
  }

  async queryUserByUsername(username: string): Promise<UserInfo | null> {
    const traceId = this.buildTraceId('queryUserByUsername')
    const startAt = Date.now()
    LogUtils.info(CLOUD_DB_TAG, '云数据库查询用户 trace=%{public}s username=%{public}s', traceId, username)
    try {
      const users = await this.waitWithTimeout<UserInfo[]>(
        this.zone.query<UserInfo>(
          new cloudDatabase.DatabaseQuery<UserInfo>(UserInfo).equalTo('username', username).limit(1)
        ),
        traceId,
        'queryUserByUsername'
      )
      LogUtils.info(CLOUD_DB_TAG, '云数据库查询用户完成 trace=%{public}s count=%{public}s costMs=%{public}s',
        traceId, users.length.toString(), (Date.now() - startAt).toString())
      this.logRawUsers(traceId, 'queryUserByUsername', users)
      if (users.length === 0) {
        return null
      }
      return users[0]
    } catch (err) {
      LogUtils.error(CLOUD_DB_TAG, '云数据库查询用户失败 trace=%{public}s error=%{public}s',
        traceId, this.formatError(err))
      throw new Error(this.formatError(err))
    }
  }

  async queryAllUserInfoForDebug(): Promise<string> {
    const traceId = this.buildTraceId('queryAllUserInfoForDebug')
    const startAt = Date.now()
    try {
      const users = await this.zone.query<UserInfo>(new cloudDatabase.DatabaseQuery<UserInfo>(UserInfo).limit(20))
      LogUtils.error(CLOUD_DB_TAG, '云数据库测试查询成功 trace=%{public}s object=%{public}s count=%{public}s costMs=%{public}s',
        traceId, CLOUD_DB_OBJECT_USER, users.length.toString(), (Date.now() - startAt).toString())
      this.logRawUsers(traceId, 'queryAllUserInfoForDebug', users)
      if (users.length === 0) {
        return 'UserInfo 查询成功：0 条'
      }
      const rows: string[] = []
      for (let i = 0; i < users.length; i++) {
        const user = users[i]
        const passwordHash = this.safeString(user.passwordHash)
        const salt = this.safeString(user.salt)
        const hasPassword = passwordHash.length > 0 && salt.length > 0
        const row = (i + 1).toString() +
          '. cloudId=' + this.safeString(user.cloudId) +
          ', localId=' + this.safeNumber(user.localId) +
          ', username=' + this.safeString(user.username) +
          ', displayName=' + this.safeString(user.displayName) +
          ', hasPassword=' + hasPassword.toString() +
          ', createdAt=' + this.safeNumber(user.createdAt) +
          ', updatedAt=' + this.safeNumber(user.updatedAt)
        rows.push(row)
        LogUtils.error(CLOUD_DB_TAG, '云数据库测试查询记录 trace=%{public}s row=%{public}s', traceId, row)
      }
      return 'UserInfo 查询成功：' + users.length.toString() + ' 条\n' + rows.join('\n')
    } catch (err) {
      LogUtils.error(CLOUD_DB_TAG, '云数据库测试查询失败 trace=%{public}s error=%{public}s',
        traceId, this.formatError(err))
      throw new Error(this.formatError(err))
    }
  }

  async createUserAccount(username: string, displayName: string, passwordHash: string, salt: string): Promise<UserInfo> {
    const now = Date.now()
    return await this.createUserAccountWithLocalId(now, username, displayName, passwordHash, salt)
  }

  async createUserAccountForLocalUser(
    userLocalId: number,
    username: string,
    displayName: string,
    passwordHash: string,
    salt: string
  ): Promise<UserInfo> {
    return await this.createUserAccountWithLocalId(userLocalId, username, displayName, passwordHash, salt)
  }

  async upsertTestUserInfoForDebug(): Promise<string> {
    const now = Date.now()
    const user = new UserInfo()
    user.cloudId = 'debug_user_' + now.toString()
    user.localId = now
    user.username = 'debug_' + now.toString()
    user.displayName = '调试写入'
    user.passwordHash = '4dfc0881'
    user.salt = 'test_salt_001'
    user.createdAt = now
    user.lastLoginAt = now
    user.updatedAt = now
    const count = await this.traceUpsertUser(this.buildTraceId('upsertTestUserInfoForDebug'), user)
    return 'UserInfo 写入成功：count=' + count.toString() + ', cloudId=' + user.cloudId + ', username=' + user.username
  }

  async updateUserLoginTime(user: UserInfo): Promise<number> {
    const now = Date.now()
    user.accountId = this.safeAccountId(user, user.cloudId)
    user.lastLoginAt = now
    user.updatedAt = now
    return await this.traceUpsertUser(this.buildTraceId('updateUserLoginTime'), user)
  }

  async restoreCloudDataToLocal(userLocalId: number, username: string, displayName: string): Promise<CloudDatabaseRestoreResult> {
    const traceId = this.buildTraceId('restoreCloudDataToLocal')
    const startAt = Date.now()
    const cloudUser = await this.queryUserByUsername(username)
    if (!cloudUser) {
      LogUtils.info(CLOUD_DB_TAG, '云数据库恢复跳过 trace=%{public}s username=%{public}s reason=云端用户不存在',
        traceId, username)
      return { bundleCount: 0, billCount: 0, categoryCount: 0, accountCount: 0, periodRuleCount: 0, budgetCount: 0 }
    }
    const accountId = this.safeAccountId(cloudUser, cloudUser.cloudId)
    const book = await AccountBookDao.getInstance().ensureDefaultBookForUser(userLocalId, displayName)
    const bundles = await this.traceQueryUserDataBundles(traceId, accountId)
    let cloudBookId = book.cloudId
    let categoryCount = 0
    let accountCount = 0
    let periodRuleCount = 0
    let budgetCount = 0
    let categoryMappings: CategoryIdMapping[] = []
    let accountMappings: PaymentAccountIdMapping[] = []
    if (bundles.length > 0) {
      const bundle = bundles[0]
      if (bundle.bookId.length > 0) {
        cloudBookId = bundle.bookId
      }
      categoryMappings = await this.restoreCategoriesFromJson(userLocalId, book.id, bundle.categoryJson)
      categoryCount = categoryMappings.length
      accountMappings = await this.restorePaymentAccountsFromJson(userLocalId, book.id, this.safeString(bundle.accountJson))
      accountCount = accountMappings.length
      periodRuleCount = await this.restorePeriodRulesFromJson(userLocalId, book.id, bundle.periodRuleJson)
      budgetCount = await this.restoreBudgetRulesFromJson(userLocalId, book.id, bundle.budgetJson, categoryMappings)
    } else {
      LogUtils.info(CLOUD_DB_TAG, '云数据库恢复未找到数据包 trace=%{public}s accountId=%{public}s', traceId, accountId)
      await PaymentAccountDao.getInstance().ensureDefaultAccounts(userLocalId, book.id)
      accountCount = 0
    }
    if (budgetCount === 0) {
      try {
        const cloudBudgetRules = await this.traceQueryBudgetRulesByBook(traceId, accountId, cloudBookId)
        budgetCount = await this.restoreBudgetRulesFromCloudRows(userLocalId, book.id, cloudBudgetRules, categoryMappings)
      } catch (budgetErr) {
        LogUtils.error(CLOUD_DB_TAG,
          '云数据库预算规则独立表恢复失败，继续使用数据包结果 trace=%{public}s error=%{public}s',
          traceId, this.formatError(budgetErr))
      }
    }
    const cloudBills = await this.traceQueryBillsByBook(traceId, accountId, cloudBookId)
    const billCount = await this.restoreBills(userLocalId, book.id, cloudBills, categoryMappings, accountMappings)
    await CategoryDao.getInstance().refreshCache()
    LogUtils.info(CLOUD_DB_TAG,
      '云数据库恢复完成 trace=%{public}s costMs=%{public}s accountId=%{public}s bundle=%{public}s bill=%{public}s category=%{public}s account=%{public}s periodRule=%{public}s budget=%{public}s',
      traceId, (Date.now() - startAt).toString(), accountId, bundles.length.toString(), billCount.toString(),
      categoryCount.toString(), accountCount.toString(), periodRuleCount.toString(), budgetCount.toString())
    return {
      bundleCount: bundles.length,
      billCount: billCount,
      categoryCount: categoryCount,
      accountCount: accountCount,
      periodRuleCount: periodRuleCount,
      budgetCount: budgetCount
    }
  }

  async queryCounts(userLocalId: number): Promise<CloudDatabaseSyncResult> {
    const traceId = this.buildTraceId('queryCounts')
    const startAt = Date.now()
    let userKey = this.buildUserKey(userLocalId)
    const book = await AccountBookDao.getInstance().ensureDefaultBookForUser(userLocalId, '')
    const bookKey = book.cloudId
    let users = await this.traceQueryUsersByCloudId(traceId, userKey)
    if (users.length === 0) {
      users = await this.traceQueryUsersByLocalId(traceId, userLocalId)
      if (users.length > 0) {
        userKey = this.safeAccountId(users[0], users[0].cloudId)
      }
    }
    const bundles = await this.traceQueryUserDataBundles(traceId, userKey)
    const bills = await this.traceQueryBillsByBook(traceId, userKey, bookKey)
    let bookCount = 0
    let categoryCount = 0
    let accountCount = 0
    let periodRuleCount = 0
    let budgetCount = 0
    if (bundles.length > 0) {
      const bundle = bundles[0]
      bookCount = bundle.bookCount
      categoryCount = bundle.categoryCount
      accountCount = this.safeNumberValue(bundle.accountCount)
      periodRuleCount = bundle.periodRuleCount
      budgetCount = bundle.budgetCount
    }
    try {
      const budgetRows = await this.traceQueryBudgetRulesByBook(traceId, userKey, bookKey)
      if (budgetRows.length > 0 || budgetCount === 0) {
        budgetCount = budgetRows.length
      }
    } catch (budgetErr) {
      LogUtils.error(CLOUD_DB_TAG,
        '云数据库预算规则独立表数量查询失败，继续使用数据包数量 trace=%{public}s error=%{public}s',
        traceId, this.formatError(budgetErr))
    }
    LogUtils.info(CLOUD_DB_TAG,
      '云数据库数量查询完成 trace=%{public}s costMs=%{public}s user=%{public}s book=%{public}s bill=%{public}s category=%{public}s account=%{public}s periodRule=%{public}s budget=%{public}s',
      traceId, (Date.now() - startAt).toString(), users.length.toString(), bookCount.toString(),
      bills.length.toString(), categoryCount.toString(), accountCount.toString(), periodRuleCount.toString(), budgetCount.toString())
    return {
      userCount: users.length,
      bookCount: bookCount,
      billCount: bills.length,
      categoryCount: categoryCount,
      accountCount: accountCount,
      periodRuleCount: periodRuleCount,
      budgetCount: budgetCount,
      bundleCount: bundles.length
    }
  }

  async checkCompleteness(userLocalId: number): Promise<CloudDatabaseCompletenessResult> {
    const traceId = this.buildTraceId('checkCompleteness')
    const localCounts = await this.queryLocalCounts(userLocalId)
    const cloudCounts = await this.queryCounts(userLocalId)
    const localTotal = localCounts.userCount + localCounts.bookCount + localCounts.billCount +
      localCounts.categoryCount + localCounts.accountCount + localCounts.periodRuleCount + localCounts.budgetCount
    const matchedTotal = this.safeMatchedCount(localCounts.userCount, cloudCounts.userCount) +
      this.safeMatchedCount(localCounts.bookCount, cloudCounts.bookCount) +
      this.safeMatchedCount(localCounts.billCount, cloudCounts.billCount) +
      this.safeMatchedCount(localCounts.categoryCount, cloudCounts.categoryCount) +
      this.safeMatchedCount(localCounts.accountCount, cloudCounts.accountCount) +
      this.safeMatchedCount(localCounts.periodRuleCount, cloudCounts.periodRuleCount) +
      this.safeMatchedCount(localCounts.budgetCount, cloudCounts.budgetCount)
    let percent = 100
    if (localTotal > 0) {
      percent = Math.floor(matchedTotal * 100 / localTotal)
    }
    const completed = percent >= 100
    LogUtils.info(CLOUD_DB_TAG,
      '云数据库完整度 trace=%{public}s local(user=%{public}s,book=%{public}s,bill=%{public}s,category=%{public}s,account=%{public}s,period=%{public}s,budget=%{public}s) cloud(user=%{public}s,book=%{public}s,bill=%{public}s,category=%{public}s,account=%{public}s,period=%{public}s,budget=%{public}s) percent=%{public}s completed=%{public}s',
      traceId, localCounts.userCount.toString(), localCounts.bookCount.toString(), localCounts.billCount.toString(),
      localCounts.categoryCount.toString(), localCounts.accountCount.toString(), localCounts.periodRuleCount.toString(), localCounts.budgetCount.toString(),
      cloudCounts.userCount.toString(), cloudCounts.bookCount.toString(), cloudCounts.billCount.toString(),
      cloudCounts.categoryCount.toString(), cloudCounts.accountCount.toString(), cloudCounts.periodRuleCount.toString(), cloudCounts.budgetCount.toString(),
      percent.toString(), completed.toString())
    return {
      localUserCount: localCounts.userCount,
      localBookCount: localCounts.bookCount,
      localBillCount: localCounts.billCount,
      localCategoryCount: localCounts.categoryCount,
      localAccountCount: localCounts.accountCount,
      localPeriodRuleCount: localCounts.periodRuleCount,
      localBudgetCount: localCounts.budgetCount,
      cloudUserCount: cloudCounts.userCount,
      cloudBookCount: cloudCounts.bookCount,
      cloudBillCount: cloudCounts.billCount,
      cloudCategoryCount: cloudCounts.categoryCount,
      cloudAccountCount: cloudCounts.accountCount,
      cloudPeriodRuleCount: cloudCounts.periodRuleCount,
      cloudBudgetCount: cloudCounts.budgetCount,
      completionPercent: percent,
      completed: completed
    }
  }

  async deleteBill(userLocalId: number, billLocalId: number): Promise<number> {
    const traceId = this.buildTraceId('deleteBill')
    const book = await AccountBookDao.getInstance().ensureDefaultBookForUser(userLocalId, '')
    const bill = new CloudBill()
    bill.cloudId = this.buildCloudId(book.cloudId, 'bill', billLocalId)
    LogUtils.info(CLOUD_DB_TAG, '云数据库删除账单 trace=%{public}s cloudId=%{public}s', traceId, bill.cloudId)
    return await this.zone.delete<CloudBill>(bill)
  }

  private async createUserAccountWithLocalId(
    userLocalId: number,
    username: string,
    displayName: string,
    passwordHash: string,
    salt: string
  ): Promise<UserInfo> {
    const traceId = this.buildTraceId('createUserAccount')
    const now = Date.now()
    const exists = await this.queryUserByUsername(username)
    if (exists) {
      const existsPasswordHash = this.safeString(exists.passwordHash)
      const existsSalt = this.safeString(exists.salt)
      if (existsPasswordHash.length > 0 && existsSalt.length > 0) {
        throw new Error('账号已存在')
      }
      exists.localId = userLocalId
      exists.accountId = this.safeAccountId(exists, exists.cloudId)
      exists.displayName = displayName
      exists.passwordHash = passwordHash
      exists.salt = salt
      exists.lastLoginAt = now
      exists.updatedAt = now
      await this.traceUpsertUser(traceId, exists)
      LogUtils.info(CLOUD_DB_TAG,
        '云数据库已为缺少密码的账号补写密码字段 trace=%{public}s username=%{public}s cloudId=%{public}s',
        traceId, username, exists.cloudId)
      return exists
    }
    const user = new UserInfo()
    user.localId = userLocalId
    user.cloudId = this.buildUserKey(userLocalId)
    user.accountId = user.cloudId
    user.username = username
    user.displayName = displayName
    user.passwordHash = passwordHash
    user.salt = salt
    user.createdAt = now
    user.lastLoginAt = now
    user.updatedAt = now
    await this.traceUpsertUser(traceId, user)
    return user
  }

  private buildUserInfo(userLocalId: number, username: string, displayName: string): UserInfo {
    const now = Date.now()
    const user = new UserInfo()
    user.cloudId = this.buildUserKey(userLocalId)
    user.accountId = user.cloudId
    user.localId = userLocalId
    user.username = username
    user.displayName = displayName
    user.passwordHash = ''
    user.salt = ''
    user.createdAt = now
    user.lastLoginAt = now
    user.updatedAt = now
    return user
  }

  private buildCloudAccountBook(userKey: string, book: AccountBook): CloudAccountBook {
    const item = new CloudAccountBook()
    item.cloudId = book.cloudId
    item.ownerUserId = userKey
    item.localId = book.id
    item.name = book.name
    item.currency = book.currency
    item.createdAt = book.createdAt
    item.updatedAt = book.updatedAt
    item.deleted = book.deleted
    return item
  }

  private buildCloudBills(userKey: string, bookKey: string, bills: Bill[]): CloudBill[] {
    const result: CloudBill[] = []
    for (let i = 0; i < bills.length; i++) {
      const source = bills[i]
      const item = new CloudBill()
      item.cloudId = this.buildCloudId(bookKey, 'bill', source.id)
      item.accountId = userKey
      item.userId = userKey
      item.bookId = bookKey
      item.localId = source.id
      item.paymentAccountLocalId = source.paymentAccountId === undefined ? 0 : source.paymentAccountId
      item.paymentAccountName = source.paymentAccountName === undefined ? '' : source.paymentAccountName
      item.categoryLocalId = source.categoryId
      item.amount = source.amount
      item.type = source.type
      item.category = source.category
      item.remark = source.remark
      item.date = source.date
      item.createdAt = source.createdAt
      item.updatedAt = source.createdAt
      item.deleted = 0
      result.push(item)
    }
    return result
  }

  private buildCloudUserDataBundle(
    userKey: string,
    bookKey: string,
    book: AccountBook,
    categories: CategoryRecord[],
    paymentAccounts: PaymentAccount[],
    periodRules: PeriodRule[],
    budgets: BudgetRule[]
  ): CloudUserDataBundle {
    const item = new CloudUserDataBundle()
    item.cloudId = 'bundle_' + userKey + '_default'
    item.accountId = userKey
    item.bookId = bookKey
    item.schemaVersion = 3
    item.bookCount = 1
    item.categoryCount = categories.length
    item.accountCount = paymentAccounts.length
    item.budgetCount = budgets.length
    item.periodRuleCount = periodRules.length
    item.bookJson = JSON.stringify(book)
    item.categoryJson = JSON.stringify(categories)
    item.accountJson = JSON.stringify(paymentAccounts)
    item.budgetJson = JSON.stringify(budgets)
    item.periodRuleJson = JSON.stringify(periodRules)
    item.updatedAt = Date.now()
    item.deleted = 0
    return item
  }

  private buildCloudCategories(userKey: string, bookKey: string, categories: CategoryRecord[]): CloudCategory[] {
    const result: CloudCategory[] = []
    const now = Date.now()
    for (let i = 0; i < categories.length; i++) {
      const source = categories[i]
      const item = new CloudCategory()
      item.cloudId = this.buildCloudId(bookKey, 'category', source.id)
      item.userId = userKey
      item.bookId = bookKey
      item.localId = source.id
      item.name = source.name
      item.icon = source.icon
      item.color = source.color
      item.type = source.type
      item.sortOrder = source.sort_order
      item.isDefault = source.is_default
      item.updatedAt = now
      item.deleted = 0
      result.push(item)
    }
    return result
  }

  private buildCloudPeriodRules(userKey: string, bookKey: string, rules: PeriodRule[]): CloudPeriodRule[] {
    const result: CloudPeriodRule[] = []
    const now = Date.now()
    for (let i = 0; i < rules.length; i++) {
      const source = rules[i]
      const item = new CloudPeriodRule()
      item.cloudId = this.buildCloudId(bookKey, 'periodRule', source.id)
      item.userId = userKey
      item.bookId = bookKey
      item.localId = source.id
      item.title = source.title
      item.amount = source.amount
      item.type = source.type
      item.category = source.category
      item.remark = source.remark
      item.cycle = source.cycle
      item.day = source.day
      item.month = source.month
      item.nextDate = source.nextDate
      item.enabled = source.enabled
      item.createdAt = source.createdAt
      item.updatedAt = now
      item.deleted = 0
      result.push(item)
    }
    return result
  }

  private buildCloudBudgetRules(userKey: string, bookKey: string, rules: BudgetRule[]): CloudBudgetRule[] {
    const result: CloudBudgetRule[] = []
    for (let i = 0; i < rules.length; i++) {
      const source = rules[i]
      const item = new CloudBudgetRule()
      item.cloudId = bookKey + '_budgetRule_' + source.id
      item.accountId = userKey
      item.userId = userKey
      item.bookId = bookKey
      item.ruleId = source.id
      item.name = source.name
      item.periodType = source.periodType
      item.scopeType = source.scopeType
      item.amount = source.amount
      item.categoryIdsJson = source.categoryIdsJson
      item.categoryNamesJson = source.categoryNamesJson
      item.dateMode = source.dateMode
      item.periodValue = source.periodValue
      item.startDay = source.startDay
      item.endDay = source.endDay
      item.compareMode = source.compareMode
      item.status = source.status
      item.enabled = source.enabled
      item.createdAt = source.createdAt
      item.updatedAt = source.updatedAt
      item.deleted = source.deleted
      result.push(item)
    }
    return result
  }

  private async queryLocalCounts(userLocalId: number): Promise<CloudDatabaseSyncResult> {
    await AccountBookDao.getInstance().ensureDefaultBookForUser(userLocalId, '')
    const filter: FilterOptions = { month: '', type: 'all', category: '' }
    const bills = await BillDao.getInstance().queryByFilter(filter)
    const categories = await CategoryDao.getInstance().queryAll()
    const paymentAccounts = await PaymentAccountDao.getInstance().queryAll()
    const periodRules = await PeriodRuleDao.getInstance().queryAll()
    const budgets = await BudgetRuleDao.getInstance().queryAll()
    return {
      userCount: userLocalId > 0 ? 1 : 0,
      bookCount: userLocalId > 0 ? 1 : 0,
      billCount: bills.length,
      categoryCount: categories.length,
      accountCount: paymentAccounts.length,
      periodRuleCount: periodRules.length,
      budgetCount: budgets.length,
      bundleCount: userLocalId > 0 ? 1 : 0
    }
  }

  private async traceUpsertUser(traceId: string, user: UserInfo): Promise<number> {
    return await this.traceUpsertOne<UserInfo>(traceId, CLOUD_DB_OBJECT_USER, user)
  }

  private async traceUpsertBook(traceId: string, book: CloudAccountBook): Promise<number> {
    return await this.traceUpsertOne<CloudAccountBook>(traceId, CLOUD_DB_OBJECT_BOOK, book)
  }

  private async traceUpsertBills(traceId: string, bills: CloudBill[]): Promise<number> {
    return await this.traceUpsertMany<CloudBill>(traceId, CLOUD_DB_OBJECT_BILL, bills)
  }

  private async traceUpsertCategories(traceId: string, categories: CloudCategory[]): Promise<number> {
    return await this.traceUpsertMany<CloudCategory>(traceId, CLOUD_DB_OBJECT_CATEGORY, categories)
  }

  private async traceUpsertPeriodRules(traceId: string, periodRules: CloudPeriodRule[]): Promise<number> {
    return await this.traceUpsertMany<CloudPeriodRule>(traceId, CLOUD_DB_OBJECT_PERIOD_RULE, periodRules)
  }

  private async traceUpsertBudgetRules(traceId: string, budgetRules: CloudBudgetRule[]): Promise<number> {
    return await this.traceUpsertMany<CloudBudgetRule>(traceId, CLOUD_DB_OBJECT_BUDGET, budgetRules)
  }

  private async traceUpsertUserDataBundle(traceId: string, bundle: CloudUserDataBundle): Promise<number> {
    return await this.traceUpsertOne<CloudUserDataBundle>(traceId, CLOUD_DB_OBJECT_USER_DATA_BUNDLE, bundle)
  }

  private async traceUpsertOne<T extends cloudDatabase.DatabaseObject>(traceId: string, objectName: string, data: T): Promise<number> {
    const startAt = Date.now()
    LogUtils.info(CLOUD_DB_TAG, '云数据库请求 trace=%{public}s action=upsert object=%{public}s count=1',
      traceId, objectName)
    const count = await this.zone.upsert<T>(data)
    LogUtils.info(CLOUD_DB_TAG, '云数据库成功 trace=%{public}s action=upsert object=%{public}s count=%{public}s costMs=%{public}s',
      traceId, objectName, count.toString(), (Date.now() - startAt).toString())
    return count
  }

  private async traceUpsertMany<T extends cloudDatabase.DatabaseObject>(traceId: string, objectName: string, dataList: T[]): Promise<number> {
    const startAt = Date.now()
    LogUtils.info(CLOUD_DB_TAG, '云数据库请求 trace=%{public}s action=upsert object=%{public}s requestCount=%{public}s',
      traceId, objectName, dataList.length.toString())
    const count = await this.zone.upsert<T>(dataList)
    LogUtils.info(CLOUD_DB_TAG, '云数据库成功 trace=%{public}s action=upsert object=%{public}s count=%{public}s costMs=%{public}s',
      traceId, objectName, count.toString(), (Date.now() - startAt).toString())
    return count
  }

  private async traceQueryUsersByCloudId(traceId: string, userKey: string): Promise<UserInfo[]> {
    const result = await this.zone.query<UserInfo>(
      new cloudDatabase.DatabaseQuery<UserInfo>(UserInfo).equalTo('cloudId', userKey)
    )
    this.logQueryCount(traceId, CLOUD_DB_OBJECT_USER, result.length)
    this.logRawUsers(traceId, 'traceQueryUsersByCloudId', result)
    return result
  }

  private async traceQueryUsersByLocalId(traceId: string, userLocalId: number): Promise<UserInfo[]> {
    const result = await this.zone.query<UserInfo>(
      new cloudDatabase.DatabaseQuery<UserInfo>(UserInfo).equalTo('localId', userLocalId).limit(1)
    )
    this.logQueryCount(traceId, CLOUD_DB_OBJECT_USER, result.length)
    this.logRawUsers(traceId, 'traceQueryUsersByLocalId', result)
    return result
  }

  private async traceQueryBooksByUser(traceId: string, userKey: string): Promise<CloudAccountBook[]> {
    const result = await this.zone.query<CloudAccountBook>(
      new cloudDatabase.DatabaseQuery<CloudAccountBook>(CloudAccountBook).equalTo('ownerUserId', userKey).equalTo('deleted', 0)
    )
    this.logQueryCount(traceId, CLOUD_DB_OBJECT_BOOK, result.length)
    this.logRawBooks(traceId, 'traceQueryBooksByUser', result)
    return result
  }

  private async traceQueryUserDataBundles(traceId: string, userKey: string): Promise<CloudUserDataBundle[]> {
    const result = await this.zone.query<CloudUserDataBundle>(
      new cloudDatabase.DatabaseQuery<CloudUserDataBundle>(CloudUserDataBundle).equalTo('accountId', userKey).equalTo('deleted', 0)
    )
    this.logQueryCount(traceId, CLOUD_DB_OBJECT_USER_DATA_BUNDLE, result.length)
    this.logRawBundles(traceId, 'traceQueryUserDataBundles', result)
    return result
  }

  private async traceQueryBillsByBook(traceId: string, userKey: string, bookKey: string): Promise<CloudBill[]> {
    const result = await this.zone.query<CloudBill>(
      new cloudDatabase.DatabaseQuery<CloudBill>(CloudBill).equalTo('userId', userKey).equalTo('bookId', bookKey).equalTo('deleted', 0)
    )
    this.logQueryCount(traceId, CLOUD_DB_OBJECT_BILL, result.length)
    this.logRawBills(traceId, 'traceQueryBillsByBook', result)
    return result
  }

  private async traceQueryCategoriesByBook(traceId: string, userKey: string, bookKey: string): Promise<CloudCategory[]> {
    const result = await this.zone.query<CloudCategory>(
      new cloudDatabase.DatabaseQuery<CloudCategory>(CloudCategory).equalTo('userId', userKey).equalTo('bookId', bookKey).equalTo('deleted', 0)
    )
    this.logQueryCount(traceId, CLOUD_DB_OBJECT_CATEGORY, result.length)
    this.logRawCategories(traceId, 'traceQueryCategoriesByBook', result)
    return result
  }

  private async traceQueryPeriodRulesByBook(traceId: string, userKey: string, bookKey: string): Promise<CloudPeriodRule[]> {
    const result = await this.zone.query<CloudPeriodRule>(
      new cloudDatabase.DatabaseQuery<CloudPeriodRule>(CloudPeriodRule).equalTo('userId', userKey).equalTo('bookId', bookKey).equalTo('deleted', 0)
    )
    this.logQueryCount(traceId, CLOUD_DB_OBJECT_PERIOD_RULE, result.length)
    this.logRawPeriodRules(traceId, 'traceQueryPeriodRulesByBook', result)
    return result
  }

  private async traceQueryBudgetRulesByBook(traceId: string, userKey: string, bookKey: string): Promise<CloudBudgetRule[]> {
    const result = await this.zone.query<CloudBudgetRule>(
      new cloudDatabase.DatabaseQuery<CloudBudgetRule>(CloudBudgetRule).equalTo('accountId', userKey).equalTo('bookId', bookKey).equalTo('deleted', 0)
    )
    this.logQueryCount(traceId, CLOUD_DB_OBJECT_BUDGET, result.length)
    this.logRawBudgetRules(traceId, 'traceQueryBudgetRulesByBook', result)
    return result
  }

  private async restoreBills(
    userLocalId: number,
    bookLocalId: number,
    cloudBills: CloudBill[],
    categoryMappings: CategoryIdMapping[],
    accountMappings: PaymentAccountIdMapping[]
  ): Promise<number> {
    const store = DBHelper.getInstance().getStore()
    await this.deleteLocalRows(store, 'bills', userLocalId, bookLocalId)
    const fallbackAccount = await PaymentAccountDao.getInstance().queryDefault()
    let count = 0
    for (let i = 0; i < cloudBills.length; i++) {
      const source = cloudBills[i]
      if (source.deleted === 1) {
        continue
      }
      const sourceCategoryId = this.safeNumberValue(source.categoryLocalId)
      let categoryId = this.findRestoredCategoryIdBySourceId(sourceCategoryId, categoryMappings)
      if (categoryId <= 0) {
        categoryId = this.findRestoredCategoryIdByName(source.category, categoryMappings)
      }
      if (categoryId <= 0) {
        const catRecord = await CategoryDao.getInstance().queryByName(source.category, source.type)
        categoryId = catRecord ? catRecord.id : 0
      }
      const sourcePaymentAccountId = this.safeNumberValue(source.paymentAccountLocalId)
      const sourcePaymentAccountName = this.safeString(source.paymentAccountName)
      let paymentAccountId = this.findRestoredAccountIdBySourceId(sourcePaymentAccountId, accountMappings)
      if (paymentAccountId <= 0 && sourcePaymentAccountName.length > 0) {
        paymentAccountId = this.findRestoredAccountIdByName(sourcePaymentAccountName, accountMappings)
      }
      if (paymentAccountId <= 0) {
        paymentAccountId = fallbackAccount.id
      }
      let paymentAccountName = sourcePaymentAccountName
      if (paymentAccountName.length === 0) {
        paymentAccountName = fallbackAccount.name
      }
      const bucket: relationalStore.ValuesBucket = {
        id: source.localId,
        userId: userLocalId,
        bookId: bookLocalId,
        paymentAccountId: paymentAccountId,
        paymentAccountName: paymentAccountName,
        amount: source.amount,
        type: source.type,
        category: source.category,
        categoryId: categoryId,
        remark: source.remark,
        date: source.date,
        createdAt: source.createdAt
      }
      await store.insert('bills', bucket)
      LogUtils.info(CLOUD_DB_TAG,
        '云数据库恢复本地账单成功 userLocalId=%{public}s bookLocalId=%{public}s cloudId=%{public}s localId=%{public}s amount=%{public}s category=%{public}s date=%{public}s',
        userLocalId.toString(), bookLocalId.toString(), source.cloudId, source.localId.toString(),
        source.amount.toString(), source.category, source.date)
      LogUtils.info(CLOUD_DB_TAG,
        '云数据库恢复账单分类映射 cloudId=%{public}s sourceCategoryLocalId=%{public}s restoredCategoryId=%{public}s sourcePaymentAccountLocalId=%{public}s restoredPaymentAccountId=%{public}s',
        source.cloudId, sourceCategoryId.toString(), categoryId.toString(), sourcePaymentAccountId.toString(),
        paymentAccountId.toString())
      count += 1
    }
    return count
  }

  private async restoreCategoriesFromJson(userLocalId: number, bookLocalId: number, jsonText: string): Promise<CategoryIdMapping[]> {
    const store = DBHelper.getInstance().getStore()
    await this.deleteLocalRows(store, 'categories', userLocalId, bookLocalId)
    const categories = this.parseCategoryArray(jsonText)
    const mappings: CategoryIdMapping[] = []
    for (let i = 0; i < categories.length; i++) {
      const source = categories[i]
      const bucket: relationalStore.ValuesBucket = {
        userId: userLocalId,
        bookId: bookLocalId,
        name: source.name,
        icon: source.icon,
        color: source.color,
        type: source.type,
        sort_order: source.sort_order,
        is_default: source.is_default
      }
      const rowId = await store.insert('categories', bucket)
      mappings.push({
        sourceId: source.id,
        restoredId: rowId,
        name: source.name,
        type: source.type
      })
    }
    LogUtils.info(CLOUD_DB_TAG, '云数据库恢复分类完成 userLocalId=%{public}s bookLocalId=%{public}s count=%{public}s',
      userLocalId.toString(), bookLocalId.toString(), mappings.length.toString())
    return mappings
  }

  private async restorePaymentAccountsFromJson(
    userLocalId: number,
    bookLocalId: number,
    jsonText: string
  ): Promise<PaymentAccountIdMapping[]> {
    if (jsonText.length === 0) {
      await PaymentAccountDao.getInstance().ensureDefaultAccounts(userLocalId, bookLocalId)
      LogUtils.info(CLOUD_DB_TAG, '云数据库账户数组为空，已保留或初始化默认账户 userLocalId=%{public}s bookLocalId=%{public}s',
        userLocalId.toString(), bookLocalId.toString())
      return []
    }
    const store = DBHelper.getInstance().getStore()
    await this.deleteLocalRows(store, 'payment_accounts', userLocalId, bookLocalId)
    const accounts = this.parsePaymentAccountArray(jsonText)
    const mappings: PaymentAccountIdMapping[] = []
    for (let i = 0; i < accounts.length; i++) {
      const source = accounts[i]
      const sourceType = this.safePaymentAccountType(source.type)
      const now = Date.now()
      const name = this.safeString(source.name).length > 0 ? this.safeString(source.name) : this.defaultPaymentAccountName(sourceType)
      const enabled = source.enabled === 0 ? 0 : 1
      const isDefault = source.isDefault === 1 ? 1 : 0
      const bucket: relationalStore.ValuesBucket = {
        userId: userLocalId,
        bookId: bookLocalId,
        name: name,
        type: sourceType,
        bankName: this.safeString(source.bankName),
        tailNumber: this.safeString(source.tailNumber),
        iconMark: this.safeString(source.iconMark),
        color: this.safeString(source.color).length > 0 ? this.safeString(source.color) : this.defaultPaymentAccountColor(sourceType),
        manualBalance: this.safeNumberValue(source.manualBalance),
        balanceUpdatedAt: this.safeNumberValue(source.balanceUpdatedAt) > 0 ? this.safeNumberValue(source.balanceUpdatedAt) : now,
        sortOrder: this.safeNumberValue(source.sortOrder),
        isDefault: isDefault,
        enabled: isDefault === 1 ? 1 : enabled,
        createdAt: this.safeNumberValue(source.createdAt) > 0 ? this.safeNumberValue(source.createdAt) : now,
        updatedAt: this.safeNumberValue(source.updatedAt) > 0 ? this.safeNumberValue(source.updatedAt) : now,
        deleted: this.safeNumberValue(source.deleted)
      }
      const rowId = await store.insert('payment_accounts', bucket)
      mappings.push({
        sourceId: this.safeNumberValue(source.id),
        restoredId: rowId,
        name: name
      })
    }
    await PaymentAccountDao.getInstance().ensureDefaultAccounts(userLocalId, bookLocalId)
    LogUtils.info(CLOUD_DB_TAG, '云数据库恢复账户完成 userLocalId=%{public}s bookLocalId=%{public}s count=%{public}s',
      userLocalId.toString(), bookLocalId.toString(), mappings.length.toString())
    return mappings
  }

  private async restorePeriodRulesFromJson(userLocalId: number, bookLocalId: number, jsonText: string): Promise<number> {
    const store = DBHelper.getInstance().getStore()
    await this.deleteLocalRows(store, 'period_rules', userLocalId, bookLocalId)
    const rules = this.parsePeriodRuleArray(jsonText)
    for (let i = 0; i < rules.length; i++) {
      const source = rules[i]
      const bucket: relationalStore.ValuesBucket = {
        userId: userLocalId,
        bookId: bookLocalId,
        title: source.title,
        amount: source.amount,
        type: source.type,
        category: source.category,
        remark: source.remark,
        cycle: source.cycle,
        day: source.day,
        month: source.month,
        nextDate: source.nextDate,
        enabled: source.enabled,
        createdAt: source.createdAt
      }
      await store.insert('period_rules', bucket)
    }
    return rules.length
  }

  private async restoreBudgetRulesFromJson(
    userLocalId: number,
    bookLocalId: number,
    jsonText: string,
    categoryMappings: CategoryIdMapping[]
  ): Promise<number> {
    const rules = this.parseBudgetRuleArray(jsonText)
    const nextRules: BudgetRule[] = []
    for (let i = 0; i < rules.length; i++) {
      const source = rules[i]
      if (source.periodType === undefined || source.scopeType === undefined) {
        nextRules.push(this.remapBudgetRuleCategoryIds(this.convertLegacyBudgetToRule(userLocalId, bookLocalId, source), categoryMappings))
      } else {
        nextRules.push(this.remapBudgetRuleCategoryIds(this.normalizeRestoredBudgetRule(userLocalId, bookLocalId, source), categoryMappings))
      }
    }
    return await BudgetRuleDao.getInstance().replaceAllForUserBook(userLocalId, bookLocalId, nextRules)
  }

  private async restoreBudgetRulesFromCloudRows(
    userLocalId: number,
    bookLocalId: number,
    rows: CloudBudgetRule[],
    categoryMappings: CategoryIdMapping[]
  ): Promise<number> {
    const nextRules: BudgetRule[] = []
    for (let i = 0; i < rows.length; i++) {
      const source = rows[i]
      if (source.deleted === 1) {
        continue
      }
      const rule = createEmptyBudgetRule()
      rule.id = this.safeString(source.ruleId).length > 0 ? source.ruleId : source.cloudId
      rule.userId = userLocalId
      rule.bookId = bookLocalId
      rule.name = this.safeString(source.name).length > 0 ? source.name : '预算规则'
      rule.periodType = this.safeBudgetPeriodType(source.periodType)
      rule.scopeType = this.safeBudgetScopeType(source.scopeType)
      rule.amount = this.safeNumberValue(source.amount)
      rule.categoryIdsJson = this.safeString(source.categoryIdsJson).length > 0 ? source.categoryIdsJson : '[]'
      rule.categoryNamesJson = this.safeString(source.categoryNamesJson).length > 0 ? source.categoryNamesJson : '[]'
      rule.dateMode = this.safeString(source.dateMode).length > 0 ? source.dateMode : 'current'
      rule.periodValue = this.safeString(source.periodValue)
      rule.startDay = this.safeNumberValue(source.startDay) > 0 ? this.safeNumberValue(source.startDay) : 1
      rule.endDay = this.safeNumberValue(source.endDay) > 0 ? this.safeNumberValue(source.endDay) : 31
      rule.compareMode = this.safeString(source.compareMode).length > 0 ? source.compareMode : 'previous'
      rule.status = this.safeString(source.status).length > 0 ? source.status : 'active'
      rule.enabled = source.enabled === 0 ? 0 : 1
      rule.createdAt = this.safeNumberValue(source.createdAt)
      rule.updatedAt = this.safeNumberValue(source.updatedAt)
      rule.deleted = 0
      nextRules.push(this.remapBudgetRuleCategoryIds(rule, categoryMappings))
    }
    return await BudgetRuleDao.getInstance().replaceAllForUserBook(userLocalId, bookLocalId, nextRules)
  }

  private remapBudgetRuleCategoryIds(rule: BudgetRule, categoryMappings: CategoryIdMapping[]): BudgetRule {
    if (rule.scopeType !== 'categories') {
      return rule
    }
    const oldIds = this.parseNumberArray(rule.categoryIdsJson)
    const names = this.parseStringArray(rule.categoryNamesJson)
    const nextIds: number[] = []
    const nextNames: string[] = []
    const count = oldIds.length > 0 ? oldIds.length : names.length
    for (let i = 0; i < count; i++) {
      let restoredId = 0
      if (i < oldIds.length) {
        restoredId = this.findRestoredCategoryIdBySourceId(oldIds[i], categoryMappings)
      }
      if (restoredId <= 0 && i < names.length) {
        restoredId = this.findRestoredCategoryIdByName(names[i], categoryMappings)
      }
      if (restoredId > 0) {
        nextIds.push(restoredId)
        if (i < names.length) {
          nextNames.push(names[i])
        } else {
          nextNames.push(this.findRestoredCategoryName(restoredId, categoryMappings))
        }
      }
    }
    rule.categoryIdsJson = JSON.stringify(nextIds)
    rule.categoryNamesJson = JSON.stringify(nextNames)
    LogUtils.info(CLOUD_DB_TAG,
      '云数据库恢复预算分类映射完成 ruleId=%{public}s oldCount=%{public}s newCount=%{public}s',
      rule.id, oldIds.length.toString(), nextIds.length.toString())
    return rule
  }

  private parseNumberArray(jsonText: string): number[] {
    if (jsonText.length === 0) {
      return []
    }
    try {
      return JSON.parse(jsonText) as number[]
    } catch (err) {
      LogUtils.error(CLOUD_DB_TAG, '解析预算分类 ID 数组失败：%{public}s', this.formatError(err))
      return []
    }
  }

  private parseStringArray(jsonText: string): string[] {
    if (jsonText.length === 0) {
      return []
    }
    try {
      return JSON.parse(jsonText) as string[]
    } catch (err) {
      LogUtils.error(CLOUD_DB_TAG, '解析预算分类名称数组失败：%{public}s', this.formatError(err))
      return []
    }
  }

  private findRestoredCategoryIdBySourceId(sourceId: number, categoryMappings: CategoryIdMapping[]): number {
    for (let i = 0; i < categoryMappings.length; i++) {
      if (categoryMappings[i].sourceId === sourceId) {
        return categoryMappings[i].restoredId
      }
    }
    return 0
  }

  private findRestoredCategoryIdByName(name: string, categoryMappings: CategoryIdMapping[]): number {
    for (let i = 0; i < categoryMappings.length; i++) {
      if (categoryMappings[i].name === name) {
        return categoryMappings[i].restoredId
      }
    }
    return 0
  }

  private findRestoredCategoryName(restoredId: number, categoryMappings: CategoryIdMapping[]): string {
    for (let i = 0; i < categoryMappings.length; i++) {
      if (categoryMappings[i].restoredId === restoredId) {
        return categoryMappings[i].name
      }
    }
    return ''
  }

  private findRestoredAccountIdBySourceId(sourceId: number, accountMappings: PaymentAccountIdMapping[]): number {
    for (let i = 0; i < accountMappings.length; i++) {
      if (accountMappings[i].sourceId === sourceId) {
        return accountMappings[i].restoredId
      }
    }
    return 0
  }

  private findRestoredAccountIdByName(name: string, accountMappings: PaymentAccountIdMapping[]): number {
    for (let i = 0; i < accountMappings.length; i++) {
      if (accountMappings[i].name === name) {
        return accountMappings[i].restoredId
      }
    }
    return 0
  }

  private async deleteLocalRows(store: relationalStore.RdbStore, tableName: string, userLocalId: number, bookLocalId: number): Promise<void> {
    const predicates = new relationalStore.RdbPredicates(tableName)
    predicates.equalTo('userId', userLocalId)
    predicates.equalTo('bookId', bookLocalId)
    await store.delete(predicates)
  }

  private async waitWithTimeout<T>(task: Promise<T>, traceId: string, action: string): Promise<T> {
    let timeoutId: number = -1
    const timeoutTask: Promise<T> = new Promise<T>((resolve, reject) => {
      timeoutId = setTimeout(() => {
        LogUtils.error(CLOUD_DB_TAG,
          '云数据库请求超时 trace=%{public}s action=%{public}s timeoutMs=%{public}s',
          traceId, action, CLOUD_DB_QUERY_TIMEOUT_MS.toString())
        reject(new Error('云数据库请求超时，当前设备可能无法访问 AGC 云数据库。若在模拟器中运行，请优先改用真机测试。'))
      }, CLOUD_DB_QUERY_TIMEOUT_MS)
    })
    try {
      return await Promise.race([task, timeoutTask])
    } finally {
      if (timeoutId >= 0) {
        clearTimeout(timeoutId)
      }
    }
  }

  private parseCategoryArray(jsonText: string): CategoryRecord[] {
    if (jsonText.length === 0) {
      return []
    }
    return JSON.parse(jsonText) as CategoryRecord[]
  }

  private parsePeriodRuleArray(jsonText: string): PeriodRule[] {
    if (jsonText.length === 0) {
      return []
    }
    return JSON.parse(jsonText) as PeriodRule[]
  }

  private parsePaymentAccountArray(jsonText: string): PaymentAccount[] {
    if (jsonText.length === 0) {
      return []
    }
    return JSON.parse(jsonText) as PaymentAccount[]
  }

  private parseBudgetRuleArray(jsonText: string): BudgetJsonItem[] {
    if (jsonText.length === 0) {
      return []
    }
    return JSON.parse(jsonText) as BudgetJsonItem[]
  }

  private normalizeRestoredBudgetRule(userLocalId: number, bookLocalId: number, source: BudgetJsonItem): BudgetRule {
    const rule = createEmptyBudgetRule()
    rule.id = source.id !== undefined ? source.id : 'budget_restore_' + Date.now().toString()
    rule.userId = userLocalId
    rule.bookId = bookLocalId
    rule.name = source.name !== undefined ? source.name : '预算规则'
    rule.periodType = source.periodType !== undefined ? source.periodType : 'month'
    rule.scopeType = source.scopeType !== undefined ? source.scopeType : 'total'
    rule.amount = source.amount !== undefined ? source.amount : 0
    rule.categoryIdsJson = source.categoryIdsJson !== undefined ? source.categoryIdsJson : '[]'
    rule.categoryNamesJson = source.categoryNamesJson !== undefined ? source.categoryNamesJson : '[]'
    rule.dateMode = source.dateMode !== undefined ? source.dateMode : 'current'
    rule.periodValue = source.periodValue !== undefined ? source.periodValue : ''
    rule.startDay = source.startDay !== undefined ? source.startDay : 1
    rule.endDay = source.endDay !== undefined ? source.endDay : 31
    rule.compareMode = source.compareMode !== undefined ? source.compareMode : 'previous'
    rule.status = source.status !== undefined ? source.status : 'active'
    rule.enabled = source.enabled !== undefined ? source.enabled : 1
    rule.createdAt = source.createdAt !== undefined ? source.createdAt : Date.now()
    rule.updatedAt = source.updatedAt !== undefined ? source.updatedAt : rule.createdAt
    rule.deleted = source.deleted !== undefined ? source.deleted : 0
    return rule
  }

  private convertLegacyBudgetToRule(userLocalId: number, bookLocalId: number, source: BudgetJsonItem): BudgetRule {
    const now = Date.now()
    const categoryId = source.categoryId !== undefined ? source.categoryId : 0
    const amount = source.amount !== undefined ? source.amount : 0
    const updatedAt = source.updatedAt !== undefined ? source.updatedAt : now
    const rule = createEmptyBudgetRule()
    rule.id = 'budget_cloud_legacy_' + userLocalId.toString() + '_' + bookLocalId.toString() + '_' + categoryId.toString()
    rule.userId = userLocalId
    rule.bookId = bookLocalId
    rule.name = '分类月预算'
    rule.periodType = 'month'
    rule.scopeType = 'categories'
    rule.amount = amount
    rule.categoryIdsJson = JSON.stringify([categoryId])
    rule.categoryNamesJson = '[]'
    rule.dateMode = 'current'
    rule.periodValue = ''
    rule.startDay = 1
    rule.endDay = 31
    rule.compareMode = 'previous'
    rule.status = 'active'
    rule.enabled = 1
    rule.createdAt = updatedAt > 0 ? updatedAt : now
    rule.updatedAt = updatedAt > 0 ? updatedAt : now
    rule.deleted = 0
    return rule
  }

  private logQueryCount(traceId: string, objectName: string, count: number): void {
    LogUtils.info(CLOUD_DB_TAG, '云数据库查询完成 trace=%{public}s object=%{public}s count=%{public}s',
      traceId, objectName, count.toString())
  }

  private logRawUsers(traceId: string, action: string, rows: UserInfo[]): void {
    for (let i = 0; i < rows.length; i++) {
      LogUtils.error(CLOUD_DB_TAG, '云数据库原始数据 trace=%{public}s action=%{public}s object=%{public}s row=%{public}s data=%{public}s',
        traceId, action, CLOUD_DB_OBJECT_USER, (i + 1).toString(), this.stringifyUser(rows[i]))
    }
  }

  private logRawBooks(traceId: string, action: string, rows: CloudAccountBook[]): void {
    for (let i = 0; i < rows.length; i++) {
      LogUtils.error(CLOUD_DB_TAG, '云数据库原始数据 trace=%{public}s action=%{public}s object=%{public}s row=%{public}s data=%{public}s',
        traceId, action, CLOUD_DB_OBJECT_BOOK, (i + 1).toString(), this.stringifyBook(rows[i]))
    }
  }

  private logRawBundles(traceId: string, action: string, rows: CloudUserDataBundle[]): void {
    for (let i = 0; i < rows.length; i++) {
      LogUtils.error(CLOUD_DB_TAG, '云数据库原始数据 trace=%{public}s action=%{public}s object=%{public}s row=%{public}s data=%{public}s',
        traceId, action, CLOUD_DB_OBJECT_USER_DATA_BUNDLE, (i + 1).toString(), this.stringifyBundle(rows[i]))
    }
  }

  private logRawBills(traceId: string, action: string, rows: CloudBill[]): void {
    for (let i = 0; i < rows.length; i++) {
      LogUtils.error(CLOUD_DB_TAG, '云数据库原始数据 trace=%{public}s action=%{public}s object=%{public}s row=%{public}s data=%{public}s',
        traceId, action, CLOUD_DB_OBJECT_BILL, (i + 1).toString(), this.stringifyBill(rows[i]))
    }
  }

  private logRawCategories(traceId: string, action: string, rows: CloudCategory[]): void {
    for (let i = 0; i < rows.length; i++) {
      LogUtils.error(CLOUD_DB_TAG, '云数据库原始数据 trace=%{public}s action=%{public}s object=%{public}s row=%{public}s data=%{public}s',
        traceId, action, CLOUD_DB_OBJECT_CATEGORY, (i + 1).toString(), this.stringifyCategory(rows[i]))
    }
  }

  private logRawPeriodRules(traceId: string, action: string, rows: CloudPeriodRule[]): void {
    for (let i = 0; i < rows.length; i++) {
      LogUtils.error(CLOUD_DB_TAG, '云数据库原始数据 trace=%{public}s action=%{public}s object=%{public}s row=%{public}s data=%{public}s',
        traceId, action, CLOUD_DB_OBJECT_PERIOD_RULE, (i + 1).toString(), this.stringifyPeriodRule(rows[i]))
    }
  }

  private logRawBudgetRules(traceId: string, action: string, rows: CloudBudgetRule[]): void {
    for (let i = 0; i < rows.length; i++) {
      LogUtils.error(CLOUD_DB_TAG, '云数据库原始数据 trace=%{public}s action=%{public}s object=%{public}s row=%{public}s data=%{public}s',
        traceId, action, CLOUD_DB_OBJECT_BUDGET, (i + 1).toString(), this.stringifyBudgetRule(rows[i]))
    }
  }

  private stringifyUser(row: UserInfo): string {
    return JSON.stringify({
      cloudId: row.cloudId,
      accountId: row.accountId,
      localId: row.localId,
      username: row.username,
      displayName: row.displayName,
      passwordHash: row.passwordHash,
      salt: row.salt,
      createdAt: row.createdAt,
      lastLoginAt: row.lastLoginAt,
      updatedAt: row.updatedAt
    })
  }

  private stringifyBook(row: CloudAccountBook): string {
    return JSON.stringify({
      cloudId: row.cloudId,
      ownerUserId: row.ownerUserId,
      localId: row.localId,
      name: row.name,
      currency: row.currency,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      deleted: row.deleted
    })
  }

  private stringifyBundle(row: CloudUserDataBundle): string {
    return JSON.stringify({
      cloudId: row.cloudId,
      accountId: row.accountId,
      bookId: row.bookId,
      schemaVersion: row.schemaVersion,
      bookCount: row.bookCount,
      categoryCount: row.categoryCount,
      accountCount: row.accountCount,
      budgetCount: row.budgetCount,
      periodRuleCount: row.periodRuleCount,
      bookJson: row.bookJson,
      categoryJson: row.categoryJson,
      accountJson: row.accountJson,
      budgetJson: row.budgetJson,
      periodRuleJson: row.periodRuleJson,
      updatedAt: row.updatedAt,
      deleted: row.deleted
    })
  }

  private stringifyBill(row: CloudBill): string {
    return JSON.stringify({
      cloudId: row.cloudId,
      accountId: row.accountId,
      userId: row.userId,
      bookId: row.bookId,
      localId: row.localId,
      paymentAccountLocalId: row.paymentAccountLocalId,
      paymentAccountName: row.paymentAccountName,
      categoryLocalId: row.categoryLocalId,
      amount: row.amount,
      type: row.type,
      category: row.category,
      remark: row.remark,
      date: row.date,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      deleted: row.deleted
    })
  }

  private stringifyCategory(row: CloudCategory): string {
    return JSON.stringify({
      cloudId: row.cloudId,
      userId: row.userId,
      bookId: row.bookId,
      localId: row.localId,
      name: row.name,
      icon: row.icon,
      color: row.color,
      type: row.type,
      sortOrder: row.sortOrder,
      isDefault: row.isDefault,
      updatedAt: row.updatedAt,
      deleted: row.deleted
    })
  }

  private stringifyPeriodRule(row: CloudPeriodRule): string {
    return JSON.stringify({
      cloudId: row.cloudId,
      userId: row.userId,
      bookId: row.bookId,
      localId: row.localId,
      title: row.title,
      amount: row.amount,
      type: row.type,
      category: row.category,
      remark: row.remark,
      cycle: row.cycle,
      day: row.day,
      month: row.month,
      nextDate: row.nextDate,
      enabled: row.enabled,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      deleted: row.deleted
    })
  }

  private stringifyBudgetRule(row: CloudBudgetRule): string {
    return JSON.stringify({
      cloudId: row.cloudId,
      accountId: row.accountId,
      userId: row.userId,
      bookId: row.bookId,
      ruleId: row.ruleId,
      name: row.name,
      periodType: row.periodType,
      scopeType: row.scopeType,
      amount: row.amount,
      categoryIdsJson: row.categoryIdsJson,
      categoryNamesJson: row.categoryNamesJson,
      dateMode: row.dateMode,
      periodValue: row.periodValue,
      startDay: row.startDay,
      endDay: row.endDay,
      compareMode: row.compareMode,
      status: row.status,
      enabled: row.enabled,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      deleted: row.deleted
    })
  }

  private logSkipEmpty(traceId: string, objectName: string, count: number): void {
    if (count === 0) {
      LogUtils.info(CLOUD_DB_TAG, '云数据库跳过 trace=%{public}s object=%{public}s reason=本地数据为空',
        traceId, objectName)
    }
  }

  private logBundleMode(traceId: string, objectName: string, detail: string): void {
    LogUtils.info(CLOUD_DB_TAG, '云数据库数组包模式 trace=%{public}s object=%{public}s detail=%{public}s',
      traceId, objectName, detail)
  }

  private safeMatchedCount(localCount: number, cloudCount: number): number {
    if (cloudCount >= localCount) {
      return localCount
    }
    return cloudCount
  }

  private buildTraceId(action: string): string {
    return action + '_' + Date.now().toString()
  }

  private buildUserKey(userLocalId: number): string {
    return 'user_' + userLocalId.toString()
  }

  private buildCloudId(parentKey: string, typeName: string, localId: number): string {
    return parentKey + '_' + typeName + '_' + localId.toString()
  }

  private safeAccountId(user: UserInfo, fallback: string): string {
    const accountId = this.safeString(user.accountId)
    if (accountId.length > 0) {
      return accountId
    }
    return fallback
  }

  private safeString(value: string | null | undefined): string {
    if (value === undefined || value === null) {
      return ''
    }
    return value
  }

  private safeNumber(value: number | null | undefined): string {
    if (value === undefined || value === null) {
      return '0'
    }
    return value.toString()
  }

  private safeNumberValue(value: number | null | undefined): number {
    if (value === undefined || value === null) {
      return 0
    }
    return value
  }

  private safePaymentAccountType(value: string | null | undefined): PaymentAccountType {
    if (value === 'bank') {
      return 'bank'
    }
    if (value === 'alipay') {
      return 'alipay'
    }
    if (value === 'wechat') {
      return 'wechat'
    }
    if (value === 'cash') {
      return 'cash'
    }
    return 'other'
  }

  private safeBudgetPeriodType(value: string | null | undefined): string {
    if (value === 'day' || value === 'month' || value === 'year') {
      return value
    }
    return 'month'
  }

  private safeBudgetScopeType(value: string | null | undefined): string {
    if (value === 'categories') {
      return 'categories'
    }
    return 'total'
  }

  private defaultPaymentAccountName(type: PaymentAccountType): string {
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

  private defaultPaymentAccountColor(type: PaymentAccountType): string {
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

  private formatError(err: Error | Object): string {
    if (err instanceof Error) {
      return err.message
    }
    const cloudError = err as CloudRuntimeError
    const parts: string[] = []
    if (cloudError.code !== undefined) {
      parts.push('code=' + cloudError.code.toString())
    }
    if (cloudError.name !== undefined && cloudError.name.length > 0) {
      parts.push('name=' + cloudError.name)
    }
    if (cloudError.message !== undefined && cloudError.message.length > 0) {
      parts.push('message=' + cloudError.message)
    }
    const jsonText = JSON.stringify(err)
    if (jsonText.length > 0 && jsonText !== '{}') {
      parts.push('json=' + jsonText)
    }
    const stringText = String(err)
    if (stringText.length > 0 && stringText !== '[object Object]') {
      parts.push('text=' + stringText)
    }
    if (parts.length === 0) {
      return '未知云数据库错误，SDK 返回对象没有可枚举字段'
    }
    return parts.join(', ')
  }
}
