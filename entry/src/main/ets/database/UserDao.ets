import { preferences, relationalStore } from '@kit.ArkData'
import { common } from '@kit.AbilityKit'
import { UserSession } from '../model/User'
import { CloudDatabaseService } from '../services/CloudDatabaseService'
import { LogUtils } from '../utils/LogUtils'
import { DBHelper } from './DBHelper'
import { CategoryDao } from './CategoryDao'
import { AccountBookDao } from './AccountBookDao'

const USER_TAG = 'UserDao'
const USER_PREF_NAME = 'yayusuan_user_session'
const CURRENT_USER_ID = 'current_user_id'
const CURRENT_USERNAME = 'current_username'
const CURRENT_DISPLAY_NAME = 'current_display_name'

interface CloudRuntimeError {
  code?: number
  message?: string
  name?: string
}

export class UserDao {
  private static instance: UserDao | null = null

  private constructor() {}

  static getInstance(): UserDao {
    if (!UserDao.instance) {
      UserDao.instance = new UserDao()
    }
    return UserDao.instance
  }

  async createLocalUser(context: common.BaseContext, username: string, displayName: string): Promise<UserSession> {
    const cleanUsername = this.normalizeUsername(username)
    const cleanDisplayName = displayName.trim().length > 0 ? displayName.trim() : cleanUsername
    LogUtils.error(USER_TAG, '创建本地用户开始 username=%{public}s displayName=%{public}s', cleanUsername, cleanDisplayName)
    const session = await this.ensureLocalUser(context, cleanUsername, cleanDisplayName)
    await this.saveCurrentUser(context, session)
    await AccountBookDao.getInstance().ensureDefaultBookForUser(session.id, session.displayName)
    await DBHelper.getInstance().ensureDefaultCategoriesForUser(session.id)
    await CategoryDao.getInstance().refreshCache()
    LogUtils.error(USER_TAG, '创建本地用户成功 userLocalId=%{public}s username=%{public}s', session.id.toString(), session.username)
    return session
  }

  async register(context: common.BaseContext, username: string, displayName: string, password: string): Promise<UserSession> {
    const cleanUsername = this.normalizeUsername(username)
    const cleanDisplayName = displayName.trim().length > 0 ? displayName.trim() : cleanUsername
    LogUtils.error(USER_TAG,
      '云端账号注册开始 username=%{public}s displayName=%{public}s passwordLength=%{public}s',
      cleanUsername, cleanDisplayName, password.length.toString())

    try {
      if (cleanUsername.length < 3) {
        throw new Error('账号至少需要 3 个字符')
      }
      if (password.length < 6) {
        throw new Error('密码至少需要 6 位')
      }

      let localSession = await this.getCurrentUser(context)
      if (!localSession) {
        localSession = await this.ensureLocalUser(context, cleanUsername, cleanDisplayName)
      }
      await AccountBookDao.getInstance().ensureDefaultBookForUser(localSession.id, localSession.displayName)
      await DBHelper.getInstance().ensureDefaultCategoriesForUser(localSession.id)
      await CategoryDao.getInstance().refreshCache()

      const salt = Date.now().toString()
      const passwordHash = this.hashPassword(password, salt)
      LogUtils.error(USER_TAG, '云端账号注册准备获取云数据库服务 username=%{public}s localUserId=%{public}s',
        cleanUsername, localSession.id.toString())
      const cloudDbService = CloudDatabaseService.getInstance()
      const user = await cloudDbService.createUserAccountForLocalUser(
        localSession.id,
        cleanUsername,
        cleanDisplayName,
        passwordHash,
        salt
      )
      const session: UserSession = {
        id: user.localId,
        username: user.username,
        displayName: user.displayName
      }
      await this.saveCurrentUser(context, session)
      LogUtils.error(USER_TAG, '云端账号注册成功，准备上传本地数据 userLocalId=%{public}s username=%{public}s',
        session.id.toString(), session.username)
      await cloudDbService.syncAndCheckLocalData(session.id, session.username, session.displayName)
      LogUtils.error(USER_TAG, '云端账号注册并上传本地数据完成 userLocalId=%{public}s username=%{public}s',
        session.id.toString(), session.username)
      return session
    } catch (err) {
      const errorText = this.formatError(err)
      LogUtils.error(USER_TAG, '云端账号注册失败 username=%{public}s error=%{public}s', cleanUsername, errorText)
      throw new Error(errorText)
    }
  }

