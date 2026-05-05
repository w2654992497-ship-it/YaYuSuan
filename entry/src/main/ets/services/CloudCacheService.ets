import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { UserDao } from '../database/UserDao'
import { CloudDatabaseService, CloudDatabaseSyncResult } from './CloudDatabaseService'
import { LogUtils } from '../utils/LogUtils'

const CLOUD_CACHE_TAG = 'CloudCacheService'
const CLOUD_CACHE_PREF = 'xiaojinyu_cloud_cache'
const LAST_SYNC_DAY = 'last_sync_day'
const NIGHT_START_HOUR = 21
const NIGHT_END_HOUR = 6

export class CloudCacheService {
  private static instance: CloudCacheService | null = null

  private constructor() {}

  static getInstance(): CloudCacheService {
    if (!CloudCacheService.instance) {
      CloudCacheService.instance = new CloudCacheService()
    }
    return CloudCacheService.instance
  }

  syncLocalCacheAtNight(context: common.BaseContext): void {
    this.doSyncLocalCacheAtNight(context).catch((err: Error) => {
      LogUtils.error(CLOUD_CACHE_TAG, '夜间云端缓存同步失败：%{public}s', JSON.stringify(err))
    })
  }

  private async doSyncLocalCacheAtNight(context: common.BaseContext): Promise<void> {
    const now = new Date()
    if (!this.isNightWindow(now)) {
      LogUtils.info(CLOUD_CACHE_TAG, '当前不在夜间云端缓存窗口，跳过同步')
      return
    }

    const dayKey = this.buildDayKey(now)
    const pref = await preferences.getPreferences(context, { name: CLOUD_CACHE_PREF })
    const lastSyncDay = await pref.get(LAST_SYNC_DAY, '') as string
    if (lastSyncDay === dayKey) {
      LogUtils.info(CLOUD_CACHE_TAG, '今日已完成云端缓存同步：%{public}s', dayKey)
      return
    }

    const session = await UserDao.getInstance().getCurrentUser(context)
    if (!session) {
      LogUtils.info(CLOUD_CACHE_TAG, '未登录本地账号，跳过云端缓存同步')
      return
    }

    const cloudRegistered = await UserDao.getInstance().isCloudRegistered(context)
    if (!cloudRegistered) {
      LogUtils.info(CLOUD_CACHE_TAG, '当前本地用户尚未注册云账号，跳过夜间云端缓存同步')
      return
    }

    const result: CloudDatabaseSyncResult =
      await CloudDatabaseService.getInstance().upsertLocalData(session.id, session.username, session.displayName)
    await pref.put(LAST_SYNC_DAY, dayKey)
    await pref.flush()
    LogUtils.info(CLOUD_CACHE_TAG,
      '夜间云端缓存同步完成：user=%{public}s book=%{public}s bill=%{public}s category=%{public}s periodRule=%{public}s budget=%{public}s',
      result.userCount.toString(), result.bookCount.toString(), result.billCount.toString(),
      result.categoryCount.toString(), result.periodRuleCount.toString(), result.budgetCount.toString())
  }

  private isNightWindow(now: Date): boolean {
    const hour = now.getHours()
    return hour >= NIGHT_START_HOUR || hour < NIGHT_END_HOUR
  }

  private buildDayKey(now: Date): string {
    const year = now.getFullYear().toString()
    const month = (now.getMonth() + 1).toString().padStart(2, '0')
    const day = now.getDate().toString().padStart(2, '0')
    return year + '-' + month + '-' + day
  }
}
