import { common } from '@kit.AbilityKit'
import { BillDao } from '../database/BillDao'
import { CategoryDao } from '../database/CategoryDao'
import { BudgetRuleDao } from '../database/BudgetRuleDao'
import { PeriodRuleDao } from '../database/PeriodRuleDao'
import { UserDao } from '../database/UserDao'
import { AccountBookDao } from '../database/AccountBookDao'
import { PaymentAccountDao } from '../database/PaymentAccountDao'
import { Bill } from '../model/Bill'
import { CategoryRecord } from '../model/Category'
import { BudgetConflictResult, BudgetOverview, BudgetRule, BudgetRuleUsage } from '../model/BudgetRule'
import { PeriodRule } from '../model/PeriodRule'
import { PaymentAccount, PaymentAccountType } from '../model/PaymentAccount'
import { FilterOptions } from '../model/FilterOptions'
import { SearchFilterOptions } from '../model/SearchFilterOptions'
import { CategoryStat, MonthStat, DaySummary } from '../model/StatResult'
import { UserSession } from '../model/User'
import {
  CloudDatabaseCompletenessResult,
  CloudDatabaseRestoreResult,
  CloudDatabaseService,
  CloudDatabaseSyncResult
} from './CloudDatabaseService'
import { LogUtils } from '../utils/LogUtils'
import { BudgetService } from './BudgetService'

const APP_DATA_API_TAG = 'AppDataApi'

export class AppDataApi {
  private static instance: AppDataApi | null = null
  private cloudRestoreBusy: boolean = false
  private lastCloudRestoreAt: number = 0
  private cloudRestoreThrottleMs: number = 5000

  private constructor() {}

  static getInstance(): AppDataApi {
    if (!AppDataApi.instance) {
      AppDataApi.instance = new AppDataApi()
    }
    return AppDataApi.instance
  }

  async addBill(context: common.BaseContext | null, bill: Bill, syncCloud: boolean): Promise<number> {
    const rowId = await BillDao.getInstance().insert(bill)
    this.notifyBillChanged('addBill')
    LogUtils.info(APP_DATA_API_TAG, '账单接口-新增账单成功 rowId=%{public}s syncCloud=%{public}s',
      rowId.toString(), syncCloud.toString())
    if (syncCloud) {
      await this.syncCloudAfterLocalChanged(context, 'addBill', rowId)
    }
    return rowId
  }

  async deleteBill(id: number, context: common.BaseContext | null, syncCloud: boolean): Promise<void> {
    await BillDao.getInstance().deleteById(id)
    this.notifyBillChanged('deleteBill')
    LogUtils.info(APP_DATA_API_TAG, '账单接口-删除账单成功 id=%{public}s syncCloud=%{public}s',
      id.toString(), syncCloud.toString())
    if (syncCloud) {
      await this.syncCloudAfterLocalChanged(context, 'deleteBill', id)
    }
  }

  async queryBillById(id: number): Promise<Bill | null> {
    return await BillDao.getInstance().queryById(id)
  }

  async updateBill(context: common.BaseContext | null, bill: Bill, syncCloud: boolean): Promise<void> {
    await BillDao.getInstance().update(bill)
    this.notifyBillChanged('updateBill')
    LogUtils.info(APP_DATA_API_TAG, '账单接口-更新账单成功 id=%{public}s syncCloud=%{public}s',
      bill.id.toString(), syncCloud.toString())
    if (syncCloud) {
      await this.syncCloudAfterLocalChanged(context, 'updateBill', bill.id)
    }
  }

  async queryBills(filter: FilterOptions): Promise<Bill[]> {
    return await BillDao.getInstance().queryByFilter(filter)
  }

  async searchBills(filter: SearchFilterOptions): Promise<Bill[]> {
    return await BillDao.getInstance().queryBySearchFilter(filter)
  }

  async queryCategoryStats(month: string, type: string): Promise<CategoryStat[]> {
    return await BillDao.getInstance().queryCategoryStats(month, type)
  }

