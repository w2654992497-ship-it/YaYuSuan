import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit'
import { window, display } from '@kit.ArkUI'
import { DBHelper } from '../database/DBHelper'
import { CategoryDao } from '../database/CategoryDao'
import { LogUtils } from '../utils/LogUtils'

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET)
    } catch (err) {
      LogUtils.error('EntryAbility', 'setColorMode failed: %{public}s', JSON.stringify(err))
    }
    LogUtils.info('EntryAbility', 'onCreate')

    DBHelper.getInstance().init(this.context).then(async () => {
      await CategoryDao.getInstance().refreshCache()
      LogUtils.info('EntryAbility', 'Database and category cache initialized')
    }).catch((err: Error) => {
      LogUtils.error('EntryAbility', 'Database init failed: %{public}s', JSON.stringify(err))
    })
  }

  onDestroy(): void {
    LogUtils.info('EntryAbility', 'onDestroy')
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    LogUtils.info('EntryAbility', 'onWindowStageCreate')

    windowStage.loadContent('pages/Index', async (err) => {
      if (err.code) {
        LogUtils.error('EntryAbility', 'loadContent failed: %{public}s', JSON.stringify(err))
        return
      }
      try {
        const mainWindow = await windowStage.getMainWindow()

        // 沉浸式：布局延伸至系统栏区域
        await mainWindow.setWindowLayoutFullScreen(true)

        // 透明系统栏，初始深色图标（适配白色顶部的账单列表页）
        await mainWindow.setWindowSystemBarProperties({
          statusBarColor: '#00000000',
          statusBarContentColor: '#000000',
          navigationBarColor: '#00000000',
          navigationBarContentColor: '#000000'
        })

        // 读取安全区域高度，换算为 vp 后存入 AppStorage（组件直接使用，无需再转换）
        const density = display.getDefaultDisplaySync().densityPixels
        const systemAvoid = mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM)
        const navAvoid = mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR)
        const sbVp = systemAvoid.topRect.height / density
        const nbVp = Math.max(systemAvoid.bottomRect.height, navAvoid.bottomRect.height) / density
        AppStorage.setOrCreate('statusBarHeight', sbVp)
        AppStorage.setOrCreate('navBarHeight', nbVp)
        // 存储 window 实例，供页面动态切换状态栏图标色
        AppStorage.setOrCreate('mainWindow', mainWindow)
        AppStorage.setOrCreate('showCategoryEditor', false)
        AppStorage.setOrCreate('editCategorySelected', '')
        AppStorage.setOrCreate('editCategoryType', 'expense')
        AppStorage.setOrCreate('categoryVersion', 0)

        LogUtils.info('EntryAbility',
          'safeArea statusBar=%{public}s navBar=%{public}s vp',
          sbVp.toFixed(1), nbVp.toFixed(1)
        )
      } catch (e) {
        LogUtils.error('EntryAbility', 'immersive setup failed: %{public}s', JSON.stringify(e))
      }
    })
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
