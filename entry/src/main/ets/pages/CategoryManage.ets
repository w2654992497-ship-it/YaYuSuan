import { CategoryRecord } from '../model/Category'
import { CategoryDao } from '../database/CategoryDao'
import { BillDao } from '../database/BillDao'
import { CategoryEditDialog } from '../components/CategoryEditDialog'
import { LogUtils } from '../utils/LogUtils'

const ITEM_H = 64

@Component
export struct CategoryManagePage {
  @State activeType: 'expense' | 'income' = 'expense'
  @State expenseList: CategoryRecord[] = []
  @State incomeList: CategoryRecord[] = []
  @State dragIdx: number = -1     // 被拖拽项在数组中的原始索引（不变）
  @State dragY: number = 0        // 浮层的Y偏移（相对原位）
  onBack: () => void = () => {}

  @State dialogMode: string = 'add'
  @State dialogType: string = 'expense'
  @State dialogName: string = ''
  @State dialogIcon: string = 'icon_other'
  @State dialogColor: string = '#78909C'
  @State editingId: number = 0
  @State editingOldName: string = ''

  private editDialogController: CustomDialogController = new CustomDialogController({
    builder: CategoryEditDialog({
      mode: this.dialogMode, categoryType: this.dialogType,
      initialName: this.dialogName, initialIcon: this.dialogIcon, initialColor: this.dialogColor,
      onConfirm: (name: string, icon: string, color: string) => { this.onDialogConfirm(name, icon, color) }
    }),
    alignment: DialogAlignment.Center, customStyle: true, maskColor: '#60000000'
  })

  aboutToAppear(): void { this.loadCategories() }

  private async loadCategories(): Promise<void> {
    this.expenseList = await CategoryDao.getInstance().queryByType('expense')
    this.incomeList = await CategoryDao.getInstance().queryByType('income')
  }

  private getList(): CategoryRecord[] {
    return this.activeType === 'expense' ? this.expenseList : this.incomeList
  }

  private setList(list: CategoryRecord[]): void {
    if (this.activeType === 'expense') this.expenseList = list
    else this.incomeList = list
  }

  private openAddDialog(): void {
    this.dialogMode = 'add'; this.dialogType = this.activeType
    this.dialogName = ''; this.dialogIcon = 'icon_other'; this.dialogColor = '#78909C'
    this.editingId = 0; this.editDialogController.open()
  }

  private openEditDialog(cat: CategoryRecord): void {
    this.dialogMode = 'edit'; this.dialogType = cat.type
    this.dialogName = cat.name; this.dialogIcon = cat.icon; this.dialogColor = cat.color
    this.editingId = cat.id; this.editingOldName = cat.name; this.editDialogController.open()
  }

  private async onDialogConfirm(name: string, icon: string, color: string): Promise<void> {
    try {
      if (this.dialogMode === 'add') {
        const maxOrder = await CategoryDao.getInstance().getMaxSortOrder(this.activeType)
        await CategoryDao.getInstance().insert({
          id: 0, name: name, icon: icon, color: color,
          type: this.activeType, sort_order: maxOrder + 1, is_default: 0
        })
      } else {
        await CategoryDao.getInstance().update({
          id: this.editingId, name: name, icon: icon, color: color,
          type: this.activeType, sort_order: 0, is_default: 0
        }, this.editingOldName)
      }
      await this.loadCategories()
    } catch (err) { LogUtils.error('CategoryManage', 'confirm: %{public}s', JSON.stringify(err)) }
  }

  private async deleteCategory(cat: CategoryRecord): Promise<void> {
    const bills = await BillDao.getInstance().queryByFilter({ month: '', type: 'all', category: cat.name })
    const msg = bills.length > 0
      ? `该分类下有 ${bills.length} 条账单，删除后显示默认样式。确定？`
      : `确认删除「${cat.name}」？`
    this.getUIContext().showAlertDialog({
      title: '删除分类', message: msg,
      primaryButton: { value: '取消', fontColor: $r('app.color.color_primary'), action: () => {} },
      secondaryButton: {
        value: '删除', fontColor: $r('app.color.color_expense'),
        action: async () => { await CategoryDao.getInstance().deleteById(cat.id); await this.loadCategories() }
      }
    })
  }

  // ── 拖拽：纯视觉偏移，数组不动，松手才排序 ──