  async queryMonthStats(months: string[]): Promise<MonthStat[]> {
    return await BillDao.getInstance().queryMonthStats(months)
  }

  async queryDailySummary(month: string): Promise<DaySummary[]> {
    return await BillDao.getInstance().queryDailySummary(month)
  }

  async queryCategoriesByType(type: 'income' | 'expense'): Promise<CategoryRecord[]> {
    return await CategoryDao.getInstance().queryByType(type)
  }

  async queryAllCategories(): Promise<CategoryRecord[]> {
    return await CategoryDao.getInstance().queryAll()
  }

  async queryCategoryById(id: number): Promise<CategoryRecord | null> {
    return await CategoryDao.getInstance().queryById(id)
  }

  async queryCategoryByName(name: string, type: string): Promise<CategoryRecord | null> {
    return await CategoryDao.getInstance().queryByName(name, type)
  }

  async addCategory(context: common.BaseContext | null, category: CategoryRecord, syncCloud: boolean): Promise<number> {
    const rowId = await CategoryDao.getInstance().insert(category)
    this.notifyDataChanged('addCategory')
    LogUtils.info(APP_DATA_API_TAG, '分类接口-新增分类成功 rowId=%{public}s syncCloud=%{public}s',
      rowId.toString(), syncCloud.toString())
    if (syncCloud) {
      await this.syncCloudAfterLocalChanged(context, 'addCategory', rowId)
    }
    return rowId
  }

  async updateCategory(context: common.BaseContext | null, category: CategoryRecord, oldName: string, syncCloud: boolean): Promise<void> {
    await CategoryDao.getInstance().update(category, oldName)
    this.notifyDataChanged('updateCategory')
    LogUtils.info(APP_DATA_API_TAG, '分类接口-更新分类成功 id=%{public}s syncCloud=%{public}s',
      category.id.toString(), syncCloud.toString())
    if (syncCloud) {
      await this.syncCloudAfterLocalChanged(context, 'updateCategory', category.id)
    }
  }

  async deleteCategory(context: common.BaseContext | null, id: number, syncCloud: boolean): Promise<boolean> {
    const deleted = await CategoryDao.getInstance().deleteById(id)
    if (deleted) {
      this.notifyDataChanged('deleteCategory')
    }
    LogUtils.info(APP_DATA_API_TAG, '分类接口-删除分类完成 id=%{public}s deleted=%{public}s syncCloud=%{public}s',
      id.toString(), deleted.toString(), syncCloud.toString())
    if (deleted && syncCloud) {
      await this.syncCloudAfterLocalChanged(context, 'deleteCategory', id)
    }
    return deleted
  }

  async queryPaymentAccounts(): Promise<PaymentAccount[]> {
    return await PaymentAccountDao.getInstance().queryAll()
  }

  async queryEnabledPaymentAccounts(): Promise<PaymentAccount[]> {
    return await PaymentAccountDao.getInstance().queryEnabled()
  }

  async queryDefaultPaymentAccount(): Promise<PaymentAccount> {
    return await PaymentAccountDao.getInstance().queryDefault()
  }

  async queryPaymentAccountById(id: number): Promise<PaymentAccount | null> {
    return await PaymentAccountDao.getInstance().queryById(id)
  }

  createPaymentAccountDraft(accountType: PaymentAccountType): PaymentAccount {
    return PaymentAccountDao.getInstance().createDraft(accountType)
  }

  async savePaymentAccount(context: common.BaseContext | null, account: PaymentAccount, syncCloud: boolean): Promise<number> {
    const rowId = await PaymentAccountDao.getInstance().upsert(account)
    this.notifyAccountChanged('savePaymentAccount')
    LogUtils.info(APP_DATA_API_TAG, '账户接口-保存账户成功 rowId=%{public}s syncCloud=%{public}s',
      rowId.toString(), syncCloud.toString())
    if (syncCloud) {
      await this.syncCloudAfterLocalChanged(context, 'savePaymentAccount', rowId)
    }
    return rowId
  }

