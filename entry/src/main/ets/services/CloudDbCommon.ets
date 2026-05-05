import { cloudDatabase } from '@kit.CloudFoundationKit'
import { LogUtils } from '../utils/LogUtils'

const COMMON_CLOUD_DB_TAG = 'CloudDbCommon'

interface CloudDbRuntimeError {
  code?: number
  message?: string
  name?: string
}

export class CloudDbCommon {
  private readonly zoneName: string
  private readonly zone: cloudDatabase.DatabaseZone

  constructor(zoneName: string) {
    this.zoneName = zoneName
    LogUtils.info(COMMON_CLOUD_DB_TAG, '云数据库初始化开始 zone=%{public}s', zoneName)
    this.zone = cloudDatabase.zone(zoneName)
    LogUtils.info(COMMON_CLOUD_DB_TAG, '云数据库初始化成功 zone=%{public}s', zoneName)
  }

  async upsertOne<T extends cloudDatabase.DatabaseObject>(objectName: string, data: T): Promise<number> {
    const traceId = this.buildTraceId('upsertOne')
    const startAt = Date.now()
    LogUtils.info(COMMON_CLOUD_DB_TAG,
      '云数据库请求 trace=%{public}s zone=%{public}s action=upsertOne object=%{public}s',
      traceId, this.zoneName, objectName)
    try {
      const count = await this.zone.upsert<T>(data)
      LogUtils.info(COMMON_CLOUD_DB_TAG,
        '云数据库成功 trace=%{public}s action=upsertOne object=%{public}s count=%{public}s costMs=%{public}s',
        traceId, objectName, count.toString(), (Date.now() - startAt).toString())
      return count
    } catch (err) {
      const errorText = this.formatError(err)
      LogUtils.error(COMMON_CLOUD_DB_TAG,
        '云数据库失败 trace=%{public}s action=upsertOne object=%{public}s costMs=%{public}s error=%{public}s',
        traceId, objectName, (Date.now() - startAt).toString(), errorText)
      throw new Error(errorText)
    }
  }

  async upsertMany<T extends cloudDatabase.DatabaseObject>(objectName: string, dataList: T[]): Promise<number> {
    const traceId = this.buildTraceId('upsertMany')
    const startAt = Date.now()
    if (dataList.length === 0) {
      LogUtils.info(COMMON_CLOUD_DB_TAG,
        '云数据库跳过 trace=%{public}s action=upsertMany object=%{public}s reason=数据为空',
        traceId, objectName)
      return 0
    }
    LogUtils.info(COMMON_CLOUD_DB_TAG,
      '云数据库请求 trace=%{public}s zone=%{public}s action=upsertMany object=%{public}s requestCount=%{public}s',
      traceId, this.zoneName, objectName, dataList.length.toString())
    try {
      const count = await this.zone.upsert<T>(dataList)
      LogUtils.info(COMMON_CLOUD_DB_TAG,
        '云数据库成功 trace=%{public}s action=upsertMany object=%{public}s count=%{public}s costMs=%{public}s',
        traceId, objectName, count.toString(), (Date.now() - startAt).toString())
      return count
    } catch (err) {
      const errorText = this.formatError(err)
      LogUtils.error(COMMON_CLOUD_DB_TAG,
        '云数据库失败 trace=%{public}s action=upsertMany object=%{public}s requestCount=%{public}s costMs=%{public}s error=%{public}s',
        traceId, objectName, dataList.length.toString(), (Date.now() - startAt).toString(), errorText)
      throw new Error(errorText)
    }
  }

