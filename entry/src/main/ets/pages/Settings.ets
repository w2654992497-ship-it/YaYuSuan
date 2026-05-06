import { preferences } from '@kit.ArkData'
import { fileIo } from '@kit.CoreFileKit'
import picker from '@ohos.file.picker'
import { CategoryRecord } from '../model/Category'
import { CategoryDao } from '../database/CategoryDao'
import { BillDao } from '../database/BillDao'
import { PeriodRuleDao } from '../database/PeriodRuleDao'
import { BudgetRuleDao } from '../database/BudgetRuleDao'
import { FilterOptions } from '../model/FilterOptions'
import { Bill } from '../model/Bill'
import { PeriodRule } from '../model/PeriodRule'
import {
  BudgetConflictResult,
  BudgetOverview,
  BudgetRule,
  BudgetRuleUsage,
  createEmptyBudgetOverview,
  createEmptyBudgetRule
} from '../model/BudgetRule'
import { AmountUtil } from '../utils/AmountUtil'
import { LogUtils } from '../utils/LogUtils'
import { UserDao } from '../database/UserDao'
import { CloudBackupListResult, CloudBackupResult, CloudBackupService } from '../services/CloudBackupService'
import { CloudDatabaseCompletenessResult, CloudDatabaseService } from '../services/CloudDatabaseService'
import { CategoryManagePage } from './CategoryManage'
import { WaterPageBg } from '../components/WaterPageBg'
import { SettingsMainPage } from './settings/SettingsMainPage'
import { SettingsUserDataPage } from './settings/SettingsUserDataPage'
import { SettingsGeneralPage } from './settings/SettingsGeneralPage'
import { SettingsPrivacyPage } from './settings/SettingsPrivacyPage'
import { SettingsSecurityPage } from './settings/SettingsSecurityPage'
import { SettingsFeedbackPage } from './settings/SettingsFeedbackPage'
import { SettingsAboutPage } from './settings/SettingsAboutPage'
import { SettingsDataToolsPage } from './settings/SettingsDataToolsPage'
import { SettingsSyncPage } from './settings/SettingsSyncPage'
import { SettingsThemePage } from './settings/SettingsThemePage'
import { SettingsBudgetPage } from './settings/SettingsBudgetPage'
import { SettingsPeriodPage } from './settings/SettingsPeriodPage'
import { SettingsAccountPage } from './settings/SettingsAccountPage'
import { AppDataApi } from '../services/AppDataApi'
import { ConfirmActionDialog } from '../components/ConfirmActionDialog'

const APP_SETTINGS_PREF_NAME = 'xiaojinyu_settings'
const BUDGET_LOCAL_PREF_NAME = 'xiaojinyu_budget_local'
const SETTINGS_TAG = 'Settings'

interface SettingsBackupData {
  appName: string
  version: string
  exportedAt: string
  bills: Bill[]
  categories: CategoryRecord[]
  periodRules: PeriodRule[]
  budgetRules: BudgetRule[]
}

@Component
export struct SettingsPage {
  @Consume('appNavStack') navStack: NavPathStack
  initialPage: string = 'main'
  @State expenseCategories: CategoryRecord[] = []
  @State incomeCategories: CategoryRecord[] = []
  @State budgetOverview: BudgetOverview = createEmptyBudgetOverview()
  @State budgetDayOverview: BudgetOverview = createEmptyBudgetOverview()
  @State budgetMonthOverview: BudgetOverview = createEmptyBudgetOverview()
  @State budgetYearOverview: BudgetOverview = createEmptyBudgetOverview()
  @State budgetRuleUsages: BudgetRuleUsage[] = []
  @State budgetRenderVersion: number = 0
  @State budgetPageMode: string = 'list'
  @State budgetDraft: BudgetRule = createEmptyBudgetRule()
  @State budgetDraftAmount: string = ''
  @State budgetSelectedCategoryIds: number[] = []
  @State budgetSelectedCategoryNames: string[] = []
  @State budgetEditingPeriodType: string = 'month'
  @State budgetPeriodTotalAmount: string = ''
  @State budgetCategoryAllocationEnabled: boolean = false
  @State budgetCategoryAllocationValues: string[] = []
  @State budgetCategoryAllocationSelectedIds: number[] = []
  @State showBudgetOverflowWarning: boolean = false
  @State budgetOverflowOverview: BudgetOverview = createEmptyBudgetOverview()
  @State currentSubPage: string = 'main'
  @State showCategoryManage: boolean = false
  @StorageLink('settingsPageState') settingsPageState: string = 'main'
  @Watch('onSettingsBackSignal')
  @StorageProp('settingsBackSignal') settingsBackSignal: number = 0
  @Watch('onBudgetVersionChanged')
  @StorageProp('budgetVersion') budgetVersion: number = 0
  @Watch('onAppDataVersionChanged')
  @StorageProp('appDataVersion') appDataVersion: number = 0
  @State selectedPeriodType: string = 'expense'
  @State periodExpenseRules: PeriodRule[] = []
  @State periodIncomeRules: PeriodRule[] = []
  @State showPeriodForm: boolean = false
  @State periodTitle: string = ''
  @State periodAmount: string = ''
  @State periodCategory: string = ''
  @State periodRemark: string = ''
  @State periodDay: string = '1'
  @State periodCycle: string = 'monthly'
  @State selectedTheme: string = 'light'
  @State selectedThemeColor: string = '#21A7A8'
  @State privacyHideAmount: boolean = false
  @State privacyLocalOnly: boolean = true
  @State securityAppLock: boolean = false
  @State securityAutoLock: boolean = false
  @State notificationEnabled: boolean = true
  @State feedbackText: string = ''
  @StorageProp('statusBarHeight') sbHeight: number = 0
  @StorageProp('currentUserId') currentUserId: number = 0
  @StorageProp('currentUserName') currentUserName: string = ''
  @StorageProp('currentUsername') currentUsername: string = ''
  @State cloudRegisterPassword: string = ''
  @State cloudRegisterBusy: boolean = false
  private budgetCloudRestoreAttempted: boolean = false

  aboutToAppear(): void {
    this.currentSubPage = this.initialPage
    this.loadBudgets(true)
    this.loadPeriodRules()
    this.loadAppSettings()
    this.syncPageState()
  }

  aboutToDisappear(): void {
    this.settingsPageState = 'main'
  }

  private syncPageState(): void {
    if (this.showCategoryManage) {
      this.settingsPageState = 'category'
    } else {
      this.settingsPageState = this.currentSubPage
    }
  }

  private goBackOneLevel(): void {
    if (this.navStack && this.initialPage !== 'main') {
      this.navStack.pop()
      return
    }
    if (this.showCategoryManage) {
      this.showCategoryManage = false
      this.loadBudgets()
    } else if (this.currentSubPage !== 'main') {
      this.currentSubPage = 'main'
    }
    this.syncPageState()
  }

  onSettingsBackSignal(): void {
    this.goBackOneLevel()
  }

  onBudgetVersionChanged(): void {
    this.loadBudgets(false)
  }

  onAppDataVersionChanged(): void {
    this.loadBudgets(false)
    this.loadPeriodRules()
  }

  private async loadBudgets(allowCloudRestore: boolean = false): Promise<void> {
    try {
      const hostContext = this.getUIContext().getHostContext()
      const shouldRestoreCloud = await this.shouldRestoreBudgetCloud(hostContext ? hostContext : null, allowCloudRestore)
      if (hostContext && shouldRestoreCloud) {
        try {
          await AppDataApi.getInstance().restoreCloudToLocal(hostContext)
          await this.markBudgetCloudRestored(hostContext)
        } catch (cloudErr) {
          LogUtils.error(SETTINGS_TAG, '预算页云端恢复失败，本地继续显示：%{public}s', this.formatError(cloudErr))
        }
      }
      try {
        this.expenseCategories = await CategoryDao.getInstance().queryByType('expense')
        this.incomeCategories = await CategoryDao.getInstance().queryByType('income')
      } catch (categoryErr) {
        this.expenseCategories = []
        this.incomeCategories = []
        LogUtils.error(SETTINGS_TAG, '预算页分类读取失败，预算规则继续显示：%{public}s', this.formatError(categoryErr))
      }
      await this.refreshBudgetRuleOverview()
    } catch (err) {
      LogUtils.error(SETTINGS_TAG, '读取预算失败：%{public}s', this.formatError(err))
    }
  }