  async setDefaultPaymentAccount(context: common.BaseContext | null, id: number, syncCloud: boolean): Promise<void> {
    await PaymentAccountDao.getInstance().setDefault(id)
    this.notifyAccountChanged('setDefaultPaymentAccount')
    if (syncCloud) {
      await this.syncCloudAfterLocalChanged(context, 'setDefaultPaymentAccount', id)
    }
  }

  async setPaymentAccountEnabled(context: common.BaseContext | null, id: number, enabled: number, syncCloud: boolean): Promise<void> {
    await PaymentAccountDao.getInstance().setEnabled(id, enabled)
    this.notifyAccountChanged('setPaymentAccountEnabled')
    if (syncCloud) {
      await this.syncCloudAfterLocalChanged(context, 'setPaymentAccountEnabled', id)
    }
  }

  async deletePaymentAccount(context: common.BaseContext | null, id: number, syncCloud: boolean): Promise<void> {
    await PaymentAccountDao.getInstance().softDelete(id)
    this.notifyAccountChanged('deletePaymentAccount')
    if (syncCloud) {
      await this.syncCloudAfterLocalChanged(context, 'deletePaymentAccount', id)
    }
  }

  async updateCategorySortOrder(context: common.BaseContext | null, items: CategoryRecord[], syncCloud: boolean): Promise<void> {
    await CategoryDao.getInstance().updateSortOrder(items)
    if (syncCloud) {
      await this.syncCloudAfterLocalChanged(context, 'updateCategorySortOrder', items.length)
    }
  }

  async getMaxCategorySortOrder(type: string): Promise<number> {
    return await CategoryDao.getInstance().getMaxSortOrder(type)
  }

  async refreshCategoryCache(): Promise<void> {
    await CategoryDao.getInstance().refreshCache()
  }

  async queryBudgetRules(): Promise<BudgetRule[]> {
    return await BudgetRuleDao.getInstance().queryAll()
  }

  async queryBudgetRuleUsages(): Promise<BudgetRuleUsage[]> {
    return await BudgetService.getInstance().buildRuleUsages()
  }

  async queryBudgetOverview(periodType: string): Promise<BudgetOverview> {
    return await BudgetService.getInstance().buildOverview(periodType)
  }

  createBudgetRuleDraft(): BudgetRule {
    return BudgetRuleDao.getInstance().createDraft()
  }

  async checkBudgetRuleConflict(rule: BudgetRule): Promise<BudgetConflictResult> {
    return await BudgetRuleDao.getInstance().checkConflict(rule)
  }

  async checkBudgetRuleOverflow(rule: BudgetRule): Promise<BudgetOverview> {
    return await BudgetService.getInstance().detectOverflowWithPending(rule)
  }

  async saveBudgetRule(context: common.BaseContext | null, rule: BudgetRule, syncCloud: boolean): Promise<string> {
    const id = await BudgetRuleDao.getInstance().upsert(rule)
    this.notifyBudgetChanged('saveBudgetRule')
    LogUtils.info(APP_DATA_API_TAG, '预算规则接口-保存成功 id=%{public}s syncCloud=%{public}s',
      id, syncCloud.toString())
    if (syncCloud) {
      await this.syncCloudAfterLocalChanged(context, 'saveBudgetRule', 0)
    }
    return id
  }

  async saveBudgetRuleBatch(
    context: common.BaseContext | null,
    rules: BudgetRule[],
    deletedRuleIds: string[],
    syncCloud: boolean
  ): Promise<void> {
    for (let i = 0; i < rules.length; i++) {
      await BudgetRuleDao.getInstance().upsert(rules[i])
    }
    for (let j = 0; j < deletedRuleIds.length; j++) {
      await BudgetRuleDao.getInstance().softDelete(deletedRuleIds[j])
    }
    this.notifyBudgetChanged('saveBudgetRuleBatch')
    LogUtils.info(APP_DATA_API_TAG, '预算规则批量保存完成 saveCount=%{public}s deleteCount=%{public}s syncCloud=%{public}s',
      rules.length.toString(), deletedRuleIds.length.toString(), syncCloud.toString())
    if (syncCloud) {
      await this.syncCloudAfterLocalChanged(context, 'saveBudgetRuleBatch', 0)
    }
  }

