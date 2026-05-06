import { BillListPage } from './BillList'
import { CalendarPage } from './Calendar'
import { AddBillPage } from './AddBill'
import { StatisticsPage } from './Statistics'
import { SettingsPage } from './Settings'
import { CategoryEditor } from '../components/CategoryEditor'
import { window } from '@kit.ArkUI'
import { common } from '@kit.AbilityKit'
import { UserDao } from '../database/UserDao'
import { UserSession } from '../model/User'
import { CloudDatabaseService } from '../services/CloudDatabaseService'
import { AccountBookDao } from '../database/AccountBookDao'
import { DBHelper } from '../database/DBHelper'
import { CategoryDao } from '../database/CategoryDao'
import { LogUtils } from '../utils/LogUtils'

class BottomTabModel {
  title: string
  selectImage: ResourceStr
  defaultImage: ResourceStr
  middleMode: boolean

  constructor(title: string, selectImage: ResourceStr, defaultImage: ResourceStr, middleMode: boolean) {
    this.title = title
    this.selectImage = selectImage
    this.defaultImage = defaultImage
    this.middleMode = middleMode
  }
}

@Component
struct BottomTabItem {
  item: BottomTabModel = new BottomTabModel('', '', '', false)
  index: number = 0
  @Prop currentTabIndex: number = 0
  onTabClick: (index: number) => void = () => {
  }

  private isActive(): boolean {
    return this.currentTabIndex === this.index
  }

  build() {
    Column() {
      if (this.item.middleMode) {
        Stack({ alignContent: Alignment.Center }) {
          Circle()
            .width(52)
            .height(52)
            .fill($r('app.color.color_accent'))
            .shadow({ radius: 10, color: $r('app.color.color_shadow_orange_22'), offsetY: 4 })

          Text('+')
            .fontSize(32)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.color_white'))
            .margin({ bottom: 3 })
        }
        .width(52)
        .height(52)
        .clip(true)
        .borderRadius(26)
        .offset({ y: -16 })
        .scale(this.isActive() ? { x: 1.04, y: 1.04 } : { x: 1, y: 1 })
        .animation({ duration: 300, curve: Curve.Friction })

        Text(this.item.title)
          .fontSize(10)
          .margin({ top: -12 })
          .fontColor(this.isActive() ? $r('app.color.color_primary') : $r('app.color.color_tab_inactive'))
          .animation({ duration: 300, curve: Curve.Ease })
      } else {
        Stack({ alignContent: Alignment.Center }) {
          if (this.isActive()) {
            Circle()
              .width(38)
              .height(38)
              .fill($r('app.color.color_selected_bg'))
          }

          Image(this.isActive() ? this.item.selectImage : this.item.defaultImage)
            .width(24)
            .height(24)
            .fillColor(this.isActive() ? $r('app.color.color_primary') : $r('app.color.color_tab_inactive'))
            .scale(this.isActive() ? { x: 1.05, y: 1.05 } : { x: 1, y: 1 })
            .animation({ duration: 300, curve: Curve.Ease })
        }
        .width(46)
        .height(38)
        .animation({ duration: 250, curve: Curve.Ease })

        Text(this.item.title)
          .fontSize(10)
          .margin({ top: 2 })
          .fontColor(this.isActive() ? $r('app.color.color_primary') : $r('app.color.color_tab_inactive'))
          .animation({ duration: 300, curve: Curve.Ease })
      }
    }
    .layoutWeight(this.item.middleMode ? 1.2 : 1)
    .height('100%')
    .padding({ top: this.item.middleMode ? 0 : 6 })
    .alignItems(HorizontalAlign.Center)
    .onClick(() => {
      this.onTabClick(this.index)
    })
  }
}
@Entry
@Component
struct Index {
  @Watch('onActiveTabChanged')
  @Provide activeTabIndex: number = 0
  @State currentTabIndex: number = 0
  @StorageProp('navBarHeight') nbHeight: number = 0
  @StorageProp('statusBarHeight') sbHeight: number = 0
  @StorageLink('showCategoryEditor') showCategoryEditor: boolean = false
  @StorageLink('settingsPageState') settingsPageState: string = 'main'
  @StorageLink('settingsBackSignal') settingsBackSignal: number = 0
  @StorageLink('isLoggedIn') @Watch('onLoginStateChanged') isLoggedIn: boolean = false
  @StorageLink('currentUserName') currentUserName: string = ''
  @State authLoading: boolean = true
  @State authRegisterMode: boolean = false
  @State authUsername: string = ''
  @State authDisplayName: string = ''
  @State authPassword: string = ''
  @State authMessage: string = ''
  @State authBusy: boolean = false
  @State userInfoQueryBusy: boolean = false
  @State userInfoQueryResult: string = ''
  @State userInfoWriteBusy: boolean = false
  @Provide('appNavStack') pageStack: NavPathStack = new NavPathStack()
  private tabController: TabsController = new TabsController()
  private tabArray: BottomTabModel[] = [
    new BottomTabModel('账单', $rawfile('icon_tab_bills.svg'), $rawfile('icon_tab_bills.svg'), false),
    new BottomTabModel('日历', $rawfile('icon_calendar.svg'), $rawfile('icon_calendar.svg'), false),
    new BottomTabModel('记账', $rawfile('icon_tab_add.svg'), $rawfile('icon_tab_add.svg'), true),
    new BottomTabModel('统计', $rawfile('icon_tab_stats.svg'), $rawfile('icon_tab_stats.svg'), false),
    new BottomTabModel('我的', $rawfile('icon_tab_settings.svg'), $rawfile('icon_tab_settings.svg'), false)
  ]

