import { relationalStore } from '@kit.ArkData'
import { DBHelper } from './DBHelper'
import { BillDao } from './BillDao'
import { PeriodRule } from '../model/PeriodRule'
import { Bill } from '../model/Bill'
import { DateUtil } from '../utils/DateUtil'
import { LogUtils } from '../utils/LogUtils'
import { AccountBookDao } from './AccountBookDao'
import { CategoryDao } from './CategoryDao'

export class PeriodRuleDao {
  private static instance: PeriodRuleDao | null = null

  private constructor() {}

  static getInstance(): PeriodRuleDao {
    if (!PeriodRuleDao.instance) {
      PeriodRuleDao.instance = new PeriodRuleDao()
    }
    return PeriodRuleDao.instance
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

  private rowToRule(rs: relationalStore.ResultSet): PeriodRule {
    return {
      id: rs.getLong(rs.getColumnIndex('id')),
      title: rs.getString(rs.getColumnIndex('title')),
      amount: rs.getLong(rs.getColumnIndex('amount')),
      type: rs.getString(rs.getColumnIndex('type')) as 'income' | 'expense',
      category: rs.getString(rs.getColumnIndex('category')),
      remark: rs.getString(rs.getColumnIndex('remark')),
      cycle: rs.getString(rs.getColumnIndex('cycle')) as 'monthly' | 'yearly',
      day: rs.getLong(rs.getColumnIndex('day')),
      month: rs.getLong(rs.getColumnIndex('month')),
      nextDate: rs.getString(rs.getColumnIndex('nextDate')),
      enabled: rs.getLong(rs.getColumnIndex('enabled')),
      createdAt: rs.getLong(rs.getColumnIndex('createdAt'))
    }
  }

  async queryByType(type: 'income' | 'expense'): Promise<PeriodRule[]> {
    try {
      const predicates = new relationalStore.RdbPredicates('period_rules')
      predicates.equalTo('userId', this.getCurrentUserId())
      predicates.equalTo('bookId', this.getCurrentBookId())
      predicates.equalTo('type', type)
      predicates.orderByAsc('nextDate')
      const rs = await this.getStore().query(predicates)
      const result: PeriodRule[] = []
      while (rs.goToNextRow()) {
        result.push(this.rowToRule(rs))
      }
      rs.close()
      return result
    } catch (err) {
      LogUtils.error('PeriodRuleDao', 'queryByType failed: %{public}s', JSON.stringify(err))
      return []
    }
  }

  async queryEnabled(): Promise<PeriodRule[]> {
    try {
      const predicates = new relationalStore.RdbPredicates('period_rules')
      predicates.equalTo('userId', this.getCurrentUserId())
      predicates.equalTo('bookId', this.getCurrentBookId())
      predicates.equalTo('enabled', 1)
      predicates.orderByAsc('nextDate')
      const rs = await this.getStore().query(predicates)
      const result: PeriodRule[] = []
      while (rs.goToNextRow()) {
        result.push(this.rowToRule(rs))
      }
      rs.close()
      return result
    } catch (err) {
      LogUtils.error('PeriodRuleDao', 'queryEnabled failed: %{public}s', JSON.stringify(err))
      return []
    }
  }

  async queryAll(): Promise<PeriodRule[]> {
    try {
      const predicates = new relationalStore.RdbPredicates('period_rules')
      predicates.equalTo('userId', this.getCurrentUserId())
      predicates.equalTo('bookId', this.getCurrentBookId())
      predicates.orderByAsc('type')
      predicates.orderByAsc('nextDate')
      const rs = await this.getStore().query(predicates)
      const result: PeriodRule[] = []
      while (rs.goToNextRow()) {
        result.push(this.rowToRule(rs))
      }
      rs.close()
      return result
    } catch (err) {
      LogUtils.error('PeriodRuleDao', 'queryAll failed: %{public}s', JSON.stringify(err))
      return []
    }
  }

  async insert(rule: PeriodRule): Promise<number> {
    const bucket: relationalStore.ValuesBucket = {
      userId: this.getCurrentUserId(),
      bookId: this.getCurrentBookId(),
      title: rule.title,
      amount: rule.amount,
      type: rule.type,
      category: rule.category,
      remark: rule.remark,
      cycle: rule.cycle,
      day: rule.day,
      month: rule.month,
      nextDate: rule.nextDate,
      enabled: rule.enabled,
      createdAt: rule.createdAt
    }
    return await this.getStore().insert('period_rules', bucket)
  }

  async updateEnabled(id: number, enabled: number): Promise<void> {
    const bucket: relationalStore.ValuesBucket = { enabled: enabled }
    const predicates = new relationalStore.RdbPredicates('period_rules')
    predicates.equalTo('id', id)
    predicates.equalTo('userId', this.getCurrentUserId())
    predicates.equalTo('bookId', this.getCurrentBookId())
    await this.getStore().update(bucket, predicates)
  }

  async deleteById(id: number): Promise<void> {
    const predicates = new relationalStore.RdbPredicates('period_rules')
    predicates.equalTo('id', id)
    predicates.equalTo('userId', this.getCurrentUserId())
    predicates.equalTo('bookId', this.getCurrentBookId())
    await this.getStore().delete(predicates)
  }

  private daysInMonth(year: number, month: number): number {
    return new Date(year, month, 0).getDate()
  }

  private buildDate(year: number, month: number, day: number): string {
    const safeDay = Math.min(day, this.daysInMonth(year, month))
    const monthText = month.toString().padStart(2, '0')
    const dayText = safeDay.toString().padStart(2, '0')
    return `${year}-${monthText}-${dayText}`
  }

  nextDateFrom(cycle: 'monthly' | 'yearly', month: number, day: number, baseDate: Date): string {
    const year = baseDate.getFullYear()
    const baseMonth = baseDate.getMonth() + 1
    const todayText = DateUtil.format(baseDate)
    if (cycle === 'monthly') {
      let target = this.buildDate(year, baseMonth, day)
      if (target < todayText) {
        let nextYear = year
        let nextMonth = baseMonth + 1
        if (nextMonth > 12) {
          nextMonth = 1
          nextYear += 1
        }
        target = this.buildDate(nextYear, nextMonth, day)
      }
      return target
    }
    let yearlyTarget = this.buildDate(year, month, day)
    if (yearlyTarget < todayText) {
      yearlyTarget = this.buildDate(year + 1, month, day)
    }
    return yearlyTarget
  }

  private nextDateAfter(rule: PeriodRule): string {
    const parts = rule.nextDate.split('-')
    const year = parseInt(parts[0], 10)
    const month = parseInt(parts[1], 10)
    const day = parseInt(parts[2], 10)
    if (rule.cycle === 'monthly') {
      let nextYear = year
      let nextMonth = month + 1
      if (nextMonth > 12) {
        nextMonth = 1
        nextYear += 1
      }
      return this.buildDate(nextYear, nextMonth, rule.day)
    }
    return this.buildDate(year + 1, rule.month, day)
  }

  private async updateNextDate(id: number, nextDate: string): Promise<void> {
    const bucket: relationalStore.ValuesBucket = { nextDate: nextDate }
    const predicates = new relationalStore.RdbPredicates('period_rules')
    predicates.equalTo('id', id)
    predicates.equalTo('userId', this.getCurrentUserId())
    predicates.equalTo('bookId', this.getCurrentBookId())
    await this.getStore().update(bucket, predicates)
  }

  async generateDueBills(): Promise<number> {
    const rules = await this.queryEnabled()
    const today = DateUtil.today()
    let count = 0
    for (let i = 0; i < rules.length; i++) {
      let rule = rules[i]
      let guard = 0
      while (rule.nextDate <= today && guard < 24) {
        const catRecord = await CategoryDao.getInstance().queryByName(rule.category, rule.type)
        const categoryId = catRecord ? catRecord.id : 0
        const bill: Bill = {
          id: 0,
          amount: rule.amount,
          type: rule.type,
          category: rule.category,
          categoryId: categoryId,
          remark: rule.remark.length > 0 ? rule.remark : rule.title,
          date: rule.nextDate,
          createdAt: Date.now()
        }
        await BillDao.getInstance().insert(bill)
        const nextDate = this.nextDateAfter(rule)
        await this.updateNextDate(rule.id, nextDate)
        rule = {
          id: rule.id,
          title: rule.title,
          amount: rule.amount,
          type: rule.type,
          category: rule.category,
          remark: rule.remark,
          cycle: rule.cycle,
          day: rule.day,
          month: rule.month,
          nextDate: nextDate,
          enabled: rule.enabled,
          createdAt: rule.createdAt
        }
        count += 1
        guard += 1
      }
    }
    return count
  }
}