  private handleDragStart(index: number): void {
    this.dragIdx = index
    this.dragY = 0
  }

  private handleDragMove(offsetY: number): void {
    if (this.dragIdx < 0) return
    const list = this.getList()
    // 边界限制
    const minY = this.dragIdx * ITEM_H * -1
    const maxY = (list.length - 1 - this.dragIdx) * ITEM_H
    this.dragY = Math.max(minY, Math.min(maxY, offsetY))
  }

  // 拖拽项最终应该落在第几个slot
  private getTargetIndex(): number {
    if (this.dragIdx < 0) return -1
    const list = this.getList()
    // 四舍五入到最近的slot
    let target = this.dragIdx + Math.round(this.dragY / ITEM_H)
    target = Math.max(0, Math.min(list.length - 1, target))
    return target
  }

  private handleDragEnd(): void {
    if (this.dragIdx < 0) return
    const from = this.dragIdx
    const to = this.getTargetIndex()

    // 先回弹动画
    this.getUIContext().animateTo({ duration: 180, curve: Curve.EaseOut }, () => {
      // 回弹到目标slot位置（相对于原位的偏移）
      this.dragY = (to - from) * ITEM_H
    })

    setTimeout(() => {
      // 真正重排数组
      if (from !== to) {
        const list = this.getList()
        const newList: CategoryRecord[] = []
        for (const item of list) { newList.push(item) }
        const moved = newList.splice(from, 1)
        newList.splice(to, 0, moved[0])
        this.dragIdx = -1
        this.dragY = 0
        this.setList(newList)
        CategoryDao.getInstance().updateSortOrder(newList)
      } else {
        this.dragIdx = -1
        this.dragY = 0
      }
    }, 190)
  }

  // 非拖拽项的偏移：被挤开的效果
  private getItemShift(index: number): number {
    if (this.dragIdx < 0 || index === this.dragIdx) return 0
    const target = this.getTargetIndex()
    // 拖拽项从 dragIdx 移到 target
    // dragIdx 和 target 之间的项需要让位
    if (this.dragIdx < target) {
      // 向下拖：dragIdx+1 到 target 的项要向上移一格
      if (index > this.dragIdx && index <= target) return ITEM_H * -1
    } else if (this.dragIdx > target) {
      // 向上拖：target 到 dragIdx-1 的项要向下移一格
      if (index >= target && index < this.dragIdx) return ITEM_H
    }
    return 0
  }

  // 浮层绝对Y
  private getFloatY(): number {
    const list = this.getList()
    const pos = this.dragIdx * ITEM_H + this.dragY
    return Math.max(0, Math.min((list.length - 1) * ITEM_H, pos))
  }

  @Builder
  TypeTab(label: string, type: 'expense' | 'income') {
    Text(label)
      .fontSize(14)
      .fontColor(this.activeType === type ? $r('app.color.color_surface') : $r('app.color.color_text_secondary'))
      .fontWeight(this.activeType === type ? FontWeight.Medium : FontWeight.Normal)
      .backgroundColor(this.activeType === type ? $r('app.color.color_primary') : $r('app.color.color_surface'))
      .borderRadius(16).padding({ left: 20, right: 20, top: 6, bottom: 6 })
      .animation({ duration: 200 })
      .onClick(() => { this.activeType = type; this.dragIdx = -1; this.dragY = 0 })
  }

