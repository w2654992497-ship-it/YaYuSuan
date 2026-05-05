import { BillDao } from '../database/BillDao'
import { BudgetRuleDao } from '../database/BudgetRuleDao'
import { Bill } from '../model/Bill'
import {
  BudgetOverview,
  BudgetPeriodRange,
  BudgetRule,
  BudgetRuleUsage,
  createEmptyBudgetOverview
} from '../model/BudgetRule'
import { FilterOptions } from '../model/FilterOptions'
import { AmountUtil } from '../utils/AmountUtil'
import { LogUtils } from '../utils/LogUtils'

const BUDGET_SERVICE_TAG = 'BudgetService'

export class BudgetService {
  private static instance: BudgetService | null = null

  private constructor() {}

  static getInstance(): BudgetService {
    if (!BudgetService.instance) {
      BudgetService.instance = new BudgetService()
    }
    return BudgetService.instance
  }

  async buildOverview(periodType: string): Promise<BudgetOverview> {
    if (periodType === 'month') {
      return await this.buildMonthOverview(this.currentMonth())
    }
    if (periodType === 'year') {
      return await this.buildYearOverview(this.currentYear())
    }
    try {
      const rules = await BudgetRuleDao.getInstance().queryActive()
      const activeRules: BudgetRule[] = []
      for (let i = 0; i < rules.length; i++) {
        const rule = rules[i]
        if (rule.periodType === periodType && this.ruleAppliesToDay(rule, this.today())) {
          activeRules.push(rule)
        }
      }
      const range = this.resolvePeriodRangeByType(periodType, 'current', '', 1, 31)
      const allBills = await this.queryExpenseBills()
      const periodBills = this.filterBillsByRange(allBills, range.startDate, range.endDate)
      if (activeRules.length === 0) {
        return this.emptyOverviewWithUsed('今日总预算', periodBills)
      }
      return this.composeOverview(activeRules, periodBills, '今日分类分配', '今日总预算')
    } catch (err) {
      LogUtils.error(BUDGET_SERVICE_TAG, '生成预算概览失败：%{public}s', JSON.stringify(err))
      return createEmptyBudgetOverview()
    }
  }

  async buildMonthOverview(month: string): Promise<BudgetOverview> {
    try {
      const rules = await BudgetRuleDao.getInstance().queryActive()
      const activeRules: BudgetRule[] = []
      for (let i = 0; i < rules.length; i++) {
        const rule = rules[i]
        if (rule.periodType === 'month' && this.ruleAppliesToMonth(rule, month)) {
          activeRules.push(rule)
        }
      }
      const range = this.resolvePeriodRangeByType('month', 'fixed', month, 1, 31)
      const allBills = await this.queryExpenseBills()
      const periodBills = this.filterBillsByRange(allBills, range.startDate, range.endDate)
      if (activeRules.length === 0) {
        return this.emptyOverviewWithUsed('本月总预算', periodBills)
      }
      return this.composeOverview(activeRules, periodBills, '本月分类分配', '本月总预算')
    } catch (err) {
      LogUtils.error(BUDGET_SERVICE_TAG, '生成月份预算概览失败：%{public}s', JSON.stringify(err))
      return createEmptyBudgetOverview()
    }
  }

  async buildYearOverview(year: string): Promise<BudgetOverview> {
    try {
      const rules = await BudgetRuleDao.getInstance().queryActive()
      const yearRules: BudgetRule[] = []
      for (let i = 0; i < rules.length; i++) {
        const rule = rules[i]
        if (rule.periodType === 'year' && this.ruleAppliesToYear(rule, year)) {
          yearRules.push(rule)
        }
      }

      const allBills = await this.queryExpenseBills()
      const yearRange = this.resolvePeriodRangeByType('year', 'fixed', year, 1, 31)
      const yearBills = this.filterBillsByRange(allBills, yearRange.startDate, yearRange.endDate)
      if (yearRules.length === 0) {
        return this.emptyOverviewWithUsed('本年总预算', yearBills)
      }
      return this.composeOverview(yearRules, yearBills, '本年分类分配', '本年总预算')
    } catch (err) {
      LogUtils.error(BUDGET_SERVICE_TAG, '生成年份预算概览失败：%{public}s', JSON.stringify(err))
      return createEmptyBudgetOverview()
    }
  }

