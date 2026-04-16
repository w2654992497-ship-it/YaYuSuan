import { relationalStore } from '@kit.ArkData'
import { Bill } from '../model/Bill'
import { LogUtils } from '../utils/LogUtils'
import { FilterOptions } from '../model/FilterOptions'
import { SearchFilterOptions } from '../model/SearchFilterOptions'
import { CategoryStat, MonthStat, DaySummary } from '../model/StatResult'
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

  async queryBySearchFilter(filter: SearchFilterOptions): Promise<Bill[]> {
    try {
      const store = this.getStore()
      const predicates = new relationalStore.RdbPredicates('bills')

      if (filter.type !== 'all') {
        predicates.equalTo('type', filter.type)
      }
      if (filter.category && filter.category.length > 0) {
        predicates.equalTo('category', filter.category)
      }
      if (filter.startDate && filter.startDate.length > 0) {
        predicates.greaterThanOrEqualTo('date', filter.startDate)
      }
      if (filter.endDate && filter.endDate.length > 0) {
        predicates.lessThanOrEqualTo('date', filter.endDate)
      }

      predicates.orderByDesc('date')
      predicates.orderByDesc('createdAt')

      const resultSet = await store.query(predicates, ['id', 'amount', 'type', 'category', 'remark', 'date', 'createdAt'])
      const bills: Bill[] = []

      while (resultSet.goToNextRow()) {
        bills.push({
          id: resultSet.getLong(resultSet.getColumnIndex('id')),
          amount: resultSet.getLong(resultSet.getColumnIndex('amount')),
          type: resultSet.getString(resultSet.getColumnIndex('type')) as 'income' | 'expense',
          category: resultSet.getString(resultSet.getColumnIndex('category')),
          remark: resultSet.getString(resultSet.getColumnIndex('remark')),
          date: resultSet.getString(resultSet.getColumnIndex('date')),
          createdAt: resultSet.getLong(resultSet.getColumnIndex('createdAt'))
        })
      }
      resultSet.close()
      return bills
    } catch (err) {
      LogUtils.error('BillDao', 'queryBySearchFilter failed: %{public}s', JSON.stringify(err))
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
          const val = incomeResult.getLong(incomeResult.getColumnIndex('total'))
          income = isNaN(val) ? 0 : val
        }
        incomeResult.close()

        const expenseResult = await store.querySql(expenseSql)
        let expense = 0
        if (expenseResult.goToNextRow()) {
          const val = expenseResult.getLong(expenseResult.getColumnIndex('total'))
          expense = isNaN(val) ? 0 : val
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

  /**
   * 查询指定月份每天的收支汇总（日历视图用）
   */
  async queryDailySummary(month: string): Promise<DaySummary[]> {
    try {
      const store = this.getStore()
      const sql = `SELECT date, ` +
        `SUM(CASE WHEN type='income' THEN amount ELSE 0 END) as income, ` +
        `SUM(CASE WHEN type='expense' THEN amount ELSE 0 END) as expense ` +
        `FROM bills WHERE date LIKE '${month}%' GROUP BY date ORDER BY date ASC`
      const resultSet = await store.querySql(sql)
      const result: DaySummary[] = []
      while (resultSet.goToNextRow()) {
        const inc = resultSet.getLong(resultSet.getColumnIndex('income'))
        const exp = resultSet.getLong(resultSet.getColumnIndex('expense'))
        result.push({
          date: resultSet.getString(resultSet.getColumnIndex('date')),
          income: isNaN(inc) ? 0 : inc,
          expense: isNaN(exp) ? 0 : exp
        })
      }
      resultSet.close()
      return result
    } catch (err) {
      LogUtils.error('BillDao', 'queryDailySummary failed: %{public}s', JSON.stringify(err))
      return []
    }
  }
}