  async login(context: common.BaseContext, username: string, password: string): Promise<UserSession> {
    const cleanUsername = this.normalizeUsername(username)
    LogUtils.error(USER_TAG, '云端账号登录开始 username=%{public}s passwordLength=%{public}s',
      cleanUsername, password.length.toString())

    try {
      const cloudDbService = CloudDatabaseService.getInstance()
      LogUtils.error(USER_TAG, '云端账号登录准备查询云端用户 username=%{public}s', cleanUsername)
      const user = await cloudDbService.queryUserByUsername(cleanUsername)
      LogUtils.error(USER_TAG, '云端账号登录云端用户查询返回 username=%{public}s exists=%{public}s',
        cleanUsername, (user !== null).toString())
      if (!user) {
        throw new Error('账号或密码不正确')
      }

      const salt = this.safeString(user.salt)
      const cloudPasswordHash = this.safeString(user.passwordHash)
      LogUtils.error(USER_TAG,
        '云端账号登录密码字段检查 username=%{public}s hasSalt=%{public}s hasPasswordHash=%{public}s',
        cleanUsername, (salt.length > 0).toString(), (cloudPasswordHash.length > 0).toString())
      if (salt.length === 0 || cloudPasswordHash.length === 0) {
        throw new Error('云端账号缺少密码信息，请重新注册账号或在平台补充 passwordHash/salt')
      }

      const passwordHash = this.hashPassword(password, salt)
      if (passwordHash !== cloudPasswordHash) {
        throw new Error('账号或密码不正确')
      }

      await cloudDbService.updateUserLoginTime(user)
      const session: UserSession = {
        id: user.localId,
        username: user.username,
        displayName: user.displayName
      }
      await this.ensureLocalUserBySession(session)
      await AccountBookDao.getInstance().ensureDefaultBookForUser(session.id, session.displayName)
      await DBHelper.getInstance().ensureDefaultCategoriesForUser(session.id)
      await this.saveCurrentUser(context, session)
      const restoreResult = await cloudDbService.restoreCloudDataToLocal(session.id, session.username, session.displayName)
      const appDataVersion = AppStorage.get<number>('appDataVersion')
      AppStorage.setOrCreate<number>('appDataVersion', appDataVersion !== undefined ? appDataVersion + 1 : 1)
      LogUtils.error(USER_TAG,
        '云端账号登录后恢复数据完成 userLocalId=%{public}s username=%{public}s bundle=%{public}s bill=%{public}s category=%{public}s periodRule=%{public}s budget=%{public}s',
        session.id.toString(), session.username, restoreResult.bundleCount.toString(), restoreResult.billCount.toString(),
        restoreResult.categoryCount.toString(), restoreResult.periodRuleCount.toString(), restoreResult.budgetCount.toString())
      await CategoryDao.getInstance().refreshCache()
      LogUtils.error(USER_TAG, '云端账号登录成功 userLocalId=%{public}s username=%{public}s',
        session.id.toString(), session.username)
      return session
    } catch (err) {
      const errorText = this.formatError(err)
      LogUtils.error(USER_TAG, '云端账号登录失败 username=%{public}s error=%{public}s', cleanUsername, errorText)
      throw new Error(errorText)
    }
  }

