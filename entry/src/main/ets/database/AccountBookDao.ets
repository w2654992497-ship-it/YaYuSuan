import { relationalStore } from '@kit.ArkData'
import { AccountBook } from '../model/AccountBook'
import { DBHelper } from './DBHelper'
import { LogUtils } from '../utils/LogUtils'

const ACCOUNT_BOOK_TAG = 'AccountBookDao'

export class AccountBookDao {
  private static instance: AccountBookDao | null = null

  private constructor() {}

  static getInstance(): AccountBookDao {
    if (!AccountBookDao.instance) {
      AccountBookDao.instance = new AccountBookDao()
    }
    return AccountBookDao.instance
  }

  private getStore(): relationalStore.RdbStore {
    return DBHelper.getInstance().getStore()
  }

  async ensureDefaultBookForUser(userId: number, displayName: string): Promise<AccountBook> {
    const exists = await this.queryFirstBookByUser(userId)
    if (exists) {
      this.applyCurrentBook(exists)
      return exists
    }

    const now = Date.now()
    const bookCloudId = 'book_' + userId.toString() + '_default'
    const bookName = displayName.length > 0 ? displayName + '的账本' : '默认账本'
    const bucket: relationalStore.ValuesBucket = {
      cloudId: bookCloudId,
      ownerUserId: userId,
      name: bookName,
      currency: 'CNY',
      createdAt: now,
      updatedAt: now,
      deleted: 0
    }
    const rowId = await this.getStore().insert('account_books', bucket)
    const book: AccountBook = {
      id: rowId,
      cloudId: bookCloudId,
      ownerUserId: userId,
      name: bookName,
      currency: 'CNY',
      createdAt: now,
      updatedAt: now,
      deleted: 0
    }
    this.applyCurrentBook(book)
    LogUtils.info(ACCOUNT_BOOK_TAG, '已创建默认账本 userId=%{public}s bookId=%{public}s cloudId=%{public}s',
      userId.toString(), book.id.toString(), book.cloudId)
    return book
  }

  async ensureDefaultBookForCurrentUser(): Promise<AccountBook> {
    const userId = AppStorage.get<number>('currentUserId')
    const displayName = AppStorage.get<string>('currentUserName')
    if (userId !== undefined && userId > 0) {
      return await this.ensureDefaultBookForUser(userId, displayName !== undefined ? displayName : '')
    }
    return await this.ensureDefaultBookForUser(1, '默认')
  }

  async queryFirstBookByUser(userId: number): Promise<AccountBook | null> {
    const predicates = new relationalStore.RdbPredicates('account_books')
    predicates.equalTo('ownerUserId', userId)
    predicates.equalTo('deleted', 0)
    predicates.orderByAsc('id')
    predicates.limitAs(1)
    const rs = await this.getStore().query(predicates)
    let book: AccountBook | null = null
    if (rs.goToNextRow()) {
      book = this.rowToBook(rs)
    }
    rs.close()
    return book
  }

  getCurrentBookId(): number {
    const bookId = AppStorage.get<number>('currentBookId')
    if (bookId !== undefined && bookId > 0) {
      return bookId
    }
    return 1
  }

  getCurrentBookCloudId(): string {
    const bookCloudId = AppStorage.get<string>('currentBookCloudId')
    if (bookCloudId !== undefined && bookCloudId.length > 0) {
      return bookCloudId
    }
    const userId = AppStorage.get<number>('currentUserId')
    if (userId !== undefined && userId > 0) {
      return 'book_' + userId.toString() + '_default'
    }
    return 'book_1_default'
  }

  applyCurrentBook(book: AccountBook): void {
    AppStorage.setOrCreate<number>('currentBookId', book.id)
    AppStorage.setOrCreate<string>('currentBookCloudId', book.cloudId)
    AppStorage.setOrCreate<string>('currentBookName', book.name)
  }

  private rowToBook(rs: relationalStore.ResultSet): AccountBook {
    return {
      id: rs.getLong(rs.getColumnIndex('id')),
      cloudId: rs.getString(rs.getColumnIndex('cloudId')),
      ownerUserId: rs.getLong(rs.getColumnIndex('ownerUserId')),
      name: rs.getString(rs.getColumnIndex('name')),
      currency: rs.getString(rs.getColumnIndex('currency')),
      createdAt: rs.getLong(rs.getColumnIndex('createdAt')),
      updatedAt: rs.getLong(rs.getColumnIndex('updatedAt')),
      deleted: rs.getLong(rs.getColumnIndex('deleted'))
    }
  }
}
