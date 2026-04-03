import { CategoryRecord } from '../model/Category'
import { CategoryDao } from '../database/CategoryDao'
import { BillDao } from '../database/BillDao'
import { CategoryEditDialog } from './CategoryEditDialog'
import { LogUtils } from '../utils/LogUtils'

const COLS = 4
const CELL_H = 88

@Component
export struct CategoryEditor {
  @StorageProp('statusBarHeight') sbHeight: number = 0
  @State activeType: 'expense' | 'income' = 'expense'
  @State expenseList: CategoryRecord[] = []
  @State incomeList: CategoryRecord[] = []
  @State isSortMode: boolean = false
  @State selectedName: string = ''
  // 拖拽状态
  @State dragIdx: number = -1
  @State dragOffX: number = 0
  @State dragOffY: number = 0
  private cellW: number = 0  // 运行时计算
  onClose: () => void = () => {}
  private dialogCtrl: CustomDialogController | null = null

  aboutToAppear(): void {
    this.loadCategories()
    this.selectedName = AppStorage.get<string>('editCategorySelected') ?? ''
    const t = AppStorage.get<string>('editCategoryType') ?? 'expense'
    this.activeType = t === 'income' ? 'income' : 'expense'
  }

  private async loadCategories(): Promise<void> {
    try {
      const expense = await CategoryDao.getInstance().queryByType('expense')
      const income = await CategoryDao.getInstance().queryByType('income')
      const nextExpense: CategoryRecord[] = []
      const nextIncome: CategoryRecord[] = []
      for (const c of expense) {
        nextExpense.push({
          id: c.id, name: c.name, icon: c.icon, color: c.color,
          type: c.type, sort_order: c.sort_order, is_default: c.is_default
        })
      }
      for (const c of income) {
        nextIncome.push({
          id: c.id, name: c.name, icon: c.icon, color: c.color,
          type: c.type, sort_order: c.sort_order, is_default: c.is_default
        })
      }
      this.expenseList = nextExpense
      this.incomeList = nextIncome
    } catch (_e) {}
  }

  private currentList(): CategoryRecord[] {
    return this.activeType === 'expense' ? this.expenseList : this.incomeList
  }

  private setCurrentList(list: CategoryRecord[]): void {
    if (this.activeType === 'expense') this.expenseList = list
    else this.incomeList = list
  }

  private notifyCategoryChanged(): void {
    AppStorage.setOrCreate('editCategorySelected', this.selectedName)
    const ver = AppStorage.get<number>('categoryVersion') ?? 0
    AppStorage.setOrCreate('categoryVersion', ver + 1)
  }

  private async deleteCat(cat: CategoryRecord): Promise<void> {
    if (this.currentList().length <= 1) {
      try { this.getUIContext().getPromptAction().showToast({ message: '至少保留一个分类' }) } catch (_e) {}
      return
    }
    try {
      await CategoryDao.getInstance().deleteById(cat.id)
      if (this.selectedName === cat.name) this.selectedName = ''
      await this.loadCategories()
      this.notifyCategoryChanged()
    } catch (_e) {}
  }

  private getExistingNames(): string[] {
    return this.currentList().map((c: CategoryRecord): string => c.name)
  }

  private editCat(cat: CategoryRecord): void {
    this.dialogCtrl = new CustomDialogController({
      builder: CategoryEditDialog({
        mode: 'edit', categoryType: this.activeType,
        initialName: cat.name, initialIcon: cat.icon, initialColor: cat.color,
        existingNames: this.getExistingNames(),
        onConfirm: async (name: string, icon: string, color: string) => {
          try {
            await CategoryDao.getInstance().update({
              id: cat.id, name: name, icon: icon, color: color,
              type: cat.type, sort_order: cat.sort_order, is_default: cat.is_default
            }, cat.name)
            if (this.selectedName === cat.name) this.selectedName = name
            await this.loadCategories()
            this.notifyCategoryChanged()
          } catch (_e) {}
        }
      }),
      alignment: DialogAlignment.Center, customStyle: true, maskColor: '#60000000'
    })
    this.dialogCtrl.open()
  }