  async buildRuleUsages(): Promise<BudgetRuleUsage[]> {
    const rules = await BudgetRuleDao.getInstance().queryAll()
    const bills = await this.queryExpenseBills()
    const result: BudgetRuleUsage[] = []
    for (let i = 0; i < rules.length; i++) {
      const rule = rules[i]
      if (rule.deleted === 1) {
        continue
      }
      const range = this.resolvePeriodRange(rule)
      const scopedBills = this.filterBillsByRange(bills, range.startDate, range.endDate)
      const usedFen = rule.enabled === 1 && rule.status === 'active' ? this.calculateUsedFen(rule, scopedBills) : 0
      const remainFen = rule.amount - usedFen > 0 ? rule.amount - usedFen : 0
      result.push({
        rule: rule,
        usedFen: usedFen,
        remainFen: remainFen,
        percent: this.safePercent(usedFen, rule.amount),
        periodLabel: this.periodLabel(rule),
        scopeLabel: this.scopeLabel(rule),
        compareLabel: this.compareLabel(rule)
      })
    }
    return result
  }

  async detectOverflowWithPending(rule: BudgetRule): Promise<BudgetOverview> {
    const rules = await BudgetRuleDao.getInstance().queryActive()
    let totalFen = 0
    let categoryFen = 0
    for (let i = 0; i < rules.length; i++) {
      const item = rules[i]
      if (item.id === rule.id || item.periodType !== rule.periodType) {
        continue
      }
      if (item.scopeType === 'total' && totalFen === 0) {
        totalFen = item.amount
      }
      if (item.scopeType === 'categories') {
        categoryFen += item.amount
      }
    }
    if (rule.scopeType === 'total') {
      totalFen = rule.amount
    } else {
      categoryFen += rule.amount
    }
    const overview = createEmptyBudgetOverview()
    overview.title = '分类预算合计超过总预算'
    overview.totalFen = totalFen
    overview.categoryBudgetFen = categoryFen
    overview.overflow = totalFen > 0 && categoryFen > totalFen
    overview.overflowFen = overview.overflow ? categoryFen - totalFen : 0
    return overview
  }

  async buildExpenseBillWarning(category: string, categoryId: number, date: string): Promise<string> {
    try {
      const rules = await BudgetRuleDao.getInstance().queryActive()
      const bills = await this.queryExpenseBills()
      let warning = ''
      let maxOverFen = 0
      for (let i = 0; i < rules.length; i++) {
        const rule = rules[i]
        const range = this.resolvePeriodRange(rule)
        if (date < range.startDate || date > range.endDate) {
          continue
        }
        if (rule.scopeType === 'categories' && !this.categoryMatchesRule(rule, categoryId, category)) {
          continue
        }
        const scopedBills = this.filterBillsByRange(bills, range.startDate, range.endDate)
        const usedFen = this.calculateUsedFen(rule, scopedBills)
        if (usedFen > rule.amount) {
          const overFen = usedFen - rule.amount
          if (overFen > maxOverFen) {
            maxOverFen = overFen
            warning = '「' + rule.name + '」已超预算 ¥' + AmountUtil.fen2Display(overFen)
          }
        }
      }
      return warning
    } catch (err) {
      LogUtils.error(BUDGET_SERVICE_TAG, '生成记账预算提醒失败：%{public}s', JSON.stringify(err))
      return ''
    }
  }

  resolvePeriodRange(rule: BudgetRule): BudgetPeriodRange {
    return this.resolvePeriodRangeByType(rule.periodType, rule.dateMode, rule.periodValue, rule.startDay, rule.endDay)
  }

