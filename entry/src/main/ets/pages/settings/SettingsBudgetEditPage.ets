import { CategoryRecord, getUnifiedCategoryColor } from '../../model/Category'
import { BudgetOverview, createEmptyBudgetOverview } from '../../model/BudgetRule'
import { AmountUtil } from '../../utils/AmountUtil'

@Component
export struct SettingsBudgetEditPage {
  @Prop periodType: string = 'month'
  @Prop totalAmount: string = ''
  @Prop allocationEnabled: boolean = false
  @Prop allocationValues: string[] = []
  @Prop selectedAllocationCategoryIds: number[] = []
  @Prop expenseCategories: CategoryRecord[] = []
  @Prop overflowOverview: BudgetOverview = createEmptyBudgetOverview()
  onCloseEditor: () => void = (): void => {}
  onTotalAmountChange: (value: string) => void = (value: string): void => {}
  onToggleAllocation: () => void = (): void => {}
  onAllocationAmountChange: (index: number, value: string) => void = (index: number, value: string): void => {}
  onToggleAllocationCategory: (cat: CategoryRecord) => void = (cat: CategoryRecord): void => {}
  onSave: () => void = (): void => {}
  private sheetScroller: Scroller = new Scroller()

  private titleText(): string {
    if (this.periodType === 'day') {
      return '编辑日预算'
    }
    if (this.periodType === 'year') {
      return '编辑年预算'
    }
    return '编辑月预算'
  }

  private categoryAmount(index: number): string {
    if (index < 0 || index >= this.allocationValues.length) {
      return ''
    }
    return this.allocationValues[index]
  }

  private money(fen: number): string {
    return '¥' + AmountUtil.rawFen2Display(fen)
  }

  private totalAllocationFen(): number {
    let total = 0
    for (let i = 0; i < this.allocationValues.length; i++) {
      const value = this.allocationValues[i]
      if (value.length > 0) {
        const cat = this.expenseCategories[i]
        if (this.isCategorySelected(cat.id)) {
          total += AmountUtil.yuan2Fen(value)
        }
      }
    }
    return total
  }

  private isCategorySelected(categoryId: number): boolean {
    for (let i = 0; i < this.selectedAllocationCategoryIds.length; i++) {
      if (this.selectedAllocationCategoryIds[i] === categoryId) {
        return true
      }
    }
    return false
  }

  private selectedCategoryCount(): number {
    let count = 0
    for (let i = 0; i < this.expenseCategories.length; i++) {
      if (this.isCategorySelected(this.expenseCategories[i].id)) {
        count += 1
      }
    }
    return count
  }

  private totalBudgetFen(): number {
    if (this.totalAmount.length === 0) {
      return 0
    }
    return AmountUtil.yuan2Fen(this.totalAmount)
  }

  private hasOverflow(): boolean {
    const totalFen = this.totalBudgetFen()
    return this.allocationEnabled && totalFen > 0 && this.totalAllocationFen() > totalFen
  }

  private overflowFen(): number {
    const diff = this.totalAllocationFen() - this.totalBudgetFen()
    return diff > 0 ? diff : 0
  }

  @Builder
  SheetHeader() {
    Stack({ alignContent: Alignment.TopEnd }) {
      Text(this.titleText())
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.color_text_primary'))
        .width('100%')
        .textAlign(TextAlign.Center)
        .padding({ top: 26, bottom: 18 })
      Text('×')
        .fontSize(30)
        .fontColor($r('app.color.color_text_secondary'))
        .width(42)
        .height(42)
        .borderRadius(21)
        .textAlign(TextAlign.Center)
        .margin({ top: 12, right: 14 })
        .onClick(this.onCloseEditor)
    }
    .width('100%')
  }