  async setBudgetRuleEnabled(context: common.BaseContext | null, id: string, enabled: number, syncCloud: boolean): Promise<void> {
    await BudgetRuleDao.getInstance().setEnabled(id, enabled)
    this.notifyBudgetChanged('setBudgetRuleEnabled')
    if (syncCloud) {
      await this.syncCloudAfterLocalChanged(context, 'setBudgetRuleEnabled', 0)
    }
  }

  async deleteBudgetRule(context: common.BaseContext | null, id: string, syncCloud: boolean): Promise<void> {
    await BudgetRuleDao.getInstance().softDelete(id)
    this.notifyBudgetChanged('deleteBudgetRule')
    if (syncCloud) {
      await this.syncCloudAfterLocalChanged(context, 'deleteBudgetRule', 0)
    }
  }

  async queryPeriodRulesByType(type: 'income' | 'expense'): Promise<PeriodRule[]> {
    return await PeriodRuleDao.getInstance().queryByType(type)
  }

  async queryEnabledPeriodRules(): Promise<PeriodRule[]> {
    return await PeriodRuleDao.getInstance().queryEnabled()
  }

  async queryAllPeriodRules(): Promise<PeriodRule[]> {
    return await PeriodRuleDao.getInstance().queryAll()
  }

  async addPeriodRule(context: common.BaseContext | null, rule: PeriodRule, syncCloud: boolean): Promise<number> {
    const rowId = await PeriodRuleDao.getInstance().insert(rule)
    LogUtils.info(APP_DATA_API_TAG, '周期记账接口-新增规则成功 rowId=%{public}s syncCloud=%{public}s',
      rowId.toString(), syncCloud.toString())
    if (syncCloud) {
      await this.syncCloudAfterLocalChanged(context, 'addPeriodRule', rowId)
    }
    return rowId
  }

  async updatePeriodRuleEnabled(context: common.BaseContext | null, id: number, enabled: number, syncCloud: boolean): Promise<void> {
    await PeriodRuleDao.getInstance().updateEnabled(id, enabled)
    if (syncCloud) {
      await this.syncCloudAfterLocalChanged(context, 'updatePeriodRuleEnabled', id)
    }
  }

  async deletePeriodRule(context: common.BaseContext | null, id: number, syncCloud: boolean): Promise<void> {
    await PeriodRuleDao.getInstance().deleteById(id)
    if (syncCloud) {
      await this.syncCloudAfterLocalChanged(context, 'deletePeriodRule', id)
    }
  }

  async generateDueBills(context: common.BaseContext | null, syncCloud: boolean): Promise<number> {
    const count = await PeriodRuleDao.getInstance().generateDueBills()
    if (count > 0) {
      this.notifyBillChanged('generateDueBills')
    }
    if (count > 0 && syncCloud) {
      await this.syncCloudAfterLocalChanged(context, 'generateDueBills', count)
    }
    return count
  }

  nextPeriodRuleDate(cycle: 'monthly' | 'yearly', month: number, day: number, baseDate: Date): string {
    return PeriodRuleDao.getInstance().nextDateFrom(cycle, month, day, baseDate)
  }

  async createLocalUser(context: common.BaseContext, username: string, displayName: string): Promise<UserSession> {
    return await UserDao.getInstance().createLocalUser(context, username, displayName)
  }

  async registerCloudUser(context: common.BaseContext, username: string, displayName: string, password: string): Promise<UserSession> {
    return await UserDao.getInstance().register(context, username, displayName, password)
  }

  async loginCloudUser(context: common.BaseContext, username: string, password: string): Promise<UserSession> {
    return await UserDao.getInstance().login(context, username, password)
  }

  async getCurrentUser(context: common.BaseContext): Promise<UserSession | null> {
    return await UserDao.getInstance().getCurrentUser(context)
  }

  async logout(context: common.BaseContext): Promise<void> {
    await UserDao.getInstance().logout(context)
  }