  resolvePeriodRangeByType(periodType: string, dateMode: string, periodValue: string, startDay: number, endDay: number): BudgetPeriodRange {
    if (periodType === 'day') {
      const value = dateMode === 'fixed' && periodValue.length > 0 ? periodValue : this.today()
      return { startDate: value, endDate: value, label: value }
    }
    if (periodType === 'year') {
      const year = dateMode === 'fixed' && periodValue.length > 0 ? periodValue : this.currentYear()
      return { startDate: year + '-01-01', endDate: year + '-12-31', label: year + '年' }
    }
    const ym = dateMode === 'fixed' && periodValue.length > 0 ? periodValue : this.currentMonth()
    let safeStart = startDay > 0 ? startDay : 1
    let safeEnd = endDay > 0 ? endDay : 31
    if (safeStart > 31) {
      safeStart = 31
    }
    if (safeEnd > 31) {
      safeEnd = 31
    }
    if (safeEnd < safeStart) {
      safeEnd = safeStart
    }
    const last = this.monthLastDay(ym)
    const actualStart = safeStart > last ? last : safeStart
    const actualEnd = safeEnd > last ? last : safeEnd
    return {
      startDate: ym + '-' + this.two(actualStart),
      endDate: ym + '-' + this.two(actualEnd),
      label: ym + ' ' + this.two(actualStart) + '日-' + this.two(actualEnd) + '日'
    }
  }

  scopeLabel(rule: BudgetRule): string {
    if (rule.scopeType === 'total') {
      return '全部支出'
    }
    const names = BudgetRuleDao.getInstance().parseCategoryNames(rule.categoryNamesJson)
    if (names.length === 0) {
      return '已选分类'
    }
    return names.join(' · ')
  }

  periodLabel(rule: BudgetRule): string {
    if (rule.periodType === 'day') {
      return '每日'
    }
    if (rule.periodType === 'year') {
      return '每年'
    }
    return '每月'
  }

  compareLabel(rule: BudgetRule): string {
    if (rule.compareMode === 'none') {
      return '不对比'
    }
    if (rule.periodType === 'day') {
      return '昨日'
    }
    if (rule.periodType === 'year') {
      return '去年'
    }
    return '上月'
  }

  private async queryExpenseBills(): Promise<Bill[]> {
    const filter: FilterOptions = { month: '', type: 'expense', category: '' }
    return await BillDao.getInstance().queryByFilter(filter)
  }

  private filterBillsByRange(bills: Bill[], startDate: string, endDate: string): Bill[] {
    const result: Bill[] = []
    for (let i = 0; i < bills.length; i++) {
      const bill = bills[i]
      if (bill.date >= startDate && bill.date <= endDate) {
        result.push(bill)
      }
    }
    return result
  }

  private calculateUsedFen(rule: BudgetRule, bills: Bill[]): number {
    if (rule.scopeType === 'total') {
      return this.sumBills(bills)
    }
    const ids = BudgetRuleDao.getInstance().parseCategoryIds(rule.categoryIdsJson)
    const names = BudgetRuleDao.getInstance().parseCategoryNames(rule.categoryNamesJson)
    let total = 0
    for (let i = 0; i < bills.length; i++) {
      const bill = bills[i]
      if (this.billMatchesCategories(bill, ids, names)) {
        total += bill.amount
      }
    }
    return total
  }

  private billMatchesCategories(bill: Bill, ids: number[], names: string[]): boolean {
    if (bill.categoryId > 0) {
      for (let i = 0; i < ids.length; i++) {
        if (ids[i] === bill.categoryId) {
          return true
        }
      }
    }
    for (let j = 0; j < names.length; j++) {
      if (names[j] === bill.category) {
        return true
      }
    }
    return false
  }

  private categoryMatchesRule(rule: BudgetRule, categoryId: number, categoryName: string): boolean {
    const ids = BudgetRuleDao.getInstance().parseCategoryIds(rule.categoryIdsJson)
    const names = BudgetRuleDao.getInstance().parseCategoryNames(rule.categoryNamesJson)
    if (categoryId > 0) {
      for (let i = 0; i < ids.length; i++) {
        if (ids[i] === categoryId) {
          return true
        }
      }
    }
    for (let j = 0; j < names.length; j++) {
      if (names[j] === categoryName) {
        return true
      }
    }
    return false
  }

