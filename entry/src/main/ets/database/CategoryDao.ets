import { relationalStore } from '@kit.ArkData'
import { CategoryRecord, refreshCategoryCache } from '../model/Category'
import { LogUtils } from '../utils/LogUtils'
import { DBHelper } from './DBHelper'

export class CategoryDao {
  private static instance: CategoryDao | null = null

  private constructor() {}

  static getInstance(): CategoryDao {
    if (!CategoryDao.instance) {
      CategoryDao.instance = new CategoryDao()
    }
    return CategoryDao.instance
  }

  private getStore(): relationalStore.RdbStore {
    return DBHelper.getInstance().getStore()
  }

  private rowToRecord(rs: relationalStore.ResultSet): CategoryRecord {
    try {
      return {
        id: rs.getLong(rs.getColumnIndex('id')),
        name: rs.getString(rs.getColumnIndex('name')),
        icon: rs.getString(rs.getColumnIndex('icon')),
        color: rs.getString(rs.getColumnIndex('color')),
        type: rs.getString(rs.getColumnIndex('type')) as 'income' | 'expense',
        sort_order: rs.getLong(rs.getColumnIndex('sort_order')),
        is_default: rs.getLong(rs.getColumnIndex('is_default'))
      }
    } catch (err) {
      LogUtils.error('CategoryDao', 'rowToRecord: %{public}s', JSON.stringify(err))
      return { id: 0, name: '', icon: 'icon_other', color: '#78909C', type: 'expense', sort_order: 0, is_default: 0 }
    }
  }

  async queryByType(type: 'income' | 'expense'): Promise<CategoryRecord[]> {
    try {
      const store = this.getStore()
      const predicates = new relationalStore.RdbPredicates('categories')
      predicates.equalTo('type', type)
      predicates.orderByAsc('sort_order')
      const rs = await store.query(predicates)
      const result: CategoryRecord[] = []
      while (rs.goToNextRow()) {
        result.push(this.rowToRecord(rs))
      }
      rs.close()
      return result
    } catch (err) {
      LogUtils.error('CategoryDao', 'queryByType: %{public}s', JSON.stringify(err))
      return []
    }
  }

  async queryAll(): Promise<CategoryRecord[]> {
    try {
      const store = this.getStore()
      const predicates = new relationalStore.RdbPredicates('categories')
      predicates.orderByAsc('type')
      predicates.orderByAsc('sort_order')
      const rs = await store.query(predicates)
      const result: CategoryRecord[] = []
      while (rs.goToNextRow()) {
        result.push(this.rowToRecord(rs))
      }
      rs.close()
      return result
    } catch (err) {
      LogUtils.error('CategoryDao', 'queryAll: %{public}s', JSON.stringify(err))
      return []
    }
  }

  async queryById(id: number): Promise<CategoryRecord | null> {
    try {
      const store = this.getStore()
      const predicates = new relationalStore.RdbPredicates('categories')
      predicates.equalTo('id', id)
      const rs = await store.query(predicates)
      let record: CategoryRecord | null = null
      if (rs.goToNextRow()) {
        record = this.rowToRecord(rs)
      }
      rs.close()
      return record
    } catch (err) {
      LogUtils.error('CategoryDao', 'queryById: %{public}s', JSON.stringify(err))
      return null
    }
  }

  async queryByName(name: string, type: string): Promise<CategoryRecord | null> {
    try {
      const store = this.getStore()
      const predicates = new relationalStore.RdbPredicates('categories')
      predicates.equalTo('name', name)
      predicates.equalTo('type', type)
      const rs = await store.query(predicates)
      let record: CategoryRecord | null = null
      if (rs.goToNextRow()) {
        record = this.rowToRecord(rs)
      }
      rs.close()
      return record
    } catch (err) {
      LogUtils.error('CategoryDao', 'queryByName: %{public}s', JSON.stringify(err))
      return null
    }
  }

  async insert(cat: CategoryRecord): Promise<number> {
    try {
      const store = this.getStore()
      const bucket: relationalStore.ValuesBucket = {
        name: cat.name,
        icon: cat.icon,
        color: cat.color,
        type: cat.type,
        sort_order: cat.sort_order,
        is_default: cat.is_default
      }
      const rowId = await store.insert('categories', bucket)
      await this.refreshCache()
      return rowId
    } catch (err) {
      LogUtils.error('CategoryDao', 'insert: %{public}s', JSON.stringify(err))
      throw new Error(String(err))
    }
  }

  async update(cat: CategoryRecord, oldName?: string): Promise<void> {
    try {
      const store = this.getStore()
      const bucket: relationalStore.ValuesBucket = {
        name: cat.name,
        icon: cat.icon,
        color: cat.color,
        sort_order: cat.sort_order
      }
      const predicates = new relationalStore.RdbPredicates('categories')
      predicates.equalTo('id', cat.id)
      await store.update(bucket, predicates)

      // 分类重命名时同步更新 bills 表
      if (oldName && oldName !== cat.name) {
        await store.executeSql(
          `UPDATE bills SET category = '${cat.name}' WHERE category = '${oldName}'`
        )
      }
      await this.refreshCache()
    } catch (err) {
      LogUtils.error('CategoryDao', 'update: %{public}s', JSON.stringify(err))
      throw new Error(String(err))
    }
  }

  async deleteById(id: number): Promise<boolean> {
    try {
      const store = this.getStore()
      // 检查是否默认分类
      const cat = await this.queryById(id)
      if (!cat || cat.is_default === 1) return false

      const predicates = new relationalStore.RdbPredicates('categories')
      predicates.equalTo('id', id)
      await store.delete(predicates)
      await this.refreshCache()
      return true
    } catch (err) {
      LogUtils.error('CategoryDao', 'deleteById: %{public}s', JSON.stringify(err))
      return false
    }
  }

  async updateSortOrder(items: CategoryRecord[]): Promise<void> {
    try {
      const store = this.getStore()
      for (let i = 0; i < items.length; i++) {
        const bucket: relationalStore.ValuesBucket = { sort_order: i }
        const predicates = new relationalStore.RdbPredicates('categories')
        predicates.equalTo('id', items[i].id)
        await store.update(bucket, predicates)
      }
    } catch (err) {
      LogUtils.error('CategoryDao', 'updateSortOrder: %{public}s', JSON.stringify(err))
    }
  }

  async getMaxSortOrder(type: string): Promise<number> {
    try {
      const store = this.getStore()
      const rs = await store.querySql(`SELECT MAX(sort_order) as max_order FROM categories WHERE type = '${type}'`)
      let maxOrder = 0
      if (rs.goToNextRow()) {
        const val = rs.getLong(rs.getColumnIndex('max_order'))
        maxOrder = isNaN(val) ? 0 : val
      }
      rs.close()
      return maxOrder
    } catch (err) {
      return 0
    }
  }

  async refreshCache(): Promise<void> {
    const allCats = await this.queryAll()
    refreshCategoryCache(allCats)
  }
}