  private async refreshBudgetRuleOverview(): Promise<void> {
    try {
      const dayOverview = await AppDataApi.getInstance().queryBudgetOverview('day')
      const monthOverview = await AppDataApi.getInstance().queryBudgetOverview('month')
      const yearOverview = await AppDataApi.getInstance().queryBudgetOverview('year')
      const sourceUsages = await AppDataApi.getInstance().queryBudgetRuleUsages()
      this.budgetRuleUsages = sourceUsages
      this.budgetDayOverview = this.cloneBudgetOverview(dayOverview)
      this.budgetMonthOverview = this.cloneBudgetOverview(monthOverview)
      this.budgetYearOverview = this.cloneBudgetOverview(yearOverview)
      this.budgetOverview = this.cloneBudgetOverview(monthOverview)
      this.budgetRenderVersion += 1
      LogUtils.info(SETTINGS_TAG,
        '预算概览刷新 day=%{public}d/%{public}d hasTotal=%{public}s cat=%{public}d month=%{public}d/%{public}d hasTotal=%{public}s cat=%{public}d year=%{public}d/%{public}d hasTotal=%{public}s cat=%{public}d rules=%{public}d',
        dayOverview.usedFen, dayOverview.totalFen, dayOverview.hasTotalRule.toString(), dayOverview.categoryBudgetFen,
        monthOverview.usedFen, monthOverview.totalFen, monthOverview.hasTotalRule.toString(), monthOverview.categoryBudgetFen,
        yearOverview.usedFen, yearOverview.totalFen, yearOverview.hasTotalRule.toString(), yearOverview.categoryBudgetFen,
        this.budgetRuleUsages.length)
    } catch (err) {
      this.budgetOverview = createEmptyBudgetOverview()
      this.budgetDayOverview = createEmptyBudgetOverview()
      this.budgetMonthOverview = createEmptyBudgetOverview()
      this.budgetYearOverview = createEmptyBudgetOverview()
      this.budgetRuleUsages = []
      this.budgetRenderVersion += 1
      LogUtils.error(SETTINGS_TAG, '新版预算概览读取失败：%{public}s', this.formatError(err))
    }
  }

  private normalizeBudgetOverview(source: BudgetOverview, usages: BudgetRuleUsage[]): BudgetOverview {
    const usageOverview = this.buildCurrentMonthBudgetOverviewFromUsages(usages)
    if (usageOverview.activeRuleCount <= 0) {
      return source
    }
    if (source.totalFen !== usageOverview.totalFen || source.usedFen !== usageOverview.usedFen ||
      source.remainFen !== usageOverview.remainFen || source.activeRuleCount !== usageOverview.activeRuleCount ||
      source.percent !== usageOverview.percent) {
      LogUtils.info(SETTINGS_TAG,
        '预算总览使用规则卡数据兜底 sourceTotal=%{public}d sourceUsed=%{public}d usageTotal=%{public}d usageUsed=%{public}d',
        source.totalFen, source.usedFen, usageOverview.totalFen, usageOverview.usedFen)
      return usageOverview
    }
    return source
  }

  private cloneBudgetOverview(source: BudgetOverview): BudgetOverview {
    return {
      title: source.title,
      totalFen: source.totalFen,
      usedFen: source.usedFen,
      remainFen: source.remainFen,
      percent: source.percent,
      activeRuleCount: source.activeRuleCount,
      hasTotalRule: source.hasTotalRule,
      categoryBudgetFen: source.categoryBudgetFen,
      overflow: source.overflow,
      overflowFen: source.overflowFen
    }
  }

  private buildCurrentMonthBudgetOverviewFromUsages(usages: BudgetRuleUsage[]): BudgetOverview {
    const overview = createEmptyBudgetOverview()
    let totalRuleFound = false
    let totalFen = 0
    let totalUsedFen = 0
    let categoryBudgetFen = 0
    let categoryUsedFen = 0
    let activeRuleCount = 0
    for (let i = 0; i < usages.length; i++) {
      const usage = usages[i]
      const rule = usage.rule
      if (!this.isCurrentMonthRule(rule)) {
        continue
      }
      activeRuleCount += 1
      if (rule.scopeType === 'total' && !totalRuleFound) {
        totalRuleFound = true
        totalFen = rule.amount
        totalUsedFen = usage.usedFen
      }
      if (rule.scopeType === 'categories') {
        categoryBudgetFen += rule.amount
        categoryUsedFen += usage.usedFen
      }
    }
    if (activeRuleCount <= 0) {
      return overview
    }
    overview.activeRuleCount = activeRuleCount
    overview.categoryBudgetFen = categoryBudgetFen
    if (totalRuleFound) {
      overview.title = '总预算'
      overview.totalFen = totalFen
      overview.usedFen = totalUsedFen
      overview.hasTotalRule = true
      overview.overflow = categoryBudgetFen > totalFen
      overview.overflowFen = overview.overflow ? categoryBudgetFen - totalFen : 0
    } else {
      overview.title = '分类预算合计'
      overview.totalFen = categoryBudgetFen
      overview.usedFen = categoryUsedFen
      overview.hasTotalRule = false
      overview.overflow = false
      overview.overflowFen = 0
    }
    overview.remainFen = overview.totalFen > overview.usedFen ? overview.totalFen - overview.usedFen : 0
    overview.percent = this.getPercent(overview.usedFen, overview.totalFen)
    return overview
  }

  private buildBudgetRestoreKey(): string {
    const storageBookId = AppStorage.get<number>('currentBookId')
    const bookId = storageBookId !== undefined && storageBookId > 0 ? storageBookId : 1
    const userId = this.currentUserId > 0 ? this.currentUserId : 1
    return 'cloud_restored_user_' + userId.toString() + '_book_' + bookId.toString()
  }

  private async shouldRestoreBudgetCloud(hostContext: Context | null, allowCloudRestore: boolean): Promise<boolean> {
    if (!hostContext || !allowCloudRestore) {
      return false
    }
    if (this.budgetCloudRestoreAttempted) {
      LogUtils.info(SETTINGS_TAG, '预算页跳过云端恢复 reason=本次页面生命周期已尝试')
      return false
    }
    this.budgetCloudRestoreAttempted = true
    const localRules = await AppDataApi.getInstance().queryBudgetRules()
    if (localRules.length > 0) {
      LogUtils.info(SETTINGS_TAG, '预算页跳过云端恢复 reason=本地已有预算规则 count=%{public}d', localRules.length)
      await this.markBudgetCloudRestored(hostContext)
      return false
    }
    const pref = await preferences.getPreferences(hostContext, { name: BUDGET_LOCAL_PREF_NAME })
    const restoreKey = this.buildBudgetRestoreKey()
    const restored = await pref.get(restoreKey, false) as boolean
    if (restored) {
      LogUtils.info(SETTINGS_TAG, '预算页跳过云端恢复 reason=本地已记录恢复标记 key=%{public}s', restoreKey)
      return false
    }
    LogUtils.info(SETTINGS_TAG, '预算页允许云端恢复 reason=本地无预算规则且无恢复标记 key=%{public}s', restoreKey)
    return true
  }

  private async markBudgetCloudRestored(hostContext: Context): Promise<void> {
    try {
      const pref = await preferences.getPreferences(hostContext, { name: BUDGET_LOCAL_PREF_NAME })
      const restoreKey = this.buildBudgetRestoreKey()
      await pref.put(restoreKey, true)
      await pref.put(restoreKey + '_time', Date.now())
      await pref.flush()
      LogUtils.info(SETTINGS_TAG, '预算页写入本地恢复标记 key=%{public}s', restoreKey)
    } catch (err) {
      LogUtils.error(SETTINGS_TAG, '预算页写入本地恢复标记失败：%{public}s', this.formatError(err))
    }
  }

  private async exportCSV(): Promise<void> {
    try {
      const filter: FilterOptions = { month: '', type: 'all', category: '' }
      const bills: Bill[] = await BillDao.getInstance().queryByFilter(filter)
      if (bills.length === 0) {
        this.showToast('暂无账单数据可导出')
        return
      }

      const bom = '\uFEFF'
      const header = '日期,类型,分类,金额(元),备注\n'
      const rows: string[] = []
      for (let i = 0; i < bills.length; i++) {
        const bill: Bill = bills[i]
        const typeLabel = bill.type === 'income' ? '收入' : '支出'
        const amount = AmountUtil.rawFen2Display(bill.amount)
        const remark = bill.remark.replace(/,/g, '，')
        rows.push(`${bill.date},${typeLabel},${bill.category},${amount},${remark}`)
      }
      const csvContent = bom + header + rows.join('\n')

      const saveOptions = new picker.DocumentSaveOptions()
      saveOptions.newFileNames = ['小金鱼记账.csv']
      const docPicker = new picker.DocumentViewPicker(this.getUIContext().getHostContext()!)
      const uriArr = await docPicker.save(saveOptions)
      if (!uriArr || uriArr.length === 0) {
        return
      }

      const file = await fileIo.open(uriArr[0], fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC)
      await fileIo.write(file.fd, csvContent)
      await fileIo.close(file.fd)

      this.showToast(`已导出 ${bills.length} 条账单`)
    } catch (err) {
      const errStr = JSON.stringify(err)
      if (errStr.includes('cancel') || errStr.includes('Cancel')) {
        return
      }
      this.showToast('导出失败，请重试')
      LogUtils.error(SETTINGS_TAG, '导出 CSV 失败：%{public}s', errStr)
    }
  }

