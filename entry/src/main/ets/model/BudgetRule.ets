export interface BudgetRule {
  id: string
  userId: number
  bookId: number
  name: string
  periodType: string
  scopeType: string
  amount: number
  categoryIdsJson: string
  categoryNamesJson: string
  dateMode: string
  periodValue: string
  startDay: number
  endDay: number
  compareMode: string
  status: string
  enabled: number
  createdAt: number
  updatedAt: number
  deleted: number
}

export interface BudgetRuleUsage {
  rule: BudgetRule
  usedFen: number
  remainFen: number
  percent: number
  periodLabel: string
  scopeLabel: string
  compareLabel: string
}

export interface BudgetOverview {
  title: string
  totalFen: number
  usedFen: number
  remainFen: number
  percent: number
  activeRuleCount: number
  hasTotalRule: boolean
  categoryBudgetFen: number
  overflow: boolean
  overflowFen: number
}

export interface BudgetPeriodRange {
  startDate: string
  endDate: string
  label: string
}

export interface BudgetConflictResult {
  hasConflict: boolean
  message: string
  conflictRuleId: string
  conflictRuleName: string
}

export function createEmptyBudgetRule(): BudgetRule {
  const now = Date.now()
  return {
    id: '',
    userId: 0,
    bookId: 0,
    name: '',
    periodType: 'month',
    scopeType: 'total',
    amount: 0,
    categoryIdsJson: '[]',
    categoryNamesJson: '[]',
    dateMode: 'current',
    periodValue: '',
    startDay: 1,
    endDay: 31,
    compareMode: 'previous',
    status: 'active',
    enabled: 1,
    createdAt: now,
    updatedAt: now,
    deleted: 0
  }
}

export function createEmptyBudgetOverview(): BudgetOverview {
  return {
    title: '还没有设置预算',
    totalFen: 0,
    usedFen: 0,
    remainFen: 0,
    percent: 0,
    activeRuleCount: 0,
    hasTotalRule: false,
    categoryBudgetFen: 0,
    overflow: false,
    overflowFen: 0
  }
}
