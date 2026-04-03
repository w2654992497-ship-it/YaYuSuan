import { relationalStore } from '@kit.ArkData'
import { common } from '@kit.AbilityKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { EXPENSE_CATEGORIES, INCOME_CATEGORIES, CategoryInfo } from '../model/Category'

const DOMAIN = 0x0000
const TAG = 'DBHelper'

const DB_CONFIG: relationalStore.StoreConfig = {
  name: 'yayusuan.db',
  securityLevel: relationalStore.SecurityLevel.S1
}

const CREATE_BILLS_SQL = `CREATE TABLE IF NOT EXISTS bills (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  amount INTEGER NOT NULL,
  type TEXT NOT NULL,
  category TEXT NOT NULL,
  remark TEXT DEFAULT '',
  date TEXT NOT NULL,
  createdAt INTEGER NOT NULL
)`

const CREATE_CATEGORIES_SQL = `CREATE TABLE IF NOT EXISTS categories (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  icon TEXT NOT NULL,
  color TEXT NOT NULL,
  type TEXT NOT NULL,
  sort_order INTEGER NOT NULL DEFAULT 0,
  is_default INTEGER NOT NULL DEFAULT 0
)`

export class DBHelper {
  private static instance: DBHelper | null = null
  private rdbStore: relationalStore.RdbStore | null = null

  private constructor() {}

  static getInstance(): DBHelper {
    if (!DBHelper.instance) {
      DBHelper.instance = new DBHelper()
    }
    return DBHelper.instance
  }

  async init(context: common.UIAbilityContext): Promise<void> {
    try {
      const store = await relationalStore.getRdbStore(context, DB_CONFIG)
      await store.executeSql(CREATE_BILLS_SQL)
      await store.executeSql(CREATE_CATEGORIES_SQL)
      this.rdbStore = store

      // 首次运行种子默认分类
      await this.seedDefaultCategories(store)

      hilog.info(DOMAIN, TAG, 'Database initialized successfully')
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Failed to initialize database: %{public}s', JSON.stringify(err))
      throw new Error(String(err))
    }
  }

  private async seedDefaultCategories(store: relationalStore.RdbStore): Promise<void> {
    try {
      const countResult = await store.querySql('SELECT COUNT(*) as cnt FROM categories')
      let count = 0
      if (countResult.goToNextRow()) {
        count = countResult.getLong(countResult.getColumnIndex('cnt'))
      }
      countResult.close()

      if (count > 0) return

      for (let i = 0; i < EXPENSE_CATEGORIES.length; i++) {
        await this.insertCategory(store, EXPENSE_CATEGORIES[i], 'expense', i, 1)
      }
      for (let i = 0; i < INCOME_CATEGORIES.length; i++) {
        await this.insertCategory(store, INCOME_CATEGORIES[i], 'income', i, 1)
      }
      hilog.info(DOMAIN, TAG, 'Default categories seeded')
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'seedDefaultCategories failed: %{public}s', JSON.stringify(err))
    }
  }

  private async insertCategory(
    store: relationalStore.RdbStore,
    cat: CategoryInfo,
    type: string,
    sortOrder: number,
    isDefault: number
  ): Promise<void> {
    try {
      const bucket: relationalStore.ValuesBucket = {
        name: cat.name,
        icon: cat.icon,
        color: cat.color,
        type: type,
        sort_order: sortOrder,
        is_default: isDefault
      }
      await store.insert('categories', bucket)
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'insertCategory failed: %{public}s', JSON.stringify(err))
    }
  }

  getStore(): relationalStore.RdbStore {
    if (!this.rdbStore) {
      throw new Error('Database not initialized. Call init() first.')
    }
    return this.rdbStore
  }
}