  async getCurrentUser(context: common.BaseContext): Promise<UserSession | null> {
    try {
      const pref = await preferences.getPreferences(context, { name: USER_PREF_NAME })
      const userId = await pref.get(CURRENT_USER_ID, 0) as number
      const username = await pref.get(CURRENT_USERNAME, '') as string
      const displayName = await pref.get(CURRENT_DISPLAY_NAME, '') as string
      if (userId <= 0 || username.length === 0) {
        return null
      }
      return {
        id: userId,
        username: username,
        displayName: displayName.length > 0 ? displayName : username
      }
    } catch (err) {
      LogUtils.error(USER_TAG, '读取当前用户会话失败：%{public}s', this.formatError(err))
      return null
    }
  }

  async logout(context: common.BaseContext): Promise<void> {
    const pref = await preferences.getPreferences(context, { name: USER_PREF_NAME })
    await pref.put(CURRENT_USER_ID, 0)
    await pref.put(CURRENT_USERNAME, '')
    await pref.put(CURRENT_DISPLAY_NAME, '')
    await pref.flush()
    AppStorage.setOrCreate<boolean>('isLoggedIn', false)
    AppStorage.setOrCreate<number>('currentUserId', 0)
    AppStorage.setOrCreate<string>('currentUserName', '')
    AppStorage.setOrCreate<string>('currentUsername', '')
    AppStorage.setOrCreate<number>('currentBookId', 0)
    AppStorage.setOrCreate<string>('currentBookCloudId', '')
    AppStorage.setOrCreate<string>('currentBookName', '')
  }

  async isCloudRegistered(context: common.BaseContext): Promise<boolean> {
    const session = await this.getCurrentUser(context)
    if (!session) {
      return false
    }
    try {
      const user = await CloudDatabaseService.getInstance().queryUserByUsername(session.username)
      if (!user) {
        return false
      }
      const salt = this.safeString(user.salt)
      const passwordHash = this.safeString(user.passwordHash)
      return user.localId === session.id && salt.length > 0 && passwordHash.length > 0
    } catch (err) {
      LogUtils.error(USER_TAG, '检查云账号注册状态失败 username=%{public}s error=%{public}s',
        session.username, this.formatError(err))
      return false
    }
  }

  private async ensureLocalUser(context: common.BaseContext, username: string, displayName: string): Promise<UserSession> {
    if (username.length < 1) {
      throw new Error('请先输入用户名')
    }
    const exists = await this.queryLocalUserByUsername(username)
    if (exists) {
      await this.updateLocalLoginTime(exists.id)
      return {
        id: exists.id,
        username: exists.username,
        displayName: exists.displayName.length > 0 ? exists.displayName : exists.username
      }
    }

    const store = DBHelper.getInstance().getStore()
    const now = Date.now()
    const bucket: relationalStore.ValuesBucket = {
      username: username,
      displayName: displayName,
      passwordHash: '',
      salt: '',
      createdAt: now,
      lastLoginAt: now
    }
    const rowId = await store.insert('users', bucket)
    const session: UserSession = {
      id: rowId,
      username: username,
      displayName: displayName
    }
    await this.saveCurrentUser(context, session)
    return session
  }

  private async ensureLocalUserBySession(session: UserSession): Promise<void> {
    const exists = await this.queryLocalUserById(session.id)
    if (exists) {
      await this.updateLocalLoginTime(session.id)
      return
    }
    try {
      const store = DBHelper.getInstance().getStore()
      const now = Date.now()
      const bucket: relationalStore.ValuesBucket = {
        id: session.id,
        username: session.username,
        displayName: session.displayName,
        passwordHash: '',
        salt: '',
        createdAt: now,
        lastLoginAt: now
      }
      await store.insert('users', bucket)
      LogUtils.error(USER_TAG, '已根据云端账号补齐本地用户 userLocalId=%{public}s username=%{public}s',
        session.id.toString(), session.username)
    } catch (err) {
      LogUtils.error(USER_TAG, '补齐本地用户失败 userLocalId=%{public}s error=%{public}s',
        session.id.toString(), this.formatError(err))
    }
  }

