import { Bill } from './Bill'

export interface CategoryStat {
  category: string
  total: number
  percent: number
  color: string
}

export interface MonthStat {
  month: string
  income: number
  expense: number
}

export interface BillGroupData {
  date: string
  bills: Bill[]
  dayIncome: number
  dayExpense: number
}

// 日历视图：每天的收支汇总
export interface DaySummary {
  date: string      // YYYY-MM-DD
  income: number    // 单位：分
  expense: number   // 单位：分
}