  aboutToAppear(): void {
    this.loadUserSession()
  }

  private async loadUserSession(): Promise<void> {
    try {
      const context = this.getUIContext().getHostContext()
      if (!context) {
        this.authLoading = false
        return
      }
      const session = await UserDao.getInstance().getCurrentUser(context)
      if (session) {
        await this.applyUserSession(session)
      }
    } catch (err) {
      LogUtils.error('Index', 'loadUserSession failed: %{public}s', JSON.stringify(err))
    }
    this.authLoading = false
  }

  private async applyUserSession(session: UserSession): Promise<void> {
    AppStorage.setOrCreate<boolean>('isLoggedIn', true)
    AppStorage.setOrCreate<number>('currentUserId', session.id)
    AppStorage.setOrCreate<string>('currentUserName', session.displayName)
    AppStorage.setOrCreate<string>('currentUsername', session.username)
    await AccountBookDao.getInstance().ensureDefaultBookForUser(session.id, session.displayName)
    await DBHelper.getInstance().ensureDefaultCategoriesForUser(session.id)
    await CategoryDao.getInstance().refreshCache()
    this.isLoggedIn = true
    this.currentUserName = session.displayName
  }

  private async submitAuth(): Promise<void> {
    if (this.authBusy) {
      LogUtils.error('Index', '云端账号提交被忽略：当前正在处理')
      return
    }
    const context = this.getUIContext().getHostContext()
    if (!context) {
      this.authMessage = '无法获取应用上下文'
      return
    }
    this.authBusy = true
    this.authMessage = ''
    LogUtils.error('Index',
      '云端账号提交开始 mode=%{public}s username=%{public}s displayName=%{public}s',
      this.authRegisterMode ? 'register' : 'login', this.authUsername, this.authDisplayName)
    try {
      let session: UserSession
      if (this.authRegisterMode) {
        LogUtils.error('Index', '云端账号注册调用 UserDao.register username=%{public}s', this.authUsername)
        session = await UserDao.getInstance().register(context, this.authUsername, this.authDisplayName, this.authPassword)
      } else {
        LogUtils.error('Index', '云端账号登录调用 UserDao.login username=%{public}s', this.authUsername)
        session = await UserDao.getInstance().login(context, this.authUsername, this.authPassword)
      }
      this.authPassword = ''
      await this.applyUserSession(session)
      LogUtils.error('Index',
        '云端账号提交成功 mode=%{public}s userLocalId=%{public}s username=%{public}s',
        this.authRegisterMode ? 'register' : 'login', session.id.toString(), session.username)
    } catch (err) {
      const errorText = this.formatError(err)
      const repaired = await this.tryRepairCloudAccountWithoutPassword(context, errorText)
      if (!repaired) {
        this.authMessage = errorText.length > 2 ? errorText : '登录失败，请检查账号和密码'
        LogUtils.error('Index', '云端账号提交失败：%{public}s', errorText)
      }
    }
    this.authBusy = false
  }