  private getCurrentMonth(): string {
    const now = new Date()
    const year = now.getFullYear()
    const month = (now.getMonth() + 1).toString().padStart(2, '0')
    return `${year}-${month}`
  }

  private getTotalBudgetFen(): number {
    return this.budgetOverview.totalFen
  }

  private getTotalUsedFen(): number {
    return this.budgetOverview.usedFen
  }

  private getSetBudgetCount(): number {
    return this.getCurrentMonthBudgetCategoryCount()
  }

  private getCurrentMonthBudgetCategoryCount(): number {
    const ids: number[] = []
    const names: string[] = []
    for (let i = 0; i < this.budgetRuleUsages.length; i++) {
      const rule = this.budgetRuleUsages[i].rule
      if (!this.isCurrentMonthCategoryRule(rule)) {
        continue
      }
      const categoryIds = BudgetRuleDao.getInstance().parseCategoryIds(rule.categoryIdsJson)
      const categoryNames = BudgetRuleDao.getInstance().parseCategoryNames(rule.categoryNamesJson)
      if (categoryIds.length > 0) {
        for (let j = 0; j < categoryIds.length; j++) {
          if (!this.containsNumber(ids, categoryIds[j])) {
            ids.push(categoryIds[j])
          }
        }
      } else {
        for (let k = 0; k < categoryNames.length; k++) {
          if (!this.containsString(names, categoryNames[k])) {
            names.push(categoryNames[k])
          }
        }
      }
    }
    if (ids.length > 0) {
      return ids.length
    }
    return names.length
  }

  private isCurrentMonthCategoryRule(rule: BudgetRule): boolean {
    if (!this.isCurrentMonthRule(rule)) {
      return false
    }
    return rule.scopeType === 'categories'
  }

  private isCurrentMonthRule(rule: BudgetRule): boolean {
    if (rule.deleted === 1 || rule.enabled !== 1 || rule.status !== 'active') {
      return false
    }
    if (rule.periodType !== 'month') {
      return false
    }
    if (rule.dateMode === 'fixed' && rule.periodValue.length > 0) {
      return rule.periodValue === this.getCurrentMonth()
    }
    return true
  }

  private containsNumber(values: number[], target: number): boolean {
    for (let i = 0; i < values.length; i++) {
      if (values[i] === target) {
        return true
      }
    }
    return false
  }

  private containsString(values: string[], target: string): boolean {
    for (let i = 0; i < values.length; i++) {
      if (values[i] === target) {
        return true
      }
    }
    return false
  }

  private getPercent(usedFen: number, budgetFen: number): number {
    if (budgetFen <= 0) {
      return 0
    }
    const percent = Math.round(usedFen * 100 / budgetFen)
    if (percent > 100) {
      return 100
    }
    return percent
  }

  private getProgressWidth(percent: number): string {
    if (percent <= 0) {
      return '0%'
    }
    if (percent >= 100) {
      return '100%'
    }
    return `${percent}%`
  }

  private getBudgetRemainFen(): number {
    return this.budgetOverview.remainFen
  }

  private getBudgetUsagePercent(): number {
    return this.budgetOverview.percent
  }

  private cloneBudgetRule(rule: BudgetRule): BudgetRule {
    return {
      id: rule.id,
      userId: rule.userId,
      bookId: rule.bookId,
      name: rule.name,
      periodType: rule.periodType,
      scopeType: rule.scopeType,
      amount: rule.amount,
      categoryIdsJson: rule.categoryIdsJson,
      categoryNamesJson: rule.categoryNamesJson,
      dateMode: rule.dateMode,
      periodValue: rule.periodValue,
      startDay: rule.startDay,
      endDay: rule.endDay,
      compareMode: rule.compareMode,
      status: rule.status,
      enabled: rule.enabled,
      createdAt: rule.createdAt,
      updatedAt: rule.updatedAt,
      deleted: rule.deleted
    }
  }

  private beginAddBudgetRule(): void {
    try {
      const draft = AppDataApi.getInstance().createBudgetRuleDraft()
      draft.id = ''
      draft.name = '本月总预算'
      draft.periodType = 'month'
      draft.scopeType = 'total'
      draft.amount = 0
      draft.categoryIdsJson = '[]'
      draft.categoryNamesJson = '[]'
      draft.dateMode = 'current'
      draft.periodValue = ''
      draft.startDay = 1
      draft.endDay = 31
      draft.compareMode = 'previous'
      draft.status = 'active'
      draft.enabled = 1
      draft.createdAt = 0
      draft.updatedAt = 0
      draft.deleted = 0
      this.budgetDraft = draft
      this.budgetDraftAmount = ''
      this.budgetSelectedCategoryIds = []
      this.budgetSelectedCategoryNames = []
      this.showBudgetOverflowWarning = false
      this.budgetPageMode = 'edit'
      LogUtils.info(SETTINGS_TAG, '新建预算规则草稿成功 userId=%{public}s bookId=%{public}s',
        draft.userId.toString(), draft.bookId.toString())
    } catch (err) {
      LogUtils.error(SETTINGS_TAG, '新建预算规则草稿失败：%{public}s', this.formatError(err))
      this.showToast('打开预算规则编辑失败，请查看 HiLog')
    }
  }

  private beginEditBudgetRule(rule: BudgetRule): void {
    this.budgetDraft = this.cloneBudgetRule(rule)
    this.budgetDraftAmount = AmountUtil.rawFen2Display(rule.amount)
    this.budgetSelectedCategoryIds = this.parseBudgetCategoryIds(rule.categoryIdsJson)
    this.budgetSelectedCategoryNames = this.parseBudgetCategoryNames(rule.categoryNamesJson)
    this.showBudgetOverflowWarning = false
    this.budgetPageMode = 'edit'
  }

  private openBudgetRuleDetail(rule: BudgetRule): void {
    this.budgetDraft = this.cloneBudgetRule(rule)
    this.budgetDraftAmount = AmountUtil.rawFen2Display(rule.amount)
    this.budgetPageMode = 'detail'
  }

  private closeBudgetEditor(): void {
    this.budgetPageMode = 'list'
    this.showBudgetOverflowWarning = false
  }

  private beginEditBudgetPeriod(periodType: string): void {
    this.budgetEditingPeriodType = periodType
    const totalRule = this.findPeriodTotalRule(periodType)
    if (totalRule !== null) {
      this.budgetDraft = this.cloneBudgetRule(totalRule)
      this.budgetPeriodTotalAmount = AmountUtil.rawFen2Display(totalRule.amount)
    } else {
      const draft = AppDataApi.getInstance().createBudgetRuleDraft()
      draft.id = ''
      draft.name = this.getBudgetDraftDefaultName(periodType, 'total')
      draft.periodType = periodType
      draft.scopeType = 'total'
      draft.amount = 0
      draft.categoryIdsJson = '[]'
      draft.categoryNamesJson = '[]'
      draft.dateMode = 'current'
      draft.periodValue = ''
      draft.startDay = 1
      draft.endDay = periodType === 'day' ? 1 : 31
      draft.compareMode = 'previous'
      draft.status = 'active'
      draft.enabled = 1
      draft.createdAt = 0
      draft.updatedAt = 0
      draft.deleted = 0
      this.budgetDraft = draft
      this.budgetPeriodTotalAmount = ''
    }
    this.budgetCategoryAllocationValues = this.buildPeriodCategoryAllocationValues(periodType)
    this.budgetCategoryAllocationSelectedIds = this.buildPeriodCategoryAllocationSelectedIds(periodType)
    this.budgetCategoryAllocationEnabled = this.hasPeriodCategoryAllocation(periodType)
    this.budgetPageMode = 'edit'
  }

  private findPeriodTotalRule(periodType: string): BudgetRule | null {
    for (let i = 0; i < this.budgetRuleUsages.length; i++) {
      const rule = this.budgetRuleUsages[i].rule
      if (rule.periodType === periodType && rule.scopeType === 'total' && rule.deleted !== 1) {
        return rule
      }
    }
    return null
  }

  private findPeriodCategoryRule(periodType: string, categoryId: number): BudgetRule | null {
    for (let i = 0; i < this.budgetRuleUsages.length; i++) {
      const rule = this.budgetRuleUsages[i].rule
      if (rule.periodType !== periodType || rule.scopeType !== 'categories' || rule.deleted === 1) {
        continue
      }
      const ids = this.parseBudgetCategoryIds(rule.categoryIdsJson)
      for (let j = 0; j < ids.length; j++) {
        if (ids[j] === categoryId) {
          return rule
        }
      }
    }
    return null
  }

