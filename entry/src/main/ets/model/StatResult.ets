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
