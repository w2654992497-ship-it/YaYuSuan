import { relationalStore } from '@kit.ArkData'
import { Bill } from '../model/Bill'
import { LogUtils } from '../utils/LogUtils'
import { FilterOptions } from '../model/FilterOptions'
import { SearchFilterOptions } from '../model/SearchFilterOptions'
import { CategoryStat, MonthStat, DaySummary } from '../model/StatResult'
import { DBHelper } from './DBHelper'
import { AccountBookDao } from './AccountBookDao'
import { PaymentAccountDao } from './PaymentAccountDao'
import { getCategoryColor } from '../model/Category'
import { DateUtil } from '../utils/DateUtil'

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

  private normalizeBillDate(dateText: string, createdAt: number): string {
    if (dateText.length > 0) {
      return dateText
    }
    if (createdAt > 0) {
      return DateUtil.format(new Date(createdAt))
    }
    return DateUtil.today()
  }

  async insert(bill: Bill): Promise<number> {
    try {
      const store = this.getStore()
      const paymentAccountId = bill.paymentAccountId === undefined ? 0 : bill.paymentAccountId
      let paymentAccountName = bill.paymentAccountName === undefined ? '' : bill.paymentAccountName
      if (paymentAccountName.length <= 0 && paymentAccountId > 0) {
        const account = await PaymentAccountDao.getInstance().queryById(paymentAccountId)
        if (account !== null) {
          paymentAccountName = account.name
        }
      }
      const createdAt = bill.createdAt > 0 ? bill.createdAt : Date.now()
      const dateText = this.normalizeBillDate(bill.date, createdAt)
      const valueBucket: relationalStore.ValuesBucket = {
        userId: this.getCurrentUserId(),
        bookId: this.getCurrentBookId(),
        amount: bill.amount,
        type: bill.type,
        category: bill.category,
        categoryId: bill.categoryId,
        paymentAccountId: paymentAccountId,
        paymentAccountName: paymentAccountName,
        remark: bill.remark,
        date: dateText,
        createdAt: createdAt
      }
      const rowId = await store.insert('bills', valueBucket)
      await PaymentAccountDao.getInstance().applyBillBalanceChange(paymentAccountId, bill.type, bill.amount, false)
      LogUtils.info('BillDao', 'Inserted bill rowId=%{public}s', String(rowId))
      return rowId
    } catch (err) {
      LogUtils.error('BillDao', 'insert failed: %{public}s', JSON.stringify(err))
      throw new Error(String(err))
    }
  }

  async deleteById(id: number): Promise<void> {
    try {
      const deletedBill = await this.queryById(id)
      const store = this.getStore()
      const predicates = new relationalStore.RdbPredicates('bills')
      predicates.equalTo('id', id)
      predicates.equalTo('userId', this.getCurrentUserId())
      predicates.equalTo('bookId', this.getCurrentBookId())
      await store.delete(predicates)
      if (deletedBill !== null) {
        const paymentAccountId = deletedBill.paymentAccountId === undefined ? 0 : deletedBill.paymentAccountId
        await PaymentAccountDao.getInstance().applyBillBalanceChange(paymentAccountId, deletedBill.type, deletedBill.amount, true)
      }
      LogUtils.info('BillDao', 'Deleted bill id=%{public}s', String(id))
    } catch (err) {
      LogUtils.error('BillDao', 'deleteById failed: %{public}s', JSON.stringify(err))
      throw new Error(String(err))
    }
  }

  async update(bill: Bill): Promise<void> {
    try {
      const oldBill = await this.queryById(bill.id)
      if (oldBill === null) {
        throw new Error('账单不存在，无法更新')
      }
      const store = this.getStore()
      const paymentAccountId = bill.paymentAccountId === undefined ? 0 : bill.paymentAccountId
      let paymentAccountName = bill.paymentAccountName === undefined ? '' : bill.paymentAccountName
      if (paymentAccountName.length <= 0 && paymentAccountId > 0) {
        const account = await PaymentAccountDao.getInstance().queryById(paymentAccountId)
        if (account !== null) {
          paymentAccountName = account.name
        }
      }
      const createdAt = bill.createdAt > 0 ? bill.createdAt : Date.now()
      const dateText = this.normalizeBillDate(bill.date, createdAt)
      const valueBucket: relationalStore.ValuesBucket = {
        amount: bill.amount,
        type: bill.type,
        category: bill.category,
        categoryId: bill.categoryId,
        paymentAccountId: paymentAccountId,
        paymentAccountName: paymentAccountName,
        remark: bill.remark,
        date: dateText,
        createdAt: createdAt
      }
      const predicates = new relationalStore.RdbPredicates('bills')
      predicates.equalTo('id', bill.id)
      predicates.equalTo('userId', this.getCurrentUserId())
      predicates.equalTo('bookId', this.getCurrentBookId())
      await store.update(valueBucket, predicates)

      const oldPaymentAccountId = oldBill.paymentAccountId === undefined ? 0 : oldBill.paymentAccountId
      await PaymentAccountDao.getInstance().applyBillBalanceChange(oldPaymentAccountId, oldBill.type, oldBill.amount, true)
      await PaymentAccountDao.getInstance().applyBillBalanceChange(paymentAccountId, bill.type, bill.amount, false)
      LogUtils.info('BillDao', 'Updated bill id=%{public}s oldAccount=%{public}s newAccount=%{public}s',
        bill.id.toString(), oldPaymentAccountId.toString(), paymentAccountId.toString())
    } catch (err) {
      LogUtils.error('BillDao', 'update failed: %{public}s', JSON.stringify(err))
      throw new Error(String(err))
    }
  }

  async queryById(id: number): Promise<Bill | null> {
    try {
      const store = this.getStore()
      const predicates = new relationalStore.RdbPredicates('bills')
      predicates.equalTo('id', id)
      predicates.equalTo('userId', this.getCurrentUserId())
      predicates.equalTo('bookId', this.getCurrentBookId())
      const resultSet = await store.query(predicates, ['id', 'amount', 'type', 'category', 'categoryId', 'paymentAccountId', 'paymentAccountName', 'remark', 'date', 'createdAt'])
      let bill: Bill | null = null
      if (resultSet.goToNextRow()) {
        const createdAt = resultSet.getLong(resultSet.getColumnIndex('createdAt'))
        const dateText = this.normalizeBillDate(resultSet.getString(resultSet.getColumnIndex('date')), createdAt)
        bill = {
          id: resultSet.getLong(resultSet.getColumnIndex('id')),
          amount: resultSet.getLong(resultSet.getColumnIndex('amount')),
          type: resultSet.getString(resultSet.getColumnIndex('type')) as 'income' | 'expense',
          category: resultSet.getString(resultSet.getColumnIndex('category')),
          categoryId: resultSet.getLong(resultSet.getColumnIndex('categoryId')),
          paymentAccountId: resultSet.getLong(resultSet.getColumnIndex('paymentAccountId')),
          paymentAccountName: resultSet.getString(resultSet.getColumnIndex('paymentAccountName')),
          remark: resultSet.getString(resultSet.getColumnIndex('remark')),
          date: dateText,
          createdAt: createdAt
        }
      }
      resultSet.close()
      return bill
    } catch (err) {
      LogUtils.error('BillDao', 'queryById failed: %{public}s', JSON.stringify(err))
      return null
    }
  }

  async queryByFilter(filter: FilterOptions): Promise<Bill[]> {
    try {
      const store = this.getStore()
      const predicates = new relationalStore.RdbPredicates('bills')
      predicates.equalTo('userId', this.getCurrentUserId())
      predicates.equalTo('bookId', this.getCurrentBookId())

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

      const resultSet = await store.query(predicates, ['id', 'amount', 'type', 'category', 'categoryId', 'paymentAccountId', 'paymentAccountName', 'remark', 'date', 'createdAt'])
      const bills: Bill[] = []

      while (resultSet.goToNextRow()) {
        const createdAt = resultSet.getLong(resultSet.getColumnIndex('createdAt'))
        const dateText = this.normalizeBillDate(resultSet.getString(resultSet.getColumnIndex('date')), createdAt)
        const bill: Bill = {
          id: resultSet.getLong(resultSet.getColumnIndex('id')),
          amount: resultSet.getLong(resultSet.getColumnIndex('amount')),
          type: resultSet.getString(resultSet.getColumnIndex('type')) as 'income' | 'expense',
          category: resultSet.getString(resultSet.getColumnIndex('category')),
          categoryId: resultSet.getLong(resultSet.getColumnIndex('categoryId')),
          paymentAccountId: resultSet.getLong(resultSet.getColumnIndex('paymentAccountId')),
          paymentAccountName: resultSet.getString(resultSet.getColumnIndex('paymentAccountName')),
          remark: resultSet.getString(resultSet.getColumnIndex('remark')),
          date: dateText,
          createdAt: createdAt
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
      predicates.equalTo('userId', this.getCurrentUserId())
      predicates.equalTo('bookId', this.getCurrentBookId())

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

      const resultSet = await store.query(predicates, ['id', 'amount', 'type', 'category', 'categoryId', 'paymentAccountId', 'paymentAccountName', 'remark', 'date', 'createdAt'])
      const bills: Bill[] = []

      while (resultSet.goToNextRow()) {
        const createdAt = resultSet.getLong(resultSet.getColumnIndex('createdAt'))
        const dateText = this.normalizeBillDate(resultSet.getString(resultSet.getColumnIndex('date')), createdAt)
        bills.push({
          id: resultSet.getLong(resultSet.getColumnIndex('id')),
          amount: resultSet.getLong(resultSet.getColumnIndex('amount')),
          type: resultSet.getString(resultSet.getColumnIndex('type')) as 'income' | 'expense',
          category: resultSet.getString(resultSet.getColumnIndex('category')),
          categoryId: resultSet.getLong(resultSet.getColumnIndex('categoryId')),
          paymentAccountId: resultSet.getLong(resultSet.getColumnIndex('paymentAccountId')),
          paymentAccountName: resultSet.getString(resultSet.getColumnIndex('paymentAccountName')),
          remark: resultSet.getString(resultSet.getColumnIndex('remark')),
          date: dateText,
          createdAt: createdAt
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
      let whereClause = `userId = ${this.getCurrentUserId()} AND bookId = ${this.getCurrentBookId()} AND type = '${type}'`
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
        const userId = this.getCurrentUserId()
        const bookId = this.getCurrentBookId()
        const incomeSql = `SELECT SUM(amount) as total FROM bills WHERE userId = ${userId} AND bookId = ${bookId} AND type = 'income' AND date LIKE '${month}%'`
        const expenseSql = `SELECT SUM(amount) as total FROM bills WHERE userId = ${userId} AND bookId = ${bookId} AND type = 'expense' AND date LIKE '${month}%'`

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
      const userId = this.getCurrentUserId()
      const bookId = this.getCurrentBookId()
      const sql = `SELECT date, ` +
        `SUM(CASE WHEN type='income' THEN amount ELSE 0 END) as income, ` +
        `SUM(CASE WHEN type='expense' THEN amount ELSE 0 END) as expense ` +
        `FROM bills WHERE userId = ${userId} AND bookId = ${bookId} AND date LIKE '${month}%' GROUP BY date ORDER BY date ASC`
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
