import { relationalStore } from '@kit.ArkData'
import { common } from '@kit.AbilityKit'
import { hilog } from '@kit.PerformanceAnalysisKit'

const DOMAIN = 0x0000
const TAG = 'DBHelper'

const DB_CONFIG: relationalStore.StoreConfig = {
  name: 'yayusuan.db',
  securityLevel: relationalStore.SecurityLevel.S1
}

const CREATE_TABLE_SQL = `CREATE TABLE IF NOT EXISTS bills (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  amount INTEGER NOT NULL,
  type TEXT NOT NULL,
  category TEXT NOT NULL,
  remark TEXT DEFAULT '',
  date TEXT NOT NULL,
  createdAt INTEGER NOT NULL
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
      await store.executeSql(CREATE_TABLE_SQL)
      this.rdbStore = store
      hilog.info(DOMAIN, TAG, 'Database initialized successfully')
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Failed to initialize database: %{public}s', JSON.stringify(err))
      throw new Error(String(err))
    }
  }

  getStore(): relationalStore.RdbStore {
    if (!this.rdbStore) {
      throw new Error('Database not initialized. Call init() first.')
    }
    return this.rdbStore
  }
}
