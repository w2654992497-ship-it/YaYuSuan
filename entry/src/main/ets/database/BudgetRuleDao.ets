import { relationalStore } from '@kit.ArkData'
import {
  BudgetConflictResult,
  BudgetRule,
  createEmptyBudgetRule
} from '../model/BudgetRule'
import { DBHelper } from './DBHelper'
import { AccountBookDao } from './AccountBookDao'
import { LogUtils } from '../utils/LogUtils'

const BUDGET_RULE_DAO_TAG = 'BudgetRuleDao'

export class BudgetRuleDao {
  private static instance: BudgetRuleDao | null = null

  private constructor() {}

  static getInstance(): BudgetRuleDao {
    if (!BudgetRuleDao.instance) {
      BudgetRuleDao.instance = new BudgetRuleDao()
    }
    return BudgetRuleDao.instance
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

  private rowToRule(rs: relationalStore.ResultSet): BudgetRule {
    return {
      id: rs.getString(rs.getColumnIndex('id')),
      userId: rs.getLong(rs.getColumnIndex('userId')),
      bookId: rs.getLong(rs.getColumnIndex('bookId')),
      name: rs.getString(rs.getColumnIndex('name')),
      periodType: rs.getString(rs.getColumnIndex('periodType')),
      scopeType: rs.getString(rs.getColumnIndex('scopeType')),
      amount: rs.getLong(rs.getColumnIndex('amount')),
      categoryIdsJson: rs.getString(rs.getColumnIndex('categoryIdsJson')),
      categoryNamesJson: rs.getString(rs.getColumnIndex('categoryNamesJson')),
      dateMode: rs.getString(rs.getColumnIndex('dateMode')),
      periodValue: rs.getString(rs.getColumnIndex('periodValue')),
      startDay: rs.getLong(rs.getColumnIndex('startDay')),
      endDay: rs.getLong(rs.getColumnIndex('endDay')),
      compareMode: rs.getString(rs.getColumnIndex('compareMode')),
      status: rs.getString(rs.getColumnIndex('status')),
      enabled: rs.getLong(rs.getColumnIndex('enabled')),
      createdAt: rs.getLong(rs.getColumnIndex('createdAt')),
      updatedAt: rs.getLong(rs.getColumnIndex('updatedAt')),
      deleted: rs.getLong(rs.getColumnIndex('deleted'))
    }
  }

  generateId(): string {
    const randomPart = Math.floor(Math.random() * 1000000).toString()
    return 'budget_' + Date.now().toString() + '_' + randomPart
  }

  createDraft(): BudgetRule {
    const rule = createEmptyBudgetRule()
    rule.id = ''
    rule.userId = this.getCurrentUserId()
    rule.bookId = this.getCurrentBookId()
    rule.name = '本月总预算'
    rule.periodType = 'month'
    rule.scopeType = 'total'
    rule.compareMode = 'previous'
    return rule
  }

  private normalizeRule(rule: BudgetRule): BudgetRule {
    const now = Date.now()
    const next = createEmptyBudgetRule()
    next.id = rule.id.length > 0 ? rule.id : this.generateId()
    next.userId = rule.userId > 0 ? rule.userId : this.getCurrentUserId()
    next.bookId = rule.bookId > 0 ? rule.bookId : this.getCurrentBookId()
    next.name = rule.name
    next.periodType = rule.periodType.length > 0 ? rule.periodType : 'month'
    next.scopeType = rule.scopeType.length > 0 ? rule.scopeType : 'total'
    next.amount = rule.amount
    next.categoryIdsJson = rule.categoryIdsJson.length > 0 ? rule.categoryIdsJson : '[]'
    next.categoryNamesJson = rule.categoryNamesJson.length > 0 ? rule.categoryNamesJson : '[]'
    next.dateMode = rule.dateMode.length > 0 ? rule.dateMode : 'current'
    next.periodValue = rule.periodValue
    next.startDay = rule.startDay > 0 ? rule.startDay : 1
    next.endDay = rule.endDay > 0 ? rule.endDay : 31
    next.compareMode = rule.compareMode.length > 0 ? rule.compareMode : 'previous'
    next.status = rule.status.length > 0 ? rule.status : 'active'
    next.enabled = rule.enabled
    next.createdAt = rule.createdAt > 0 ? rule.createdAt : now
    next.updatedAt = now
    next.deleted = rule.deleted
    return next
  }

  private ruleToBucket(rule: BudgetRule): relationalStore.ValuesBucket {
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

  async queryAll(): Promise<BudgetRule[]> {
    try {
      const predicates = new relationalStore.RdbPredicates('budget_rules')
      predicates.equalTo('userId', this.getCurrentUserId())
      predicates.equalTo('bookId', this.getCurrentBookId())
      predicates.equalTo('deleted', 0)
      predicates.orderByAsc('periodType')
      predicates.orderByDesc('updatedAt')
      const rs = await this.getStore().query(predicates)
      const result: BudgetRule[] = []
      while (rs.goToNextRow()) {
        result.push(this.rowToRule(rs))
      }
      rs.close()
      return result
    } catch (err) {
      LogUtils.error(BUDGET_RULE_DAO_TAG, '查询预算规则失败：%{public}s', JSON.stringify(err))
      return []
    }
  }

  async debugLogBudgetRulesForSettings(stage: string): Promise<void> {
    try {
      const currentUserId = this.getCurrentUserId()
      const currentBookId = this.getCurrentBookId()
      LogUtils.info(BUDGET_RULE_DAO_TAG, '预算设置数据库快照 stage=%{public}s currentUserId=%{public}d currentBookId=%{public}d',
        stage, currentUserId, currentBookId)

      const rawPredicates = new relationalStore.RdbPredicates('budget_rules')
      rawPredicates.orderByDesc('updatedAt')
      const rawRs = await this.getStore().query(rawPredicates)
      let rawCount = 0
      while (rawRs.goToNextRow()) {
        const rule = this.rowToRule(rawRs)
        rawCount += 1
        LogUtils.info(BUDGET_RULE_DAO_TAG,
          '预算设置数据库原始行 index=%{public}d id=%{public}s userId=%{public}d bookId=%{public}d name=%{public}s period=%{public}s scope=%{public}s amount=%{public}d status=%{public}s enabled=%{public}d deleted=%{public}d updatedAt=%{public}d cats=%{public}s',
          rawCount, rule.id, rule.userId, rule.bookId, rule.name, rule.periodType, rule.scopeType, rule.amount,
          rule.status, rule.enabled, rule.deleted, rule.updatedAt, rule.categoryIdsJson)
      }
      rawRs.close()
      LogUtils.info(BUDGET_RULE_DAO_TAG, '预算设置数据库原始行总数=%{public}d', rawCount)

      const filteredRules = await this.queryAll()
      LogUtils.info(BUDGET_RULE_DAO_TAG, '预算设置当前账本可显示规则数=%{public}d', filteredRules.length)
      for (let i = 0; i < filteredRules.length; i++) {
        const rule = filteredRules[i]
        LogUtils.info(BUDGET_RULE_DAO_TAG,
          '预算设置当前账本规则 index=%{public}d id=%{public}s name=%{public}s period=%{public}s scope=%{public}s amount=%{public}d status=%{public}s enabled=%{public}d deleted=%{public}d',
          i + 1, rule.id, rule.name, rule.periodType, rule.scopeType, rule.amount, rule.status, rule.enabled,
          rule.deleted)
      }
    } catch (err) {
      LogUtils.error(BUDGET_RULE_DAO_TAG, '预算设置数据库快照失败：%{public}s', JSON.stringify(err))
    }
  }

  async queryActive(): Promise<BudgetRule[]> {
    try {
      const predicates = new relationalStore.RdbPredicates('budget_rules')
      predicates.equalTo('userId', this.getCurrentUserId())
      predicates.equalTo('bookId', this.getCurrentBookId())
      predicates.equalTo('deleted', 0)
      predicates.equalTo('status', 'active')
      predicates.equalTo('enabled', 1)
      predicates.orderByAsc('scopeType')
      predicates.orderByDesc('updatedAt')
      const rs = await this.getStore().query(predicates)
      const result: BudgetRule[] = []
      while (rs.goToNextRow()) {
        result.push(this.rowToRule(rs))
      }
      rs.close()
      return result
    } catch (err) {
      LogUtils.error(BUDGET_RULE_DAO_TAG, '查询生效预算规则失败：%{public}s', JSON.stringify(err))
      return []
    }
  }

  async queryById(id: string): Promise<BudgetRule | null> {
    try {
      const predicates = new relationalStore.RdbPredicates('budget_rules')
      predicates.equalTo('id', id)
      predicates.equalTo('userId', this.getCurrentUserId())
      predicates.equalTo('bookId', this.getCurrentBookId())
      predicates.limitAs(1)
      const rs = await this.getStore().query(predicates)
      let result: BudgetRule | null = null
      if (rs.goToNextRow()) {
        result = this.rowToRule(rs)
      }
      rs.close()
      return result
    } catch (err) {
      LogUtils.error(BUDGET_RULE_DAO_TAG, '按 ID 查询预算规则失败：%{public}s', JSON.stringify(err))
      return null
    }
  }

  async upsert(rule: BudgetRule): Promise<string> {
    const store = this.getStore()
    const next = this.normalizeRule(rule)
    const predicates = new relationalStore.RdbPredicates('budget_rules')
    predicates.equalTo('id', next.id)
    const rs = await store.query(predicates, ['id'])
    let exists = false
    if (rs.goToNextRow()) {
      exists = true
    }
    rs.close()
    if (exists) {
      await store.update(this.ruleToBucket(next), predicates)
      LogUtils.info(BUDGET_RULE_DAO_TAG, '更新预算规则 id=%{public}s name=%{public}s', next.id, next.name)
    } else {
      await store.insert('budget_rules', this.ruleToBucket(next))
      LogUtils.info(BUDGET_RULE_DAO_TAG, '新增预算规则 id=%{public}s name=%{public}s', next.id, next.name)
    }
    return next.id
  }

  async setEnabled(id: string, enabled: number): Promise<void> {
    const predicates = new relationalStore.RdbPredicates('budget_rules')
    predicates.equalTo('id', id)
    predicates.equalTo('userId', this.getCurrentUserId())
    predicates.equalTo('bookId', this.getCurrentBookId())
    const bucket: relationalStore.ValuesBucket = {
      enabled: enabled,
      updatedAt: Date.now()
    }
    await this.getStore().update(bucket, predicates)
  }

  async softDelete(id: string): Promise<void> {
    const predicates = new relationalStore.RdbPredicates('budget_rules')
    predicates.equalTo('id', id)
    predicates.equalTo('userId', this.getCurrentUserId())
    predicates.equalTo('bookId', this.getCurrentBookId())
    const bucket: relationalStore.ValuesBucket = {
      deleted: 1,
      updatedAt: Date.now()
    }
    await this.getStore().update(bucket, predicates)
  }

  async replaceAllForUserBook(userId: number, bookId: number, rules: BudgetRule[]): Promise<number> {
    const store = this.getStore()
    const predicates = new relationalStore.RdbPredicates('budget_rules')
    predicates.equalTo('userId', userId)
    predicates.equalTo('bookId', bookId)
    await store.delete(predicates)
    let count = 0
    for (let i = 0; i < rules.length; i++) {
      const source = rules[i]
      source.userId = userId
      source.bookId = bookId
      const bucket = this.ruleToBucket(this.normalizeRule(source))
      await store.insert('budget_rules', bucket)
      count += 1
    }
    return count
  }

  parseCategoryIds(jsonText: string): number[] {
    if (jsonText.length === 0) {
      return []
    }
    try {
      return JSON.parse(jsonText) as number[]
    } catch (err) {
      LogUtils.error(BUDGET_RULE_DAO_TAG, '解析预算分类 ID 失败：%{public}s', JSON.stringify(err))
      return []
    }
  }

  parseCategoryNames(jsonText: string): string[] {
    if (jsonText.length === 0) {
      return []
    }
    try {
      return JSON.parse(jsonText) as string[]
    } catch (err) {
      LogUtils.error(BUDGET_RULE_DAO_TAG, '解析预算分类名称失败：%{public}s', JSON.stringify(err))
      return []
    }
  }

  buildCategoryIdsJson(ids: number[]): string {
    return JSON.stringify(ids)
  }

  buildCategoryNamesJson(names: string[]): string {
    return JSON.stringify(names)
  }

  private hasCategoryId(ids: number[], targetId: number): boolean {
    for (let i = 0; i < ids.length; i++) {
      if (ids[i] === targetId) {
        return true
      }
    }
    return false
  }

  async checkConflict(rule: BudgetRule): Promise<BudgetConflictResult> {
    const rules = await this.queryActive()
    if (rule.scopeType === 'total') {
      for (let i = 0; i < rules.length; i++) {
        const item = rules[i]
        if (item.id !== rule.id && item.periodType === rule.periodType && item.scopeType === 'total') {
          return {
            hasConflict: true,
            message: '当前周期已存在总预算规则',
            conflictRuleId: item.id,
            conflictRuleName: item.name
          }
        }
      }
      return { hasConflict: false, message: '', conflictRuleId: '', conflictRuleName: '' }
    }
    const targetIds = this.parseCategoryIds(rule.categoryIdsJson)
    for (let i = 0; i < rules.length; i++) {
      const item = rules[i]
      if (item.id !== rule.id && item.periodType === rule.periodType && item.scopeType === 'categories') {
        const currentIds = this.parseCategoryIds(item.categoryIdsJson)
        for (let j = 0; j < targetIds.length; j++) {
          if (this.hasCategoryId(currentIds, targetIds[j])) {
            return {
              hasConflict: true,
              message: '该分类已存在同周期预算规则',
              conflictRuleId: item.id,
              conflictRuleName: item.name
            }
          }
        }
      }
    }
    return { hasConflict: false, message: '', conflictRuleId: '', conflictRuleName: '' }
  }
}
