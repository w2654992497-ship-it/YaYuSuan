import { common } from '@kit.AbilityKit'
import { BusinessError, request } from '@kit.BasicServicesKit'
import { fileIo } from '@kit.CoreFileKit'
import { cloudStorage } from '@kit.CloudFoundationKit'
import { CategoryRecord } from '../model/Category'
import { Bill } from '../model/Bill'
import { PeriodRule } from '../model/PeriodRule'
import { BudgetRule } from '../model/BudgetRule'
import { BillDao } from '../database/BillDao'
import { CategoryDao } from '../database/CategoryDao'
import { PeriodRuleDao } from '../database/PeriodRuleDao'
import { BudgetRuleDao } from '../database/BudgetRuleDao'
import { FilterOptions } from '../model/FilterOptions'
import { LogUtils } from '../utils/LogUtils'

const CLOUD_BACKUP_TAG = 'CloudBackupService'
const CLOUD_BACKUP_DIR = 'backups/'

export interface CloudBackupData {
  appName: string
  version: string
  exportedAt: string
  bills: Bill[]
  categories: CategoryRecord[]
  periodRules: PeriodRule[]
  budgetRules: BudgetRule[]
}

export interface CloudBackupResult {
  cloudPath: string
  billCount: number
  categoryCount: number
  periodRuleCount: number
  budgetCount: number
}

export interface CloudBackupListResult {
  files: string[]
  directories: string[]
  pageMarker: string
}

export class CloudBackupService {
  private static instance: CloudBackupService | null = null
  private bucket: cloudStorage.StorageBucket = cloudStorage.bucket()

  private constructor() {}

  static getInstance(): CloudBackupService {
    if (!CloudBackupService.instance) {
      CloudBackupService.instance = new CloudBackupService()
    }
    return CloudBackupService.instance
  }

  async uploadBackup(context: common.Context, userId: number): Promise<CloudBackupResult> {
    const filter: FilterOptions = { month: '', type: 'all', category: '' }
    const bills = await BillDao.getInstance().queryByFilter(filter)
    const categories = await CategoryDao.getInstance().queryAll()
    const periodRules = await PeriodRuleDao.getInstance().queryAll()
    const budgetRules = await BudgetRuleDao.getInstance().queryAll()
    const exportedAt = new Date().toISOString()
    const fileName = this.buildBackupFileName(exportedAt)
    const cloudPath = this.buildUserBackupDir(userId) + fileName
    const data: CloudBackupData = {
      appName: '小金鱼记账',
      version: '1.0.0',
      exportedAt: exportedAt,
      bills: bills,
      categories: categories,
      periodRules: periodRules,
      budgetRules: budgetRules
    }

    const localPath = await this.writeCacheFile(context, fileName, JSON.stringify(data))
    const task = await this.bucket.uploadFile(context, {
      localPath: localPath,
      cloudPath: cloudPath,
      mode: request.agent.Mode.BACKGROUND,
      network: request.agent.Network.ANY,
      metadata: {
        contentType: 'application/json',
        customMetadata: {
          appName: 'YaYuSuan',
          backupVersion: '1.0.0'
        }
      }
    })
    await this.startTask(task, 'upload', localPath)
    return {
      cloudPath: cloudPath,
      billCount: bills.length,
      categoryCount: categories.length,
      periodRuleCount: periodRules.length,
      budgetCount: budgetRules.length
    }
  }

  async listBackups(userId: number): Promise<CloudBackupListResult> {
    const result = await this.bucket.list(this.buildUserBackupDir(userId), { maxResults: 100 })
    return {
      files: result.files,
      directories: result.directories,
      pageMarker: result.pageMarker ? result.pageMarker : ''
    }
  }

  async getDownloadUrl(cloudPath: string): Promise<string> {
    return await this.bucket.getDownloadURL(cloudPath)
  }

  private buildBackupFileName(exportedAt: string): string {
    let name = exportedAt.replace(/:/g, '-')
    name = name.replace(/\./g, '-')
    return 'yayusuan-backup-' + name + '.json'
  }

  private buildUserBackupDir(userId: number): string {
    return CLOUD_BACKUP_DIR + userId.toString() + '/'
  }

  private async writeCacheFile(context: common.Context, fileName: string, content: string): Promise<string> {
    const filePath = context.cacheDir + '/' + fileName
    const file = await fileIo.open(filePath, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC)
    try {
      await fileIo.write(file.fd, content)
    } finally {
      await fileIo.close(file.fd)
    }
    return filePath
  }

  private startTask(task: request.agent.Task, action: string, localPath: string): Promise<void> {
    return new Promise<void>((resolve, reject) => {
      task.on('completed', () => {
        LogUtils.info(CLOUD_BACKUP_TAG, '云备份任务完成：%{public}s', action)
        this.removeCacheFile(localPath)
        resolve()
      })
      task.on('failed', () => {
        const message = '云备份任务失败：' + action
        LogUtils.error(CLOUD_BACKUP_TAG, '%{public}s', message)
        this.removeCacheFile(localPath)
        reject(new Error(message))
      })
      task.start((err: BusinessError) => {
        if (err) {
          LogUtils.error(CLOUD_BACKUP_TAG, '启动云备份任务失败：%{public}s', JSON.stringify(err))
          reject(new Error(err.message))
        }
      })
    })
  }

  private removeCacheFile(localPath: string): void {
    fileIo.unlink(localPath).catch((err: BusinessError) => {
      LogUtils.error(CLOUD_BACKUP_TAG, '清理云备份临时文件失败：%{public}s', JSON.stringify(err))
    })
  }
}
