export interface PeriodRule {
  id: number
  title: string
  amount: number
  type: 'income' | 'expense'
  category: string
  remark: string
  cycle: 'monthly' | 'yearly'
  day: number
  month: number
  nextDate: string
  enabled: number
  createdAt: number
}