  private async queryLocalUserByUsername(username: string): Promise<UserSession | null> {
    const store = DBHelper.getInstance().getStore()
    const predicates = new relationalStore.RdbPredicates('users')
    predicates.equalTo('username', username)
    const rs = await store.query(predicates, ['id', 'username', 'displayName'])
    let session: UserSession | null = null
    if (rs.goToNextRow()) {
      session = {
        id: rs.getLong(rs.getColumnIndex('id')),
        username: rs.getString(rs.getColumnIndex('username')),
        displayName: rs.getString(rs.getColumnIndex('displayName'))
      }
    }
    rs.close()
    return session
  }

  private async queryLocalUserById(userId: number): Promise<UserSession | null> {
    const store = DBHelper.getInstance().getStore()
    const predicates = new relationalStore.RdbPredicates('users')
    predicates.equalTo('id', userId)
    const rs = await store.query(predicates, ['id', 'username', 'displayName'])
    let session: UserSession | null = null
    if (rs.goToNextRow()) {
      session = {
        id: rs.getLong(rs.getColumnIndex('id')),
        username: rs.getString(rs.getColumnIndex('username')),
        displayName: rs.getString(rs.getColumnIndex('displayName'))
      }
    }
    rs.close()
    return session
  }

  private async updateLocalLoginTime(userId: number): Promise<void> {
    const store = DBHelper.getInstance().getStore()
    const bucket: relationalStore.ValuesBucket = {
      lastLoginAt: Date.now()
    }
    const predicates = new relationalStore.RdbPredicates('users')
    predicates.equalTo('id', userId)
    await store.update(bucket, predicates)
  }

  private async saveCurrentUser(context: common.BaseContext, session: UserSession): Promise<void> {
    const pref = await preferences.getPreferences(context, { name: USER_PREF_NAME })
    await pref.put(CURRENT_USER_ID, session.id)
    await pref.put(CURRENT_USERNAME, session.username)
    await pref.put(CURRENT_DISPLAY_NAME, session.displayName)
    await pref.flush()
    AppStorage.setOrCreate<boolean>('isLoggedIn', true)
    AppStorage.setOrCreate<number>('currentUserId', session.id)
    AppStorage.setOrCreate<string>('currentUserName', session.displayName)
    AppStorage.setOrCreate<string>('currentUsername', session.username)
  }

  private normalizeUsername(username: string): string {
    return username.trim().toLowerCase()
  }

  private hashPassword(password: string, salt: string): string {
    let hash = 2166136261
    const text = salt + ':' + password
    for (let i = 0; i < text.length; i++) {
      hash = hash ^ text.charCodeAt(i)
      hash = hash * 16777619
      if (hash < 0) {
        hash = -hash
      }
      hash = hash % 4294967296
    }
    return hash.toString(16)
  }

  private safeString(value: string | null | undefined): string {
    if (value === undefined || value === null) {
      return ''
    }
    return value
  }

  private formatError(err: Error | Object): string {
    if (err instanceof Error) {
      return err.message
    }
    const cloudError = err as CloudRuntimeError
    const parts: string[] = []
    if (cloudError.code !== undefined) {
      parts.push('code=' + cloudError.code.toString())
    }
    if (cloudError.name !== undefined && cloudError.name.length > 0) {
      parts.push('name=' + cloudError.name)
    }
    if (cloudError.message !== undefined && cloudError.message.length > 0) {
      parts.push('message=' + cloudError.message)
    }
    const jsonText = JSON.stringify(err)
    if (jsonText.length > 0 && jsonText !== '{}') {
      parts.push('json=' + jsonText)
    }
    const stringText = String(err)
    if (stringText.length > 0 && stringText !== '[object Object]') {
      parts.push('text=' + stringText)
    }
    if (parts.length === 0) {
      return '未知云数据库错误：SDK 返回对象没有可解析字段'
    }
    return parts.join(', ')
  }
}