  async isCloudRegistered(context: common.BaseContext): Promise<boolean> {
    return await UserDao.getInstance().isCloudRegistered(context)
  }

  async ensureCurrentBook(userId: number, displayName: string): Promise<void> {
    await AccountBookDao.getInstance().ensureDefaultBookForUser(userId, displayName)
  }

  async syncCloud(context: common.BaseContext): Promise<CloudDatabaseSyncResult | null> {
    const session = await UserDao.getInstance().getCurrentUser(context)
    if (!session) {
      LogUtils.info(APP_DATA_API_TAG, '云同步跳过 reason=当前没有用户会话')
      return null
    }
    return await CloudDatabaseService.getInstance().upsertLocalData(session.id, session.username, session.displayName)
  }

  async restoreCloudToLocal(context: common.BaseContext): Promise<CloudDatabaseRestoreResult | null> {
    const session = await UserDao.getInstance().getCurrentUser(context)
    if (!session) {
      LogUtils.info(APP_DATA_API_TAG, '云恢复跳过 reason=当前没有用户会话')
      return null
    }
    const registered = await UserDao.getInstance().isCloudRegistered(context)
    if (!registered) {
      LogUtils.info(APP_DATA_API_TAG, '云恢复跳过 userLocalId=%{public}s reason=当前用户未注册云账号', session.id.toString())
      return null
    }
    const now = Date.now()
    if (this.cloudRestoreBusy) {
      LogUtils.info(APP_DATA_API_TAG,
        '云恢复跳过 userLocalId=%{public}s username=%{public}s reason=已有恢复任务运行中',
        session.id.toString(), session.username)
      return null
    }
    if (now - this.lastCloudRestoreAt < this.cloudRestoreThrottleMs) {
      LogUtils.info(APP_DATA_API_TAG,
        '云恢复跳过 userLocalId=%{public}s username=%{public}s reason=距离上次恢复过近 costMs=%{public}s',
        session.id.toString(), session.username, (now - this.lastCloudRestoreAt).toString())
      return null
    }
    this.cloudRestoreBusy = true
    this.lastCloudRestoreAt = now
    try {
      const result = await CloudDatabaseService.getInstance().restoreCloudDataToLocal(session.id, session.username, session.displayName)
      this.notifyBudgetChanged('restoreCloudToLocal')
      return result
    } finally {
      this.cloudRestoreBusy = false
    }
  }

  async syncAndCheckCloud(context: common.BaseContext): Promise<CloudDatabaseCompletenessResult | null> {
    const session = await UserDao.getInstance().getCurrentUser(context)
    if (!session) {
      LogUtils.info(APP_DATA_API_TAG, '云同步检查跳过 reason=当前没有用户会话')
      return null
    }
    return await CloudDatabaseService.getInstance().syncAndCheckLocalData(session.id, session.username, session.displayName)
  }

  async checkCloudCompleteness(userLocalId: number): Promise<CloudDatabaseCompletenessResult> {
    return await CloudDatabaseService.getInstance().checkCompleteness(userLocalId)
  }

