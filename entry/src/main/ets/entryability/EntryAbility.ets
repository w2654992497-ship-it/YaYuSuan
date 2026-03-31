import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit'
import { window } from '@kit.ArkUI'
import { DBHelper } from '../database/DBHelper'
import { LogUtils } from '../utils/LogUtils'

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET)
    } catch (err) {
      LogUtils.error('EntryAbility', 'setColorMode failed: %{public}s', JSON.stringify(err))
    }
    LogUtils.info('EntryAbility', 'onCreate')

    DBHelper.getInstance().init(this.context).then(() => {
      LogUtils.info('EntryAbility', 'Database initialized')
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
      // 设置状态栏为亮色主题（白底黑字），与应用顶部背景一致
      try {
        const mainWindow = await windowStage.getMainWindow()
        await mainWindow.setWindowSystemBarProperties({
          statusBarColor: '#FFFFFF',
          statusBarContentColor: '#000000',
          navigationBarColor: '#FFFFFF',
          navigationBarContentColor: '#000000'
        })
      } catch (e) {
        LogUtils.error('EntryAbility', 'setSystemBarProperties failed: %{public}s', JSON.stringify(e))
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