  @Builder
  TotalRow() {
    Row() {
      Text('总预算')
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.color_text_primary'))
        .width(96)
      Text('¥')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.color_text_primary'))
        .margin({ right: 8 })
      TextInput({ text: this.totalAmount, placeholder: '请输入预算金额' })
        .fontSize(18)
        .fontColor($r('app.color.color_text_primary'))
        .placeholderColor($r('app.color.color_text_secondary'))
        .backgroundColor(Color.Transparent)
        .border({ width: 0 })
        .padding(0)
        .layoutWeight(1)
        .textAlign(TextAlign.End)
        .onChange(this.onTotalAmountChange)
    }
    .width('100%')
    .height(62)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  AllocationHeader() {
    Row() {
      Column() {
        Text('按分类分配')
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.color_text_primary'))
        Text('不设置分类也可以正常统计支出占比')
          .fontSize(12)
          .fontColor($r('app.color.color_text_secondary'))
          .margin({ top: 4 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      Toggle({ type: ToggleType.Switch, isOn: this.allocationEnabled })
        .selectedColor($r('app.color.color_primary'))
        .onChange(() => {
          this.onToggleAllocation()
        })
    }
    .width('100%')
    .height(62)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  AllocationRow(cat: CategoryRecord, index: number) {
    Row() {
      Image($rawfile(cat.icon + '.svg'))
        .width(22)
        .height(22)
        .fillColor(getUnifiedCategoryColor(cat.name))
        .margin({ right: 12 })
      Text(cat.name)
        .fontSize(16)
        .fontColor($r('app.color.color_text_primary'))
        .layoutWeight(1)
      Text('¥')
        .fontSize(15)
        .fontColor($r('app.color.color_text_secondary'))
        .margin({ right: 4 })
      TextInput({ text: this.categoryAmount(index), placeholder: '0.00' })
        .width(112)
        .height(42)
        .fontSize(15)
        .fontColor($r('app.color.color_text_primary'))
        .placeholderColor($r('app.color.color_text_secondary'))
        .backgroundColor($r('app.color.color_bg'))
        .border({ width: 0 })
        .borderRadius(12)
        .padding({ left: 10, right: 10 })
        .textAlign(TextAlign.End)
        .onChange((value: string) => {
          this.onAllocationAmountChange(index, value)
        })
      Text('×')
        .fontSize(20)
        .fontColor($r('app.color.color_text_secondary'))
        .width(28)
        .height(42)
        .textAlign(TextAlign.Center)
        .onClick(() => {
          this.onToggleAllocationCategory(cat)
        })
    }
    .width('100%')
    .height(58)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  AllocationList() {
    Column() {
      ForEach(this.expenseCategories, (cat: CategoryRecord, index: number) => {
        if (this.isCategorySelected(cat.id)) {
          this.AllocationRow(cat, index)
          Divider().color($r('app.color.color_divider')).margin({ left: 34 })
        }
      }, (cat: CategoryRecord) => cat.id.toString())
    }
    .width('100%')
    .padding({ left: 12, right: 12 })
    .backgroundColor($r('app.color.color_surface'))
    .border({ width: 1, color: $r('app.color.color_divider') })
    .borderRadius(16)
  }

  @Builder
  AddCategoryGrid() {
    Column() {
      Row() {
        Text('添加分类分配')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.color_text_primary'))
        Blank()
        Text(this.selectedCategoryCount().toString() + '/' + this.expenseCategories.length.toString())
          .fontSize(12)
          .fontColor($r('app.color.color_text_secondary'))
      }
      .width('100%')
      .margin({ bottom: 10 })

      Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
        ForEach(this.expenseCategories, (cat: CategoryRecord) => {
          if (!this.isCategorySelected(cat.id)) {
            Row() {
              Image($rawfile(cat.icon + '.svg'))
                .width(16)
                .height(16)
                .fillColor(getUnifiedCategoryColor(cat.name))
              Text(cat.name)
                .fontSize(13)
                .fontColor($r('app.color.color_text_primary'))
                .margin({ left: 6 })
            }
            .height(36)
            .padding({ left: 10, right: 10 })
            .borderRadius(12)
            .border({ width: 1, color: $r('app.color.color_divider') })
            .backgroundColor($r('app.color.color_surface'))
            .margin({ right: 8, bottom: 8 })
            .onClick(() => {
              this.onToggleAllocationCategory(cat)
            })
          }
        }, (cat: CategoryRecord) => cat.id.toString())
      }
      .width('100%')
    }
    .width('100%')
    .margin({ top: 12 })
  }

  @Builder
  EditorCard() {
    Column() {
      this.TotalRow()
      Divider().color($r('app.color.color_divider'))
      this.AllocationHeader()
      if (this.allocationEnabled) {
        if (this.selectedCategoryCount() > 0) {
          this.AllocationList()
        } else {
          Column() {
            Text('还没有分类分配')
              .fontSize(15)
              .fontColor($r('app.color.color_text_primary'))
            Text('点击下方分类手动添加，不会默认填满全部分类。')
              .fontSize(12)
              .fontColor($r('app.color.color_text_secondary'))
              .margin({ top: 6 })
          }
          .width('100%')
          .height(82)
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
          .backgroundColor($r('app.color.color_surface'))
          .border({ width: 1, color: $r('app.color.color_divider') })
          .borderRadius(16)
        }
        this.AddCategoryGrid()
        Row() {
          Text('分类分配合计')
            .fontSize(13)
            .fontColor($r('app.color.color_text_secondary'))
          Blank()
          Text(this.money(this.totalAllocationFen()))
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.hasOverflow() ? $r('app.color.color_accent') : $r('app.color.color_text_primary'))
        }
        .width('100%')
        .margin({ top: 12 })
        if (this.hasOverflow()) {
          Text('分类分配已超过总预算 ' + this.money(this.overflowFen()) + '，系统只提醒，不会叠加到总预算。')
            .fontSize(12)
            .fontColor($r('app.color.color_accent'))
            .width('100%')
            .margin({ top: 8 })
        }
      }
    }
    .width('calc(100% - 32vp)')
    .padding({ left: 16, right: 16, bottom: 16 })
    .backgroundColor($r('app.color.color_card_overlay'))
    .border({ width: 1, color: $r('app.color.color_divider') })
    .borderRadius(18)
    .margin({ left: 16, right: 16 })
  }

  build() {
    Column() {
      Row()
        .width(44)
        .height(5)
        .borderRadius(3)
        .backgroundColor($r('app.color.color_divider'))
        .margin({ top: 10 })
      this.SheetHeader()
      Scroll(this.sheetScroller) {
        Column() {
          this.EditorCard()
          Text('分类分配只在当前预算周期内生效，可随时调整。')
            .fontSize(12)
            .fontColor($r('app.color.color_text_secondary'))
            .width('100%')
            .textAlign(TextAlign.Center)
            .margin({ top: 14, bottom: 16 })
        }
        .width('100%')
      }
      .layoutWeight(1)
      .align(Alignment.Top)
      .scrollBar(BarState.Off)

      Row({ space: 14 }) {
        Button('取消')
          .layoutWeight(1)
          .height(50)
          .fontSize(17)
          .fontColor($r('app.color.color_text_primary'))
          .backgroundColor($r('app.color.color_card_overlay'))
          .border({ width: 1, color: $r('app.color.color_divider') })
          .borderRadius(18)
          .onClick(this.onCloseEditor)
        Button('保存')
          .layoutWeight(1)
          .height(50)
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.color_white'))
          .backgroundColor($r('app.color.color_primary'))
          .borderRadius(18)
          .onClick(this.onSave)
      }
      .width('100%')
      .padding({ left: 16, right: 16, bottom: 18 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
    .alignItems(HorizontalAlign.Center)
  }
}