  private async tryRepairCloudAccountWithoutPassword(context: common.BaseContext, errorText: string): Promise<boolean> {
    if (this.authRegisterMode) {
      return false
    }
    if (!errorText.includes('缺少密码信息') && !errorText.includes('passwordHash')) {
      return false
    }
    if (this.authUsername.trim().length < 3 || this.authPassword.length < 6) {
      this.authMessage = '云端账号缺少密码信息，请输入至少 6 位密码后重试'
      return true
    }
    try {
      LogUtils.error('Index', '检测到云端账号缺少密码字段，自动补写 passwordHash/salt username=%{public}s', this.authUsername)
      this.authMessage = '正在修复云端账号密码信息...'
      const displayName = this.authDisplayName.trim().length > 0 ? this.authDisplayName : this.authUsername
      const session = await UserDao.getInstance().register(context, this.authUsername, displayName, this.authPassword)
      this.authPassword = ''
      await this.applyUserSession(session)
      this.authMessage = ''
      LogUtils.error('Index', '云端账号密码字段自动修复完成 userLocalId=%{public}s username=%{public}s',
        session.id.toString(), session.username)
      return true
    } catch (repairErr) {
      const repairErrorText = this.formatError(repairErr)
      this.authMessage = '云端账号密码修复失败：' + repairErrorText
      LogUtils.error('Index', '云端账号密码字段自动修复失败：%{public}s', repairErrorText)
      return true
    }
  }

  private async createLocalProfile(): Promise<void> {
    if (this.authBusy) {
      LogUtils.error('Index', '创建本地用户被忽略：当前正在处理')
      return
    }
    const context = this.getUIContext().getHostContext()
    if (!context) {
      this.authMessage = '无法获取应用上下文'
      return
    }
    this.authBusy = true
    this.authMessage = ''
    try {
      LogUtils.error('Index', '创建本地用户调用 UserDao.createLocalUser username=%{public}s', this.authUsername)
      const session = await UserDao.getInstance().createLocalUser(context, this.authUsername, this.authDisplayName)
      await this.applyUserSession(session)
      this.authPassword = ''
      LogUtils.error('Index', '创建本地用户成功 userLocalId=%{public}s username=%{public}s',
        session.id.toString(), session.username)
    } catch (err) {
      const errorText = this.formatError(err)
      this.authMessage = errorText.length > 2 ? errorText : '创建本地用户失败'
      LogUtils.error('Index', '创建本地用户失败：%{public}s', errorText)
    }
    this.authBusy = false
  }

  private async queryAllUserInfoForDebug(): Promise<void> {
    if (this.userInfoQueryBusy) {
      LogUtils.error('Index', 'UserInfo 测试查询被忽略：当前正在查询')
      return
    }
    this.userInfoQueryBusy = true
    this.userInfoQueryResult = '正在查询 UserInfo...'
    LogUtils.error('Index', '登录页 UserInfo 测试查询开始')
    try {
      const result = await CloudDatabaseService.getInstance().queryAllUserInfoForDebug()
      this.userInfoQueryResult = result
      LogUtils.error('Index', '登录页 UserInfo 测试查询成功 result=%{public}s', result)
    } catch (err) {
      const errorText = this.formatError(err)
      this.userInfoQueryResult = 'UserInfo 查询失败：' + errorText
      LogUtils.error('Index', '登录页 UserInfo 测试查询失败 error=%{public}s', errorText)
    }
    this.userInfoQueryBusy = false
  }