  private ruleAppliesToMonth(rule: BudgetRule, month: string): boolean {
    if (rule.dateMode !== 'fixed') {
      return month === this.currentMonth()
    }
    if (rule.periodValue.length === 0) {
      return month === this.currentMonth()
    }
    return rule.periodValue === month
  }

  private ruleAppliesToYear(rule: BudgetRule, year: string): boolean {
    if (rule.dateMode !== 'fixed') {
      return year === this.currentYear()
    }
    if (rule.periodValue.length === 0) {
      return year === this.currentYear()
    }
    return rule.periodValue === year
  }

  private ruleAppliesToDay(rule: BudgetRule, day: string): boolean {
    if (rule.dateMode !== 'fixed') {
      return day === this.today()
    }
    if (rule.periodValue.length === 0) {
      return day === this.today()
    }
    return rule.periodValue === day
  }

  private composeOverview(activeRules: BudgetRule[], periodBills: Bill[], categoryTitle: string, totalTitle: string): BudgetOverview {
    let totalRule: BudgetRule | null = null
    let categoryBudgetFen = 0
    for (let i = 0; i < activeRules.length; i++) {
      const rule = activeRules[i]
      if (rule.scopeType === 'total' && totalRule === null) {
        totalRule = rule
      }
      if (rule.scopeType === 'categories') {
        categoryBudgetFen += rule.amount
      }
    }

    let totalFen = 0
    let usedFen = this.sumBills(periodBills)
    let hasTotalRule = false
    let title = totalTitle
    if (totalRule !== null) {
      totalFen = totalRule.amount
      hasTotalRule = true
      title = totalTitle
    } else if (categoryBudgetFen > 0) {
      totalFen = categoryBudgetFen
      title = categoryTitle
    }
    const remainFen = totalFen > usedFen ? totalFen - usedFen : 0
    const overflow = hasTotalRule && categoryBudgetFen > totalFen
    return {
      title: title,
      totalFen: totalFen,
      usedFen: usedFen,
      remainFen: remainFen,
      percent: this.safePercent(usedFen, totalFen),
      activeRuleCount: activeRules.length,
      hasTotalRule: hasTotalRule,
      categoryBudgetFen: categoryBudgetFen,
      overflow: overflow,
      overflowFen: overflow ? categoryBudgetFen - totalFen : 0
    }
  }

  private emptyOverviewWithUsed(title: string, periodBills: Bill[]): BudgetOverview {
    const overview = createEmptyBudgetOverview()
    overview.title = title
    overview.usedFen = this.sumBills(periodBills)
    return overview
  }

  private sumBills(bills: Bill[]): number {
    let total = 0
    for (let i = 0; i < bills.length; i++) {
      total += bills[i].amount
    }
    return total
  }

  private safePercent(usedFen: number, totalFen: number): number {
    if (totalFen <= 0) {
      return 0
    }
    const percent = Math.round(usedFen * 100 / totalFen)
    if (percent > 100) {
      return 100
    }
    if (percent < 0) {
      return 0
    }
    return percent
  }

  private currentMonth(): string {
    const now = new Date()
    return now.getFullYear().toString() + '-' + this.two(now.getMonth() + 1)
  }

  private currentYear(): string {
    return new Date().getFullYear().toString()
  }

  private today(): string {
    const now = new Date()
    return now.getFullYear().toString() + '-' + this.two(now.getMonth() + 1) + '-' + this.two(now.getDate())
  }

  private monthLastDay(ym: string): number {
    const parts = ym.split('-')
    if (parts.length !== 2) {
      return 31
    }
    const year = parseInt(parts[0], 10)
    const month = parseInt(parts[1], 10)
    if (isNaN(year) || isNaN(month)) {
      return 31
    }
    return new Date(year, month, 0).getDate()
  }

  private two(value: number): string {
    if (value < 10) {
      return '0' + value.toString()
    }
    return value.toString()
  }

  formatFen(fen: number): string {
    return AmountUtil.rawFen2Display(fen)
  }
}