  private addCat(): void {
    this.dialogCtrl = new CustomDialogController({
      builder: CategoryEditDialog({
        mode: 'add', categoryType: this.activeType,
        initialName: '', initialIcon: 'icon_other', initialColor: '#78909C',
        existingNames: this.getExistingNames(),
        onConfirm: async (n: string, i: string, c: string) => {
          try {
            const mx = await CategoryDao.getInstance().getMaxSortOrder(this.activeType)
            await CategoryDao.getInstance().insert({
              id: 0, name: n, icon: i, color: c,
              type: this.activeType, sort_order: mx + 1, is_default: 0
            })
            await this.loadCategories()
            this.notifyCategoryChanged()
          } catch (_e) {}
        }
      }),
      alignment: DialogAlignment.Center, customStyle: true, maskColor: '#60000000'
    })
    this.dialogCtrl.open()
  }

  private renderKey(cat: CategoryRecord): string {
    return `${cat.id}_${cat.name}_${cat.icon}_${cat.color}_${cat.sort_order}`
  }

  private resetCats(): void {
    this.getUIContext().showAlertDialog({
      title: '重置分类', message: '恢复默认分类，自定义分类将删除。确定？',
      primaryButton: { value: '取消', fontColor: $r('app.color.color_primary'), action: () => {} },
      secondaryButton: {
        value: '重置', fontColor: $r('app.color.color_expense'),
        action: async () => {
          try {
            for (const c of this.currentList()) {
              if (c.is_default === 0) await CategoryDao.getInstance().deleteById(c.id)
            }
            await this.loadCategories()
            if (!this.currentList().some((c: CategoryRecord): boolean => c.name === this.selectedName)) {
              this.selectedName = ''
            }
            this.notifyCategoryChanged()
          } catch (_e) {}
        }
      }
    })
  }

  private doClose(): void {
    AppStorage.setOrCreate('editCategorySelected', this.selectedName)
    // 触发记账页刷新分类
    const ver = AppStorage.get<number>('categoryVersion') ?? 0
    AppStorage.setOrCreate('categoryVersion', ver + 1)
    this.onClose()
  }

  // 长按检测
  private touchDownTime: number = 0
  private touchStartX: number = 0
  private touchStartY: number = 0
  private readonly LONG_PRESS_MS = 250

  // ── 拖拽（onTouch 方案） ──

  // 拖拽项当前应落在哪个目标索引
  private getTargetIdx(): number {
    if (this.dragIdx < 0) return -1
    const list = this.currentList()
    const fromRow = Math.floor(this.dragIdx / COLS)
    const fromCol = this.dragIdx % COLS
    const cw = this.cellW > 0 ? this.cellW : 90
    const colOff = Math.round(this.dragOffX / cw)
    const rowOff = Math.round(this.dragOffY / CELL_H)
    const tCol = Math.max(0, Math.min(COLS - 1, fromCol + colOff))
    const tRow = Math.max(0, fromRow + rowOff)
    let t = tRow * COLS + tCol
    return Math.max(0, Math.min(list.length - 1, t))
  }

  // 非拖拽项的偏移（一维线性处理：from→target之间的项偏移一个格位）
  private getShiftX(index: number): number {
    if (this.dragIdx < 0 || index === this.dragIdx) return 0
    const target = this.getTargetIdx()
    const from = this.dragIdx
    if (from === target) return 0
    const cw = this.cellW > 0 ? this.cellW : 90
    if (from < target && index > from && index <= target) {
      // 往前移一格
      if ((index % COLS) === 0) return (COLS - 1) * cw  // 行首→上一行末
      return cw * -1
    } else if (from > target && index >= target && index < from) {
      // 往后移一格
      if ((index % COLS) === COLS - 1) return (COLS - 1) * cw * -1  // 行末→下一行首
      return cw
    }
    return 0
  }

  private getShiftY(index: number): number {
    if (this.dragIdx < 0 || index === this.dragIdx) return 0
    const target = this.getTargetIdx()
    const from = this.dragIdx
    if (from === target) return 0
    if (from < target && index > from && index <= target) {
      if ((index % COLS) === 0) return CELL_H * -1
      return 0
    } else if (from > target && index >= target && index < from) {
      if ((index % COLS) === COLS - 1) return CELL_H
      return 0
    }
    return 0
  }

  // 浮层绝对位置
  private getFloatX(): number {
    const cw = this.cellW > 0 ? this.cellW : 90
    return (this.dragIdx % COLS) * cw + this.dragOffX
  }