  private async upsertTestUserInfoForDebug(): Promise<void> {
    if (this.userInfoWriteBusy) {
      LogUtils.error('Index', 'UserInfo 测试写入被忽略：当前正在写入')
      return
    }
    this.userInfoWriteBusy = true
    this.userInfoQueryResult = '正在写入 UserInfo 测试记录...'
    LogUtils.error('Index', '登录页 UserInfo 测试写入开始')
    try {
      const result = await CloudDatabaseService.getInstance().upsertTestUserInfoForDebug()
      this.userInfoQueryResult = result
      LogUtils.error('Index', '登录页 UserInfo 测试写入成功 result=%{public}s', result)
    } catch (err) {
      const errorText = this.formatError(err)
      this.userInfoQueryResult = 'UserInfo 写入失败：' + errorText
      LogUtils.error('Index', '登录页 UserInfo 测试写入失败 error=%{public}s', errorText)
    }
    this.userInfoWriteBusy = false
  }

  private formatError(err: Error | Object): string {
    if (err instanceof Error) {
      return err.message
    }
    const errorInfo = err as RuntimeErrorInfo
    const parts: string[] = []
    if (errorInfo.code !== undefined) {
      parts.push('code=' + errorInfo.code.toString())
    }
    if (errorInfo.name !== undefined && errorInfo.name.length > 0) {
      parts.push('name=' + errorInfo.name)
    }
    if (errorInfo.message !== undefined && errorInfo.message.length > 0) {
      parts.push('message=' + errorInfo.message)
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
      return '未知错误：SDK 返回对象没有可枚举字段'
    }
    return parts.join(', ')
  }

  onActiveTabChanged(): void {
    this.currentTabIndex = this.activeTabIndex
    this.tabController.changeIndex(this.activeTabIndex)
    this.updateStatusBar(this.activeTabIndex)
  }

  onLoginStateChanged(): void {
    this.pageStack.clear()
    if (!this.isLoggedIn) {
      this.onTabClick(0)
    }
  }

  private updateStatusBar(index: number): void {
    const win = AppStorage.get<window.Window>('mainWindow')
    if (!win) {
      return
    }
    win.setWindowSystemBarProperties({
      statusBarContentColor: index === 2 ? '#FFFFFF' : '#10233F' // 系统栏 API 需要字符串颜色
    }).catch((e: Error) => {
      LogUtils.error('Index', 'setStatusBar failed: %{public}s', e.message)
    })
  }

  private onTabClick(index: number) {
    this.currentTabIndex = index
    this.activeTabIndex = index
    this.tabController.changeIndex(index)
    this.updateStatusBar(index)
  }

  private isTabBarVisible(): boolean {
    if (this.showCategoryEditor) {
      return false
    }
    return true
  }

  onBackPress(): boolean {
    if (this.pageStack.getAllPathName().length > 0) {
      return false
    }
    if (this.currentTabIndex === 4 && this.settingsPageState !== 'main') {
      this.settingsBackSignal = this.settingsBackSignal + 1
      return true
    }
    if (this.currentTabIndex !== 0) {
      this.onTabClick(0)
      return true
    }
    return false
  }