  private buildPeriodCategoryAllocationValues(periodType: string): string[] {
    const values: string[] = []
    for (let i = 0; i < this.expenseCategories.length; i++) {
      const cat = this.expenseCategories[i]
      const rule = this.findPeriodCategoryRule(periodType, cat.id)
      values.push(rule !== null && rule.amount > 0 ? AmountUtil.rawFen2Display(rule.amount) : '')
    }
    return values
  }

  private buildPeriodCategoryAllocationSelectedIds(periodType: string): number[] {
    const ids: number[] = []
    for (let i = 0; i < this.expenseCategories.length; i++) {
      const cat = this.expenseCategories[i]
      const rule = this.findPeriodCategoryRule(periodType, cat.id)
      if (rule !== null && rule.amount > 0) {
        ids.push(cat.id)
      }
    }
    return ids
  }

  private isBudgetAllocationCategorySelected(categoryId: number): boolean {
    for (let i = 0; i < this.budgetCategoryAllocationSelectedIds.length; i++) {
      if (this.budgetCategoryAllocationSelectedIds[i] === categoryId) {
        return true
      }
    }
    return false
  }

  private hasPeriodCategoryAllocation(periodType: string): boolean {
    for (let i = 0; i < this.budgetRuleUsages.length; i++) {
      const rule = this.budgetRuleUsages[i].rule
      if (rule.periodType === periodType && rule.scopeType === 'categories' && rule.deleted !== 1 && rule.amount > 0) {
        return true
      }
    }
    return false
  }

  private setBudgetPeriodTotalAmount(value: string): void {
    this.budgetPeriodTotalAmount = this.normalizeAmount(value)
  }

  private toggleBudgetCategoryAllocation(): void {
    this.budgetCategoryAllocationEnabled = !this.budgetCategoryAllocationEnabled
  }

  private setBudgetCategoryAllocationAmount(index: number, value: string): void {
    const next: string[] = []
    for (let i = 0; i < this.expenseCategories.length; i++) {
      if (i === index) {
        next.push(this.normalizeAmount(value))
      } else if (i < this.budgetCategoryAllocationValues.length) {
        next.push(this.budgetCategoryAllocationValues[i])
      } else {
        next.push('')
      }
    }
    this.budgetCategoryAllocationValues = next
  }

  private toggleBudgetAllocationCategory(cat: CategoryRecord): void {
    const nextIds: number[] = []
    let exists = false
    for (let i = 0; i < this.budgetCategoryAllocationSelectedIds.length; i++) {
      const categoryId = this.budgetCategoryAllocationSelectedIds[i]
      if (categoryId === cat.id) {
        exists = true
      } else {
        nextIds.push(categoryId)
      }
    }
    if (!exists) {
      nextIds.push(cat.id)
    } else {
      const nextValues: string[] = []
      for (let j = 0; j < this.expenseCategories.length; j++) {
        if (this.expenseCategories[j].id === cat.id) {
          nextValues.push('')
        } else if (j < this.budgetCategoryAllocationValues.length) {
          nextValues.push(this.budgetCategoryAllocationValues[j])
        } else {
          nextValues.push('')
        }
      }
      this.budgetCategoryAllocationValues = nextValues
    }
    this.budgetCategoryAllocationSelectedIds = nextIds
  }

  private createCategoryBudgetRule(periodType: string, cat: CategoryRecord, amountFen: number, oldRule: BudgetRule | null): BudgetRule {
    const rule = oldRule !== null ? this.cloneBudgetRule(oldRule) : AppDataApi.getInstance().createBudgetRuleDraft()
    rule.name = this.periodPrefix(periodType) + cat.name + '分配'
    rule.periodType = periodType
    rule.scopeType = 'categories'
    rule.amount = amountFen
    rule.categoryIdsJson = JSON.stringify([cat.id])
    rule.categoryNamesJson = JSON.stringify([cat.name])
    rule.dateMode = 'current'
    rule.periodValue = ''
    rule.startDay = 1
    rule.endDay = periodType === 'day' ? 1 : 31
    rule.compareMode = 'previous'
    rule.status = 'active'
    rule.enabled = 1
    rule.deleted = 0
    return rule
  }

  private periodPrefix(periodType: string): string {
    if (periodType === 'day') {
      return '今日'
    }
    if (periodType === 'year') {
      return '本年'
    }
    return '本月'
  }

  private async saveBudgetPeriodSettings(): Promise<void> {
    const amountFen = AmountUtil.yuan2Fen(this.budgetPeriodTotalAmount)
    if (amountFen <= 0) {
      this.showToast('总预算金额必须大于 0')
      return
    }
    const hostContext = this.getUIContext().getHostContext()
    const totalRule = this.cloneBudgetRule(this.budgetDraft)
    totalRule.name = this.getBudgetDraftDefaultName(this.budgetEditingPeriodType, 'total')
    totalRule.periodType = this.budgetEditingPeriodType
    totalRule.scopeType = 'total'
    totalRule.amount = amountFen
    totalRule.categoryIdsJson = '[]'
    totalRule.categoryNamesJson = '[]'
    totalRule.dateMode = 'current'
    totalRule.periodValue = ''
    totalRule.startDay = 1
    totalRule.endDay = this.budgetEditingPeriodType === 'day' ? 1 : 31
    totalRule.compareMode = 'previous'
    totalRule.status = 'active'
    totalRule.enabled = 1
    totalRule.deleted = 0

    const saveRules: BudgetRule[] = [totalRule]
    const deleteRuleIds: string[] = []
    for (let i = 0; i < this.expenseCategories.length; i++) {
      const cat = this.expenseCategories[i]
      const oldRule = this.findPeriodCategoryRule(this.budgetEditingPeriodType, cat.id)
      let allocationFen = 0
      if (this.budgetCategoryAllocationEnabled && this.isBudgetAllocationCategorySelected(cat.id) &&
        i < this.budgetCategoryAllocationValues.length &&
        this.budgetCategoryAllocationValues[i].length > 0) {
        allocationFen = AmountUtil.yuan2Fen(this.budgetCategoryAllocationValues[i])
      }
      if (allocationFen > 0) {
        const categoryRule = this.createCategoryBudgetRule(this.budgetEditingPeriodType, cat, allocationFen, oldRule)
        saveRules.push(categoryRule)
      } else if (oldRule !== null) {
        deleteRuleIds.push(oldRule.id)
      }
    }

    await AppDataApi.getInstance().saveBudgetRuleBatch(hostContext ? hostContext : null, saveRules, deleteRuleIds, true)

    this.budgetPageMode = 'list'
    this.showToast('预算设置已保存')
    await this.loadBudgets()
  }

  private parseBudgetCategoryIds(jsonText: string): number[] {
    if (jsonText.length === 0) {
      return []
    }
    try {
      return JSON.parse(jsonText) as number[]
    } catch (err) {
      LogUtils.error(SETTINGS_TAG, '解析预算分类 ID 失败：%{public}s', JSON.stringify(err))
      return []
    }
  }

  private parseBudgetCategoryNames(jsonText: string): string[] {
    if (jsonText.length === 0) {
      return []
    }
    try {
      return JSON.parse(jsonText) as string[]
    } catch (err) {
      LogUtils.error(SETTINGS_TAG, '解析预算分类名称失败：%{public}s', JSON.stringify(err))
      return []
    }
  }

  private isBudgetCategorySelected(categoryId: number): boolean {
    for (let i = 0; i < this.budgetSelectedCategoryIds.length; i++) {
      if (this.budgetSelectedCategoryIds[i] === categoryId) {
        return true
      }
    }
    return false
  }

  private setBudgetDraftName(value: string): void {
    const next = this.cloneBudgetRule(this.budgetDraft)
    next.name = value
    this.budgetDraft = next
  }

  private getBudgetDraftDefaultName(periodType: string, scopeType: string): string {
    let periodLabel = '本月'
    if (periodType === 'day') {
      periodLabel = '今日'
    } else if (periodType === 'year') {
      periodLabel = '本年'
    }
    return periodLabel + (scopeType === 'categories' ? '分类预算' : '总预算')
  }

  private isBudgetDraftDefaultName(name: string): boolean {
    return name === '今日总预算' || name === '今日分类预算' ||
      name === '本月总预算' || name === '本月分类预算' ||
      name === '本年总预算' || name === '本年分类预算'
  }

  private setBudgetDraftAmount(value: string): void {
    this.budgetDraftAmount = this.normalizeAmount(value)
  }