  private getFloatY(): number {
    const list = this.currentList()
    const maxRow = Math.ceil(list.length / COLS) - 1
    const pos = Math.floor(this.dragIdx / COLS) * CELL_H + this.dragOffY
    return Math.max(0, Math.min(maxRow * CELL_H, pos))
  }

  private finishDrag(): void {
    if (this.dragIdx < 0) return
    const from = this.dragIdx
    const to = this.getTargetIdx()

    // 立即重排，无延迟
    if (from !== to) {
      const list = this.currentList()
      const newList: CategoryRecord[] = []
      for (const item of list) newList.push(item)
      const moved = newList.splice(from, 1)
      newList.splice(to, 0, moved[0])
      this.dragIdx = -1
      this.dragOffX = 0
      this.dragOffY = 0
      this.setCurrentList(newList)
      this.notifyCategoryChanged()
      CategoryDao.getInstance().updateSortOrder(newList).catch(() => {})
    } else {
      this.dragIdx = -1
      this.dragOffX = 0
      this.dragOffY = 0
    }
  }

  @Builder
  CatIcon(cat: CategoryRecord, selected: boolean) {
    Column() {
      Column() {
        Image($rawfile(cat.icon + '.svg')).width(28).height(28)
          .fillColor(selected ? $r('app.color.color_surface') : $r('app.color.color_text_secondary'))
          .draggable(false)
      }
      .width(56).height(56).borderRadius(28)
      .backgroundColor(selected ? cat.color : $r('app.color.color_bg'))
      .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)

      Text(cat.name).fontSize(12).margin({ top: 6 })
        .fontColor(selected ? $r('app.color.color_text_primary') : $r('app.color.color_text_secondary'))
        .fontWeight(selected ? FontWeight.Medium : FontWeight.Normal)
    }
    .alignItems(HorizontalAlign.Center)
  }

  build() {
    Column() {
      // 顶部
      Row() {
        Text('取消').fontSize(15).fontColor($r('app.color.color_text_secondary'))
          .onClick(() => { this.doClose() })
        Text('编辑分类').fontSize(17).fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.color_text_primary'))
          .layoutWeight(1).textAlign(TextAlign.Center)
        Text(this.isSortMode ? '完成' : '排序').fontSize(15)
          .fontColor($r('app.color.color_primary')).fontWeight(FontWeight.Medium)
          .onClick(() => {
            if (this.isSortMode) { this.dragIdx = -1; this.dragOffX = 0; this.dragOffY = 0 }
            this.isSortMode = !this.isSortMode
          })
      }
      .width('100%').padding({ left: 20, right: 20, top: this.sbHeight + 12, bottom: 10 })

      // 切换
      Row({ space: 8 }) {
        Text('支出').fontSize(14)
          .fontColor(this.activeType === 'expense' ? $r('app.color.color_surface') : $r('app.color.color_text_secondary'))
          .fontWeight(this.activeType === 'expense' ? FontWeight.Medium : FontWeight.Normal)
          .backgroundColor(this.activeType === 'expense' ? $r('app.color.color_duck') : $r('app.color.color_surface'))
          .borderRadius(16).padding({ left: 20, right: 20, top: 6, bottom: 6 })
          .onClick(() => { this.activeType = 'expense' })
        Text('收入').fontSize(14)
          .fontColor(this.activeType === 'income' ? $r('app.color.color_surface') : $r('app.color.color_text_secondary'))
          .fontWeight(this.activeType === 'income' ? FontWeight.Medium : FontWeight.Normal)
          .backgroundColor(this.activeType === 'income' ? $r('app.color.color_primary') : $r('app.color.color_surface'))
          .borderRadius(16).padding({ left: 20, right: 20, top: 6, bottom: 6 })
          .onClick(() => { this.activeType = 'income' })
      }
      .width('100%').justifyContent(FlexAlign.Center).padding({ bottom: 12 })

      Text(this.isSortMode ? '长按拖拽排序，点击×删除' : '点击图标编辑内容')
        .fontSize(12).fontColor($r('app.color.color_text_secondary'))
        .width('100%').textAlign(TextAlign.Center).margin({ bottom: 8 })

      // ── 网格区（Stack 浮层方案） ──
      Stack({ alignContent: Alignment.TopStart }) {
        // 底层网格
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(this.currentList(), (cat: CategoryRecord, index: number) => {
            Column() {
              if (this.dragIdx === index) {
                // 占位
                Column().width(56).height(56).borderRadius(28)
                  .backgroundColor($r('app.color.color_bg')).opacity(0.4)
                Text(' ').fontSize(12).margin({ top: 6 })
              } else {
                Stack({ alignContent: Alignment.TopEnd }) {
                  // 编辑页面始终显示彩色
                  this.CatIcon(cat, true)

                  // 叉号
                  if (this.isSortMode && this.currentList().length > 1) {
                    Text('×').fontSize(11).fontColor($r('app.color.color_surface'))
                      .width(18).height(18).borderRadius(9).textAlign(TextAlign.Center)
                      .backgroundColor($r('app.color.color_expense'))
                      .onClick(() => { this.deleteCat(cat) })
                  }
                }
              }
            }
            .width('25%')
            .height(CELL_H)
            .justifyContent(FlexAlign.Center)
            .alignItems(HorizontalAlign.Center)
            .draggable(false)
            // 被挤项偏移
            .translate({ x: this.getShiftX(index), y: this.getShiftY(index) })
            .animation(this.dragIdx >= 0 && this.dragIdx !== index
              ? { duration: 280, curve: Curve.EaseInOut }
              : { duration: 0 })
            .onTouch((event: TouchEvent) => {
              if (!this.isSortMode) return
              const touch = event.touches[0]
              if (event.type === TouchType.Down) {
                this.touchDownTime = Date.now()
                this.touchStartX = touch.x
                this.touchStartY = touch.y
              } else if (event.type === TouchType.Move) {
                if (this.dragIdx === index) {
                  // 已在拖拽：跟手
                  this.dragOffX = touch.x - this.touchStartX
                  this.dragOffY = touch.y - this.touchStartY
                } else if (this.dragIdx < 0) {
                  // 检测长按
                  const dt = Date.now() - this.touchDownTime
                  const dx = Math.abs(touch.x - this.touchStartX)
                  const dy = Math.abs(touch.y - this.touchStartY)
                  if (dt >= this.LONG_PRESS_MS && dx < 20 && dy < 20) {
                    // 激活拖拽
                    this.dragIdx = index
                    this.dragOffX = 0
                    this.dragOffY = 0
                    this.touchStartX = touch.x
                    this.touchStartY = touch.y
                  }
                }
              } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
                if (this.dragIdx === index) {
                  this.finishDrag()
                }
                this.touchDownTime = 0
              }
            })
            .onClick(() => {
              if (!this.isSortMode) this.editCat(cat)
            })
          }, (cat: CategoryRecord) => this.renderKey(cat))
        }
        .width('100%')
        .padding({ left: 8, right: 8 })
        .onAreaChange((_o: Area, n: Area) => {
          // 运行时算出每格宽度
          const w = n.width as number
          if (w > 0) this.cellW = (w - 16) / COLS
        })

        // 浮层：纯图标+文字，无背景无边框
        if (this.dragIdx >= 0 && this.dragIdx < this.currentList().length) {
          Column() {
            this.CatIcon(this.currentList()[this.dragIdx], true)
          }
          .width('25%')
          .height(CELL_H)
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
          .scale({ x: 1.15, y: 1.15 })
          .translate({ x: this.getFloatX(), y: this.getFloatY() })
          .hitTestBehavior(HitTestMode.None)
        }
      }
      .layoutWeight(1)

      // 底部
      Column({ space: 10 }) {
        Row({ space: 10 }) {
          Button('+ 添加').layoutWeight(1).height(44).fontSize(14)
            .fontColor($r('app.color.color_primary'))
            .backgroundColor($r('app.color.color_surface')).borderRadius(22)
            .border({ width: 1, color: $r('app.color.color_primary') })
            .onClick(() => { this.addCat() })
          Button('重置').layoutWeight(1).height(44).fontSize(14)
            .fontColor($r('app.color.color_expense'))
            .backgroundColor($r('app.color.color_surface')).borderRadius(22)
            .border({ width: 1, color: $r('app.color.color_expense') })
            .onClick(() => { this.resetCats() })
        }.width('100%')

        Button('完成').width('100%').height(48).fontSize(16).fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.color_surface')).backgroundColor($r('app.color.color_duck'))
          .borderRadius(24).onClick(() => { this.doClose() })
      }
      .width('100%').padding({ left: 20, right: 20, top: 8, bottom: 20 })
    }
    .width('100%').height('100%').backgroundColor($r('app.color.color_surface'))
  }
}