  @Builder
  LoginGate() {
    Stack() {
      Image($rawfile('illustration_fish_bowl.png'))
        .width(150)
        .height(112)
        .objectFit(ImageFit.Contain)
        .opacity(0.9)
        .position({ x: 196, y: 72 })

      Column() {
        Text('小金鱼记账')
          .fontSize(30)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.color_text_primary'))
          .width('100%')
        Text(this.authRegisterMode ? '创建本地账号后开始记账' : '登录本地账号继续使用')
          .fontSize(15)
          .fontColor($r('app.color.color_text_secondary'))
          .width('100%')
          .margin({ top: 8, bottom: 28 })

        TextInput({ placeholder: '账号', text: this.authUsername })
          .height(48)
          .fontSize(15)
          .backgroundColor($r('app.color.color_bg'))
          .borderRadius(16)
          .padding({ left: 14, right: 14 })
          .onChange((value: string) => {
            this.authUsername = value
          })

        if (this.authRegisterMode) {
          TextInput({ placeholder: '昵称', text: this.authDisplayName })
            .height(48)
            .fontSize(15)
            .backgroundColor($r('app.color.color_bg'))
            .borderRadius(16)
            .padding({ left: 14, right: 14 })
            .margin({ top: 12 })
            .onChange((value: string) => {
              this.authDisplayName = value
            })
        }

        TextInput({ placeholder: '密码', text: this.authPassword })
          .height(48)
          .fontSize(15)
          .type(InputType.Password)
          .backgroundColor($r('app.color.color_bg'))
          .borderRadius(16)
          .padding({ left: 14, right: 14 })
          .margin({ top: 12 })
          .onChange((value: string) => {
            this.authPassword = value
          })

        if (this.authMessage.length > 0) {
          Text(this.authMessage)
            .fontSize(12)
            .fontColor($r('app.color.color_expense'))
            .width('100%')
            .margin({ top: 10 })
            .maxLines(2)
        }

        Button(this.authBusy ? '处理中...' : (this.authRegisterMode ? '注册并登录' : '登录'))
          .width('100%')
          .height(48)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.color_white'))
          .backgroundColor($r('app.color.color_primary'))
          .borderRadius(24)
          .margin({ top: 22 })
          .onClick(() => {
            this.submitAuth()
          })

        Button(this.authBusy ? '处理中...' : '仅创建本地用户名使用')
          .width('100%')
          .height(44)
          .fontSize(14)
          .fontColor($r('app.color.color_primary'))
          .backgroundColor($r('app.color.color_bg'))
          .borderRadius(22)
          .margin({ top: 8 })
          .onClick(() => {
            this.createLocalProfile()
          })

        Button(this.authRegisterMode ? '已有账号，去登录' : '没有账号，创建一个')
          .width('100%')
          .height(44)
          .fontSize(14)
          .fontColor($r('app.color.color_primary'))
          .backgroundColor('#00000000')
          .margin({ top: 8 })
          .onClick(() => {
            this.authRegisterMode = !this.authRegisterMode
            this.authMessage = ''
          })

        // Button(this.userInfoQueryBusy ? '查询中...' : '测试查询 UserInfo 全表')
        //   .width('100%')
        //   .height(40)
        //   .fontSize(13)
        //   .fontColor($r('app.color.color_text_primary'))
        //   .backgroundColor($r('app.color.color_bg'))
        //   .borderRadius(20)
        //   .margin({ top: 6 })
        //   .onClick(() => {
        //     this.queryAllUserInfoForDebug()
        //   })

        // Button(this.userInfoWriteBusy ? '写入中...' : '测试写入 UserInfo')
        //   .width('100%')
        //   .height(40)
        //   .fontSize(13)
        //   .fontColor($r('app.color.color_text_primary'))
        //   .backgroundColor($r('app.color.color_bg'))
        //   .borderRadius(20)
        //   .margin({ top: 6 })
        //   .onClick(() => {
        //     this.upsertTestUserInfoForDebug()
        //   })

        if (this.userInfoQueryResult.length > 0) {
          Text(this.userInfoQueryResult)
            .fontSize(11)
            .fontColor($r('app.color.color_text_secondary'))
            .width('100%')
            .maxLines(8)
            .margin({ top: 8 })
        }
      }
      .width('calc(100% - 32vp)')
      .padding({ left: 20, right: 20, top: 28, bottom: 20 })
      .backgroundColor($r('app.color.color_surface'))
      .borderRadius(24)
      .shadow({ radius: 16, color: $r('app.color.color_shadow_blue_08'), offsetY: 6 })
      .margin({ left: 16, right: 16 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.start_window_background'))
    .alignContent(Alignment.Center)
  }

  @Builder
  AppContent() {
    if (this.authLoading) {
      Stack() {
        Text('正在读取账号...')
          .fontSize(15)
          .fontColor($r('app.color.color_text_secondary'))
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.start_window_background'))
    } else if (!this.isLoggedIn) {
      this.LoginGate()
    } else {
      Stack({ alignContent: Alignment.Bottom }) {
        Tabs({ barPosition: BarPosition.End, controller: this.tabController, index: this.currentTabIndex }) {
          ForEach(this.tabArray, (item: BottomTabModel, index: number) => {
            if (index === 0) {
              TabContent() {
                BillListPage()
              }
              .backgroundColor($r('app.color.start_window_background'))
            } else if (index === 1) {
              TabContent() {
                CalendarPage()
              }
              .backgroundColor($r('app.color.start_window_background'))
            } else if (index === 2) {
              TabContent() {
                AddBillPage()
              }.backgroundColor($r('app.color.start_window_background'))
            } else if (index === 3) {
              TabContent() {
                StatisticsPage()
              }.backgroundColor($r('app.color.start_window_background'))
            } else if (index === 4) {
              TabContent() {
                SettingsPage({ initialPage: 'main' })
              }.backgroundColor($r('app.color.start_window_background'))
            }
          }, (item: BottomTabModel, index: number) => JSON.stringify(item) + index)
        }
        .barHeight(0)
        .scrollable(false)
        .onChange((index: number) => this.onTabClick(index))
        .padding({ bottom: this.isTabBarVisible() ? 56 + this.nbHeight : 0 })

        if (this.isTabBarVisible()) {
          Flex({ justifyContent: FlexAlign.SpaceAround, alignItems: ItemAlign.Center }) {
            ForEach(this.tabArray, (item: BottomTabModel, index: number) => {
              BottomTabItem({
                item: item,
                index: index,
                currentTabIndex: this.currentTabIndex,
                onTabClick: (tabIndex: number) => {
                  this.onTabClick(tabIndex)
                }
              })
            }, (item: BottomTabModel, index: number) => JSON.stringify(item) + index)
          }
          .width('100%')
          .height(56 + this.nbHeight)
          .padding({ bottom: this.nbHeight })
          .backgroundColor($r('app.color.color_surface'))
          .border({ width: { top: 0.5 }, color: $r('app.color.color_divider') })
          .shadow({ radius: 14, color: $r('app.color.color_shadow_blue_08'), offsetY: -4 })
        }

        if (this.showCategoryEditor) {
          CategoryEditor({
            onClose: () => {
              this.getUIContext().animateTo({ duration: 250, curve: Curve.EaseIn }, () => {
                this.showCategoryEditor = false
              })
            }
          })
            .transition(
              TransitionEffect.asymmetric(
                TransitionEffect.OPACITY.combine(TransitionEffect.translate({ y: 800 }))
                  .animation({ duration: 300, curve: Curve.EaseOut }),
                TransitionEffect.OPACITY.combine(TransitionEffect.translate({ y: 800 }))
                  .animation({ duration: 250, curve: Curve.EaseIn })
              )
            )
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.start_window_background'))
    }
  }

  build() {
    Navigation(this.pageStack) {
      this.AppContent()
    }
    .hideTitleBar(true)
    .mode(NavigationMode.Stack)
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.start_window_background'))
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}

interface RuntimeErrorInfo {
  code?: number
  message?: string
  name?: string
}