  private async syncCloudAfterLocalChanged(context: common.BaseContext | null, action: string, targetId: number): Promise<void> {
    if (!context) {
      LogUtils.error(APP_DATA_API_TAG, '本地变更后云同步跳过 action=%{public}s targetId=%{public}s reason=无法获取应用上下文',
        action, targetId.toString())
      return
    }
    try {
      const session = await UserDao.getInstance().getCurrentUser(context)
      if (!session) {
        LogUtils.info(APP_DATA_API_TAG, '本地变更后云同步跳过 action=%{public}s targetId=%{public}s reason=当前没有用户会话',
          action, targetId.toString())
        return
      }
      const registered = await UserDao.getInstance().isCloudRegistered(context)
      if (!registered) {
        LogUtils.info(APP_DATA_API_TAG,
          '本地变更后云同步跳过 action=%{public}s targetId=%{public}s userLocalId=%{public}s reason=当前用户未注册云账号',
          action, targetId.toString(), session.id.toString())
        return
      }
      LogUtils.info(APP_DATA_API_TAG, '本地变更后云同步开始 action=%{public}s targetId=%{public}s userLocalId=%{public}s username=%{public}s',
        action, targetId.toString(), session.id.toString(), session.username)
      if (action === 'deleteBill') {
        try {
          await CloudDatabaseService.getInstance().deleteBill(session.id, targetId)
        } catch (deleteErr) {
          LogUtils.error(APP_DATA_API_TAG, '云端删除账单失败，继续同步本地数据 action=%{public}s targetId=%{public}s error=%{public}s',
            action, targetId.toString(), this.formatError(deleteErr))
        }
      }
      const result = await CloudDatabaseService.getInstance().upsertLocalData(session.id, session.username, session.displayName)
      LogUtils.info(APP_DATA_API_TAG,
        '本地变更后云同步完成 action=%{public}s targetId=%{public}s user=%{public}s bundle=%{public}s bill=%{public}s category=%{public}s account=%{public}s periodRule=%{public}s budget=%{public}s',
        action, targetId.toString(), result.userCount.toString(), result.bundleCount.toString(), result.billCount.toString(),
        result.categoryCount.toString(), result.accountCount.toString(), result.periodRuleCount.toString(), result.budgetCount.toString())
    } catch (err) {
      LogUtils.error(APP_DATA_API_TAG, '本地变更后云同步失败 action=%{public}s targetId=%{public}s error=%{public}s',
        action, targetId.toString(), this.formatError(err))
    }
  }

  private notifyDataChanged(reason: string): void {
    const version = AppStorage.get<number>('appDataVersion')
    const nextVersion = version !== undefined ? version + 1 : 1
    AppStorage.setOrCreate<number>('appDataVersion', nextVersion)
    LogUtils.info(APP_DATA_API_TAG, '应用数据版本更新 reason=%{public}s version=%{public}s', reason, nextVersion.toString())
  }

  private notifyAccountChanged(reason: string): void {
    this.notifyDataChanged(reason)
    const version = AppStorage.get<number>('paymentAccountVersion')
    const nextVersion = version !== undefined ? version + 1 : 1
    AppStorage.setOrCreate<number>('paymentAccountVersion', nextVersion)
    LogUtils.info(APP_DATA_API_TAG, '账户数据版本更新 reason=%{public}s version=%{public}s', reason, nextVersion.toString())
  }

  private notifyBillChanged(reason: string): void {
    this.notifyAccountChanged(reason)
    const billVersion = AppStorage.get<number>('billDataVersion')
    const nextBillVersion = billVersion !== undefined ? billVersion + 1 : 1
    AppStorage.setOrCreate<number>('billDataVersion', nextBillVersion)
    const budgetVersion = AppStorage.get<number>('budgetVersion')
    const nextBudgetVersion = budgetVersion !== undefined ? budgetVersion + 1 : 1
    AppStorage.setOrCreate<number>('budgetVersion', nextBudgetVersion)
    LogUtils.info(APP_DATA_API_TAG, '账单数据版本更新 reason=%{public}s version=%{public}s budgetVersion=%{public}s',
      reason, nextBillVersion.toString(), nextBudgetVersion.toString())
  }

  private notifyBudgetChanged(reason: string): void {
    const version = AppStorage.get<number>('budgetVersion')
    const nextVersion = version !== undefined ? version + 1 : 1
    AppStorage.setOrCreate<number>('budgetVersion', nextVersion)
    LogUtils.info(APP_DATA_API_TAG, '预算数据版本更新 reason=%{public}s version=%{public}s', reason, nextVersion.toString())
  }

  private formatError(err: Error | Object): string {
    if (err instanceof Error) {
      return err.message
    }
    const jsonText = JSON.stringify(err)
    if (jsonText.length > 0 && jsonText !== '{}') {
      return jsonText
    }
    const stringText = String(err)
    if (stringText.length > 0 && stringText !== '[object Object]') {
      return stringText
    }
    return '未知错误'
  }
}
