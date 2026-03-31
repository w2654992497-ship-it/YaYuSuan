import { relationalStore } from '@kit.ArkData'
import { Bill } from '../model/Bill'
import { LogUtils } from '../utils/LogUtils'
import { FilterOptions } from '../model/FilterOptions'
import { CategoryStat, MonthStat } from '../model/StatResult'
import { DBHelper } from './DBHelper'
import { getCategoryColor } from '../model/Category'

export class BillDao {
  private static instance: BillDao | null = null

  private constructor() {}

  static getInstance(): BillDao {
    if (!BillDao.instance) {
      BillDao.instance = new BillDao()
    }
    return BillDao.instance
  }

  private getStore(): relationalStore.RdbStore {
    return DBHelper.getInstance().getStore()
  }

  async insert(bill: Bill): Promise<number> {
    try {
      const store = this.getStore()
      const valueBucket: relationalStore.ValuesBucket = {
        amount: bill.amount,
        type: bill.type,
        category: bill.category,
        remark: bill.remark,
        date: bill.date,
        createdAt: bill.createdAt
      }
      const rowId = await store.insert('bills', valueBucket)
      LogUtils.info('BillDao', 'Inserted bill rowId=%{public}d', String(rowId))
      return rowId
    } catch (err) {
      LogUtils.error('BillDao', 'insert failed: %{public}s', JSON.stringify(err))
      throw new Error(String(err))
    }
  }

  async deleteById(id: number): Promise<void> {
    try {
      const store = this.getStore()
      const predicates = new relationalStore.RdbPredicates('bills')
      predicates.equalTo('id', id)
      await store.delete(predicates)
      LogUtils.info('BillDao', 'Deleted bill id=%{public}d', String(id))
    } catch (err) {
      LogUtils.error('BillDao', 'deleteById failed: %{public}s', JSON.stringify(err))
      throw new Error(String(err))
    }
  }

  async queryByFilter(filter: FilterOptions): Promise<Bill[]> {
    try {
      const store = this.getStore()
      const predicates = new relationalStore.RdbPredicates('bills')

      if (filter.month && filter.month.length > 0) {
        predicates.like('date', `${filter.month}%`)
      }
      if (filter.type !== 'all') {
        predicates.equalTo('type', filter.type)
      }
      if (filter.category && filter.category.length > 0) {
        predicates.equalTo('category', filter.category)
      }

      predicates.orderByDesc('date')
      predicates.orderByDesc('createdAt')

      const resultSet = await store.query(predicates, ['id', 'amount', 'type', 'category', 'remark', 'date', 'createdAt'])
      const bills: Bill[] = []

      while (resultSet.goToNextRow()) {
        const bill: Bill = {
          id: resultSet.getLong(resultSet.getColumnIndex('id')),
          amount: resultSet.getLong(resultSet.getColumnIndex('amount')),
          type: resultSet.getString(resultSet.getColumnIndex('type')) as 'income' | 'expense',
          category: resultSet.getString(resultSet.getColumnIndex('category')),
          remark: resultSet.getString(resultSet.getColumnIndex('remark')),
          date: resultSet.getString(resultSet.getColumnIndex('date')),
          createdAt: resultSet.getLong(resultSet.getColumnIndex('createdAt'))
        }
        bills.push(bill)
      }
      resultSet.close()
      return bills
    } catch (err) {
      LogUtils.error('BillDao', 'queryByFilter failed: %{public}s', JSON.stringify(err))
      return []
    }
  }

  async queryCategoryStats(month: string, type: string): Promise<CategoryStat[]> {
    try {
      const store = this.getStore()
      let whereClause = `type = '${type}'`
      if (month && month.length > 0) {
        whereClause += ` AND date LIKE '${month}%'`
      }
      const sql = `SELECT category, SUM(amount) as total FROM bills WHERE ${whereClause} GROUP BY category ORDER BY total DESC`
      const resultSet = await store.querySql(sql)
      const stats: CategoryStat[] = []
      let grandTotal = 0

      while (resultSet.goToNextRow()) {
        const category = resultSet.getString(resultSet.getColumnIndex('category'))
        const total = resultSet.getLong(resultSet.getColumnIndex('total'))
        grandTotal += total
        stats.push({
          category: category,
          total: total,
          percent: 0,
          color: getCategoryColor(category)
        })
      }
      resultSet.close()

      if (grandTotal > 0) {
        for (const stat of stats) {
          stat.percent = Math.round((stat.total / grandTotal) * 100)
        }
      }

      return stats
    } catch (err) {
      LogUtils.error('BillDao', 'queryCategoryStats failed: %{public}s', JSON.stringify(err))
      return []
    }
  }

  async queryMonthStats(months: string[]): Promise<MonthStat[]> {
    try {
      const store = this.getStore()
      const monthStats: MonthStat[] = []

      for (const month of months) {
        const incomeSql = `SELECT SUM(amount) as total FROM bills WHERE type = 'income' AND date LIKE '${month}%'`
        const expenseSql = `SELECT SUM(amount) as total FROM bills WHERE type = 'expense' AND date LIKE '${month}%'`

        const incomeResult = await store.querySql(incomeSql)
        let income = 0
        if (incomeResult.goToNextRow()) {
          income = incomeResult.getLong(incomeResult.getColumnIndex('total'))
        }
        incomeResult.close()

        const expenseResult = await store.querySql(expenseSql)
        let expense = 0
        if (expenseResult.goToNextRow()) {
          expense = expenseResult.getLong(expenseResult.getColumnIndex('total'))
        }
        expenseResult.close()

        monthStats.push({ month: month, income: income, expense: expense })
      }

      return monthStats
    } catch (err) {
      LogUtils.error('BillDao', 'queryMonthStats failed: %{public}s', JSON.stringify(err))
      return []
    }
  }
}