  private setBudgetDraftScope(scopeType: string): void {
    const next = this.cloneBudgetRule(this.budgetDraft)
    const shouldSyncName = this.isBudgetDraftDefaultName(next.name)
    next.scopeType = scopeType
    if (scopeType === 'total') {
      this.budgetSelectedCategoryIds = []
      this.budgetSelectedCategoryNames = []
      next.categoryIdsJson = '[]'
      next.categoryNamesJson = '[]'
    }
    if (shouldSyncName) {
      next.name = this.getBudgetDraftDefaultName(next.periodType, next.scopeType)
    }
    this.budgetDraft = next
  }

  private setBudgetDraftPeriod(periodType: string): void {
    const next = this.cloneBudgetRule(this.budgetDraft)
    const shouldSyncName = this.isBudgetDraftDefaultName(next.name)
    next.periodType = periodType
    next.dateMode = 'current'
    next.periodValue = ''
    if (periodType === 'day') {
      next.startDay = 1
      next.endDay = 1
    } else {
      next.startDay = 1
      next.endDay = 31
    }
    if (shouldSyncName) {
      next.name = this.getBudgetDraftDefaultName(next.periodType, next.scopeType)
    }
    this.budgetDraft = next
  }

  private toggleBudgetCategory(cat: CategoryRecord): void {
    const nextIds: number[] = []
    const nextNames: string[] = []
    let exists = false
    for (let i = 0; i < this.budgetSelectedCategoryIds.length; i++) {
      if (this.budgetSelectedCategoryIds[i] === cat.id) {
        exists = true
      } else {
        nextIds.push(this.budgetSelectedCategoryIds[i])
        nextNames.push(this.budgetSelectedCategoryNames[i])
      }
    }
    if (!exists) {
      nextIds.push(cat.id)
      nextNames.push(cat.name)
    }
    this.budgetSelectedCategoryIds = nextIds
    this.budgetSelectedCategoryNames = nextNames
    const next = this.cloneBudgetRule(this.budgetDraft)
    next.scopeType = 'categories'
    next.categoryIdsJson = JSON.stringify(nextIds)
    next.categoryNamesJson = JSON.stringify(nextNames)
    this.budgetDraft = next
  }

  private async saveBudgetDraft(forceSave: boolean): Promise<void> {
    const name = this.budgetDraft.name.trim()
    if (name.length === 0) {
      this.showToast('请输入规则名称')
      return
    }
    const amountFen = AmountUtil.yuan2Fen(this.budgetDraftAmount)
    if (amountFen <= 0) {
      this.showToast('预算金额必须大于 0')
      return
    }
    if (this.budgetDraft.scopeType === 'categories' && this.budgetSelectedCategoryIds.length === 0) {
      this.showToast('分类预算至少选择一个分类')
      return
    }
    const next = this.cloneBudgetRule(this.budgetDraft)
    next.name = name
    next.amount = amountFen
    next.categoryIdsJson = JSON.stringify(this.budgetSelectedCategoryIds)
    next.categoryNamesJson = JSON.stringify(this.budgetSelectedCategoryNames)
    const conflict: BudgetConflictResult = await AppDataApi.getInstance().checkBudgetRuleConflict(next)
    if (conflict.hasConflict) {
      this.showToast(conflict.message + '：' + conflict.conflictRuleName)
      return
    }
    const overflow = await AppDataApi.getInstance().checkBudgetRuleOverflow(next)
    if (!forceSave && overflow.overflow) {
      this.budgetOverflowOverview = overflow
      this.showBudgetOverflowWarning = true
      return
    }
    const hostContext = this.getUIContext().getHostContext()
    LogUtils.info(SETTINGS_TAG,
      '预算设置准备保存 id=%{public}s userId=%{public}d bookId=%{public}d name=%{public}s period=%{public}s scope=%{public}s amount=%{public}d enabled=%{public}d status=%{public}s',
      next.id, next.userId, next.bookId, next.name, next.periodType, next.scopeType, next.amount, next.enabled,
      next.status)
    const savedId = await AppDataApi.getInstance().saveBudgetRule(hostContext ? hostContext : null, next, true)
    LogUtils.info(SETTINGS_TAG, '预算设置保存完成 savedId=%{public}s，开始刷新列表', savedId)
    this.showBudgetOverflowWarning = false
    this.budgetPageMode = 'list'
    this.showToast('预算规则已保存')
    await this.loadBudgets()
  }

  private async toggleBudgetRuleEnabled(rule: BudgetRule): Promise<void> {
    const hostContext = this.getUIContext().getHostContext()
    const nextEnabled = rule.enabled === 1 ? 0 : 1
    await AppDataApi.getInstance().setBudgetRuleEnabled(hostContext ? hostContext : null, rule.id, nextEnabled, true)
    this.showToast(nextEnabled === 1 ? '预算规则已启用' : '预算规则已停用')
    await this.loadBudgets()
    this.budgetPageMode = 'list'
  }

  private async deleteBudgetRule(rule: BudgetRule): Promise<void> {
    const hostContext = this.getUIContext().getHostContext()
    await AppDataApi.getInstance().deleteBudgetRule(hostContext ? hostContext : null, rule.id, true)
    this.showToast('预算规则已删除')
    await this.loadBudgets()
    this.budgetPageMode = 'list'
  }

  private confirmToggleBudgetRule(rule: BudgetRule): void {
    const isStop = rule.enabled === 1
    let ctrl: CustomDialogController | null = null
    ctrl = new CustomDialogController({
      builder: ConfirmActionDialog({
        title: isStop ? '停用预算规则' : '启用预算规则',
        message: isStop ? '停用后，该规则不会参与预算统计，但规则数据会保留。' : '启用后，该规则会重新参与预算统计。',
        confirmText: isStop ? '确认停用' : '确认启用',
        danger: false,
        onConfirm: () => {
          if (ctrl) {
            ctrl.close()
          }
          this.toggleBudgetRuleEnabled(rule)
        }
      }),
      alignment: DialogAlignment.Center,
      autoCancel: true,
      customStyle: true,
      maskColor: $r('app.color.color_dialog_mask')
    })
    ctrl.open()
  }

  private confirmDeleteBudgetRule(rule: BudgetRule): void {
    let ctrl: CustomDialogController | null = null
    ctrl = new CustomDialogController({
      builder: ConfirmActionDialog({
        title: '删除预算规则',
        message: '删除后该规则不会再显示，也不会参与预算统计。云端同步时会同步删除状态。',
        confirmText: '确认删除',
        danger: true,
        onConfirm: () => {
          if (ctrl) {
            ctrl.close()
          }
          this.deleteBudgetRule(rule)
        }
      }),
      alignment: DialogAlignment.Center,
      autoCancel: true,
      customStyle: true,
      maskColor: $r('app.color.color_dialog_mask')
    })
    ctrl.open()
  }

  private normalizeAmount(value: string): string {
    let filtered = value.replace(/[^0-9.]/g, '')
    const dotIdx = filtered.indexOf('.')
    if (dotIdx !== -1) {
      const after = filtered.substring(dotIdx + 1).replace(/\./g, '')
      filtered = filtered.substring(0, dotIdx + 1) + after.substring(0, 2)
    }
    if (filtered.length > 1 && filtered[0] === '0' && filtered[1] !== '.') {
      filtered = filtered.substring(1)
    }
    return filtered
  }

