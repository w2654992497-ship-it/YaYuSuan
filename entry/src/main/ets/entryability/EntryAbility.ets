import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit'
import { window, display } from '@kit.ArkUI'
import { request } from '@kit.BasicServicesKit'
import { cloudCommon } from '@kit.CloudFoundationKit'
import { DBHelper } from '../database/DBHelper'
import { CategoryDao } from '../database/CategoryDao'
import { PeriodRuleDao } from '../database/PeriodRuleDao'
import { CloudCacheService } from '../services/CloudCacheService'
import { LogUtils } from '../utils/LogUtils'

export default class EntryAbility extends UIAbility {
  private dbReadyPromise: Promise<void> | null = null

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET)
    } catch (err) {
      LogUtils.error('EntryAbility', 'setColorMode failed: %{public}s', JSON.stringify(err))
    }
    LogUtils.info('EntryAbility', 'onCreate')
    this.initCloudStorage()
    this.dbReadyPromise = this.initDatabase()
  }

  private initCloudStorage(): void {
    try {
      cloudCommon.init({
        storageOptions: {
          mode: request.agent.Mode.BACKGROUND,
          network: request.agent.Network.ANY
        }
      })
      LogUtils.info('EntryAbility', 'Cloud storage initialized')
    } catch (err) {
      LogUtils.error('EntryAbility', 'Cloud storage init failed: %{public}s', JSON.stringify(err))
    }
  }

  private async initDatabase(): Promise<void> {
    try {
      await DBHelper.getInstance().init(this.context)
      await CategoryDao.getInstance().refreshCache()
      await PeriodRuleDao.getInstance().generateDueBills()
      CloudCacheService.getInstance().syncLocalCacheAtNight(this.context)
      LogUtils.info('EntryAbility', 'Database and category cache initialized')
    } catch (err) {
      LogUtils.error('EntryAbility', 'Database init failed: %{public}s', JSON.stringify(err))
      throw new Error(JSON.stringify(err))
    }
  }

  onDestroy(): void {
    LogUtils.info('EntryAbility', 'onDestroy')
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    LogUtils.info('EntryAbility', 'onWindowStageCreate')
    this.prepareWindowAndLoadContent(windowStage)
  }

  private async prepareWindowAndLoadContent(windowStage: window.WindowStage): Promise<void> {
    try {
      const mainWindow = await windowStage.getMainWindow()

      // 沉浸式：布局延伸到系统栏区域。
      await mainWindow.setWindowLayoutFullScreen(true)

      await mainWindow.setWindowSystemBarProperties({
        statusBarColor: '#00000000',
        statusBarContentColor: '#000000',
        navigationBarColor: '#00000000',
        navigationBarContentColor: '#000000'
      })

      const density = display.getDefaultDisplaySync().densityPixels
      const systemAvoid = mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM)
      const navAvoid = mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR)
      const sbVp = systemAvoid.topRect.height / density
      const nbVp = Math.max(systemAvoid.bottomRect.height, navAvoid.bottomRect.height) / density
      AppStorage.setOrCreate('statusBarHeight', sbVp)
      AppStorage.setOrCreate('navBarHeight', nbVp)
      AppStorage.setOrCreate('mainWindow', mainWindow)
      AppStorage.setOrCreate('showCategoryEditor', false)
      AppStorage.setOrCreate('settingsPageState', 'main')
      AppStorage.setOrCreate('settingsBackSignal', 0)
      AppStorage.setOrCreate('editCategorySelected', '')
      AppStorage.setOrCreate('editCategoryType', 'expense')
      AppStorage.setOrCreate('categoryVersion', 0)
      AppStorage.setOrCreate('isLoggedIn', false)
      AppStorage.setOrCreate('currentUserId', 0)
      AppStorage.setOrCreate('currentUserName', '')
      AppStorage.setOrCreate('currentUsername', '')

      LogUtils.info('EntryAbility',
        'safeArea statusBar=%{public}s navBar=%{public}s vp',
        sbVp.toFixed(1), nbVp.toFixed(1)
      )

      if (this.dbReadyPromise) {
        LogUtils.info('EntryAbility', '等待数据库初始化完成后加载首页')
        await this.dbReadyPromise
      }

      windowStage.loadContent('pages/Index', (err) => {
        if (err.code) {
          LogUtils.error('EntryAbility', 'loadContent failed: %{public}s', JSON.stringify(err))
          return
        }
        LogUtils.info('EntryAbility', '首页加载完成')
      })
    } catch (err) {
      LogUtils.error('EntryAbility', 'window setup or loadContent failed: %{public}s', JSON.stringify(err))
    }
  }

  onWindowStageDestroy(): void {
    LogUtils.info('EntryAbility', 'onWindowStageDestroy')
  }

  onForeground(): void {
    LogUtils.debug('EntryAbility', 'onForeground')
  }

  onBackground(): void {
    LogUtils.debug('EntryAbility', 'onBackground')
  }
}