  @Builder
  ItemContent(cat: CategoryRecord, showActions: boolean) {
    Row() {
      Text('⠿').fontSize(20)
        .fontColor($r('app.color.color_tab_inactive'))
        .width(28).textAlign(TextAlign.Center)

      Column() {
        Image($rawfile(cat.icon + '.svg')).width(22).height(22).fillColor($r('app.color.color_surface'))
      }
      .width(44).height(44).borderRadius(22).backgroundColor(cat.color)
      .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center).margin({ right: 14 })

      Text(cat.name).fontSize(16).fontColor($r('app.color.color_text_primary')).layoutWeight(1)

      if (cat.is_default === 1) {
        Text('默认').fontSize(10).fontColor($r('app.color.color_text_secondary'))
          .backgroundColor($r('app.color.color_bg')).borderRadius(8)
          .padding({ left: 6, right: 6, top: 2, bottom: 2 }).margin({ right: 8 })
      }
      if (showActions) {
        Image($rawfile('icon_edit.svg')).width(18).height(18)
          .fillColor($r('app.color.color_text_secondary')).margin({ right: 12 })
          .onClick(() => { this.openEditDialog(cat) })
        if (cat.is_default === 0) {
          Image($rawfile('icon_other.svg')).width(18).height(18)
            .fillColor($r('app.color.color_expense'))
            .onClick(() => { this.deleteCategory(cat) })
        }
      }
    }
    .width('100%').height(ITEM_H).padding({ left: 8, right: 16 }).alignItems(VerticalAlign.Center)
  }

  build() {
    Column() {
      Row() {
        Image($rawfile('icon_chevron_left.svg')).width(24).height(24)
          .fillColor($r('app.color.color_text_primary')).onClick(() => { this.onBack() })
        Text('分类管理').fontSize(18).fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.color_text_primary')).layoutWeight(1).textAlign(TextAlign.Center)
        Column().width(24)
      }.width('100%').padding({ left: 16, right: 16, top: 12, bottom: 12 })

      Row({ space: 8 }) {
        this.TypeTab('支出', 'expense')
        this.TypeTab('收入', 'income')
      }.width('100%').justifyContent(FlexAlign.Center).padding({ top: 4, bottom: 8 })

      Text('长按拖拽调整顺序').fontSize(12).fontColor($r('app.color.color_text_secondary'))
        .width('100%').textAlign(TextAlign.Center).margin({ bottom: 8 })

      Stack({ alignContent: Alignment.TopStart }) {
        // 底层列表（数组顺序不变，靠 translate 模拟位移）
        Column() {
          ForEach(this.getList(), (cat: CategoryRecord, index: number) => {
            Column() {
              if (this.dragIdx === index) {
                // 占位：半透明虚线框
                Row()
                  .width('100%').height(ITEM_H)
                  .backgroundColor($r('app.color.color_bg'))
                  .border({ width: 1, color: $r('app.color.color_divider'), style: BorderStyle.Dashed })
                  .borderRadius(8)
                  .opacity(0.6)
              } else {
                this.ItemContent(cat, this.dragIdx < 0)
              }
            }
            .translate({ x: 0, y: this.getItemShift(index) })
            .animation({ duration: 300, curve: Curve.FastOutSlowIn })
            .gesture(
              GestureGroup(GestureMode.Sequence,
                LongPressGesture({ repeat: false, duration: 300 })
                  .onAction(() => { this.handleDragStart(index) }),
                PanGesture({ direction: PanDirection.Vertical })
                  .onActionUpdate((e: GestureEvent) => { if (e) this.handleDragMove(e.offsetY) })
                  .onActionEnd(() => { this.handleDragEnd() })
                  .onActionCancel(() => { this.handleDragEnd() })
              )
            )
          }, (cat: CategoryRecord) => cat.id.toString())
        }.width('100%')

        // 浮层（跟手，无动画延迟）
        if (this.dragIdx >= 0 && this.dragIdx < this.getList().length) {
          Row() {
            this.ItemContent(this.getList()[this.dragIdx], false)
          }
          .width('100%').height(ITEM_H)
          .backgroundColor($r('app.color.color_surface'))
          .borderRadius(14)
          .shadow({ radius: 20, color: 'rgba(0,0,0,0.18)', offsetY: 6 })
          .scale({ x: 1.03, y: 1.03 })
          .translate({ x: 0, y: this.getFloatY() })
          .hitTestBehavior(HitTestMode.None)
        }
      }
      .layoutWeight(1)
      .width('calc(100% - 32vp)')
      .backgroundColor($r('app.color.color_surface'))
      .borderRadius(20)
      .margin({ left: 16, right: 16 })
      .clip(true)

      Blank()

      Button('+ 添加分类')
        .width('calc(100% - 32vp)').height(48).fontSize(15).fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.color_primary')).backgroundColor($r('app.color.color_surface'))
        .borderRadius(24).border({ width: 1, color: $r('app.color.color_primary'), style: BorderStyle.Dashed })
        .margin({ left: 16, right: 16, top: 12, bottom: 20 })
        .onClick(() => { this.openAddDialog() })
    }.width('100%').height('100%').backgroundColor($r('app.color.color_bg'))
  }
}