  private showToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message })
    } catch (err) {
      LogUtils.error(SETTINGS_TAG, 'Toast 显示失败：%{public}s', this.formatError(err))
    }
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

  private showPending(featureName: string): void {
    this.showToast(`${featureName}将在后续版本接入`)
  }

  private async loadAppSettings(): Promise<void> {
    try {
      const pref = await preferences.getPreferences(this.getUIContext().getHostContext()!, { name: APP_SETTINGS_PREF_NAME })
      this.selectedTheme = await pref.get('theme_mode', 'light') as string
      this.selectedThemeColor = await pref.get('theme_color', '#21A7A8') as string
      AppStorage.setOrCreate<string>('themeMode', this.selectedTheme)
      AppStorage.setOrCreate<string>('themeColor', this.selectedThemeColor)
      this.privacyHideAmount = await pref.get('privacy_hide_amount', false) as boolean
      this.privacyLocalOnly = await pref.get('privacy_local_only', true) as boolean
      this.securityAppLock = await pref.get('security_app_lock', false) as boolean
      this.securityAutoLock = await pref.get('security_auto_lock', false) as boolean
      AppStorage.setOrCreate<boolean>('privacyHideAmount', this.privacyHideAmount)
    } catch (err) {
      LogUtils.error(SETTINGS_TAG, '读取设置失败：%{public}s', JSON.stringify(err))
    }
  }

  private async saveAppBool(key: string, value: boolean): Promise<void> {
    try {
      const pref = await preferences.getPreferences(this.getUIContext().getHostContext()!, { name: APP_SETTINGS_PREF_NAME })
      await pref.put(key, value)
      await pref.flush()
    } catch (err) {
      LogUtils.error(SETTINGS_TAG, '保存开关失败：%{public}s', JSON.stringify(err))
      this.showToast('保存失败，请重试')
    }
  }

  private async saveAppString(key: string, value: string): Promise<void> {
    try {
      const pref = await preferences.getPreferences(this.getUIContext().getHostContext()!, { name: APP_SETTINGS_PREF_NAME })
      await pref.put(key, value)
      await pref.flush()
    } catch (err) {
      LogUtils.error(SETTINGS_TAG, '保存设置失败：%{public}s', JSON.stringify(err))
      this.showToast('保存失败，请重试')
    }
  }

  private setThemeMode(mode: string): void {
    this.selectedTheme = mode
    AppStorage.setOrCreate<string>('themeMode', mode)
    this.saveAppString('theme_mode', mode)
  }

  private setThemeColor(color: string): void {
    this.selectedThemeColor = color
    AppStorage.setOrCreate<string>('themeColor', color)
    this.saveAppString('theme_color', color)
  }

  private getThemeModeLabel(): string {
    if (this.selectedTheme === 'dark') {
      return '深色模式'
    }
    if (this.selectedTheme === 'system') {
      return '跟随系统'
    }
    return '浅色模式'
  }

  private async exportBackupJson(): Promise<void> {
    try {
      const filter: FilterOptions = { month: '', type: 'all', category: '' }
      const bills = await BillDao.getInstance().queryByFilter(filter)
      const categories = await CategoryDao.getInstance().queryAll()
      const periodRules = await PeriodRuleDao.getInstance().queryAll()
      const budgetRules = await BudgetRuleDao.getInstance().queryAll()
      const data: SettingsBackupData = {
        appName: '小金鱼记账',
        version: '1.0.0',
        exportedAt: new Date().toISOString(),
        bills: bills,
        categories: categories,
        periodRules: periodRules,
        budgetRules: budgetRules
      }
      const saveOptions = new picker.DocumentSaveOptions()
      saveOptions.newFileNames = ['小金鱼记账备份.json']
      const docPicker = new picker.DocumentViewPicker(this.getUIContext().getHostContext()!)
      const uriArr = await docPicker.save(saveOptions)
      if (!uriArr || uriArr.length === 0) {
        return
      }
      const file = await fileIo.open(uriArr[0], fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC)
      await fileIo.write(file.fd, JSON.stringify(data))
      await fileIo.close(file.fd)
      this.showToast(`已备份 ${bills.length} 条账单`)
    } catch (err) {
      const errStr = JSON.stringify(err)
      if (errStr.includes('cancel') || errStr.includes('Cancel')) {
        return
      }
      LogUtils.error(SETTINGS_TAG, '导出备份失败：%{public}s', errStr)
      this.showToast('备份失败，请重试')
    }
  }

  private async uploadCloudBackup(): Promise<void> {
    try {
      const context = this.getUIContext().getHostContext()
      if (!context) {
        this.showToast('无法获取应用上下文')
        return
      }
      if (this.currentUserId <= 0) {
        this.showToast('请先登录账号')
        return
      }
      this.showToast('正在上传云备份...')
      const result: CloudBackupResult = await CloudBackupService.getInstance().uploadBackup(context, this.currentUserId)
      this.showToast(`云备份已完成：${result.billCount} 条账单`)
      LogUtils.info(SETTINGS_TAG, '云备份完成：%{public}s', result.cloudPath)
    } catch (err) {
      LogUtils.error(SETTINGS_TAG, '云备份失败：%{public}s', JSON.stringify(err))
      this.showToast('云备份失败，请检查网络、AGC配置和云存储权限')
    }
  }

  private async checkCloudBackups(): Promise<void> {
    try {
      if (this.currentUserId <= 0) {
        this.showToast('请先登录账号')
        return
      }
      const result: CloudBackupListResult = await CloudBackupService.getInstance().listBackups(this.currentUserId)
      if (result.files.length === 0) {
        this.showToast('云端暂无备份文件')
        return
      }
      this.showToast(`云端已有 ${result.files.length} 个备份文件`)
      LogUtils.info(SETTINGS_TAG, '云端备份列表：%{public}s', JSON.stringify(result.files))
    } catch (err) {
      LogUtils.error(SETTINGS_TAG, '查询云备份失败：%{public}s', JSON.stringify(err))
      this.showToast('查询云备份失败，请检查网络、AGC配置和云存储权限')
    }
  }

  private async uploadCloudDatabase(): Promise<void> {
    try {
      if (this.currentUserId <= 0) {
        this.showToast('请先登录账号')
        return
      }
      const context = this.getUIContext().getHostContext()
      if (!context) {
        this.showToast('无法获取应用上下文')
        return
      }
      const cloudRegistered = await UserDao.getInstance().isCloudRegistered(context)
      if (!cloudRegistered) {
        this.showToast('请先注册云账号，再同步云数据库')
        return
      }
      LogUtils.info(SETTINGS_TAG,
        '云数据库回调-设置页触发同步 userLocalId=%{public}s username=%{public}s',
        this.currentUserId.toString(), this.getActiveUsername())
      this.showToast('正在写入云数据库...')
      const result: CloudDatabaseCompletenessResult =
        await CloudDatabaseService.getInstance().syncAndCheckLocalData(this.currentUserId, this.getActiveUsername(), this.currentUserName)
      this.showToast(`云数据库同步完成：完整度 ${result.completionPercent}%`)
      LogUtils.info(SETTINGS_TAG,
        '云数据库同步完成：localBill=%{public}s cloudBill=%{public}s localCategory=%{public}s cloudCategory=%{public}s localPeriod=%{public}s cloudPeriod=%{public}s localBudget=%{public}s cloudBudget=%{public}s percent=%{public}s',
        result.localBillCount.toString(), result.cloudBillCount.toString(), result.localCategoryCount.toString(),
        result.cloudCategoryCount.toString(), result.localPeriodRuleCount.toString(), result.cloudPeriodRuleCount.toString(),
        result.localBudgetCount.toString(), result.cloudBudgetCount.toString(), result.completionPercent.toString())
    } catch (err) {
      LogUtils.error(SETTINGS_TAG, '云数据库回调-设置页同步失败：%{public}s', JSON.stringify(err))
      this.showToast('云数据库写入失败，请检查网络、AGC 对象类型、存储区名称和权限')
    }
  }

  private async registerCloudAccountAndUpload(): Promise<void> {
    if (this.cloudRegisterBusy) {
      return
    }
    if (this.currentUserId <= 0) {
      this.showToast('请先创建本地用户名')
      return
    }
    if (this.cloudRegisterPassword.length < 6) {
      this.showToast('密码至少需要 6 位')
      return
    }
    const context = this.getUIContext().getHostContext()
    if (!context) {
      this.showToast('无法获取应用上下文')
      return
    }
    this.cloudRegisterBusy = true
    try {
      const username = this.getActiveUsername()
      LogUtils.info(SETTINGS_TAG,
        '设置页注册云账号并上传开始 userLocalId=%{public}s username=%{public}s passwordLength=%{public}s',
        this.currentUserId.toString(), username, this.cloudRegisterPassword.length.toString())
      await UserDao.getInstance().register(context, username, this.currentUserName, this.cloudRegisterPassword)
      this.cloudRegisterPassword = ''
      this.showToast('云账号已注册，本地数据已上传')
      LogUtils.info(SETTINGS_TAG, '设置页注册云账号并上传完成 userLocalId=%{public}s username=%{public}s',
        this.currentUserId.toString(), username)
    } catch (err) {
      LogUtils.error(SETTINGS_TAG, '设置页注册云账号并上传失败：%{public}s', JSON.stringify(err))
      this.showToast('注册或上传失败，请查看 HiLog')
    }
    this.cloudRegisterBusy = false
  }

  private getActiveUsername(): string {
    if (this.currentUsername.length > 0) {
      return this.currentUsername
    }
    return this.currentUserName
  }

  private async checkCloudDatabase(): Promise<void> {
    try {
      if (this.currentUserId <= 0) {
        this.showToast('请先登录账号')
        return
      }
      LogUtils.info(SETTINGS_TAG,
        '云数据库回调-设置页触发检查 userLocalId=%{public}s username=%{public}s',
        this.currentUserId.toString(), this.currentUserName)
      this.showToast('正在查询云数据库...')
      const result: CloudDatabaseCompletenessResult = await CloudDatabaseService.getInstance().checkCompleteness(this.currentUserId)
      this.showToast(`云数据库完整度 ${result.completionPercent}%：账单 ${result.cloudBillCount}/${result.localBillCount}，预算 ${result.cloudBudgetCount}/${result.localBudgetCount}`)
      LogUtils.info(SETTINGS_TAG,
        '云数据库完整度检查：localUser=%{public}s cloudUser=%{public}s localBill=%{public}s cloudBill=%{public}s localCategory=%{public}s cloudCategory=%{public}s localPeriod=%{public}s cloudPeriod=%{public}s localBudget=%{public}s cloudBudget=%{public}s percent=%{public}s',
        result.localUserCount.toString(), result.cloudUserCount.toString(), result.localBillCount.toString(),
        result.cloudBillCount.toString(), result.localCategoryCount.toString(), result.cloudCategoryCount.toString(),
        result.localPeriodRuleCount.toString(), result.cloudPeriodRuleCount.toString(),
        result.localBudgetCount.toString(), result.cloudBudgetCount.toString(), result.completionPercent.toString())
    } catch (err) {
      LogUtils.error(SETTINGS_TAG, '云数据库回调-设置页检查失败：%{public}s', JSON.stringify(err))
      this.showToast('云数据库查询失败，请检查 XiaoJinYu、对象类型和权限')
    }
  }

  private async logoutCurrentUser(): Promise<void> {
    try {
      const context = this.getUIContext().getHostContext()
      if (context) {
        await UserDao.getInstance().logout(context)
      }
      AppStorage.setOrCreate<boolean>('isLoggedIn', false)
      AppStorage.setOrCreate<number>('currentUserId', 0)
      AppStorage.setOrCreate<string>('currentUserName', '')
      AppStorage.setOrCreate<string>('currentUsername', '')
      this.showToast('已退出登录')
    } catch (err) {
      LogUtils.error(SETTINGS_TAG, '退出登录失败：%{public}s', JSON.stringify(err))
      this.showToast('退出登录失败，请重试')
    }
  }

  private submitFeedback(): void {
    if (this.feedbackText.trim().length === 0) {
      this.showToast('请先填写反馈内容')
      return
    }
    this.feedbackText = ''
    this.showToast('反馈已记录，感谢你的建议')
  }

  private async loadPeriodRules(): Promise<void> {
    await PeriodRuleDao.getInstance().generateDueBills()
    this.periodExpenseRules = await PeriodRuleDao.getInstance().queryByType('expense')
    this.periodIncomeRules = await PeriodRuleDao.getInstance().queryByType('income')
  }

  private currentPeriodRules(): PeriodRule[] {
    return this.selectedPeriodType === 'expense' ? this.periodExpenseRules : this.periodIncomeRules
  }

  private currentPeriodCategories(): CategoryRecord[] {
    return this.selectedPeriodType === 'expense' ? this.expenseCategories : this.incomeCategories
  }

  private beginAddPeriodRule(): void {
    const cats = this.currentPeriodCategories()
    this.periodTitle = ''
    this.periodAmount = ''
    this.periodCategory = cats.length > 0 ? cats[0].name : ''
    this.periodRemark = ''
    this.periodDay = '1'
    this.periodCycle = 'monthly'
    this.showPeriodForm = true
  }

  private async savePeriodRule(): Promise<void> {
    const amountFen = AmountUtil.yuan2Fen(this.periodAmount)
    if (amountFen <= 0) {
      this.showToast('请输入有效金额')
      return
    }
    if (this.periodCategory.length === 0) {
      this.showToast('请选择分类')
      return
    }
    let day = parseInt(this.periodDay, 10)
    if (isNaN(day) || day <= 0) {
      day = 1
    }
    if (day > 31) {
      day = 31
    }
    const title = this.periodTitle.length > 0 ? this.periodTitle : this.periodCategory
    const cycle = this.periodCycle === 'yearly' ? 'yearly' : 'monthly'
    const nextDate = PeriodRuleDao.getInstance().nextDateFrom(cycle, new Date().getMonth() + 1, day, new Date())
    await PeriodRuleDao.getInstance().insert({
      id: 0,
      title: title,
      amount: amountFen,
      type: this.selectedPeriodType === 'income' ? 'income' : 'expense',
      category: this.periodCategory,
      remark: this.periodRemark,
      cycle: cycle,
      day: day,
      month: new Date().getMonth() + 1,
      nextDate: nextDate,
      enabled: 1,
      createdAt: Date.now()
    })
    this.showPeriodForm = false
    await this.loadPeriodRules()
    this.showToast('周期账单已保存')
  }

  private async togglePeriodRule(rule: PeriodRule): Promise<void> {
    await PeriodRuleDao.getInstance().updateEnabled(rule.id, rule.enabled === 1 ? 0 : 1)
    await this.loadPeriodRules()
  }

  private async deletePeriodRule(rule: PeriodRule): Promise<void> {
    await PeriodRuleDao.getInstance().deleteById(rule.id)
    await this.loadPeriodRules()
    this.showToast('已删除周期账单')
  }

  @Builder
  MainPage() {
    SettingsMainPage({
      sbHeight: this.sbHeight,
      currentUserName: this.currentUserName,
      totalBudgetFen: this.getTotalBudgetFen(),
      usedBudgetFen: this.getTotalUsedFen(),
      remainBudgetFen: this.getBudgetRemainFen(),
      progressWidth: this.getProgressWidth(this.getBudgetUsagePercent()),
      budgetUsagePercent: this.getBudgetUsagePercent(),
      setBudgetCount: this.getSetBudgetCount(),
      expenseCategoryCount: this.expenseCategories.length,
      dayBudgetOverview: this.budgetDayOverview,
      monthBudgetOverview: this.budgetMonthOverview,
      yearBudgetOverview: this.budgetYearOverview,
      budgetRefreshVersion: this.budgetRenderVersion,
      onOpenUserData: () => {
        if (this.navStack) {
          this.navStack.pushPathByName('userDataSettings', null)
        } else {
          this.currentSubPage = 'userData'
          this.syncPageState()
        }
      },
      onOpenAccount: () => {
        if (this.navStack) {
          this.navStack.pushPathByName('accountSettings', null)
        } else {
          this.currentSubPage = 'account'
          this.syncPageState()
        }
      },
      onOpenBudget: () => {
        if (this.navStack) {
          this.navStack.pushPathByName('budgetSettings', null)
        } else {
          this.currentSubPage = 'budget'
          this.loadBudgets(true)
          this.syncPageState()
        }
      },
      onOpenCategory: () => {
        if (this.navStack) {
          this.navStack.pushPathByName('categoryManage', null)
        } else {
          this.showCategoryManage = true
          this.syncPageState()
        }
      },
      onOpenPeriod: () => {
        if (this.navStack) {
          this.navStack.pushPathByName('periodBill', null)
        } else {
          this.currentSubPage = 'period'
          this.syncPageState()
        }
      },
      onOpenGeneral: () => {
        if (this.navStack) {
          this.navStack.pushPathByName('generalSettings', null)
        } else {
          this.currentSubPage = 'general'
          this.syncPageState()
        }
      },
      onExportCsv: () => {
        this.exportCSV()
      },
      onLogout: () => {
        this.logoutCurrentUser()
      }
    })
  }
  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      WaterPageBg()

      if (this.showCategoryManage) {
        CategoryManagePage({
          onBack: () => {
            this.showCategoryManage = false
            this.loadBudgets()
            this.syncPageState()
          }
        })
      } else if (this.currentSubPage === 'budget') {
        SettingsBudgetPage({
          sbHeight: this.sbHeight,
          mode: this.budgetPageMode,
          dayOverview: this.budgetDayOverview,
          monthOverview: this.budgetMonthOverview,
          yearOverview: this.budgetYearOverview,
          refreshVersion: this.budgetRenderVersion,
          expenseCategories: this.expenseCategories,
          editingPeriodType: this.budgetEditingPeriodType,
          periodTotalAmount: this.budgetPeriodTotalAmount,
          categoryAllocationEnabled: this.budgetCategoryAllocationEnabled,
          categoryAllocationValues: this.budgetCategoryAllocationValues,
          selectedAllocationCategoryIds: this.budgetCategoryAllocationSelectedIds,
          overflowOverview: this.budgetOverflowOverview,
          onBack: () => {
            this.goBackOneLevel()
          },
          onBeginEditPeriod: (periodType: string) => {
            this.beginEditBudgetPeriod(periodType)
          },
          onCloseEditor: () => {
            this.closeBudgetEditor()
          },
          onPeriodTotalAmountChange: (value: string) => {
            this.setBudgetPeriodTotalAmount(value)
          },
          onToggleCategoryAllocation: () => {
            this.toggleBudgetCategoryAllocation()
          },
          onCategoryAllocationAmountChange: (index: number, value: string) => {
            this.setBudgetCategoryAllocationAmount(index, value)
          },
          onToggleAllocationCategory: (cat: CategoryRecord) => {
            this.toggleBudgetAllocationCategory(cat)
          },
          onSavePeriodBudget: () => {
            this.saveBudgetPeriodSettings()
          }
        })
      } else if (this.currentSubPage === 'account') {
        SettingsAccountPage({
          sbHeight: this.sbHeight,
          onBack: () => {
            this.goBackOneLevel()
          }
        })
      } else if (this.currentSubPage === 'period') {
        SettingsPeriodPage({
          sbHeight: this.sbHeight,
          selectedPeriodType: this.selectedPeriodType,
          periodRules: this.currentPeriodRules(),
          periodCategories: this.currentPeriodCategories(),
          showPeriodForm: this.showPeriodForm,
          periodTitle: this.periodTitle,
          periodAmount: this.periodAmount,
          periodCategory: this.periodCategory,
          periodRemark: this.periodRemark,
          periodDay: this.periodDay,
          periodCycle: this.periodCycle,
          onBack: () => {
            this.goBackOneLevel()
          },
          onSelectType: (periodType: string) => {
            this.selectedPeriodType = periodType
          },
          onBeginAdd: () => {
            this.beginAddPeriodRule()
          },
          onCloseForm: () => {
            this.showPeriodForm = false
          },
          onToggleRule: (rule: PeriodRule) => {
            this.togglePeriodRule(rule)
          },
          onDeleteRule: (rule: PeriodRule) => {
            this.deletePeriodRule(rule)
          },
          onTitleChange: (value: string) => {
            this.periodTitle = value
          },
          onAmountChange: (value: string) => {
            this.periodAmount = this.normalizeAmount(value)
          },
          onCategoryChange: (value: string) => {
            this.periodCategory = value
          },
          onRemarkChange: (value: string) => {
            this.periodRemark = value
          },
          onCycleChange: (value: string) => {
            this.periodCycle = value
          },
          onDayChange: (value: string) => {
            this.periodDay = value
          },
          onSaveRule: () => {
            this.savePeriodRule()
          },
          onUnsupportedWeekly: () => {
            this.showToast('每周周期将在后续版本接入')
          },
          onUnsupportedCustom: () => {
            this.showToast('自定义周期将在后续版本接入')
          }
        })
      } else if (this.currentSubPage === 'theme') {
        SettingsThemePage({
          sbHeight: this.sbHeight,
          selectedTheme: this.selectedTheme,
          selectedThemeColor: this.selectedThemeColor,
          themeModeLabel: this.getThemeModeLabel(),
          onBack: () => {
            this.goBackOneLevel()
          },
          onSelectMode: (mode: string) => {
            this.setThemeMode(mode)
          },
          onSelectColor: (color: string) => {
            this.setThemeColor(color)
          }
        })
      } else if (this.currentSubPage === 'general') {
        SettingsGeneralPage({
          sbHeight: this.sbHeight,
          themeModeLabel: this.getThemeModeLabel(),
          notificationEnabled: this.notificationEnabled,
          onBack: () => {
            this.goBackOneLevel()
          },
          onOpenTheme: () => {
            if (this.navStack) {
              this.navStack.pushPathByName('themeMode', null)
            } else {
              this.currentSubPage = 'theme'
              this.syncPageState()
            }
          },
          onOpenSecurity: () => {
            if (this.navStack) {
              this.navStack.pushPathByName('securitySettings', null)
            } else {
              this.currentSubPage = 'security'
              this.syncPageState()
            }
          },
          onOpenPrivacy: () => {
            if (this.navStack) {
              this.navStack.pushPathByName('privacySettings', null)
            } else {
              this.currentSubPage = 'privacy'
              this.syncPageState()
            }
          },
          onToggleNotification: () => {
            this.notificationEnabled = !this.notificationEnabled
          },
          onClearCache: () => {
            this.showToast('缓存已清理')
          },
          onOpenFeedback: () => {
            if (this.navStack) {
              this.navStack.pushPathByName('feedbackPage', null)
            } else {
              this.currentSubPage = 'feedback'
              this.syncPageState()
            }
          },
          onOpenAbout: () => {
            if (this.navStack) {
              this.navStack.pushPathByName('aboutPage', null)
            } else {
              this.currentSubPage = 'about'
              this.syncPageState()
            }
          },
          onReminder: () => {
            this.showToast('提醒时间设置将在下一版开放')
          },
          onWeekStart: () => {
            this.showToast('当前固定为周一开始')
          }
        })
      } else if (this.currentSubPage === 'userData') {
        SettingsUserDataPage({
          sbHeight: this.sbHeight,
          currentUserName: this.currentUserName,
          onBack: () => {
            this.goBackOneLevel()
          },
          onExportBackup: () => {
            this.exportBackupJson()
          },
          onUploadCloudBackup: () => {
            this.uploadCloudBackup()
          },
          onClearCache: () => {
            this.showToast('缓存已清理')
          },
          onExportCsv: () => {
            this.exportCSV()
          }
        })
      } else if (this.currentSubPage === 'data') {
        SettingsDataToolsPage({
          sbHeight: this.sbHeight,
          activeUsername: this.getActiveUsername(),
          cloudRegisterPassword: this.cloudRegisterPassword,
          cloudRegisterBusy: this.cloudRegisterBusy,
          onBack: () => {
            this.goBackOneLevel()
          },
          onPasswordChange: (value: string) => {
            this.cloudRegisterPassword = value
          },
          onExportBackup: () => {
            this.exportBackupJson()
          },
          onUploadCloudBackup: () => {
            this.uploadCloudBackup()
          },
          onCheckCloudBackups: () => {
            this.checkCloudBackups()
          },
          onRegisterCloudAccount: () => {
            this.registerCloudAccountAndUpload()
          },
          onUploadCloudDatabase: () => {
            this.uploadCloudDatabase()
          },
          onCheckCloudDatabase: () => {
            this.checkCloudDatabase()
          },
          onExportCsv: () => {
            this.exportCSV()
          },
          onClearCache: () => {
            this.showToast('缓存已清理')
          }
        })
      } else if (this.currentSubPage === 'privacy') {
        SettingsPrivacyPage({
          sbHeight: this.sbHeight,
          privacyHideAmount: this.privacyHideAmount,
          privacyLocalOnly: this.privacyLocalOnly,
          onBack: () => {
            this.goBackOneLevel()
          },
          onToggleHideAmount: () => {
            this.privacyHideAmount = !this.privacyHideAmount
            AppStorage.setOrCreate<boolean>('privacyHideAmount', this.privacyHideAmount)
            this.saveAppBool('privacy_hide_amount', this.privacyHideAmount)
          },
          onToggleLocalOnly: () => {
            this.privacyLocalOnly = !this.privacyLocalOnly
            this.saveAppBool('privacy_local_only', this.privacyLocalOnly)
          },
          onConfirm: () => {
            this.showToast('隐私设置已保存')
          }
        })
      } else if (this.currentSubPage === 'sync') {
        SettingsSyncPage({
          sbHeight: this.sbHeight,
          onBack: () => {
            this.goBackOneLevel()
          },
          onExportMigration: () => {
            this.exportBackupJson()
          },
          onShowRoadmap: () => {
            this.showToast('同步能力已纳入 P2')
          }
        })
      } else if (this.currentSubPage === 'security') {
        SettingsSecurityPage({
          sbHeight: this.sbHeight,
          securityAppLock: this.securityAppLock,
          securityAutoLock: this.securityAutoLock,
          onBack: () => {
            this.goBackOneLevel()
          },
          onToggleAppLock: () => {
            this.securityAppLock = !this.securityAppLock
            this.saveAppBool('security_app_lock', this.securityAppLock)
          },
          onToggleAutoLock: () => {
            this.securityAutoLock = !this.securityAutoLock
            this.saveAppBool('security_auto_lock', this.securityAutoLock)
          },
          onSave: () => {
            this.showToast('安全偏好已保存')
          }
        })
      } else if (this.currentSubPage === 'feedback') {
        SettingsFeedbackPage({
          sbHeight: this.sbHeight,
          feedbackText: this.feedbackText,
          onBack: () => {
            this.goBackOneLevel()
          },
          onChangeText: (value: string) => {
            this.feedbackText = value
          },
          onSubmit: () => {
            this.submitFeedback()
          },
          onRoadmap: () => {
            this.showToast('反馈服务端接入为 P2')
          }
        })
      } else if (this.currentSubPage === 'about') {
        SettingsAboutPage({
          sbHeight: this.sbHeight,
          onBack: () => {
            this.goBackOneLevel()
          },
          onCheckVersion: () => {
            this.showToast('当前已是 1.0.0')
          }
        })
      } else {
        this.MainPage()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Transparent)
  }
}