  async query<T extends cloudDatabase.DatabaseObject>(objectName: string,
    query: cloudDatabase.DatabaseQuery<T>): Promise<T[]> {
    const traceId = this.buildTraceId('query')
    const startAt = Date.now()
    LogUtils.info(COMMON_CLOUD_DB_TAG,
      '云数据库请求 trace=%{public}s zone=%{public}s action=query object=%{public}s',
      traceId, this.zoneName, objectName)
    try {
      const result = await this.zone.query<T>(query)
      LogUtils.info(COMMON_CLOUD_DB_TAG,
        '云数据库成功 trace=%{public}s action=query object=%{public}s count=%{public}s costMs=%{public}s',
        traceId, objectName, result.length.toString(), (Date.now() - startAt).toString())
      return result
    } catch (err) {
      const errorText = this.formatError(err)
      LogUtils.error(COMMON_CLOUD_DB_TAG,
        '云数据库失败 trace=%{public}s action=query object=%{public}s costMs=%{public}s error=%{public}s',
        traceId, objectName, (Date.now() - startAt).toString(), errorText)
      throw new Error(errorText)
    }
  }

  async deleteOne<T extends cloudDatabase.DatabaseObject>(objectName: string, data: T): Promise<number> {
    const traceId = this.buildTraceId('deleteOne')
    const startAt = Date.now()
    LogUtils.info(COMMON_CLOUD_DB_TAG,
      '云数据库请求 trace=%{public}s zone=%{public}s action=deleteOne object=%{public}s',
      traceId, this.zoneName, objectName)
    try {
      const count = await this.zone.delete<T>(data)
      LogUtils.info(COMMON_CLOUD_DB_TAG,
        '云数据库成功 trace=%{public}s action=deleteOne object=%{public}s count=%{public}s costMs=%{public}s',
        traceId, objectName, count.toString(), (Date.now() - startAt).toString())
      return count
    } catch (err) {
      const errorText = this.formatError(err)
      LogUtils.error(COMMON_CLOUD_DB_TAG,
        '云数据库失败 trace=%{public}s action=deleteOne object=%{public}s costMs=%{public}s error=%{public}s',
        traceId, objectName, (Date.now() - startAt).toString(), errorText)
      throw new Error(errorText)
    }
  }

  async deleteMany<T extends cloudDatabase.DatabaseObject>(objectName: string, dataList: T[]): Promise<number> {
    const traceId = this.buildTraceId('deleteMany')
    const startAt = Date.now()
    if (dataList.length === 0) {
      LogUtils.info(COMMON_CLOUD_DB_TAG,
        '云数据库跳过 trace=%{public}s action=deleteMany object=%{public}s reason=数据为空',
        traceId, objectName)
      return 0
    }
    LogUtils.info(COMMON_CLOUD_DB_TAG,
      '云数据库请求 trace=%{public}s zone=%{public}s action=deleteMany object=%{public}s requestCount=%{public}s',
      traceId, this.zoneName, objectName, dataList.length.toString())
    try {
      const count = await this.zone.delete<T>(dataList)
      LogUtils.info(COMMON_CLOUD_DB_TAG,
        '云数据库成功 trace=%{public}s action=deleteMany object=%{public}s count=%{public}s costMs=%{public}s',
        traceId, objectName, count.toString(), (Date.now() - startAt).toString())
      return count
    } catch (err) {
      const errorText = this.formatError(err)
      LogUtils.error(COMMON_CLOUD_DB_TAG,
        '云数据库失败 trace=%{public}s action=deleteMany object=%{public}s requestCount=%{public}s costMs=%{public}s error=%{public}s',
        traceId, objectName, dataList.length.toString(), (Date.now() - startAt).toString(), errorText)
      throw new Error(errorText)
    }
  }

  private buildTraceId(action: string): string {
    return action + '_' + Date.now().toString()
  }

  private formatError(err: Error | Object): string {
    if (err instanceof Error) {
      return err.message
    }
    const cloudError = err as CloudDbRuntimeError
    const parts: string[] = []
    if (cloudError.code !== undefined) {
      parts.push(cloudError.code.toString())
    }
    if (cloudError.message !== undefined && cloudError.message.length > 0) {
      parts.push(cloudError.message)
    }
    if (cloudError.name !== undefined && cloudError.name.length > 0) {
      parts.push(cloudError.name)
    }
    if (parts.length > 0) {
      return parts.join(':')
    }
    return JSON.stringify(err)
  }
}
